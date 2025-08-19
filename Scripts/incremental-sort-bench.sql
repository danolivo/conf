--
-- Script in supprt to the problem analysis and answer:
-- https://www.postgresql.org/message-id/CA+Tgmob-7XM5xsB+Vco5XmRkMYKgFi4xhCTfL2N6WJuqYS93CQ@mail.gmail.com
--

--
-- Case 1: Uniform distribution
--

DROP TABLE IF EXISTS test CASCADE;
SET max_parallel_workers_per_gather = 0;

-- Change this parameter to setup specific number of groups
\set groups 0

CREATE TABLE test (x text, y text) WITH (autovacuum_enabled = false);
INSERT INTO test (x,y) (
  SELECT
    'value-' || (random() * :groups)::integer,
    'a little longer value-' || random()
  FROM generate_series(1,1E6) AS gs
);
CREATE INDEX ON test (x);
VACUUM ANALYZE test;

-- Queries:
SET enable_sort = 'on';
SET enable_incremental_sort = 'off';
EXPLAIN (ANALYZE, COSTS ON, BUFFERS ON, TIMING ON)
SELECT * FROM test ORDER BY x,y;

SET enable_sort = 'off';
SET enable_incremental_sort = 'on';
EXPLAIN (ANALYZE, COSTS ON, BUFFERS ON, TIMING ON)
SELECT * FROM test ORDER BY x,y;

SET enable_seqscan = 'off';
SET enable_sort = 'on';
SET enable_incremental_sort = 'off';
EXPLAIN (ANALYZE, COSTS ON, BUFFERS ON, TIMING ON)
SELECT * FROM test ORDER BY x,y;

SET enable_seqscan = 'on';

/*
 Sort  (cost=119920.84..122420.84 rows=1000000 width=49) (actual time=28989.945..29174.153 rows=1000000.00 loops=1)
   Sort Key: x, y
   Sort Method: quicksort  Memory: 94309kB
   Buffers: shared hit=10263
   ->  Seq Scan on test  (cost=0.00..20263.00 rows=1000000 width=49) (actual time=0.020..141.117 rows=1000000.00 loops=1)
         Buffers: shared hit=10263
 Planning Time: 0.081 ms
 Execution Time: 29291.846 ms

 Incremental Sort  (cost=128320.27..140820.29 rows=1000000 width=49) (actual time=22050.041..22237.499 rows=1000000.00 loops=1)
   Sort Key: x, y
   Presorted Key: x
   Full-sort Groups: 1  Sort Method: quicksort  Average Memory: 29kB  Peak Memory: 29kB
   Pre-sorted Groups: 1  Sort Method: quicksort  Average Memory: 94309kB  Peak Memory: 94309kB
   Buffers: shared hit=11107
   ->  Index Scan using test_x_idx on test  (cost=0.42..28662.42 rows=1000000 width=49) (actual time=0.060..466.527 rows=1000000.00 loops=1)
         Index Searches: 1
         Buffers: shared hit=11107
 Planning Time: 0.086 ms
 Execution Time: 22351.524 ms

 Sort  (cost=128320.27..130820.27 rows=1000000 width=49) (actual time=29644.796..29839.890 rows=1000000.00 loops=1)
   Sort Key: x, y
   Sort Method: quicksort  Memory: 94309kB
   Buffers: shared hit=11107
   ->  Index Scan using test_x_idx on test  (cost=0.42..28662.42 rows=1000000 width=49) (actual time=0.060..454.205 rows=1000000.00 loops=1)
         Index Searches: 1
         Buffers: shared hit=11107
 Planning Time: 0.080 ms
 Execution Time: 29959.003 ms
*/


--
-- Case 2: Normal distribution
--

CREATE EXTENSION IF NOT EXISTS tablefunc;
DROP TABLE IF EXISTS test CASCADE;
SET max_parallel_workers_per_gather = 0;

\set stddev 50
CREATE TABLE test (x text, y text) WITH (autovacuum_enabled = false);
INSERT INTO test (x,y) (
  SELECT
    'value-' || abs(nr)::integer,
    'a little longer value-' || random()
  FROM normal_rand(1E6::integer, 0.::float8, (:stddev)::float8) AS nr
);
CREATE INDEX ON test (x);
VACUUM ANALYZE test;

/*
 Sort  (cost=119967.84..122467.84 rows=1000000 width=49) (actual time=22362.699..22548.236 rows=1000000.00 loops=1)
   Sort Key: x, y
   Sort Method: quicksort  Memory: 94756kB
   Buffers: shared hit=10310
   ->  Seq Scan on test  (cost=0.00..20310.00 rows=1000000 width=49) (actual time=0.018..136.534 rows=1000000.00 loops=1)
         Buffers: shared hit=10310
 Planning Time: 0.076 ms
 Execution Time: 22664.556 ms

 Incremental Sort  (cost=658.34..134218.97 rows=1000000 width=49) (actual time=131.460..15256.221 rows=1000000.00 loops=1)
   Sort Key: x, y
   Presorted Key: x
   Full-sort Groups: 185  Sort Method: quicksort  Average Memory: 29kB  Peak Memory: 29kB
   Pre-sorted Groups: 193  Sort Method: quicksort  Average Memory: 1491kB  Peak Memory: 1497kB
   Buffers: shared hit=627815
   ->  Index Scan using test_x_idx on test  (cost=0.42..59714.33 rows=1000000 width=49) (actual time=0.060..1006.547 rows=1000000.00 loops=1)
         Index Searches: 1
         Buffers: shared hit=627815
 Planning Time: 0.083 ms
 Execution Time: 15317.889 ms

 Sort  (cost=159372.18..161872.18 rows=1000000 width=49) (actual time=20420.331..20563.908 rows=1000000.00 loops=1)
   Sort Key: x, y
   Sort Method: quicksort  Memory: 94756kB
   Buffers: shared hit=627815
   ->  Index Scan using test_x_idx on test  (cost=0.42..59714.33 rows=1000000 width=49) (actual time=0.039..1142.231 rows=1000000.00 loops=1)
         Index Searches: 1
         Buffers: shared hit=627815
 Planning Time: 0.059 ms
 Execution Time: 20670.041 ms
*/
