#!/bin/bash
set -euo pipefail

# uncomment to echo all commands, if needed, for debugging
#set -x

source ./func.sh

hdr Checking for AWS env vars

HOPPER_COMMAND=${1:-help}  

# if [ -z ${HOPPER_PROFILE+x} ]; then echo "HOPPER_PROFILE must be set"; exit 1; fi
# if [ -z ${AWS_ACCESS_KEY_ID+x} ]; then echo "AWS_ACCESS_KEY_ID must be set"; exit 1; fi
# if [ -z ${AWS_SECRET_ACCESS_KEY+x} ]; then echo "AWS_SECRET_ACCESS_KEY must be set"; exit 2; fi
# if [ -z ${AWS_SESSION_TOKEN+x} ]; then echo "AWS_SESSION_TOKEN must be set"; exit 3; fi

# builds and launches a local container for Hopper debugging
hdr Building local container

docker buildx build -t hopper .

hdr Starting local container

time docker run --rm -tiv $(pwd)/runtime:/hopper/runtime \
    --env-file env-vars \
    --env-file <(aws configure export-credentials --profile $HOPPER_PROFILE --format env-no-export) \
    hopper $HOPPER_COMMAND
