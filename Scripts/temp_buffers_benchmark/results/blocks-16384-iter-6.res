SET
CREATE EXTENSION
SET
"TEST RUN: " temp_buffers= 16384, ntuples= 16384*7
"Prepare table"
CREATE TABLE
INSERT 0 114688
"Check real number of disk pages used by the table"
 pg_relpages 
-------------
       16384
(1 row)

"Check actually allocated buffers (should be approximately "16384")"
 pg_allocated_local_buffers 
----------------------------
                      16391
(1 row)

"MEASURE: Flush the table block-by-block (verify 'local written' in output)"
                             QUERY PLAN                             
--------------------------------------------------------------------
 Function Scan on pg_flush_local_buffers (actual rows=1.00 loops=1)
   Buffers: local written=16389
 Planning Time: 0.006 ms
 Execution Time: 24.759 ms
(4 rows)

"MEASURE: Dry flush - no dirty buffers to write (verify 'local written' is zero)"
                             QUERY PLAN                             
--------------------------------------------------------------------
 Function Scan on pg_flush_local_buffers (actual rows=1.00 loops=1)
 Planning Time: 0.013 ms
 Execution Time: 0.016 ms
(3 rows)

"Evict test table from memory buffers by creating a displacer table"
"NOTE: insert extra tuples to be sure we evicted all the pages of the test table"
SELECT 115836
"NO MEASURE: Flush displacer to ensure it's on disk (verify 'local written')"
"Note: Evicting already-flushed buffers requires no disk writes"
                             QUERY PLAN                             
--------------------------------------------------------------------
 Function Scan on pg_flush_local_buffers (actual rows=1.00 loops=1)
   Buffers: local written=16387
 Planning Time: 0.016 ms
 Execution Time: 26.053 ms
(4 rows)

"Drop displacer table to free buffers"
DROP TABLE
"MEASURE: Read temp table block-by-block"
                            QUERY PLAN                             
-------------------------------------------------------------------
 Function Scan on pg_read_temp_relation (actual rows=1.00 loops=1)
   Buffers: local read=16384
 Planning Time: 0.012 ms
 Execution Time: 19.265 ms
(4 rows)

"MEASURE: Dry run - all pages now in memory (verify 'local hit' count)"
                            QUERY PLAN                             
-------------------------------------------------------------------
 Function Scan on pg_read_temp_relation (actual rows=1.00 loops=1)
   Buffers: local hit=16384
 Planning Time: 0.012 ms
 Execution Time: 0.473 ms
(4 rows)

"NO MEASURE: Evict test table from buffers by filling them with a dummy table"
SELECT 115836
DROP TABLE
"MEASURE: Read blocks of the temp table randomly"
                            QUERY PLAN                             
-------------------------------------------------------------------
 Function Scan on pg_read_temp_relation (actual rows=1.00 loops=1)
   Buffers: local read=16384
 Planning Time: 0.013 ms
 Execution Time: 21.666 ms
(4 rows)

                            QUERY PLAN                             
-------------------------------------------------------------------
 Function Scan on pg_read_temp_relation (actual rows=1.00 loops=1)
   Buffers: local hit=16384
 Planning Time: 0.013 ms
 Execution Time: 0.853 ms
(4 rows)

                            QUERY PLAN                             
-------------------------------------------------------------------
 Function Scan on pg_temp_buffers_dirty (actual rows=1.00 loops=1)
   Buffers: local hit=16384 dirtied=16384
 Planning Time: 0.005 ms
 Execution Time: 0.678 ms
(4 rows)

"Flush temp buffers to disk: they were read in random order. So, it will "
"be written in random order too"
                             QUERY PLAN                             
--------------------------------------------------------------------
 Function Scan on pg_flush_local_buffers (actual rows=1.00 loops=1)
   Buffers: local written=16384
 Planning Time: 0.003 ms
 Execution Time: 27.383 ms
(4 rows)

