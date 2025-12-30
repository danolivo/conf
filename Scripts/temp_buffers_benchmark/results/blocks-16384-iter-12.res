SET
CREATE EXTENSION
SET
"TEST RUN: " temp_buffers= 16384, ntuples= 16384*7
"Prepare table"
CREATE TABLE
INSERT 0 114688
"Check real number of disk pages used by the table"
 pg_relpages 
-------------
       16384
(1 row)

"MEASURE: flush of the table, block-by-block (Check 'local written' to be sure)"
                             QUERY PLAN                             
--------------------------------------------------------------------
 Function Scan on pg_flush_local_buffers (actual rows=1.00 loops=1)
   Buffers: local written=16389
 Planning Time: 0.006 ms
 Execution Time: 25.600 ms
(4 rows)

"MEASURE: dry flush (Nothing to write. Check 'local written' to be sure)"
                             QUERY PLAN                             
--------------------------------------------------------------------
 Function Scan on pg_flush_local_buffers (actual rows=1.00 loops=1)
 Planning Time: 0.016 ms
 Execution Time: 0.020 ms
(3 rows)

"Check actually Allocated buffers. Should be equal to "16384" or so"
 pg_allocated_local_buffers 
----------------------------
                      16391
(1 row)

"Wash away test table from memory buffers"
SELECT 114688
"NO MEASURE: flush displacer to exclude writings on read test (Check 'local written' to be sure)"
"Evictions of already flushed buffers don't need disk operations"
                             QUERY PLAN                             
--------------------------------------------------------------------
 Function Scan on pg_flush_local_buffers (actual rows=1.00 loops=1)
   Buffers: local written=14700
 Planning Time: 0.020 ms
 Execution Time: 23.149 ms
(4 rows)

"DROP displacer to free buffers"
DROP TABLE
"MEASURE: Read temp table block-by-block"
                            QUERY PLAN                             
-------------------------------------------------------------------
 Function Scan on pg_read_temp_relation (actual rows=1.00 loops=1)
   Buffers: local read=16384
 Planning Time: 0.014 ms
 Execution Time: 19.467 ms
(4 rows)

"MEASURE: Dry-run: all the pages in the memory (check 'local hit')"
                            QUERY PLAN                             
-------------------------------------------------------------------
 Function Scan on pg_read_temp_relation (actual rows=1.00 loops=1)
   Buffers: local hit=16384
 Planning Time: 0.012 ms
 Execution Time: 0.470 ms
(4 rows)

