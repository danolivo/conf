#!/bin/sh

postgres --version > results/pgver.res

for it in $(seq 1 30); do
  echo "ITERATION: $it"
  
  # Limit memory size with 2^30. With 2^32 I already see kinda swapping effects
  # and 6x slower IOps.
  for i in $(seq 20 2 30); do
    bytes=$((2**i));
    nblocks=$(($bytes/8192));
    echo "2^$i $bytes, $nblocks";
    psql -vnbuffers="$nblocks" -f flush-read-pages.sql > results/blocks-$nblocks-iter-$it.res
  done
  
  echo "Cooling down for 10 seconds..."
  sleep 10
done