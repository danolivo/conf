CREATE EXTENSION
SET
temp_buffers= 32768, ntuples= 32768*7
"Prepare table"
CREATE TABLE
INSERT 0 229376
"Check real number of disk pages used by the table"
 pg_relpages 
-------------
       32768
(1 row)

"MEASURE: flush of the table, block-by-block (Check 'local written' to be sure)"
                             QUERY PLAN                             
--------------------------------------------------------------------
 Function Scan on pg_flush_local_buffers (actual rows=1.00 loops=1)
   Buffers: local written=32767
 Planning Time: 0.010 ms
 Execution Time: 129.747 ms
(4 rows)

"MEASURE: dry flush (Nothing to write. Check 'local written' to be sure)"
                             QUERY PLAN                             
--------------------------------------------------------------------
 Function Scan on pg_flush_local_buffers (actual rows=1.00 loops=1)
 Planning Time: 0.026 ms
 Execution Time: 0.088 ms
(3 rows)

"Check actually Allocated buffers. Should be equal to :nbuffers"
 pg_allocated_local_buffers 
----------------------------
                      32768
(1 row)

"Wash away test table from memory buffers"
SELECT 229376
"NO MEASURE: flush displacer to exclude writings on read test (Check 'local written' to be sure)"
                             QUERY PLAN                             
--------------------------------------------------------------------
 Function Scan on pg_flush_local_buffers (actual rows=1.00 loops=1)
   Buffers: local written=32756
 Planning Time: 0.031 ms
 Execution Time: 128.309 ms
(4 rows)

"MEASURE: Read temp table block-by-block"
                            QUERY PLAN                             
-------------------------------------------------------------------
 Function Scan on pg_read_temp_relation (actual rows=1.00 loops=1)
   Buffers: local hit=10 read=32758
 Planning Time: 0.032 ms
 Execution Time: 134.937 ms
(4 rows)

"MEASURE: Dry-run: all the pages in the memory (check 'local hit')"
                            QUERY PLAN                             
-------------------------------------------------------------------
 Function Scan on pg_read_temp_relation (actual rows=1.00 loops=1)
   Buffers: local hit=75 read=32693
 Planning Time: 0.027 ms
 Execution Time: 132.270 ms
(4 rows)

                            QUERY PLAN                             
-------------------------------------------------------------------
 Function Scan on pg_read_temp_relation (actual rows=1.00 loops=1)
   Buffers: local hit=32768
 Planning Time: 0.026 ms
 Execution Time: 6.586 ms
(4 rows)

