-- Join-filtered rows, version 2: a big table and a small one.
--   big:   10^7 rows, tuple width 64 bytes (x int4 = 4 + payload text 59 chars = 60)
--          every 100th row has x in 1..10 (10^4 rows per value, 10^5 in total),
--          all other rows have x > 100 and match nothing
--   small: 100 rows, x = 1..100; only 10 of them (1..10) have a partner
-- Result: 10^5 rows.
-- PostgreSQL 18.6, max_parallel_workers_per_gather = 0, jit = off,
-- shared_buffers = 1GB, work_mem = 256MB.

DROP TABLE IF EXISTS big, small;
CREATE TABLE big (x integer, payload text);
CREATE TABLE small (x integer);
INSERT INTO big
  SELECT CASE WHEN g % 100 = 0 THEN 1 + (g / 100) % 10 ELSE 100 + g END,
         rpad(g::text, 59, 'x')
  FROM generate_series(1, 10000000) g;
INSERT INTO small SELECT g FROM generate_series(1, 100) g;
VACUUM ANALYZE big, small;

-- 1) no indexes -> join-big-small-noindex.raw.txt
EXPLAIN (ANALYZE, TIMING OFF, COSTS OFF, BUFFERS OFF)
SELECT * FROM big JOIN small USING (x);

-- 2) index on the big side -> join-big-small-index.raw.txt
CREATE INDEX big_x_idx ON big (x);
VACUUM ANALYZE big;
EXPLAIN (ANALYZE, TIMING OFF, COSTS OFF, BUFFERS OFF)
SELECT * FROM big JOIN small USING (x);

-- Observed (warm cache, 5 runs each):
--   1) Hash Join, 299-306 ms. Seq Scan on big returns 10^7 rows; 9.9*10^6
--      probes find nothing and 90 of 100 hashed rows are never matched --
--      neither is visible. Estimate: rows=421 vs 100000 actual.
--   2) Nested Loop + Index Scan on big, 83-85 ms. Index Scan shows
--      rows=1000.00 loops=100 -- an average: in fact 90 loops return 0 rows
--      and 10 loops return 10^4 each. Buffers: shared hit=100383 (the matching
--      rows sit on ~one page each), vs 113637 for the seq scan.
