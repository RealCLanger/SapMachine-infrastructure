#!/bin/bash
set -e

DEPTH_OPTION="--depth 1"
PR_REF=
PR_SPEC=
if [ ! -z $4 ]; then
  DEPTH_OPTION=
  PR_REF=pull/$4/head
  PR_SPEC=$PR_REF:pr
fi

if [[ `uname` == CYGWIN* ]]; then
  GIT_TOOL="/cygdrive/c/Program Files/Git/cmd/git.exe"
  GIT_TOOL_FOR_EVAL="/cygdrive/c/Program\ Files/Git/cmd/git.exe"
else
  GIT_TOOL=git
  GIT_TOOL_FOR_EVAL=git
fi

if [ ! -z $GIT_USER ]; then
  GIT_CREDENTIALS="-c credential.helper='!f() { sleep 1; echo \"username=${GIT_USER}\"; echo \"password=${GIT_PASSWORD}\"; }; f'"
fi

"$GIT_TOOL" --version
(set -ex && "$GIT_TOOL" init $2)
cd $2

if GIT_TERMINAL_PROMPT=0 "$GIT_TOOL" ls-remote --tags "$1" | grep -q "refs/tags/$3"; then
  # we have a tag
  (set -ex && GIT_TERMINAL_PROMPT=0 eval "$GIT_TOOL_FOR_EVAL" $GIT_CREDENTIALS fetch $DEPTH_OPTION $1 $3 $PR_SPEC)
  (set -ex && "$GIT_TOOL" checkout $3)
  if [ ! -z $4 ]; then
    echo "Should not happen: Try to merge $4 into tag $3"
    exit -1
  fi
elif GIT_TERMINAL_PROMPT=0 "$GIT_TOOL" ls-remote --heads "$1" | grep -q "refs/heads/$3"; then
  # we have a branch
  (set -ex && GIT_TERMINAL_PROMPT=0 eval "$GIT_TOOL_FOR_EVAL" $GIT_CREDENTIALS fetch --no-tags $DEPTH_OPTION $1 $3:ref $PR_SPEC)
  (set -ex && "$GIT_TOOL" checkout ref)
  if [ ! -z $4 ]; then
    git config user.name SAPMACHINE_PR_TEST
    git config user.email sapmachine@sap.com
    (set -ex && "$GIT_TOOL" merge pr)
  fi
else
  echo "$3 is not a valid git reference"
  exit -1
fi
