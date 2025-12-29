CREATE EXTENSION
SET
temp_buffers= 128, ntuples= 128*7
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
 Planning Time: 0.012 ms
 Execution Time: 0.465 ms
(4 rows)

"MEASURE: dry flush (Nothing to write. Check 'local written' to be sure)"
                             QUERY PLAN                             
--------------------------------------------------------------------
 Function Scan on pg_flush_local_buffers (actual rows=1.00 loops=1)
 Planning Time: 0.008 ms
 Execution Time: 0.005 ms
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
 Planning Time: 0.007 ms
 Execution Time: 0.600 ms
(4 rows)

"MEASURE: Read temp table block-by-block"
                            QUERY PLAN                             
-------------------------------------------------------------------
 Function Scan on pg_read_temp_relation (actual rows=1.00 loops=1)
   Buffers: local hit=2 read=126
 Planning Time: 0.006 ms
 Execution Time: 0.519 ms
(4 rows)

"MEASURE: Dry-run: all the pages in the memory (check 'local hit')"
                            QUERY PLAN                             
-------------------------------------------------------------------
 Function Scan on pg_read_temp_relation (actual rows=1.00 loops=1)
   Buffers: local hit=123 read=5
 Planning Time: 0.006 ms
 Execution Time: 0.059 ms
(4 rows)

                            QUERY PLAN                             
-------------------------------------------------------------------
 Function Scan on pg_read_temp_relation (actual rows=1.00 loops=1)
   Buffers: local hit=128
 Planning Time: 0.005 ms
 Execution Time: 0.036 ms
(4 rows)

