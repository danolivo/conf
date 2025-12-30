SET
CREATE EXTENSION
SET
"TEST RUN: " temp_buffers= 65536, ntuples= 65536*7
"Prepare table"
CREATE TABLE
INSERT 0 458752
"Check real number of disk pages used by the table"
 pg_relpages 
-------------
       65536
(1 row)

"MEASURE: flush of the table, block-by-block (Check 'local written' to be sure)"
                             QUERY PLAN                             
--------------------------------------------------------------------
 Function Scan on pg_flush_local_buffers (actual rows=1.00 loops=1)
   Buffers: local written=65553
 Planning Time: 0.005 ms
 Execution Time: 101.160 ms
(4 rows)

"MEASURE: dry flush (Nothing to write. Check 'local written' to be sure)"
                             QUERY PLAN                             
--------------------------------------------------------------------
 Function Scan on pg_flush_local_buffers (actual rows=1.00 loops=1)
 Planning Time: 0.019 ms
 Execution Time: 0.064 ms
(3 rows)

"Check actually Allocated buffers. Should be equal to "65536" or so"
 pg_allocated_local_buffers 
----------------------------
                      65555
(1 row)

"Wash away test table from memory buffers"
SELECT 458752
"NO MEASURE: flush displacer to exclude writings on read test (Check 'local written' to be sure)"
"Evictions of already flushed buffers don't need disk operations"
                             QUERY PLAN                             
--------------------------------------------------------------------
 Function Scan on pg_flush_local_buffers (actual rows=1.00 loops=1)
   Buffers: local written=58792
 Planning Time: 0.023 ms
 Execution Time: 84.756 ms
(4 rows)

"DROP displacer to free buffers"
DROP TABLE
"MEASURE: Read temp table block-by-block"
                            QUERY PLAN                             
-------------------------------------------------------------------
 Function Scan on pg_read_temp_relation (actual rows=1.00 loops=1)
   Buffers: local read=65536
 Planning Time: 0.016 ms
 Execution Time: 80.522 ms
(4 rows)

"MEASURE: Dry-run: all the pages in the memory (check 'local hit')"
                            QUERY PLAN                             
-------------------------------------------------------------------
 Function Scan on pg_read_temp_relation (actual rows=1.00 loops=1)
   Buffers: local hit=65536
 Planning Time: 0.014 ms
 Execution Time: 2.116 ms
(4 rows)

