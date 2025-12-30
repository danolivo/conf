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
   Buffers: local written=127
 Planning Time: 0.025 ms
 Execution Time: 1.183 ms
(4 rows)

"MEASURE: dry flush (Nothing to write. Check 'local written' to be sure)"
                             QUERY PLAN                             
--------------------------------------------------------------------
 Function Scan on pg_flush_local_buffers (actual rows=1.00 loops=1)
 Planning Time: 0.018 ms
 Execution Time: 0.009 ms
(3 rows)

"Check actually Allocated buffers. Should be equal to :nbuffers"
 pg_allocated_local_buffers 
----------------------------
                        128
(1 row)

"Wash away test table from memory buffers"
SELECT 896
"NO MEASURE: flush displacer to exclude writings on read test (Check 'local written' to be sure)"
                             QUERY PLAN                             
--------------------------------------------------------------------
 Function Scan on pg_flush_local_buffers (actual rows=1.00 loops=1)
   Buffers: local written=126
 Planning Time: 0.023 ms
 Execution Time: 1.097 ms
(4 rows)

"DROP displacer to free buffers"
DROP TABLE
"MEASURE: Read temp table block-by-block"
                            QUERY PLAN                             
-------------------------------------------------------------------
 Function Scan on pg_read_temp_relation (actual rows=1.00 loops=1)
   Buffers: local hit=2 read=126
 Planning Time: 0.019 ms
 Execution Time: 1.188 ms
(4 rows)

"MEASURE: Dry-run: all the pages in the memory (check 'local hit')"
                            QUERY PLAN                             
-------------------------------------------------------------------
 Function Scan on pg_read_temp_relation (actual rows=1.00 loops=1)
   Buffers: local hit=128
 Planning Time: 0.015 ms
 Execution Time: 0.045 ms
(4 rows)

