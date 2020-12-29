#!/bin/bash

DATA_DIR=/tmp/delta-sample-beta

if [ -d "$DATA_DIR" ]; then
    echo "Cannot proceed if the dir $DATA_DIR exists!"
    exit 1
fi


# needs a dummy entry to represent the beginning of time.
# the URL and checksum values will be ignored
write-delta --data-dir $DATA_DIR -r 0.0.0 -p 0.0.0 --diff-url "http://localhost:8080/nothing" --diff-b2bsum 0 --expected-pck-b2bsum 0


# first update
write-delta --data-dir $DATA_DIR -r 0.0.1 -p 0.0.0 --diff-url "http://localhost:8080/FIRST_DIFF_HERE" --diff-b2bsum ABC --expected-pck-b2bsum  DEF

# second update
write-delta --data-dir $DATA_DIR -r 0.0.2 -p 0.0.1 --diff-url "http://localhost:8080/SECOND_DIFF_HERE" --diff-b2bsum 012 -e 345
