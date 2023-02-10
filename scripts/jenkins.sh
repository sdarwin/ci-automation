#!/bin/bash

# A script to run lcov and gcovr on a pull request, generating coverage reports.

# Run in a docker container ubuntu:22.04

# ----------------
# First, configuring a few variables and settings that would already be available in a Jenkins job but 
# if run in standalone mode would need to be set
# ----------------

set -xe

apt-get update
apt-get install sudo

REPONAME=url
ORGANIZATION=CPPAlliance
ghprbTargetBranch=develop
JOBFOLDER="${REPONAME}_job_folder"

echo "Initial cleanup. Remove job folder"
rm -rf ${JOBFOLDER}
echo "Remove target folder"
rm -rf ${REPONAME}
echo "Remove boost-root"
rm -rf boost-root

git clone https://github.com/$ORGANIZATION/$REPONAME ${JOBFOLDER}
cd ${JOBFOLDER}

# ----------------
# The main script
# ----------------

set -xe

if [ -z "${REPONAME}" ]; then
        echo "Please set the env variable REPONAME"
        exit 1
fi

if [ -z "${ORGANIZATION}" ]; then
        echo "Please set the env variable ORGANIZATION"
        exit 1
fi

# these packages are already installed on containers.

# already run, above:
# sudo apt-get update
sudo apt-get install -y python3-pip sudo git curl jq

# Based on drone.sh. Copied everything from there and modified.

export DRONE_JOB_BUILDTYPE="codecov"
export B2_TOOLSET="gcc-11"
export COVERALLS_REPO_TOKEN="xyz"
export CODECOV_TOKEN="abc"

export TRAVIS_BUILD_DIR=$(pwd)
export DRONE_BUILD_DIR=$(pwd)
export TRAVIS_BRANCH=$DRONE_BRANCH
export TRAVIS_EVENT_TYPE=$DRONE_BUILD_EVENT
export VCS_COMMIT_ID=$DRONE_COMMIT
export GIT_COMMIT=$DRONE_COMMIT
export REPO_NAME=${ORGANIZATION}/${REPONAME}
export USER=$(whoami)
export CC=${CC:-gcc}
export PATH=~/.local/bin:/usr/local/bin:$PATH
export BOOST_CI_CODECOV_IO_UPLOAD="skip"

common_install () {
  git clone https://github.com/boostorg/boost-ci.git boost-ci-cloned --depth 1
  cp -prf boost-ci-cloned/ci .
  rm -rf boost-ci-cloned
  
  if [ "$TRAVIS_OS_NAME" == "osx" ]; then
      unset -f cd
  fi
  
  export SELF=`basename $REPO_NAME`
  export BOOST_CI_TARGET_BRANCH="$TRAVIS_BRANCH"
  export BOOST_CI_SRC_FOLDER=$(pwd)
  
  . ./ci/common_install.sh
}

# if [ "$DRONE_JOB_BUILDTYPE" == "codecov" ]; then

echo '==================================> INSTALL'

common_install

echo '==================================> SCRIPT'

cd $BOOST_ROOT/libs/$SELF
ci/travis/codecov.sh

# coveralls
# uses multiple lcov steps from boost-ci codecov.sh script
if [ -n "${COVERALLS_REPO_TOKEN}" ]; then
    # actually, not "processing coveralls"
    # pip3 install --user cpp-coveralls
    pip3 install --user gcovr
    cd $BOOST_CI_SRC_FOLDER

    export PATH=/tmp/lcov/bin:$PATH
    command -v lcov
    lcov --version

    lcov --remove coverage.info -o coverage_filtered.info '*/test/*' '*/extra/*'
    # cpp-coveralls --verbose -l coverage_filtered.info
fi

# Now the tracefile is coverage_filtered.info
genhtml -o genhtml coverage_filtered.info

# gcovr

