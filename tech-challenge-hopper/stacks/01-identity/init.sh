#!/bin/bash
source ./func.sh

ABS_SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
SCRIPT_DIR=$( echo $ABS_SCRIPT_DIR | sed 's|.*/||' )

hdr "Creating $SCRIPT_DIR stack resources"
(
    cd $ABS_SCRIPT_DIR &&
        pnpm install &&
        pulumi stack init $(cat ../runtime/.cluster-id)-$SCRIPT_DIR-$AWS_DEFAULT_REGION &&
        pulumi config set aws:region $AWS_DEFAULT_REGION &&
        pulumi config set cluster_name $CLUSTER_NAME &&
        pulumi config set cluster_domain $CLUSTER_DOMAIN &&
        pulumi config set --secret aws_access_key_id $AWS_ACCESS_KEY_ID &&
        pulumi config set --secret aws_secret_access_key $AWS_SECRET_ACCESS_KEY &&
        pulumi config set --secret github_user $GITHUB_USER &&
        pulumi config set --secret github_pat $GITHUB_USER_PAT &&
        pulumi config set --secret teams_channel_url $TEAMS_CHANNEL_URL &&
        pulumi up --yes --skip-preview --logtostderr
) || true
