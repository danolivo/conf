#!/bin/sh
for it in $(seq 1 10); do
  echo "ITERATION: $it"
  for i in $(seq 20 2 32); do
    bytes=$((2**i));
    nblocks=$(($bytes/8192));
    echo "2^$i $bytes, $nblocks";
    psql -vnbuffers="$nblocks" -f flush-read-pages.sql > results/blocks-$nblocks-iter-$it.res
  done
done