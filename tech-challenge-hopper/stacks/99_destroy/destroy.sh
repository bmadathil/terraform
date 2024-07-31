#!/bin/bash
source /hopper/func.sh

if [[ ! -f /hopper/runtime/.cluster-id ]]; then
    echo -e "\nFile .cluster-id does not exist in volume - was it already destroyed?"
    exit 1
fi

ABS_SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
SCRIPT_DIR=$( echo $ABS_SCRIPT_DIR | sed 's|.*/||' )
CLUSTER_ID=$(cat /hopper/runtime/.cluster-id)

# log pulumi in to the remote state storage location
hdr "Logging in to remote state storage"
pulumi login s3://pulumi-state-$CLUSTER_ID-$AWS_DEFAULT_REGION

# remove stacks
for dir in $(ls -d *-* | sort -r); do
    
    if [[ "$dir" == "50-workloads" ]]; then
        
        cd /hopper/$dir && ./destroy_all.sh
        
    else
        
        hdr "Deleting $dir stack"
        (
            cd /hopper/$dir &&
            pulumi destroy --stack $CLUSTER_ID-$dir-$AWS_DEFAULT_REGION --yes --skip-preview --logtostderr &&
            pulumi stack rm $CLUSTER_ID-$dir-$AWS_DEFAULT_REGION --yes --logtostderr
        ) || true
        
    fi
done

# remove pulumi state storage bucket
hdr "Deleting S3 bucket"
aws s3 rm s3://pulumi-state-$CLUSTER_ID-$AWS_DEFAULT_REGION --recursive
aws s3api delete-bucket \
--bucket pulumi-state-$CLUSTER_ID-$AWS_DEFAULT_REGION \
--region $AWS_DEFAULT_REGION

# remove cluster id file
hdr "Deleting .cluster-id file"
rm /hopper/runtime/.cluster-id
