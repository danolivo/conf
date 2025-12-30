SET
CREATE EXTENSION
SET
"TEST RUN: " temp_buffers= 4096, ntuples= 4096*7
"Prepare table"
CREATE TABLE
INSERT 0 28672
"Check real number of disk pages used by the table"
 pg_relpages 
-------------
        4096
(1 row)

"MEASURE: flush of the table, block-by-block (Check 'local written' to be sure)"
                             QUERY PLAN                             
--------------------------------------------------------------------
 Function Scan on pg_flush_local_buffers (actual rows=1.00 loops=1)
   Buffers: local written=4098
 Planning Time: 0.004 ms
 Execution Time: 6.213 ms
(4 rows)

"MEASURE: dry flush (Nothing to write. Check 'local written' to be sure)"
                             QUERY PLAN                             
--------------------------------------------------------------------
 Function Scan on pg_flush_local_buffers (actual rows=1.00 loops=1)
 Planning Time: 0.012 ms
 Execution Time: 0.007 ms
(3 rows)

"Check actually Allocated buffers. Should be equal to "4096" or so"
 pg_allocated_local_buffers 
----------------------------
                       4100
(1 row)

"Wash away test table from memory buffers"
SELECT 28672
"NO MEASURE: flush displacer to exclude writings on read test (Check 'local written' to be sure)"
"Evictions of already flushed buffers don't need disk operations"
                             QUERY PLAN                             
--------------------------------------------------------------------
 Function Scan on pg_flush_local_buffers (actual rows=1.00 loops=1)
   Buffers: local written=3679
 Planning Time: 0.013 ms
 Execution Time: 6.028 ms
(4 rows)

"DROP displacer to free buffers"
DROP TABLE
"MEASURE: Read temp table block-by-block"
                            QUERY PLAN                             
-------------------------------------------------------------------
 Function Scan on pg_read_temp_relation (actual rows=1.00 loops=1)
   Buffers: local read=4096
 Planning Time: 0.012 ms
 Execution Time: 4.735 ms
(4 rows)

"MEASURE: Dry-run: all the pages in the memory (check 'local hit')"
                            QUERY PLAN                             
-------------------------------------------------------------------
 Function Scan on pg_read_temp_relation (actual rows=1.00 loops=1)
   Buffers: local hit=4096
 Planning Time: 0.014 ms
 Execution Time: 0.111 ms
(4 rows)

