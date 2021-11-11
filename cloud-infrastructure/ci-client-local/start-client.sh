#!/bin/sh

SERVER_URL=$1
SECRET=$2
CLIENT_NO_CERTIFICATE_CHECK=$3

JAVA_ARGS="-Xms4g"

if [ -f nohup.out ]; then
    mv nohup.out "client-$(date +"%d_%m_%y-%H_%M_%S_%N").out"
fi

nohup ./sapmachine-jre/bin/java -jar /home/jenkins/client.jar -jnlpUrl ${SERVER_URL} -secret ${SECRET} -workDir /home/jenkins/client-home ${CLIENT_NO_CERTIFICATE_CHECK} > nohup.out 2>&1 &
