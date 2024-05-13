#!/bin/bash

set -ex

if [ -n "${1}" ]; then
    REPONAME=$1
fi

echo ${REPONAME}
echo "done"

