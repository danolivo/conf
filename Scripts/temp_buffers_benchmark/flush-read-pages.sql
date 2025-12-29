-- Setup input variable nbuffers beforehand

CREATE EXTENSION IF NOT EXISTS pgstattuple;

SET temp_buffers = :nbuffers;
\set ntuples :nbuffers * 7

\echo temp_buffers= :nbuffers, ntuples= :ntuples

\echo "Prepare table"
CREATE TEMP TABLE test (x text);
INSERT INTO test (x) (SELECT r FROM repeat('a', 1024) AS r
  CROSS JOIN (SELECT 1 FROM generate_series(1,:ntuples)) AS q);

\echo "Check real number of disk pages used by the table"
SELECT * FROM pg_relpages('test');

\echo "MEASURE: flush of the table, block-by-block (Check 'local written' to be sure)"
EXPLAIN (ANALYZE, COSTS OFF, TIMING OFF, SUMMARY ON, BUFFERS ON)
SELECT * FROM pg_flush_local_buffers();

\echo "MEASURE: dry flush (Nothing to write. Check 'local written' to be sure)"
EXPLAIN (ANALYZE, COSTS OFF, TIMING OFF, SUMMARY ON, BUFFERS ON)
SELECT * FROM pg_flush_local_buffers();

\echo "Check actually Allocated buffers. Should be equal to :nbuffers"
SELECT * FROM pg_allocated_local_buffers();

\echo "Wash away test table from memory buffers"
CREATE TEMP TABLE displacer AS (SELECT r FROM repeat('a', 1024) AS r
  CROSS JOIN (SELECT 1 FROM generate_series(1,:ntuples)) AS q);
\echo "NO MEASURE: flush displacer to exclude writings on read test (Check 'local written' to be sure)"
EXPLAIN (ANALYZE, COSTS OFF, TIMING OFF, SUMMARY ON, BUFFERS ON)
SELECT * FROM pg_flush_local_buffers();

\echo "MEASURE: Read temp table block-by-block"
EXPLAIN (ANALYZE, COSTS OFF, TIMING OFF, SUMMARY ON, BUFFERS ON)
SELECT * FROM pg_read_temp_relation('test');

\echo "MEASURE: Dry-run: all the pages in the memory (check 'local hit')"
EXPLAIN (ANALYZE, COSTS OFF, TIMING OFF, SUMMARY ON, BUFFERS ON)
SELECT * FROM pg_read_temp_relation('test');
EXPLAIN (ANALYZE, COSTS OFF, TIMING OFF, SUMMARY ON, BUFFERS ON)
SELECT * FROM pg_read_temp_relation('test');
