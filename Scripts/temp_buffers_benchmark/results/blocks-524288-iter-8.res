SET
CREATE EXTENSION
SET
"TEST RUN: " temp_buffers= 524288, ntuples= 524288*7
"Prepare table"
CREATE TABLE
INSERT 0 3670016
"Check real number of disk pages used by the table"
 pg_relpages 
-------------
      524288
(1 row)

"MEASURE: flush of the table, block-by-block (Check 'local written' to be sure)"
                             QUERY PLAN                             
--------------------------------------------------------------------
 Function Scan on pg_flush_local_buffers (actual rows=1.00 loops=1)
   Buffers: local written=524287
 Planning Time: 0.010 ms
 Execution Time: 13790.320 ms
(4 rows)

"MEASURE: dry flush (Nothing to write. Check 'local written' to be sure)"
                             QUERY PLAN                             
--------------------------------------------------------------------
 Function Scan on pg_flush_local_buffers (actual rows=1.00 loops=1)
 Planning Time: 0.028 ms
 Execution Time: 1.364 ms
(3 rows)

"Check actually Allocated buffers. Should be equal to :nbuffers"
 pg_allocated_local_buffers 
----------------------------
                     524288
(1 row)

"Wash away test table from memory buffers"
SELECT 3670016
"NO MEASURE: flush displacer to exclude writings on read test (Check 'local written' to be sure)"
                             QUERY PLAN                             
--------------------------------------------------------------------
 Function Scan on pg_flush_local_buffers (actual rows=1.00 loops=1)
   Buffers: local written=524156
 Planning Time: 0.029 ms
 Execution Time: 13210.704 ms
(4 rows)

"DROP displacer to free buffers"
DROP TABLE
"MEASURE: Read temp table block-by-block"
                            QUERY PLAN                             
-------------------------------------------------------------------
 Function Scan on pg_read_temp_relation (actual rows=1.00 loops=1)
   Buffers: local hit=130 read=524158
 Planning Time: 0.029 ms
 Execution Time: 2749.236 ms
(4 rows)

"MEASURE: Dry-run: all the pages in the memory (check 'local hit')"
                            QUERY PLAN                             
-------------------------------------------------------------------
 Function Scan on pg_read_temp_relation (actual rows=1.00 loops=1)
   Buffers: local hit=132 read=524156
 Planning Time: 0.030 ms
 Execution Time: 3692.899 ms
(4 rows)

