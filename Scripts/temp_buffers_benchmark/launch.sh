#!/bin/sh

postgres --version > results/pgver.res

for it in $(seq 1 30); do
  echo "ITERATION: $it"
  for i in $(seq 20 2 32); do
    bytes=$((2**i));
    nblocks=$(($bytes/8192));
    echo "2^$i $bytes, $nblocks";
    psql -vnbuffers="$nblocks" -f flush-read-pages.sql > results/blocks-$nblocks-iter-$it.res
  done
  
  echo "Cooling down for 30 seconds..."
  sleep 30
done