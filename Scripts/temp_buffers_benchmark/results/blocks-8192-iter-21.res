SET
CREATE EXTENSION
SET
"TEST RUN: " temp_buffers= 8192, ntuples= 8192*7
"Prepare table"
CREATE TABLE
INSERT 0 57344
"Check real number of disk pages used by the table"
 pg_relpages 
-------------
        8192
(1 row)

"MEASURE: flush of the table, block-by-block (Check 'local written' to be sure)"
                             QUERY PLAN                             
--------------------------------------------------------------------
 Function Scan on pg_flush_local_buffers (actual rows=1.00 loops=1)
   Buffers: local written=8191
 Planning Time: 0.005 ms
 Execution Time: 12.536 ms
(4 rows)

"MEASURE: dry flush (Nothing to write. Check 'local written' to be sure)"
                             QUERY PLAN                             
--------------------------------------------------------------------
 Function Scan on pg_flush_local_buffers (actual rows=1.00 loops=1)
 Planning Time: 0.011 ms
 Execution Time: 0.009 ms
(3 rows)

"Check actually Allocated buffers. Should be equal to :nbuffers"
 pg_allocated_local_buffers 
----------------------------
                       8192
(1 row)

"Wash away test table from memory buffers"
SELECT 57344
"NO MEASURE: flush displacer to exclude writings on read test (Check 'local written' to be sure)"
"Evictions of already flushed buffers don't need disk operations"
                             QUERY PLAN                             
--------------------------------------------------------------------
 Function Scan on pg_flush_local_buffers (actual rows=1.00 loops=1)
   Buffers: local written=8186
 Planning Time: 0.016 ms
 Execution Time: 12.348 ms
(4 rows)

"DROP displacer to free buffers"
DROP TABLE
"MEASURE: Read temp table block-by-block"
                            QUERY PLAN                             
-------------------------------------------------------------------
 Function Scan on pg_read_temp_relation (actual rows=1.00 loops=1)
   Buffers: local hit=4 read=8188
 Planning Time: 0.018 ms
 Execution Time: 9.452 ms
(4 rows)

"MEASURE: Dry-run: all the pages in the memory (check 'local hit')"
                            QUERY PLAN                             
-------------------------------------------------------------------
 Function Scan on pg_read_temp_relation (actual rows=1.00 loops=1)
   Buffers: local hit=72 read=8120
 Planning Time: 0.016 ms
 Execution Time: 9.313 ms
(4 rows)

