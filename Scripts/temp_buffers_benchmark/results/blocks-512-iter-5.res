SET
CREATE EXTENSION
SET
"TEST RUN: " temp_buffers= 512, ntuples= 512*7
"Prepare table"
CREATE TABLE
INSERT 0 3584
"Check real number of disk pages used by the table"
 pg_relpages 
-------------
         512
(1 row)

"MEASURE: flush of the table, block-by-block (Check 'local written' to be sure)"
                             QUERY PLAN                             
--------------------------------------------------------------------
 Function Scan on pg_flush_local_buffers (actual rows=1.00 loops=1)
   Buffers: local written=511
 Planning Time: 0.002 ms
 Execution Time: 0.530 ms
(4 rows)

"MEASURE: dry flush (Nothing to write. Check 'local written' to be sure)"
                             QUERY PLAN                             
--------------------------------------------------------------------
 Function Scan on pg_flush_local_buffers (actual rows=1.00 loops=1)
 Planning Time: 0.002 ms
 Execution Time: 0.002 ms
(3 rows)

"Check actually Allocated buffers. Should be equal to :nbuffers"
 pg_allocated_local_buffers 
----------------------------
                        512
(1 row)

"Wash away test table from memory buffers"
SELECT 3584
"NO MEASURE: flush displacer to exclude writings on read test (Check 'local written' to be sure)"
"Evictions of already flushed buffers don't need disk operations"
                             QUERY PLAN                             
--------------------------------------------------------------------
 Function Scan on pg_flush_local_buffers (actual rows=1.00 loops=1)
   Buffers: local written=510
 Planning Time: 0.003 ms
 Execution Time: 1.165 ms
(4 rows)

"DROP displacer to free buffers"
DROP TABLE
"MEASURE: Read temp table block-by-block"
                            QUERY PLAN                             
-------------------------------------------------------------------
 Function Scan on pg_read_temp_relation (actual rows=1.00 loops=1)
   Buffers: local hit=2 read=510
 Planning Time: 0.002 ms
 Execution Time: 0.489 ms
(4 rows)

"MEASURE: Dry-run: all the pages in the memory (check 'local hit')"
                            QUERY PLAN                             
-------------------------------------------------------------------
 Function Scan on pg_read_temp_relation (actual rows=1.00 loops=1)
   Buffers: local hit=512
 Planning Time: 0.002 ms
 Execution Time: 0.015 ms
(4 rows)

