SET
CREATE EXTENSION
SET
"TEST RUN: " temp_buffers= 4096, ntuples= 4096*7
"Prepare table"
CREATE TABLE
INSERT 0 28672
"Check real number of disk pages used by the table"
 pg_relpages 
-------------
        4096
(1 row)

"Check actually allocated buffers (should be approximately "4096")"
 pg_allocated_local_buffers 
----------------------------
                       4100
(1 row)

"MEASURE: Flush the table block-by-block (verify 'local written' in output)"
                             QUERY PLAN                             
--------------------------------------------------------------------
 Function Scan on pg_flush_local_buffers (actual rows=1.00 loops=1)
   Buffers: local written=4098
 Planning Time: 0.003 ms
 Execution Time: 6.892 ms
(4 rows)

"MEASURE: Dry flush - no dirty buffers to write (verify 'local written' is zero)"
                             QUERY PLAN                             
--------------------------------------------------------------------
 Function Scan on pg_flush_local_buffers (actual rows=1.00 loops=1)
 Planning Time: 0.021 ms
 Execution Time: 0.008 ms
(3 rows)

"Evict test table from memory buffers by creating a displacer table"
"NOTE: insert extra tuples to be sure we evicted all the pages of the test table"
SELECT 28959
"NO MEASURE: Flush displacer to ensure it's on disk (verify 'local written')"
"Note: Evicting already-flushed buffers requires no disk writes"
                             QUERY PLAN                             
--------------------------------------------------------------------
 Function Scan on pg_flush_local_buffers (actual rows=1.00 loops=1)
   Buffers: local written=4099
 Planning Time: 0.017 ms
 Execution Time: 6.581 ms
(4 rows)

"Drop displacer table to free buffers"
DROP TABLE
"MEASURE: Read temp table block-by-block"
                            QUERY PLAN                             
-------------------------------------------------------------------
 Function Scan on pg_read_temp_relation (actual rows=1.00 loops=1)
   Buffers: local read=4096
 Planning Time: 0.013 ms
 Execution Time: 4.585 ms
(4 rows)

"MEASURE: Dry run - all pages now in memory (verify 'local hit' count)"
                            QUERY PLAN                             
-------------------------------------------------------------------
 Function Scan on pg_read_temp_relation (actual rows=1.00 loops=1)
   Buffers: local hit=4096
 Planning Time: 0.012 ms
 Execution Time: 0.116 ms
(4 rows)

"NO MEASURE: Evict test table from buffers by filling them with a dummy table"
SELECT 28959
DROP TABLE
"MEASURE: Read blocks of the temp table randomly"
                            QUERY PLAN                             
-------------------------------------------------------------------
 Function Scan on pg_read_temp_relation (actual rows=1.00 loops=1)
   Buffers: local read=4096
 Planning Time: 0.013 ms
 Execution Time: 5.097 ms
(4 rows)

                            QUERY PLAN                             
-------------------------------------------------------------------
 Function Scan on pg_read_temp_relation (actual rows=1.00 loops=1)
   Buffers: local hit=4096
 Planning Time: 0.011 ms
 Execution Time: 0.174 ms
(4 rows)

                            QUERY PLAN                             
-------------------------------------------------------------------
 Function Scan on pg_temp_buffers_dirty (actual rows=1.00 loops=1)
   Buffers: local hit=4096 dirtied=4096
 Planning Time: 0.002 ms
 Execution Time: 0.132 ms
(4 rows)

"Flush temp buffers to disk: they were read in random order. So, it will "
"be written in random order too"
                             QUERY PLAN                             
--------------------------------------------------------------------
 Function Scan on pg_flush_local_buffers (actual rows=1.00 loops=1)
   Buffers: local written=4096
 Planning Time: 0.002 ms
 Execution Time: 6.306 ms
(4 rows)

