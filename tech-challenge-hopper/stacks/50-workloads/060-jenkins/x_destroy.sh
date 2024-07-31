#!/bin/bash
set -euo pipefail

ABS_SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
SCRIPT_DIR=$( echo $ABS_SCRIPT_DIR | sed 's|.*/||' )
CLUSTER_ID=$(cat /hopper/runtime/.cluster-id)

(
    pulumi destroy --stack organization/hopper-workloads-$SCRIPT_DIR/$CLUSTER_ID-$SCRIPT_DIR-$AWS_DEFAULT_REGION --yes --skip-preview --logtostderr &&
    pulumi stack rm organization/hopper-workloads-$SCRIPT_DIR/$CLUSTER_ID-$SCRIPT_DIR-$AWS_DEFAULT_REGION --yes --logtostderr
) || true
