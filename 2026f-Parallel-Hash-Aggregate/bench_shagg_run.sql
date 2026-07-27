-- bench_shagg_run.sql
--
-- One benchmark cell: table x worker count x feature on/off.
--
--   psql -v tab=bench_shagg_dbl -v workers=8 -v shagg=on  -f bench_shagg_run.sql
--
-- Scaling sweep (mirrors the explain-basic.txt series):
--   for w in 2 4 6 8 12; do for s in off on; do
--     psql -v tab=bench_shagg_dbl -v workers=$w -v shagg=$s -f bench_shagg_run.sql
--   done; done
--
-- For the numeric flat-state path, install contrib/shared_numeric_agg,
-- then run with -v tab=bench_shagg_num prefixed by:
--   SET search_path = shared_agg, "$user", public, pg_catalog;
-- (uncomment the line below) and compare against the stock run.

\if :{?tab}     \else \set tab bench_shagg_dbl \endif
\if :{?workers} \else \set workers 8 \endif
\if :{?shagg}   \else \set shagg on \endif

-- environment: same knobs as the original query_dbl.sql
SET client_min_messages = error;
SET cpu_operator_cost = 0.001;
SET min_parallel_table_scan_size = 0;
SET max_parallel_workers = 16;
SET max_parallel_workers_per_gather = 16;
SET jit = off;
SET parallel_setup_cost = 1;
SET parallel_tuple_cost = 0.0001;
SET work_mem TO '4GB';

-- SET search_path = shared_agg, "$user", public, pg_catalog;  -- numeric flat path

SET enable_parallel_hash_agg = :shagg;

ALTER TABLE :tab SET (parallel_workers = :workers);

\echo ==== table=:tab workers=:workers enable_parallel_hash_agg=:shagg ====

EXPLAIN (ANALYZE, COSTS OFF, BUFFERS OFF, TIMING ON)
SELECT
    f008_type, f008_rtref, f008_rrref, f009rref, f010rref,
    f011_type, f011_rtref, f011_rrref, f012, f013rref,
    f014rref, f015rref, f016rref,
    SUM(v1), SUM(v2), SUM(v3), SUM(v4), SUM(v5), SUM(v6), SUM(v7)
FROM :tab
GROUP BY
    f008_type, f008_rtref, f008_rrref, f009rref, f010rref,
    f011_type, f011_rtref, f011_rrref, f012, f013rref,
    f014rref, f015rref, f016rref;

/*
 Finalize HashAggregate  (cost=198855.20..201855.21 rows=300001 width=221) (actual time=7278.532..7582.396 rows=592000.00 loops=1)
   Group Key: f008_type, f008_rtref, f008_rrref, f009rref, f010rref, f011_type, f011_rtref, f011_rrref, f012, f013rref, f014rref, f015rref, f016rref
   Batches: 1  Memory Usage: 204833kB
   ->  Gather  (cost=147615.03..150855.04 rows=2400008 width=221) (actual time=871.869..2163.199 rows=2249318.00 loops=1)
         Workers Planned: 8
         Workers Launched: 8
         ->  Partial HashAggregate  (cost=147614.03..150614.04 rows=300001 width=221) (actual time=866.154..1007.627 rows=249924.22 loops=9)
               Group Key: f008_type, f008_rtref, f008_rrref, f009rref, f010rref, f011_type, f011_rtref, f011_rrref, f012, f013rref, f014rref, f015rref, f016rref
               Batches: 1  Memory Usage: 98337kB
               Worker 0:  Batches: 1  Memory Usage: 90145kB
               Worker 1:  Batches: 1  Memory Usage: 81953kB
               Worker 2:  Batches: 1  Memory Usage: 90145kB
               Worker 3:  Batches: 1  Memory Usage: 98337kB
               Worker 4:  Batches: 1  Memory Usage: 81953kB
               Worker 5:  Batches: 1  Memory Usage: 65569kB
               Worker 6:  Batches: 1  Memory Usage: 98337kB
               Worker 7:  Batches: 1  Memory Usage: 90145kB
               ->  Parallel Seq Scan on bench_shagg_dbl  (cost=0.00..140114.01 rows=375001 width=221) (actual time=0.013..39.792 rows=333333.33 loops=9)
 Planning Time: 0.691 ms
 Execution Time: 7655.459 ms

 Gather  (cost=147615.03..151016.71 rows=266664 width=221) (actual time=1014.695..1118.927 rows=592000.00 loops=1)
   Workers Planned: 8
   Workers Launched: 8
   ->  Parallel HashAggregate  (cost=147614.03..150989.04 rows=33333 width=221) (actual time=1009.105..1053.658 rows=65777.78 loops=9)
         Group Key: f008_type, f008_rtref, f008_rrref, f009rref, f010rref, f011_type, f011_rtref, f011_rrref, f012, f013rref, f014rref, f015rref, f016rref
         ->  Parallel Seq Scan on bench_shagg_dbl  (cost=0.00..140114.01 rows=375001 width=221) (actual time=0.012..40.116 rows=333333.33 loops=9)
 Planning Time: 0.695 ms
 Execution Time: 1133.674 ms
 */

-- num:

/*
 Finalize HashAggregate (actual time=22022.997..24117.957 rows=592000.00 loops=1)
   Group Key: f008_type, f008_rtref, f008_rrref, f009rref, f010rref, f011_type, f011_rtref, f011_rrref, f012, f013rref, f014rref, f015rref, f016rref
   Batches: 1  Memory Usage: 4481049kB
   ->  Gather (actual time=2024.452..6237.613 rows=2440146.00 loops=1)
         Workers Planned: 8
         Workers Launched: 8
         ->  Partial HashAggregate (actual time=2018.297..4047.409 rows=271127.33 loops=9)
               Group Key: f008_type, f008_rtref, f008_rrref, f009rref, f010rref, f011_type, f011_rtref, f011_rrref, f012, f013rref, f014rref, f015rref, f016rref
               Batches: 1  Memory Usage: 1949721kB
               Worker 0:  Batches: 1  Memory Usage: 2105369kB
               Worker 1:  Batches: 1  Memory Usage: 2236441kB
               Worker 2:  Batches: 1  Memory Usage: 2203673kB
               Worker 3:  Batches: 1  Memory Usage: 1957913kB
               Worker 4:  Batches: 1  Memory Usage: 2121753kB
               Worker 5:  Batches: 1  Memory Usage: 1908761kB
               Worker 6:  Batches: 1  Memory Usage: 2007065kB
               Worker 7:  Batches: 1  Memory Usage: 2007065kB
               ->  Parallel Seq Scan on bench_shagg_num (actual time=0.160..252.678 rows=333333.33 loops=9)
 Planning Time: 0.839 ms
 Execution Time: 25071.708 ms

 Gather (actual time=3160.374..3561.249 rows=592000.00 loops=1)
   Workers Planned: 8
   Workers Launched: 8
   ->  Parallel HashAggregate (actual time=3154.668..3426.873 rows=65777.78 loops=9)
         Group Key: f008_type, f008_rtref, f008_rrref, f009rref, f010rref, f011_type, f011_rtref, f011_rrref, f012, f013rref, f014rref, f015rref, f016rref
         ->  Parallel Seq Scan on bench_shagg_num (actual time=0.109..105.448 rows=333333.33 loops=9)
 Planning Time: 0.695 ms
 Execution Time: 3608.548 ms


*/