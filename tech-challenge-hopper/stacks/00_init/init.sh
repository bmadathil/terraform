#!/bin/bash
source ./func.sh

if [[ -f /hopper/runtime/.cluster-id ]]; then
    echo -e "\nFile .cluster-id already exists in volume - is a cluster already deployed?"
    exit 1
fi

# generate a short, random string to identify the cluster
hdr "Creating random cluster id"
echo $CLUSTER_NAME-$(echo $RANDOM | md5sum | head -c 5) >/hopper/runtime/.cluster-id
msg "Cluster ID: $(cat ./runtime/.cluster-id)"

# create remote state storage for pulumi
hdr "Creating S3 bucket"
shopt -s nocasematch
[[ "$AWS_DEFAULT_REGION" != "us-east-1" ]] && locParam+=(--create-bucket-configuration LocationConstraint=$AWS_DEFAULT_REGION)
aws s3api create-bucket \
    --bucket pulumi-state-$(cat ./runtime/.cluster-id)-$AWS_DEFAULT_REGION \
    --region $AWS_DEFAULT_REGION \
    --acl private "${locParam[@]}"

# after creating the bucket, apply public access block config
aws s3api put-public-access-block \
    --bucket pulumi-state-$(cat ./runtime/.cluster-id)-$AWS_DEFAULT_REGION \
    --region $AWS_DEFAULT_REGION \
    --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

# log pulumi in to the remote state storage location
hdr "Logging in to remote state storage"
pulumi login s3://pulumi-state-$(cat ./runtime/.cluster-id)-$AWS_DEFAULT_REGION
