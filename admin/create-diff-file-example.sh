#!/bin/bash

OLD_PACK="beta-0.0.0.pck"
NEW_PACK="beta-0.0.1.pck"
DIFF_OUT="beta-0.0.0.pck_to_beta.0.0.1.pck.diff"
NEW_SIZE=`du -k "$NEW_PACK" | cut -f1`

NUM_THREADS=8
SORT_PARTITIONS="$(($NUM_THREADS - 1))"
MAGIC="$(($NUM_THREADS * 3))"
SCAN_CHUNK_SIZE_FIRST_PASS=$(( NEW_SIZE / MAGIC ))
SCAN_CHUNK_SIZE=$(( SCAN_CHUNK_SIZE > 0 ? SCAN_CHUNK_SIZE : 1 ))

echo "SORT_PARTITIONS $SORT_PARTITIONS"
echo "SCAN_CHUNK_SIZE $SCAN_CHUNK_SIZE"

bic diff $OLD_PACK $NEW_PACK $DIFF_OUT --method zstd --sort-partitions $SORT_PARTITIONS --scan-chunk-size $SCAN_CHUNK_SIZE
