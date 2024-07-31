#!/bin/bash
set -euxo pipefail

ABS_SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
SCRIPT_DIR=$( echo $ABS_SCRIPT_DIR | sed 's|.*/||' )

pnpm install &&
pulumi stack select organization/$(cat ../../runtime/.cluster-id)-$SCRIPT_DIR-$AWS_DEFAULT_REGION &&
pulumi config set aws:region $AWS_DEFAULT_REGION &&
pulumi config set hopper-workloads-$SCRIPT_DIR:serviceStackRef organization/hopper-aws-services/$(cat ../../runtime/.cluster-id)-20-aws-services-$AWS_DEFAULT_REGION
