#!/bin/bash

set -e


USAGE="Must provide two arguments: /path/to/old.pck /path/to/new.pck"

if [ -n "$1" ]; then
    OLD_PACK=$1
else
    echo $USAGE
    exit 1
fi

if [ -n "$2" ]; then
    NEW_PACK=$2
else
    echo $USAGE
    exit 1
fi


DIFF_OUT="${OLD_PACK}_to_${NEW_PACK}.diff"
# size of the newer file, in bytes
NEW_SIZE=`du -k "$NEW_PACK" | cut -f1`

NUM_THREADS=8
SORT_PARTITIONS=$((NUM_THREADS - 1))
MAGIC=$((NUM_THREADS * 3))
SCAN_CHUNK_SIZE_FIRST_PASS=$(( NEW_SIZE / MAGIC ))
SCAN_CHUNK_SIZE=$(( SCAN_CHUNK_SIZE > 0 ? SCAN_CHUNK_SIZE : 1 ))


echo "SORT_PARTITIONS $SORT_PARTITIONS"
echo "SCAN_CHUNK_SIZE $SCAN_CHUNK_SIZE"
echo "DIFF_OUT        $DIFF_OUT"

bic diff $OLD_PACK $NEW_PACK $DIFF_OUT --method zstd --sort-partitions $SORT_PARTITIONS --scan-chunk-size $SCAN_CHUNK_SIZE
