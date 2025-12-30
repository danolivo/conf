SET
CREATE EXTENSION
SET
"TEST RUN: " temp_buffers= 32768, ntuples= 32768*7
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
 Planning Time: 0.012 ms
 Execution Time: 139.241 ms
(4 rows)

"MEASURE: dry flush (Nothing to write. Check 'local written' to be sure)"
                             QUERY PLAN                             
--------------------------------------------------------------------
 Function Scan on pg_flush_local_buffers (actual rows=1.00 loops=1)
 Planning Time: 0.027 ms
 Execution Time: 0.098 ms
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
 Execution Time: 134.670 ms
(4 rows)

"DROP displacer to free buffers"
DROP TABLE
"MEASURE: Read temp table block-by-block"
                            QUERY PLAN                             
-------------------------------------------------------------------
 Function Scan on pg_read_temp_relation (actual rows=1.00 loops=1)
   Buffers: local hit=10 read=32758
 Planning Time: 0.030 ms
 Execution Time: 133.408 ms
(4 rows)

"MEASURE: Dry-run: all the pages in the memory (check 'local hit')"
                            QUERY PLAN                             
-------------------------------------------------------------------
 Function Scan on pg_read_temp_relation (actual rows=1.00 loops=1)
   Buffers: local hit=12 read=32756
 Planning Time: 0.029 ms
 Execution Time: 140.469 ms
(4 rows)

