SET
CREATE EXTENSION
SET
"TEST RUN: " temp_buffers= 2048, ntuples= 2048*7
"Prepare table"
CREATE TABLE
INSERT 0 14336
"Check real number of disk pages used by the table"
 pg_relpages 
-------------
        2048
(1 row)

"MEASURE: flush of the table, block-by-block (Check 'local written' to be sure)"
                             QUERY PLAN                             
--------------------------------------------------------------------
 Function Scan on pg_flush_local_buffers (actual rows=1.00 loops=1)
   Buffers: local written=2049
 Planning Time: 0.004 ms
 Execution Time: 2.885 ms
(4 rows)

"MEASURE: dry flush (Nothing to write. Check 'local written' to be sure)"
                             QUERY PLAN                             
--------------------------------------------------------------------
 Function Scan on pg_flush_local_buffers (actual rows=1.00 loops=1)
 Planning Time: 0.006 ms
 Execution Time: 0.004 ms
(3 rows)

"Check actually Allocated buffers. Should be equal to "2048" or so"
 pg_allocated_local_buffers 
----------------------------
                       2051
(1 row)

"Wash away test table from memory buffers"
SELECT 14336
"NO MEASURE: flush displacer to exclude writings on read test (Check 'local written' to be sure)"
"Evictions of already flushed buffers don't need disk operations"
                             QUERY PLAN                             
--------------------------------------------------------------------
 Function Scan on pg_flush_local_buffers (actual rows=1.00 loops=1)
   Buffers: local written=1841
 Planning Time: 0.013 ms
 Execution Time: 2.790 ms
(4 rows)

"DROP displacer to free buffers"
DROP TABLE
"MEASURE: Read temp table block-by-block"
                            QUERY PLAN                             
-------------------------------------------------------------------
 Function Scan on pg_read_temp_relation (actual rows=1.00 loops=1)
   Buffers: local read=2048
 Planning Time: 0.012 ms
 Execution Time: 2.328 ms
(4 rows)

"MEASURE: Dry-run: all the pages in the memory (check 'local hit')"
                            QUERY PLAN                             
-------------------------------------------------------------------
 Function Scan on pg_read_temp_relation (actual rows=1.00 loops=1)
   Buffers: local hit=2048
 Planning Time: 0.011 ms
 Execution Time: 0.058 ms
(4 rows)

