#!/bin/bash
source /hopper/func.sh

ABS_SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
SCRIPT_DIR=$( echo $ABS_SCRIPT_DIR | sed 's|.*/||' )

hdr "Processing $SCRIPT_DIR stacks"

# process all directories beginning with a number
for dir in $(ls $ABS_SCRIPT_DIR/[0-9][0-9][0-9][!x]* -d -r); do
    hdr "Deleting $dir stack"
    $dir/x_destroy.sh
done