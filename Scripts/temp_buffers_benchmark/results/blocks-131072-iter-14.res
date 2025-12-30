SET
CREATE EXTENSION
SET
"TEST RUN: " temp_buffers= 131072, ntuples= 131072*7
"Prepare table"
CREATE TABLE
INSERT 0 917504
"Check real number of disk pages used by the table"
 pg_relpages 
-------------
      131072
(1 row)

"MEASURE: flush of the table, block-by-block (Check 'local written' to be sure)"
                             QUERY PLAN                             
--------------------------------------------------------------------
 Function Scan on pg_flush_local_buffers (actual rows=1.00 loops=1)
   Buffers: local written=131105
 Planning Time: 0.005 ms
 Execution Time: 200.752 ms
(4 rows)

"MEASURE: dry flush (Nothing to write. Check 'local written' to be sure)"
                             QUERY PLAN                             
--------------------------------------------------------------------
 Function Scan on pg_flush_local_buffers (actual rows=1.00 loops=1)
 Planning Time: 0.016 ms
 Execution Time: 0.120 ms
(3 rows)

"Check actually Allocated buffers. Should be equal to "131072" or so"
 pg_allocated_local_buffers 
----------------------------
                     131107
(1 row)

"Wash away test table from memory buffers"
SELECT 917504
"NO MEASURE: flush displacer to exclude writings on read test (Check 'local written' to be sure)"
"Evictions of already flushed buffers don't need disk operations"
                             QUERY PLAN                             
--------------------------------------------------------------------
 Function Scan on pg_flush_local_buffers (actual rows=1.00 loops=1)
   Buffers: local written=117589
 Planning Time: 0.021 ms
 Execution Time: 169.828 ms
(4 rows)

"DROP displacer to free buffers"
DROP TABLE
"MEASURE: Read temp table block-by-block"
                            QUERY PLAN                             
-------------------------------------------------------------------
 Function Scan on pg_read_temp_relation (actual rows=1.00 loops=1)
   Buffers: local read=131072
 Planning Time: 0.024 ms
 Execution Time: 178.023 ms
(4 rows)

"MEASURE: Dry-run: all the pages in the memory (check 'local hit')"
                            QUERY PLAN                             
-------------------------------------------------------------------
 Function Scan on pg_read_temp_relation (actual rows=1.00 loops=1)
   Buffers: local hit=131072
 Planning Time: 0.016 ms
 Execution Time: 4.397 ms
(4 rows)

