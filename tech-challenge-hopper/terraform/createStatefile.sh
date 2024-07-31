#!/bin/bash

# Set variables
BUCKET_NAME="tech-chal-unique-terraform-state-bucket"
REGION="us-east-1"

# Create the S3 bucket
echo "Creating S3 bucket: $BUCKET_NAME"
aws s3api create-bucket --bucket $BUCKET_NAME --region $REGION

# Enable versioning
echo "Enabling versioning on the bucket"
aws s3api put-bucket-versioning --bucket $BUCKET_NAME --versioning-configuration Status=Enabled

# Enable server-side encryption
echo "Enabling server-side encryption"
aws s3api put-bucket-encryption --bucket $BUCKET_NAME --server-side-encryption-configuration '{
    "Rules": [
        {
            "ApplyServerSideEncryptionByDefault": {
                "SSEAlgorithm": "AES256"
            }
        }
    ]
}'

# Add a bucket policy (optional, adjust as needed)
echo "Adding bucket policy"
aws s3api put-bucket-policy --bucket $BUCKET_NAME --policy '{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "EnforceTLS",
            "Effect": "Deny",
            "Principal": "*",
            "Action": "s3:*",
            "Resource": [
                "arn:aws:s3:::'"$BUCKET_NAME"'",
                "arn:aws:s3:::'"$BUCKET_NAME"'/*"
            ],
            "Condition": {
                "Bool": {
                    "aws:SecureTransport": "false"
                }
            }
        }
    ]
}'

echo "S3 bucket created and configured successfully"

