SET
CREATE EXTENSION
SET
"TEST RUN: " temp_buffers= 2048, ntuples= 2048*7
"Prepare table"
CREATE TABLE
INSERT 0 14336
"Check real number of disk pages used by the table"
 pg_relpages 
-------------
        2048
(1 row)

"MEASURE: flush of the table, block-by-block (Check 'local written' to be sure)"
                             QUERY PLAN                             
--------------------------------------------------------------------
 Function Scan on pg_flush_local_buffers (actual rows=1.00 loops=1)
   Buffers: local written=2047
 Planning Time: 0.011 ms
 Execution Time: 9.865 ms
(4 rows)

"MEASURE: dry flush (Nothing to write. Check 'local written' to be sure)"
                             QUERY PLAN                             
--------------------------------------------------------------------
 Function Scan on pg_flush_local_buffers (actual rows=1.00 loops=1)
 Planning Time: 0.028 ms
 Execution Time: 0.014 ms
(3 rows)

"Check actually Allocated buffers. Should be equal to :nbuffers"
 pg_allocated_local_buffers 
----------------------------
                       2048
(1 row)

"Wash away test table from memory buffers"
SELECT 14336
"NO MEASURE: flush displacer to exclude writings on read test (Check 'local written' to be sure)"
                             QUERY PLAN                             
--------------------------------------------------------------------
 Function Scan on pg_flush_local_buffers (actual rows=1.00 loops=1)
   Buffers: local written=2046
 Planning Time: 0.030 ms
 Execution Time: 8.688 ms
(4 rows)

"DROP displacer to free buffers"
DROP TABLE
"MEASURE: Read temp table block-by-block"
                            QUERY PLAN                             
-------------------------------------------------------------------
 Function Scan on pg_read_temp_relation (actual rows=1.00 loops=1)
   Buffers: local hit=2 read=2046
 Planning Time: 0.025 ms
 Execution Time: 8.535 ms
(4 rows)

"MEASURE: Dry-run: all the pages in the memory (check 'local hit')"
                            QUERY PLAN                             
-------------------------------------------------------------------
 Function Scan on pg_read_temp_relation (actual rows=1.00 loops=1)
   Buffers: local hit=2048
 Planning Time: 0.025 ms
 Execution Time: 0.439 ms
(4 rows)

