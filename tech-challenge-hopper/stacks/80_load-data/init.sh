#!/bin/bash
source ./func.sh

dir="80_load-data"

hdr "Copying contents of data folder to S3 for processing"

aws s3 cp /hopper/runtime/data s3://$CLUSTER_NAME-data-bucket/ --recursive --include "*.csv"

hdr "All CSV files uploaded!"
