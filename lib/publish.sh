#!/bin/bash
set -ex

TIMESTAMP=`date +'%Y%m%d_%H_%M_%S'`
TIMESTAMP_LONG=`date +'%Y/%m/%d %H:%M:%S'`
UNAME=`uname`

PRE_RELEASE_OPT="-p"
if [ "$RELEASE" == true ]; then
  PRE_RELEASE_OPT=""

  if [[ $UNAME == Darwin ]]; then
    exit 0
  fi
fi

if [[ -z $SAPMACHINE_GIT_REPOSITORY ]]; then
  SAPMACHINE_GIT_REPOSITORY="http://github.com/SAP/SapMachine.git"
fi

if [ "$SAPMACHINE_VERSION" != "" ]; then
    VERSION_TAG=$SAPMACHINE_VERSION
elif [ "$GIT_REF" != "" ]; then
    VERSION_TAG=$GIT_REF
else
    echo "Neither SAPMACHINE_VERSION nor GIT_REF were set"
    exit 1
fi
python3 SapMachine-Infrastructure/lib/github_publish.py -t $VERSION_TAG $PRE_RELEASE_OPT || true

ls -la

ARCHIVE_NAME_JDK="$(cat jdk_bundle_name.txt)"
ARCHIVE_NAME_JRE="$(cat jre_bundle_name.txt)"
ARCHIVE_NAME_SYMBOLS="$(cat symbols_bundle_name.txt)"

HAS_ZIP=$(ls sapmachine-jdk-*_bin.zip | wc -l)

if [ "$HAS_ZIP" -lt "1" ]; then
    ARCHIVE_SUM_JDK="$(echo $ARCHIVE_NAME_JDK | sed 's/tar\.gz/sha256\.txt/')"
    ARCHIVE_SUM_JRE="$(echo $ARCHIVE_NAME_JRE | sed 's/tar\.gz/sha256\.txt/')"
else
    ARCHIVE_SUM_JDK="$(echo $ARCHIVE_NAME_JDK | sed 's/zip/sha256\.txt/')"
    ARCHIVE_SUM_JRE="$(echo $ARCHIVE_NAME_JRE | sed 's/zip/sha256\.txt/')"
fi
ARCHIVE_SUM_SYMBOLS="$(echo $ARCHIVE_NAME_SYMBOLS | sed 's/tar\.gz/sha256\.txt/')"

shasum -a 256 $ARCHIVE_NAME_JDK > $ARCHIVE_SUM_JDK
shasum -a 256 $ARCHIVE_NAME_JRE > $ARCHIVE_SUM_JRE
shasum -a 256 $ARCHIVE_NAME_SYMBOLS > $ARCHIVE_SUM_SYMBOLS

python3 SapMachine-Infrastructure/lib/github_publish.py -t $VERSION_TAG -a "${ARCHIVE_NAME_JDK}"
python3 SapMachine-Infrastructure/lib/github_publish.py -t $VERSION_TAG -a "${ARCHIVE_NAME_JRE}"
python3 SapMachine-Infrastructure/lib/github_publish.py -t $VERSION_TAG -a "${ARCHIVE_NAME_SYMBOLS}"
python3 SapMachine-Infrastructure/lib/github_publish.py -t $VERSION_TAG -a "${ARCHIVE_SUM_JDK}"
python3 SapMachine-Infrastructure/lib/github_publish.py -t $VERSION_TAG -a "${ARCHIVE_SUM_JRE}"
python3 SapMachine-Infrastructure/lib/github_publish.py -t $VERSION_TAG -a "${ARCHIVE_SUM_SYMBOLS}"

if [ $UNAME == Darwin ]; then
    DMG_NAME_JDK="$(cat jdk_dmg_name.txt)"
    DMG_NAME_JRE="$(cat jre_dmg_name.txt)"

    DMG_SUM_JDK="$(echo $DMG_NAME_JDK | sed 's/dmg/sha256\.dmg\.txt/')"
    DMG_SUM_JRE="$(echo $DMG_NAME_JRE | sed 's/dmg/sha256\.dmg\.txt/')"

    shasum -a 256 $DMG_NAME_JDK > $DMG_SUM_JDK
    shasum -a 256 $DMG_NAME_JRE > $DMG_SUM_JRE

    python3 SapMachine-Infrastructure/lib/github_publish.py -t $VERSION_TAG -a "${DMG_NAME_JDK}"
    python3 SapMachine-Infrastructure/lib/github_publish.py -t $VERSION_TAG -a "${DMG_NAME_JRE}"
    python3 SapMachine-Infrastructure/lib/github_publish.py -t $VERSION_TAG -a "${DMG_SUM_JDK}"
    python3 SapMachine-Infrastructure/lib/github_publish.py -t $VERSION_TAG -a "${DMG_SUM_JRE}"
fi
