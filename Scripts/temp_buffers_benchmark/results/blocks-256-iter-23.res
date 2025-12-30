SET
CREATE EXTENSION
SET
"TEST RUN: " temp_buffers= 256, ntuples= 256*7
"Prepare table"
CREATE TABLE
INSERT 0 1792
"Check real number of disk pages used by the table"
 pg_relpages 
-------------
         256
(1 row)

"MEASURE: flush of the table, block-by-block (Check 'local written' to be sure)"
                             QUERY PLAN                             
--------------------------------------------------------------------
 Function Scan on pg_flush_local_buffers (actual rows=1.00 loops=1)
   Buffers: local written=257
 Planning Time: 0.004 ms
 Execution Time: 0.308 ms
(4 rows)

"MEASURE: dry flush (Nothing to write. Check 'local written' to be sure)"
                             QUERY PLAN                             
--------------------------------------------------------------------
 Function Scan on pg_flush_local_buffers (actual rows=1.00 loops=1)
 Planning Time: 0.003 ms
 Execution Time: 0.002 ms
(3 rows)

"Check actually Allocated buffers. Should be equal to "256" or so"
 pg_allocated_local_buffers 
----------------------------
                        259
(1 row)

"Wash away test table from memory buffers"
SELECT 1792
"NO MEASURE: flush displacer to exclude writings on read test (Check 'local written' to be sure)"
"Evictions of already flushed buffers don't need disk operations"
                             QUERY PLAN                             
--------------------------------------------------------------------
 Function Scan on pg_flush_local_buffers (actual rows=1.00 loops=1)
   Buffers: local written=231
 Planning Time: 0.008 ms
 Execution Time: 0.500 ms
(4 rows)

"DROP displacer to free buffers"
DROP TABLE
"MEASURE: Read temp table block-by-block"
                            QUERY PLAN                             
-------------------------------------------------------------------
 Function Scan on pg_read_temp_relation (actual rows=1.00 loops=1)
   Buffers: local read=256
 Planning Time: 0.007 ms
 Execution Time: 0.328 ms
(4 rows)

"MEASURE: Dry-run: all the pages in the memory (check 'local hit')"
                            QUERY PLAN                             
-------------------------------------------------------------------
 Function Scan on pg_read_temp_relation (actual rows=1.00 loops=1)
   Buffers: local hit=256
 Planning Time: 0.004 ms
 Execution Time: 0.012 ms
(4 rows)

