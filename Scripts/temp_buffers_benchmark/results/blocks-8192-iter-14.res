SET
CREATE EXTENSION
SET
"TEST RUN: " temp_buffers= 8192, ntuples= 8192*7
"Prepare table"
CREATE TABLE
INSERT 0 57344
"Check real number of disk pages used by the table"
 pg_relpages 
-------------
        8192
(1 row)

"Check actually allocated buffers (should be approximately "8192")"
 pg_allocated_local_buffers 
----------------------------
                       8197
(1 row)

"MEASURE: Flush the table block-by-block (verify 'local written' in output)"
                             QUERY PLAN                             
--------------------------------------------------------------------
 Function Scan on pg_flush_local_buffers (actual rows=1.00 loops=1)
   Buffers: local written=8195
 Planning Time: 0.002 ms
 Execution Time: 12.297 ms
(4 rows)

"MEASURE: Dry flush - no dirty buffers to write (verify 'local written' is zero)"
                             QUERY PLAN                             
--------------------------------------------------------------------
 Function Scan on pg_flush_local_buffers (actual rows=1.00 loops=1)
 Planning Time: 0.009 ms
 Execution Time: 0.009 ms
(3 rows)

"Evict test table from memory buffers by creating a displacer table"
"NOTE: insert extra tuples to be sure we evicted all the pages of the test table"
SELECT 57918
"NO MEASURE: Flush displacer to ensure it's on disk (verify 'local written')"
"Note: Evicting already-flushed buffers requires no disk writes"
                             QUERY PLAN                             
--------------------------------------------------------------------
 Function Scan on pg_flush_local_buffers (actual rows=1.00 loops=1)
   Buffers: local written=8196
 Planning Time: 0.014 ms
 Execution Time: 12.676 ms
(4 rows)

"Drop displacer table to free buffers"
DROP TABLE
"MEASURE: Read temp table block-by-block"
                            QUERY PLAN                             
-------------------------------------------------------------------
 Function Scan on pg_read_temp_relation (actual rows=1.00 loops=1)
   Buffers: local read=8192
 Planning Time: 0.017 ms
 Execution Time: 9.360 ms
(4 rows)

"MEASURE: Dry run - all pages now in memory (verify 'local hit' count)"
                            QUERY PLAN                             
-------------------------------------------------------------------
 Function Scan on pg_read_temp_relation (actual rows=1.00 loops=1)
   Buffers: local hit=8192
 Planning Time: 0.015 ms
 Execution Time: 0.234 ms
(4 rows)

"NO MEASURE: Evict test table from buffers by filling them with a dummy table"
SELECT 57918
DROP TABLE
"MEASURE: Read blocks of the temp table randomly"
                            QUERY PLAN                             
-------------------------------------------------------------------
 Function Scan on pg_read_temp_relation (actual rows=1.00 loops=1)
   Buffers: local read=8192
 Planning Time: 0.014 ms
 Execution Time: 10.446 ms
(4 rows)

                            QUERY PLAN                             
-------------------------------------------------------------------
 Function Scan on pg_read_temp_relation (actual rows=1.00 loops=1)
   Buffers: local hit=8192
 Planning Time: 0.012 ms
 Execution Time: 0.389 ms
(4 rows)

                            QUERY PLAN                             
-------------------------------------------------------------------
 Function Scan on pg_temp_buffers_dirty (actual rows=1.00 loops=1)
   Buffers: local hit=8192 dirtied=8192
 Planning Time: 0.003 ms
 Execution Time: 0.287 ms
(4 rows)

"Flush temp buffers to disk: they were read in random order. So, it will "
"be written in random order too"
                             QUERY PLAN                             
--------------------------------------------------------------------
 Function Scan on pg_flush_local_buffers (actual rows=1.00 loops=1)
   Buffers: local written=8192
 Planning Time: 0.003 ms
 Execution Time: 13.324 ms
(4 rows)

