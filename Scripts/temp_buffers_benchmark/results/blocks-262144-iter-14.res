SET
CREATE EXTENSION
SET
"TEST RUN: " temp_buffers= 262144, ntuples= 262144*7
"Prepare table"
CREATE TABLE
INSERT 0 1835008
"Check real number of disk pages used by the table"
 pg_relpages 
-------------
      262144
(1 row)

"MEASURE: flush of the table, block-by-block (Check 'local written' to be sure)"
                             QUERY PLAN                             
--------------------------------------------------------------------
 Function Scan on pg_flush_local_buffers (actual rows=1.00 loops=1)
   Buffers: local written=262209
 Planning Time: 0.004 ms
 Execution Time: 405.069 ms
(4 rows)

"MEASURE: dry flush (Nothing to write. Check 'local written' to be sure)"
                             QUERY PLAN                             
--------------------------------------------------------------------
 Function Scan on pg_flush_local_buffers (actual rows=1.00 loops=1)
 Planning Time: 0.020 ms
 Execution Time: 0.235 ms
(3 rows)

"Check actually Allocated buffers. Should be equal to "262144" or so"
 pg_allocated_local_buffers 
----------------------------
                     262211
(1 row)

"Wash away test table from memory buffers"
SELECT 1835008
"NO MEASURE: flush displacer to exclude writings on read test (Check 'local written' to be sure)"
"Evictions of already flushed buffers don't need disk operations"
                             QUERY PLAN                             
--------------------------------------------------------------------
 Function Scan on pg_flush_local_buffers (actual rows=1.00 loops=1)
   Buffers: local written=235182
 Planning Time: 0.020 ms
 Execution Time: 4560.675 ms
(4 rows)

"DROP displacer to free buffers"
DROP TABLE
"MEASURE: Read temp table block-by-block"
                            QUERY PLAN                             
-------------------------------------------------------------------
 Function Scan on pg_read_temp_relation (actual rows=1.00 loops=1)
   Buffers: local read=262144
 Planning Time: 0.021 ms
 Execution Time: 367.711 ms
(4 rows)

"MEASURE: Dry-run: all the pages in the memory (check 'local hit')"
                            QUERY PLAN                             
-------------------------------------------------------------------
 Function Scan on pg_read_temp_relation (actual rows=1.00 loops=1)
   Buffers: local hit=262144
 Planning Time: 0.021 ms
 Execution Time: 10.311 ms
(4 rows)

