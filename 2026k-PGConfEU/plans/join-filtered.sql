-- Join-filtered rows that vanilla EXPLAIN does not show.
-- Two unindexed tables, 10^6 rows each.
--   t1.x: 1 .. 1 000 000, unique      -> only 10 values (1..10) have a partner
--   t2.x: 1 .. 10, 100 000 rows each  -> every row has a partner
-- Result: 10^6 rows; 999 990 rows of t1 are thrown away by the join.
-- PostgreSQL 18.6, max_parallel_workers_per_gather = 0, jit = off, work_mem = 256MB.

DROP TABLE IF EXISTS t1, t2;
CREATE TABLE t1 (x integer);
CREATE TABLE t2 (x integer);
INSERT INTO t1 SELECT g FROM generate_series(1, 1000000) g;
INSERT INTO t2 SELECT 1 + g % 10 FROM generate_series(1, 1000000) g;
VACUUM ANALYZE t1, t2;

-- the hash join (planner's choice) -> join-filtered-hash.raw.txt
EXPLAIN (ANALYZE, TIMING OFF, COSTS OFF, BUFFERS OFF)
SELECT * FROM t1 JOIN t2 USING (x);

-- check: 10 rows of t1 have a partner, 10^6 rows in the result
SELECT count(*) FROM t1 WHERE EXISTS (SELECT 1 FROM t2 WHERE t2.x = t1.x);

-- Nested loop: postponed. 10^6 x 10^6 = 10^12 pairs; measured 34 s per
-- 10^9 pairs on this machine, so the full run is ~9.5 hours.
-- SET enable_hashjoin = off; SET enable_mergejoin = off;
-- EXPLAIN (ANALYZE, TIMING OFF, COSTS OFF, BUFFERS OFF)
-- SELECT * FROM t1 JOIN t2 USING (x);

-- Index on the side where only 10 rows match -> join-filtered-index.raw.txt
-- Planner switches to Nested Loop + Memoize + Index Only Scan on t1.
CREATE INDEX t1_x_idx ON t1 (x);
VACUUM ANALYZE t1;
EXPLAIN (ANALYZE, TIMING OFF, COSTS OFF, BUFFERS OFF)
SELECT * FROM t1 JOIN t2 USING (x);

-- Indexes on both sides -> join-filtered-both.raw.txt
-- Planner switches to Merge Join over two Index Only Scans. The t1 scan
-- stops after 11 rows: t2 ends at x = 10, so the merge stops there.
-- Data-dependent: with t2.x = 999991..1000000 (the top of t1's range) the
-- planner keeps Nested Loop + Memoize instead, 92.5 ms.
CREATE INDEX t2_x_idx ON t2 (x);
VACUUM ANALYZE t2;
EXPLAIN (ANALYZE, TIMING OFF, COSTS OFF, BUFFERS OFF)
SELECT * FROM t1 JOIN t2 USING (x);
