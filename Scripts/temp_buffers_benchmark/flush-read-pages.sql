/*
 * Benchmark: Sequential read versus sequential write for temporary table pages
 *
 * Goal:
 * This benchmark measures how much effort PostgreSQL needs to flush temporary
 * buffers to disk before parallel query execution.
 *
 * The query optimiser is assumed to have access to basic statistics: the total
 * number of allocated temporary pages and the percentage of dirty pages.
 * Using this data, the optimiser should estimate whether it's worth flushing
 * temporary buffers to disk (enabling parallel scans of temporary tables) or
 * executing temporary table scans sequentially without parallel workers.
 *
 * NOTE: Build PostgreSQL with optimisations enabled (-O2 or -O3) for
 * accurate results.
 */

-- Setup input variable nbuffers beforehand

SET client_min_messages TO 'ERROR';
CREATE EXTENSION IF NOT EXISTS pgstattuple;

/*
 * Increase the number of allocated buffers by 10% to accommodate additional
 * metadata blocks (Free Space Map and Visibility Map).
 */
SELECT (:nbuffers + 0.01 * :nbuffers)::bigint AS effective_nbuffers \gset

SET temp_buffers = :effective_nbuffers;
\set ntuples :nbuffers * 7

\echo "TEST RUN: " temp_buffers= :nbuffers, ntuples= :ntuples

\echo "Prepare table"
CREATE TEMP TABLE test (x text);
INSERT INTO test (x) (SELECT r FROM repeat('a', 1024) AS r
  CROSS JOIN (SELECT 1 FROM generate_series(1,:ntuples)) AS q);

\echo "Check real number of disk pages used by the table"
SELECT * FROM pg_relpages('test');

\echo "Check actually allocated buffers (should be approximately ":nbuffers")"
SELECT * FROM pg_allocated_local_buffers();

\echo "MEASURE: Flush the table block-by-block (verify 'local written' in output)"
EXPLAIN (ANALYZE, COSTS OFF, TIMING OFF, SUMMARY ON, BUFFERS ON)
SELECT * FROM pg_flush_local_buffers();

\echo "MEASURE: Dry flush - no dirty buffers to write (verify 'local written' is zero)"
EXPLAIN (ANALYZE, COSTS OFF, TIMING OFF, SUMMARY ON, BUFFERS ON)
SELECT * FROM pg_flush_local_buffers();

\echo "Evict test table from memory buffers by creating a displacer table"
\echo "NOTE: insert extra tuples to be sure we evicted all the pages of the test table"
CREATE TEMP TABLE displacer AS (SELECT r FROM repeat('a', 1024) AS r
  CROSS JOIN (SELECT 1 FROM generate_series(1, :effective_nbuffers * 7)) AS q);
\echo "NO MEASURE: Flush displacer to ensure it's on disk (verify 'local written')"
\echo "Note: Evicting already-flushed buffers requires no disk writes"
EXPLAIN (ANALYZE, COSTS OFF, TIMING OFF, SUMMARY ON, BUFFERS ON)
SELECT * FROM pg_flush_local_buffers();
\echo "Drop displacer table to free buffers"
DROP TABLE displacer;

\echo "MEASURE: Read temp table block-by-block"
EXPLAIN (ANALYZE, COSTS OFF, TIMING OFF, SUMMARY ON, BUFFERS ON)
SELECT * FROM pg_read_temp_relation('test', false);

\echo "MEASURE: Dry run - all pages now in memory (verify 'local hit' count)"
EXPLAIN (ANALYZE, COSTS OFF, TIMING OFF, SUMMARY ON, BUFFERS ON)
SELECT * FROM pg_read_temp_relation('test', false);

/* *****************************************************************************
 *
 * Benchmark random access
 *
 * ************************************************************************** */

\echo "NO MEASURE: Evict test table from buffers by filling them with a dummy table"
CREATE TEMP TABLE displacer AS (SELECT r FROM repeat('a', 1024) AS r
  CROSS JOIN (SELECT 1 FROM generate_series(1, :effective_nbuffers * 7)) AS q);
DROP TABLE displacer;

/*
 * Temp buffers are scanned sequentially, from first to the last one. At this
 * moment each page is free (thanks dropped 'displacer' table. Hence, picking
 * a block randomly and put it into the next free place we will have random
 * distribution of disk blocks across the temp_buffers.
 */
\echo "MEASURE: Read blocks of the temp table randomly"
EXPLAIN (ANALYZE, COSTS OFF, TIMING OFF, SUMMARY ON, BUFFERS ON)
SELECT * FROM pg_read_temp_relation('test', true);
-- Just to check
EXPLAIN (ANALYZE, COSTS OFF, TIMING OFF, SUMMARY ON, BUFFERS ON)
SELECT * FROM pg_read_temp_relation('test', false);
-- Mark pages dirty, ensure each of them in temp buffers
EXPLAIN (ANALYZE, COSTS OFF, TIMING OFF, SUMMARY ON, BUFFERS ON)
SELECT * FROM pg_temp_buffers_dirty('test');

\echo "Flush temp buffers to disk: they were read in random order. So, it will "
\echo "be written in random order too"
EXPLAIN (ANALYZE, COSTS OFF, TIMING OFF, SUMMARY ON, BUFFERS ON)
SELECT * FROM pg_flush_local_buffers();
