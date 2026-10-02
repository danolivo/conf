-- Join-filtered rows, version 3: only 1000 rows of big match, stored densely.
--   big:   10^7 rows, tuple width 64 bytes (x int4 + payload text, 59 chars)
--          rows 5 000 001 .. 5 001 000 (one contiguous block of ~12 heap
--          pages in the middle of the table) have x in 1..10, 100 rows each;
--          all other rows have x > 100 and match nothing
--   small: 100 rows, x = 1..100; only 10 of them (1..10) have a partner
-- Result: 1000 rows.
-- PostgreSQL 18.6, max_parallel_workers_per_gather = 0, jit = off,
-- shared_buffers = 1GB, work_mem = 256MB.

DROP TABLE IF EXISTS big, small;
CREATE TABLE big (x integer, payload text);
CREATE TABLE small (x integer);
INSERT INTO big
  SELECT CASE WHEN g BETWEEN 5000001 AND 5001000 THEN 1 + g % 10 ELSE 100 + g END,
         rpad(g::text, 59, 'x')
  FROM generate_series(1, 10000000) g;
INSERT INTO small SELECT g FROM generate_series(1, 100) g;
VACUUM ANALYZE big, small;

-- 1) no indexes -> join-big-small-dense-noindex.raw.txt
EXPLAIN (ANALYZE, TIMING OFF, COSTS OFF)
SELECT * FROM big JOIN small USING (x);

-- 2) index on the big side -> join-big-small-dense-index.raw.txt
CREATE INDEX big_x_idx ON big (x);
VACUUM ANALYZE big;
EXPLAIN (ANALYZE, TIMING OFF, COSTS OFF)
SELECT * FROM big JOIN small USING (x);

-- Observed (warm cache, 5 runs each):
--   the 1000 matching rows sit on heap pages 56818..56829 (12 pages)
--   1) Hash Join, 330-339 ms, shared hit=113637 on big: all 10^7 rows read,
--      9 999 000 probes find nothing, 90 of 100 hashed rows never match.
--      Estimate rows=100 vs 1000 actual.
--   2) Merge Join, 0.13-0.16 ms, shared hit=124 on big. Index Scan stops at
--      row 1001 (first x = 101 > max(small.x)). Sort shows rows=1090 from a
--      100-row table: 990 re-reads by mark/restore (10 values x 99 extra
--      outer duplicates). 124 buffer hits = ~12 heap pages revisited once
--      per x value (values are interleaved inside the block) + index pages.

-- 3) forced Nested Loop
SET enable_hashjoin = off;
SET enable_mergejoin = off;
EXPLAIN (ANALYZE, TIMING OFF, COSTS OFF)
SELECT * FROM big JOIN small USING (x);
--   with the index -> join-big-small-dense-nl-index.raw.txt
--     0.14-0.19 ms. Index Scan rows=10.00 loops=100 is an average: 90 loops
--     return 0 rows, 10 loops return 100. shared hit=420 vs 124 for the
--     merge join: ~3 index pages per empty probe x 90 = ~270 wasted hits.
--   without the index (DROP INDEX big_x_idx) -> join-big-small-dense-nl-noindex.raw.txt
--     20.8-21.0 s. Rows Removed by Join Filter: 999999000 = 10^7 x 100 - 1000:
--     it counts compared pairs, not rows without a partner.
