SET
CREATE EXTENSION
SET
"TEST RUN: " temp_buffers= 1024, ntuples= 1024*7
"Prepare table"
CREATE TABLE
INSERT 0 7168
"Check real number of disk pages used by the table"
 pg_relpages 
-------------
        1024
(1 row)

"Check actually allocated buffers (should be approximately "1024")"
 pg_allocated_local_buffers 
----------------------------
                       1027
(1 row)

"MEASURE: Flush the table block-by-block (verify 'local written' in output)"
                             QUERY PLAN                             
--------------------------------------------------------------------
 Function Scan on pg_flush_local_buffers (actual rows=1.00 loops=1)
   Buffers: local written=1025
 Planning Time: 0.002 ms
 Execution Time: 0.964 ms
(4 rows)

"MEASURE: Dry flush - no dirty buffers to write (verify 'local written' is zero)"
                             QUERY PLAN                             
--------------------------------------------------------------------
 Function Scan on pg_flush_local_buffers (actual rows=1.00 loops=1)
 Planning Time: 0.002 ms
 Execution Time: 0.002 ms
(3 rows)

"Evict test table from memory buffers by creating a displacer table"
"NOTE: insert extra tuples to be sure we evicted all the pages of the test table"
SELECT 7238
"NO MEASURE: Flush displacer to ensure it's on disk (verify 'local written')"
"Note: Evicting already-flushed buffers requires no disk writes"
                             QUERY PLAN                             
--------------------------------------------------------------------
 Function Scan on pg_flush_local_buffers (actual rows=1.00 loops=1)
   Buffers: local written=980
 Planning Time: 0.005 ms
 Execution Time: 1.533 ms
(4 rows)

"Drop displacer table to free buffers"
DROP TABLE
"MEASURE: Read temp table block-by-block"
                            QUERY PLAN                             
-------------------------------------------------------------------
 Function Scan on pg_read_temp_relation (actual rows=1.00 loops=1)
   Buffers: local read=1024
 Planning Time: 0.004 ms
 Execution Time: 1.018 ms
(4 rows)

"MEASURE: Dry run - all pages now in memory (verify 'local hit' count)"
                            QUERY PLAN                             
-------------------------------------------------------------------
 Function Scan on pg_read_temp_relation (actual rows=1.00 loops=1)
   Buffers: local hit=1024
 Planning Time: 0.002 ms
 Execution Time: 0.027 ms
(4 rows)

"NO MEASURE: Evict test table from buffers by filling them with a dummy table"
SELECT 7238
DROP TABLE
"MEASURE: Read blocks of the temp table randomly"
                            QUERY PLAN                             
-------------------------------------------------------------------
 Function Scan on pg_read_temp_relation (actual rows=1.00 loops=1)
   Buffers: local read=1024
 Planning Time: 0.008 ms
 Execution Time: 1.156 ms
(4 rows)

                            QUERY PLAN                             
-------------------------------------------------------------------
 Function Scan on pg_read_temp_relation (actual rows=1.00 loops=1)
   Buffers: local hit=1024
 Planning Time: 0.005 ms
 Execution Time: 0.038 ms
(4 rows)

                            QUERY PLAN                             
-------------------------------------------------------------------
 Function Scan on pg_temp_buffers_dirty (actual rows=1.00 loops=1)
   Buffers: local hit=1024 dirtied=1024
 Planning Time: 0.002 ms
 Execution Time: 0.034 ms
(4 rows)

"Flush temp buffers to disk: they were read in random order. So, it will "
"be written in random order too"
                             QUERY PLAN                             
--------------------------------------------------------------------
 Function Scan on pg_flush_local_buffers (actual rows=1.00 loops=1)
   Buffers: local written=1024
 Planning Time: 0.002 ms
 Execution Time: 1.147 ms
(4 rows)

