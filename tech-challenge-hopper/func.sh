#!/bin/bash
set -e

### shared functions for common messaging

# decode and display a banner string
bnr() {
  echo $1 | base64 -d | gunzip
}

# header
hdr() {
  echo -e "\n\n----- $@ -----"
}

# message
msg() {
  echo -e "\n$@"
}

if [[ "$BASH_SOURCE" == "$0" ]]; then
  $*
fi