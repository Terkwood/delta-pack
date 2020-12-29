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
write-delta --data-dir $DATA_DIR -r 0.0.1 -p 0.0.0 --diff-url "http://localhost:8080/beta-0.0.0.pck_to_beta-0.0.1.pck.diff" --diff-b2bsum b190af8bc9be9a3c151a4da310a768382324275c7f8a3cd6921a434127b33de23d1cf3839503bf435beaf51a7c05a320afaecd21f5f82f5806f33c70f7f1152d --expected-pck-b2bsum  6335cdb952c209e9682c9e4631ebee7e6415b0eee39ac25d183e3373a4b897617a79f0dfae50f4d3a6e7694aadda8f73a265e2608aa36df6dfe2ef35e77e954f

# second update
write-delta --data-dir $DATA_DIR -r 0.0.2 -p 0.0.1 --diff-url "http://localhost:8080/beta-0.0.1.pck_to_beta-0.0.2.pck.diff" --diff-b2bsum 677938de482dca72d11f973cd9c4281fbe72eb2b966b1c861fc7a8f34a8b9f6c9d5d109be8e609b775d851f62574e6ce41175b22b7cbd4525bc146577f1b90e2 -e 57d633fcb116310f900d6ed515710ec5d8acca57b29bc4b9a45b4eed4dd0134a7531dd80b19d4dc227925d0aa36224b09cdf98c5bd1b7342d239010e58cb78a9