GCOVRFILTER_ORIG_EXAMPLE='.*/http_proto/.*'
GCOVRFILTER=".*/$REPONAME/.*"
mkdir gcovr
mkdir -p json
cd ../boost-root
gcovr -p --html-details --exclude '.*/test/.*' --exclude '.*/extra/.*' --filter "$GCOVRFILTER" --html --output $BOOST_CI_SRC_FOLDER/gcovr/index.html
ls -al $BOOST_CI_SRC_FOLDER/gcovr

gcovr -p --json-summary --exclude '.*/test/.*' --exclude '.*/extra/.*' --filter "$GCOVRFILTER" --output $BOOST_CI_SRC_FOLDER/json/summary.pr.json
echo "Original summary"
jq . $BOOST_CI_SRC_FOLDER/json/summary.pr.json

# ---------------------------------------------------------------------
# RUN EVERYTHING AGAIN the same way on the target branch, usually develop
# ---------------------------------------------------------------------

# preparation:

# change this to an env variable from pull request builder:
TARGET_BRANCH=$ghprbTargetBranch

cd $BOOST_CI_SRC_FOLDER
BOOST_CI_SRC_FOLDER_ORIG=$BOOST_CI_SRC_FOLDER
rm -rf ../boost-root
cd ..
git clone -b $TARGET_BRANCH https://github.com/$ORGANIZATION/$SELF
cd $SELF
# The "new" BOOST_CI_SRC_FOLDER:
export BOOST_CI_SRC_FOLDER=$(pwd)
export BOOST_CI_SRC_FOLDER_TARGET=$(pwd)

# done with prep, now everything is the same as before

echo '==================================> INSTALL (target branch)'

common_install

echo '==================================> SCRIPT'

cd $BOOST_ROOT/libs/$SELF
ci/travis/codecov.sh

# coveralls
# uses multiple lcov steps from boost-ci codecov.sh script
if [ -n "${COVERALLS_REPO_TOKEN}" ]; then
    # actually, not "processing coveralls"
    # pip3 install --user cpp-coveralls
    pip3 install --user gcovr
    cd $BOOST_CI_SRC_FOLDER

    export PATH=/tmp/lcov/bin:$PATH
    command -v lcov
    lcov --version

    lcov --remove coverage.info -o coverage_filtered.info '*/test/*' '*/extra/*'
    # cpp-coveralls --verbose -l coverage_filtered.info
fi

# Now the tracefile is coverage_filtered.info
genhtml -o genhtml coverage_filtered.info

# gcovr

GCOVRFILTER_ORIG_EXAMPLE='.*/http_proto/.*'
GCOVRFILTER=".*/$REPONAME/.*"
mkdir gcovr
mkdir -p json
cd ../boost-root
gcovr -p --html-details --exclude '.*/test/.*' --exclude '.*/extra/.*' --filter "$GCOVRFILTER" --html --output $BOOST_CI_SRC_FOLDER/gcovr/index.html
ls -al $BOOST_CI_SRC_FOLDER/gcovr

gcovr -p --json-summary --exclude '.*/test/.*' --exclude '.*/extra/.*' --filter "$GCOVRFILTER" --output $BOOST_CI_SRC_FOLDER/json/summary.targetbranch.json
echo "Target branch summary"
jq . $BOOST_CI_SRC_FOLDER/json/summary.targetbranch.json

# Done with building target branch. Return everything back.

BOOST_CI_SRC_FOLDER=$BOOST_CI_SRC_FOLDER_ORIG
cd $BOOST_CI_SRC_FOLDER

# gcov-compare.py. download and run it.

mkdir -p ~/.local/bin
GITHUB_REPO_URL="https://github.com/CPPAlliance/ci-automation/raw/master"
DIR="scripts"
FILENAME="gcov-compare.py"
URL="${GITHUB_REPO_URL}/$DIR/$FILENAME"
FILE=~/.local/bin/$FILENAME 
if [ ! -f "$FILE" ]; then
    curl -s -S --retry 10 -L -o $FILE $URL && chmod 755 $FILE
fi

$FILE $BOOST_CI_SRC_FOLDER_ORIG/json/summary.pr.json $BOOST_CI_SRC_FOLDER_TARGET/json/summary.targetbranch.json > gcovr/coverage_diff.txt


