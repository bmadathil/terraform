#!/bin/bash
source ./func.sh

ABS_SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
SCRIPT_DIR=$( echo $ABS_SCRIPT_DIR | sed 's|.*/||' )

hdr "Processing $SCRIPT_DIR stacks"

# process all directories beginning with a number
for d in $(ls $ABS_SCRIPT_DIR/[0-9][0-9][0-9][!x]* -d); do
    $d/init.sh
done
