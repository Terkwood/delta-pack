#!/bin/bash

DATA_DIR=/tmp/delta-sample-beta

PATCH_SERVER="http://192.168.86.29:8080"

if [ -d "$DATA_DIR" ]; then
    echo "Cannot proceed if the dir $DATA_DIR exists!"
    exit 1
fi


# needs a dummy entry to represent the beginning of time.
# the URL and checksum values will be ignored
write-delta --data-dir $DATA_DIR -r 0.0.0 -p 0.0.0 --diff-url "$PATCH_SERVER/nothing" --diff-b2bsum 0 --expected-pck-b2bsum 0


# first update
write-delta --data-dir $DATA_DIR -r 0.0.1 -p 0.0.0 --diff-url "$PATCH_SERVER/beta-0.0.0.pck_to_beta-0.0.1.pck.diff" --diff-b2bsum `cat beta-0.0.0.pck_to_beta-0.0.1.pck.diff.b2bsum` --expected-pck-b2bsum  `cat beta-0.0.1.pck.b2bsum`

# second update
write-delta --data-dir $DATA_DIR -r 0.0.2 -p 0.0.1 --diff-url "$PATCH_SERVER/beta-0.0.1.pck_to_beta-0.0.2.pck.diff" --diff-b2bsum `cat beta-0.0.1.pck_to_beta-0.0.2.pck.diff.b2bsum` -e `cat beta-0.0.2.pck.b2bsum`
