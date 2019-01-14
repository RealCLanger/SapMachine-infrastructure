'''
Copyright (c) 2001-2018 by SAP SE, Walldorf, Germany.
All rights reserved. Confidential and proprietary.
'''

import os
import sys
import json
import re
import utils
import argparse

from os.path import join
from string import Template

template_alpine ='''
FROM alpine:3.5

MAINTAINER Rene Schuenemann <sapmachine@sap.com>

RUN apk update; \
    apk add ${dependencies};

WORKDIR /etc/apk/keys
RUN wget https://dist.sapmachine.io/alpine/sapmachine%40sap.com-5a673212.rsa.pub

WORKDIR /

RUN echo "http://dist.sapmachine.io/alpine/3.5" >> /etc/apk/repositories

RUN apk update; \
    apk add ${package};

${add_user}
'''

template_ubuntu = '''
FROM ubuntu:16.04

MAINTAINER Rene Schuenemann <sapmachine@sap.com>

RUN rm -rf /var/lib/apt/lists/* && apt-get clean && apt-get update \\
    && apt-get install -y --no-install-recommends ${dependencies} \\
    && rm -rf /var/lib/apt/lists/*

RUN wget -q -O - https://dist.sapmachine.io/debian/sapmachine.key | apt-key add - \\
    && echo "deb http://dist.sapmachine.io/debian/amd64/ ./" >> /etc/apt/sources.list \\
    && apt-get update \\
    && apt-get -y --no-install-recommends install ${package}

${add_user}
'''

def main(argv=None):
    parser = argparse.ArgumentParser()
    parser.add_argument('-t', '--tag', help='the GIT tag to build the image from', metavar='GIT_TAG', required=True)
    parser.add_argument('-i', '--imagetype', help='sets the image type', choices=['jdk', 'jre', 'test'], required=True)
    parser.add_argument('-p', '--publish', help='publish the image', action='store_true', default=False)
    parser.add_argument('--alpine', help='build Alpine Linux image', action='store_true', default=False)
    parser.add_argument('--latest', help='tag image as latest', action='store_true', default=False)
    parser.add_argument('--workdir', help='specify the working directory', metavar='DIR', required=False)
    args = parser.parse_args()

    tag = args.tag
    image_type = args.imagetype
    publish = args.publish
    build_alpine = args.alpine
    latest = args.latest
    workdir = args.workdir

    version, version_part, major, build_number, sap_build_number, os_ext = utils.sapmachine_tag_components(tag)

    if version is None:
        raise Exception(str.format('Invalid tag: {0}', tag))

    dependencies = 'wget ca-certificates'

    if image_type == 'test':
        if build_alpine:
            dependencies += ' zip git unzip coreutils python binutils shadow bash'
            add_user = 'RUN groupadd -g 1002 jenkins; useradd -ms /bin/bash jenkins -u 1002 -g 1002'
        else:
            dependencies += ' zip git unzip realpath python binutils'
            add_user = 'RUN useradd -ms /bin/bash jenkins -u 1002'
    else:
        add_user = ''

    if build_alpine:
        package = str.format('sapmachine-{0}-{1}={2}.{3}.{4}-r0',
            major,
             'jdk' if image_type == 'test' else image_type,
            version_part,
            build_number,
            sap_build_number)
    else:
        package = str.format('sapmachine-{0}-{1}={2}+{3}.{4}',
            major,
            'jdk' if image_type == 'test' else image_type,
            version_part,
            build_number,
            sap_build_number)

    if workdir is None:
        workdir = join(os.getcwd(), 'docker_work', image_type)

    utils.remove_if_exists(workdir)
    os.makedirs(workdir)

    if build_alpine:
        template = template_alpine
    else:
        template = template_ubuntu

    with open(join(workdir, 'Dockerfile'), 'w+') as dockerfile:
        dockerfile.write(Template(template).substitute(dependencies=dependencies, package=package, add_user=add_user))

    if 'DOCKER_USER' in os.environ and image_type != 'test':
        docker_user = os.environ['DOCKER_USER']
        match = re.match(r'([0-9]+)(\.[0-9]+)?(\.[0-9]+)?', version_part)
        version_part_expanded = version_part

        i = 0
        while i < (3 - match.lastindex):
            version_part_expanded += '.0'
            i += 1

        docker_tag = str.format('{0}/jdk{1}:{2}.{3}.{4}{5}{6}',
            docker_user,
            major,
            version_part_expanded,
            build_number,
            sap_build_number,
            '-jre' if image_type == 'jre' else '',
            '-alpine' if build_alpine else '')

        docker_tag_latest = str.format('{0}/jdk{1}:latest{2}{3}',
            docker_user,
            major,
            '-jre' if image_type == 'jre' else '',
            '-alpine' if build_alpine else '')

        if latest:
            utils.run_cmd(['docker', 'build', '-t', docker_tag, '-t', docker_tag_latest, workdir])
        else:
            utils.run_cmd(['docker', 'build', '-t', docker_tag, workdir])


        retcode, out, err = utils.run_cmd(['docker', 'run', docker_tag, 'java', '-version'], throw=False, std=True)

        if retcode != 0:
            raise Exception(str.format('Failed to run Docker image: {0}', err))

        version_2, version_part_2, major_2, build_number_2, sap_build_number_2 = utils.sapmachine_version_components(err, multiline=True)

        if version_part != version_part_2 or build_number != build_number_2 or sap_build_number != sap_build_number_2:
           raise Exception(str.format('Invalid version found in Docker image:\n{0}', err))


        retcode, out, err = utils.run_cmd(['docker', 'run', docker_tag, 'which', 'javac'], throw=False, std=True)

        if image_type == 'jdk':
            if retcode != 0 or not out:
                raise Exception('Image type is not JDK')
        else:
            if retcode == 0:
                raise Exception('Image type is not JRE')

        if publish and 'DOCKER_PASSWORD' in os.environ:
            docker_password = os.environ['DOCKER_PASSWORD']
            utils.run_cmd(['docker', 'login', '-u', docker_user, '-p', docker_password])
            utils.run_cmd(['docker', 'push', docker_tag])

            if latest:
                utils.run_cmd(['docker', 'push', docker_tag_latest])

if __name__ == "__main__":
    sys.exit(main())
