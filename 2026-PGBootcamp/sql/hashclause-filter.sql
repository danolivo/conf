-- HashJoin hashclause filter

https://github.com/danolivo/pgdev/tree/join-filter

SELECT queryid,LEFT(query, 13) AS query,                                                                 ROUND(avg_avg::numeric,2) AS error,
  ROUND(lf_avg::numeric,2) AS scan_f,
  ROUND(jf_avg::numeric,2) AS join_f                                                                   FROM track_data
ORDER BY jf_avg DESC LIMIT 10;

       queryid        |     query     | error | scan_f |  join_f   
----------------------+---------------+-------+--------+-----------
 -3135863217603061370 | /* 32a.sql */ |  1.83 |   0.00 | 430659.68
  5025464644910963332 | /* 25b.sql */ |  1.58 |   4.77 |  61812.43
   969606574527514143 | /* 2a.sql */  |  2.87 |   0.00 |  48692.36
  8307542826537749406 | /* 5a.sql */  |  2.71 |   0.00 |  22364.01
 -8287516654825389938 | /* 12b.sql */ |  1.64 |   0.05 |  22095.91
  3345454269340541014 | /* 10b.sql */ |  3.28 |   4.76 |  21820.98
  6570380967973041608 | /* 1b.sql */  |  2.43 |   0.03 |  21817.95
 -7718801079997731049 | /* 1d.sql */  |  2.46 |   0.03 |  21348.56
   868681592535365242 | /* 7b.sql */  |  1.45 |   0.00 |  20322.10
  5164706688251065689 | /* 24b.sql */ |  1.94 |   7.30 |  11925.55
(10 rows)

CREATE TABLE test (x integer, y integer);
INSERT INTO test (x,y) (SELECT gs, -gs FROM generate_series(0,1E4) AS gs);
VACUUM ANALYZE test;

SET max_parallel_workers_per_gather = 0;
EXPLAIN (ANALYZE, COSTS OFF, BUFFERS OFF, TIMING OFF)
SELECT count(*) FROM test t1 JOIN test t2 ON (t1.x = t2.y);

 Aggregate (actual rows=1.00 loops=1)
   ->  Hash Join (actual rows=1.00 loops=1)
         Hash Cond: (t1.x = t2.y)
         Rows Removed by Hash Matching: 10000
         ->  Seq Scan on test t1 (actual rows=10001.00 loops=1)
         ->  Hash (actual rows=10001.00 loops=1)
               Buckets: 16384  Batches: 1  Memory Usage: 480kB
               ->  Seq Scan on test t2 (actual rows=10001.00 loops=1)

SET enable_hashjoin = off;

 Aggregate (actual rows=1.00 loops=1)
   ->  Merge Join (actual rows=1.00 loops=1)
         Merge Cond: (t1.x = t2.y)
         ->  Sort (actual rows=2.00 loops=1)
               Sort Key: t1.x
               Sort Method: quicksort  Memory: 385kB
               ->  Seq Scan on test t1 (actual rows=10001.00 loops=1)
         ->  Sort (actual rows=10001.00 loops=1)
               Sort Key: t2.y
               Sort Method: quicksort  Memory: 385kB
               ->  Seq Scan on test t2 (actual rows=10001.00 loops=1)

SET enable_mergejoin = off;

 Aggregate (actual rows=1.00 loops=1)
   ->  Nested Loop (actual rows=1.00 loops=1)
         Join Filter: (t1.x = t2.y)
         Rows Removed by Join Filter: 100020000
         ->  Seq Scan on test t1 (actual rows=10001.00 loops=1)
         ->  Materialize (actual rows=10001.00 loops=10001)
               Storage: Memory  Maximum Storage: 441kB
               ->  Seq Scan on test t2 (actual rows=10001.00 loops=1)