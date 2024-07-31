#!/bin/bash
source ./func.sh

ABS_SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
SCRIPT_DIR=$( echo $ABS_SCRIPT_DIR | sed 's|.*/||' )

hdr "Creating $SCRIPT_DIR stack resources"
(
    cd $ABS_SCRIPT_DIR &&
        pnpm install &&
        pulumi stack init organization/$(cat ../../runtime/.cluster-id)-$SCRIPT_DIR-$AWS_DEFAULT_REGION &&
        pulumi config set aws:region $AWS_DEFAULT_REGION &&
        pulumi config set hopper-workloads-$SCRIPT_DIR:identityStackRef organization/hopper-identity/$(cat ../../runtime/.cluster-id)-01-identity-$AWS_DEFAULT_REGION &&
        pulumi config set hopper-workloads-$SCRIPT_DIR:infrastructureStackRef organization/hopper-infrastructure/$(cat ../../runtime/.cluster-id)-11-infrastructure-$AWS_DEFAULT_REGION &&
        pulumi config set hopper-workloads-$SCRIPT_DIR:serviceStackRef organization/hopper-aws-services/$(cat ../../runtime/.cluster-id)-20-aws-services-$AWS_DEFAULT_REGION &&
        pulumi up --yes --skip-preview --logtostderr
) || true
