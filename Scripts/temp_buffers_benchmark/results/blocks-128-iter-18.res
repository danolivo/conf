SET
CREATE EXTENSION
SET
"TEST RUN: " temp_buffers= 128, ntuples= 128*7
"Prepare table"
CREATE TABLE
INSERT 0 896
"Check real number of disk pages used by the table"
 pg_relpages 
-------------
         128
(1 row)

"MEASURE: flush of the table, block-by-block (Check 'local written' to be sure)"
                             QUERY PLAN                             
--------------------------------------------------------------------
 Function Scan on pg_flush_local_buffers (actual rows=1.00 loops=1)
   Buffers: local written=129
 Planning Time: 0.004 ms
 Execution Time: 0.176 ms
(4 rows)

"MEASURE: dry flush (Nothing to write. Check 'local written' to be sure)"
                             QUERY PLAN                             
--------------------------------------------------------------------
 Function Scan on pg_flush_local_buffers (actual rows=1.00 loops=1)
 Planning Time: 0.003 ms
 Execution Time: 0.002 ms
(3 rows)

"Check actually Allocated buffers. Should be equal to "128" or so"
 pg_allocated_local_buffers 
----------------------------
                        131
(1 row)

"Wash away test table from memory buffers"
SELECT 896
"NO MEASURE: flush displacer to exclude writings on read test (Check 'local written' to be sure)"
"Evictions of already flushed buffers don't need disk operations"
                             QUERY PLAN                             
--------------------------------------------------------------------
 Function Scan on pg_flush_local_buffers (actual rows=1.00 loops=1)
   Buffers: local written=116
 Planning Time: 0.002 ms
 Execution Time: 0.376 ms
(4 rows)

"DROP displacer to free buffers"
DROP TABLE
"MEASURE: Read temp table block-by-block"
                            QUERY PLAN                             
-------------------------------------------------------------------
 Function Scan on pg_read_temp_relation (actual rows=1.00 loops=1)
   Buffers: local read=128
 Planning Time: 0.002 ms
 Execution Time: 0.177 ms
(4 rows)

"MEASURE: Dry-run: all the pages in the memory (check 'local hit')"
                            QUERY PLAN                             
-------------------------------------------------------------------
 Function Scan on pg_read_temp_relation (actual rows=1.00 loops=1)
   Buffers: local hit=128
 Planning Time: 0.002 ms
 Execution Time: 0.008 ms
(4 rows)

