
SET work_mem = '128MB';

EXPLAIN (ANALYZE, COSTS ON, TIMING OFF, BUFFERS OFF, SUMMARY ON)
SELECT floor(random()*1000) AS x FROM generate_series(1,1E5)
  UNION ALL
SELECT floor(random()*1000) AS x FROM generate_series(1,1E5)
  UNION ALL
SELECT floor(random()*1000) AS x FROM generate_series(1,1E5)
  UNION ALL
SELECT floor(random()*1000) AS x FROM generate_series(1,1E5)
  UNION ALL
SELECT floor(random()*1000) AS x FROM generate_series(1,1E5)
  UNION ALL
SELECT floor(random()*1000) AS x FROM generate_series(1,1E5)
  UNION ALL
SELECT floor(random()*1000) AS x FROM generate_series(1,1E5)
  UNION ALL
SELECT floor(random()*1000) AS x FROM generate_series(1,1E5)
  UNION ALL
SELECT floor(random()*1000) AS x FROM generate_series(1,1E5)
  UNION ALL
SELECT floor(random()*1000) AS x FROM generate_series(1,1E5)
ORDER BY x;