#!/bin/sh
for i in $(seq 20 2 32); do
  bytes=$((2**i));
  nblocks=$(($bytes/8192));
  echo "2^$i $bytes, $nblocks";
  psql -vnbuffers="$nblocks" -f flush-read-pages.sql > test-blocks-$nblocks.res
done
