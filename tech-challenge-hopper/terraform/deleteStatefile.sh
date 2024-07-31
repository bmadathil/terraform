#!/bin/bash

BUCKET="tech-chal-unique-terraform-state-bucket"

# Delete non-current versions
aws s3api list-object-versions --bucket "$BUCKET" --output=json | \
jq -r '.Versions[] | .Key + " " + .VersionId' | \
while read key version; do
    echo "Deleting $key version $version"
    aws s3api delete-object --bucket "$BUCKET" --key "$key" --version-id "$version"
done

# Delete delete markers
aws s3api list-object-versions --bucket "$BUCKET" --output=json | \
jq -r '.DeleteMarkers[] | .Key + " " + .VersionId' | \
while read key version; do
    echo "Deleting delete marker $key version $version"
    aws s3api delete-object --bucket "$BUCKET" --key "$key" --version-id "$version"
done

echo "Bucket contents deleted"
