#!/bin/bash
set -ex

MAJOR_VERSION=$1

BASE_BRANCH="sapmachine"
GREP_PATTERN="(sapmachine$)"
if [[ $MAJOR_VERSION == 10* ]]; then
  BASE_BRANCH="sapmachine10"
  GREP_PATTERN="(sapmachine10)"
fi
if [[ $MAJOR_VERSION == 11* ]]; then
  BASE_BRANCH="sapmachine11"
  GREP_PATTERN="(sapmachine11)"
fi
if [[ $MAJOR_VERSION == 12* ]]; then
  BASE_BRANCH="sapmachine12"
  GREP_PATTERN="(sapmachine12)"
fi

if [ -d SapMachine ]; then
    rm -rf SapMachine;
fi
export GIT_COMMITTER_NAME=$GIT_USER
export GIT_COMMITTER_EMAIL="sapmachine@sap.com"
git clone -b $BASE_BRANCH "http://$GIT_USER:$GIT_PASSWORD@$SAPMACHINE_GIT_REPO" SapMachine

pushd SapMachine
git config user.email $GIT_COMMITTER_EMAIL
git config user.name $GIT_COMMITTER_NAME

REGEXP="s/jdk\-$MAJOR_VERSION\+([0-9]*)/\1/p"
LAST_BUILD_JDK_TAG=$(git tag | sed -rn $REGEXP | sort -nr | head -n1)

JDK_TAG="jdk-$MAJOR_VERSION+$LAST_BUILD_JDK_TAG"
echo "LAST_JDK_TAG=$LAST_BUILD_JDK_TAG"

BRANCHES=( "$BASE_BRANCH" )
for base in "${BRANCHES[@]}"
do
  git checkout $base
  GREP_PATTERN="($base$)"
  set +e
  JDK_TAG_CONTAINING_BRANCH=$(git branch -a --contains tags/jdk-$MAJOR_VERSION+$LAST_BUILD_JDK_TAG 2> /dev/null | \
  grep -E $GREP_PATTERN )

  echo "$JDK_TAG_CONTAINING_BRANCH"

  SAPMACHINE_TAG="sapmachine-$MAJOR_VERSION+$LAST_BUILD_JDK_TAG-0"
  SAPMACHINE_TAG_CONTAINING_BRANCH=$(git branch -a --contains tags/$SAPMACHINE_TAG 2> /dev/null | \
  grep -E $GREP_PATTERN )
  echo "$SAPMACHINE_TAG_CONTAINING_BRANCH"
  set -e

  if [ "$JDK_TAG_CONTAINING_BRANCH" ] && [ -z "$SAPMACHINE_TAG_CONTAINING_BRANCH" ] ; then

    echo "Create tag $SAPMACHINE_TAG"
    git checkout $base
    git tag $SAPMACHINE_TAG
    git push --tags

    URL_TAG=$(echo $SAPMACHINE_TAG | sed 's/\+/\%2B/g')
    CRUMB=$(curl --user $JENKINS_PASSWORD  $JENKINS_URL/crumbIssuer/api/xml?xpath=concat\(//crumbRequestField,%22:%22,//crumb\))

    curl -H $CRUMB -X POST --user $JENKINS_PASSWORD \
    "$JENKINS_URL/job/build-$MAJOR_VERSION-release-linux_x86_64/buildWithParameters?TOKEN=test-token&GIT_TAG_NAME=$URL_TAG&PUBLISH=true&RUN_TESTS=true"
    curl -H $CRUMB -X POST --user $JENKINS_PASSWORD \
    "$JENKINS_URL/job/build-$MAJOR_VERSION-release-linux_ppc64le/buildWithParameters?TOKEN=test-token&GIT_TAG_NAME=$URL_TAG&PUBLISH=true&RUN_TESTS=true&PROPAGATE_RESULT=false" || true
    curl -H $CRUMB -X POST --user $JENKINS_PASSWORD \
    "$JENKINS_URL/job/build-$MAJOR_VERSION-release-linux_ppc64/buildWithParameters?TOKEN=test-token&GIT_TAG_NAME=$URL_TAG&PUBLISH=true&RUN_TESTS=true&PROPAGATE_RESULT=false" || true
    curl -H $CRUMB -X POST --user $JENKINS_PASSWORD \
    "$JENKINS_URL/job/build-$MAJOR_VERSION-release-windows_x86_64/buildWithParameters?TOKEN=test-token&GIT_TAG_NAME=$URL_TAG&PUBLISH=true&RUN_TESTS=true&PROPAGATE_RESULT=false" || true
    curl -H $CRUMB -X POST --user $JENKINS_PASSWORD \
    "$JENKINS_URL/job/build-$MAJOR_VERSION-release-macos_x86_64/buildWithParameters?TOKEN=test-token&GIT_TAG_NAME=$URL_TAG&PUBLISH=true&RUN_TESTS=true&PROPAGATE_RESULT=false" || true
  fi
done
