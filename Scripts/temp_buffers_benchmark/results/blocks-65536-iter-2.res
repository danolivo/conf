SET
CREATE EXTENSION
SET
"TEST RUN: " temp_buffers= 65536, ntuples= 65536*7
"Prepare table"
CREATE TABLE
INSERT 0 458752
"Check real number of disk pages used by the table"
 pg_relpages 
-------------
       65536
(1 row)

"Check actually allocated buffers (should be approximately "65536")"
 pg_allocated_local_buffers 
----------------------------
                      65555
(1 row)

"MEASURE: Flush the table block-by-block (verify 'local written' in output)"
                             QUERY PLAN                             
--------------------------------------------------------------------
 Function Scan on pg_flush_local_buffers (actual rows=1.00 loops=1)
   Buffers: local written=65553
 Planning Time: 0.002 ms
 Execution Time: 98.673 ms
(4 rows)

"MEASURE: Dry flush - no dirty buffers to write (verify 'local written' is zero)"
                             QUERY PLAN                             
--------------------------------------------------------------------
 Function Scan on pg_flush_local_buffers (actual rows=1.00 loops=1)
 Planning Time: 0.014 ms
 Execution Time: 0.058 ms
(3 rows)

"Evict test table from memory buffers by creating a displacer table"
"NOTE: insert extra tuples to be sure we evicted all the pages of the test table"
SELECT 463337
"NO MEASURE: Flush displacer to ensure it's on disk (verify 'local written')"
"Note: Evicting already-flushed buffers requires no disk writes"
                             QUERY PLAN                             
--------------------------------------------------------------------
 Function Scan on pg_flush_local_buffers (actual rows=1.00 loops=1)
   Buffers: local written=65535
 Planning Time: 0.022 ms
 Execution Time: 108.218 ms
(4 rows)

"Drop displacer table to free buffers"
DROP TABLE
"MEASURE: Read temp table block-by-block"
                            QUERY PLAN                             
-------------------------------------------------------------------
 Function Scan on pg_read_temp_relation (actual rows=1.00 loops=1)
   Buffers: local read=65536
 Planning Time: 0.018 ms
 Execution Time: 86.759 ms
(4 rows)

"MEASURE: Dry run - all pages now in memory (verify 'local hit' count)"
                            QUERY PLAN                             
-------------------------------------------------------------------
 Function Scan on pg_read_temp_relation (actual rows=1.00 loops=1)
   Buffers: local hit=65536
 Planning Time: 0.014 ms
 Execution Time: 2.036 ms
(4 rows)

"NO MEASURE: Evict test table from buffers by filling them with a dummy table"
SELECT 463337
DROP TABLE
"MEASURE: Read blocks of the temp table randomly"
                            QUERY PLAN                             
-------------------------------------------------------------------
 Function Scan on pg_read_temp_relation (actual rows=1.00 loops=1)
   Buffers: local read=65536
 Planning Time: 0.014 ms
 Execution Time: 97.110 ms
(4 rows)

                            QUERY PLAN                             
-------------------------------------------------------------------
 Function Scan on pg_read_temp_relation (actual rows=1.00 loops=1)
   Buffers: local hit=65536
 Planning Time: 0.015 ms
 Execution Time: 4.372 ms
(4 rows)

                            QUERY PLAN                             
-------------------------------------------------------------------
 Function Scan on pg_temp_buffers_dirty (actual rows=1.00 loops=1)
   Buffers: local hit=65536 dirtied=65536
 Planning Time: 0.006 ms
 Execution Time: 2.676 ms
(4 rows)

"Flush temp buffers to disk: they were read in random order. So, it will "
"be written in random order too"
                             QUERY PLAN                             
--------------------------------------------------------------------
 Function Scan on pg_flush_local_buffers (actual rows=1.00 loops=1)
   Buffers: local written=65536
 Planning Time: 0.002 ms
 Execution Time: 117.890 ms
(4 rows)

