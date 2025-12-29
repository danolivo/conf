CREATE EXTENSION
SET
temp_buffers= 131072, ntuples= 131072*7
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
   Buffers: local written=131071
 Planning Time: 0.010 ms
 Execution Time: 581.507 ms
(4 rows)

"MEASURE: dry flush (Nothing to write. Check 'local written' to be sure)"
                             QUERY PLAN                             
--------------------------------------------------------------------
 Function Scan on pg_flush_local_buffers (actual rows=1.00 loops=1)
 Planning Time: 0.029 ms
 Execution Time: 0.363 ms
(3 rows)

"Check actually Allocated buffers. Should be equal to :nbuffers"
 pg_allocated_local_buffers 
----------------------------
                     131072
(1 row)

"Wash away test table from memory buffers"
SELECT 917504
"NO MEASURE: flush displacer to exclude writings on read test (Check 'local written' to be sure)"
                             QUERY PLAN                             
--------------------------------------------------------------------
 Function Scan on pg_flush_local_buffers (actual rows=1.00 loops=1)
   Buffers: local written=131036
 Planning Time: 0.033 ms
 Execution Time: 529.227 ms
(4 rows)

"MEASURE: Read temp table block-by-block"
                            QUERY PLAN                             
-------------------------------------------------------------------
 Function Scan on pg_read_temp_relation (actual rows=1.00 loops=1)
   Buffers: local hit=34 read=131038
 Planning Time: 0.032 ms
 Execution Time: 582.918 ms
(4 rows)

"MEASURE: Dry-run: all the pages in the memory (check 'local hit')"
                            QUERY PLAN                             
-------------------------------------------------------------------
 Function Scan on pg_read_temp_relation (actual rows=1.00 loops=1)
   Buffers: local hit=99 read=130973
 Planning Time: 0.028 ms
 Execution Time: 552.237 ms
(4 rows)

                            QUERY PLAN                             
-------------------------------------------------------------------
 Function Scan on pg_read_temp_relation (actual rows=1.00 loops=1)
   Buffers: local hit=131072
 Planning Time: 0.029 ms
 Execution Time: 30.253 ms
(4 rows)

