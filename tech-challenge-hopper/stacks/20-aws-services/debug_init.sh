#!/bin/bash
set -euxo pipefail

ABS_SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
SCRIPT_DIR=$( echo $ABS_SCRIPT_DIR | sed 's|.*/||' )

pnpm install &&
pulumi stack select organization/$(cat ../runtime/.cluster-id)-$SCRIPT_DIR-$AWS_DEFAULT_REGION &&
pulumi config set aws:region $AWS_DEFAULT_REGION &&
pulumi config set hopper-aws-services:identityStackRef organization/hopper-identity/$(cat ../runtime/.cluster-id)-01-identity-$AWS_DEFAULT_REGION &&
pulumi config set hopper-aws-services:infrastructureStackRef organization/hopper-infrastructure/$(cat ../runtime/.cluster-id)-11-infrastructure-$AWS_DEFAULT_REGION 
