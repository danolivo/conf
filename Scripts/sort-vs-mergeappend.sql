/*
 * Patch to test:
 * https://www.postgresql.org/message-id/2bc323df-0662-406a-8abf-dade726b31d8@gmail.com
 */

DROP TABLE IF EXISTS test CASCADE;
DEALLOCATE ALL;

DO $$
DECLARE
  parts integer := 16;
  i integer;
BEGIN
  -- Remove shreds, if still exists
  FOR i IN 1..parts LOOP
    EXECUTE format('DROP TABLE IF EXISTS l%s', i);
  END LOOP;

  CREATE TEMP TABLE test (x real, y real DEFAULT random())
  PARTITION BY HASH (x);
  
  FOR i IN 1..parts LOOP
    EXECUTE format('CREATE TEMP TABLE l%s PARTITION OF test FOR VALUES WITH (modulus %s, remainder %s)', i, parts, i-1);
  END LOOP;
END$$;

-- Let's change the constant in this INSERT to obtain different table size
INSERT INTO test (x) SELECT random() FROM generate_series(1,1E1);
CREATE INDEX ON test (y);
ANALYZE;
ANALYZE test;

SET work_mem = '128MB';
SET plan_cache_mode = 'force_generic_plan';
SET max_parallel_workers_per_gather = 0;
SET enable_indexscan = 'off';
SET enable_bitmapscan = 'off';
RESET enable_sort;

--SET enable_sort = 'off';

/*
SET enable_sort = 'on';

EXPLAIN (COSTS ON) SELECT * FROM test ORDER BY y;

1E1: Sort  (cost=9.53..9.57 rows=17 width=8)
1E2: Sort  (cost=20.82..21.07 rows=100 width=8)
1E3: Merge Append  (cost=56.19..83.69 rows=1000 width=8)
1E4: Merge Append  (cost=612.74..887.74 rows=10000 width=8)
1E5: Merge Append  (cost=7754.19..10504.19 rows=100000 width=8)
1E6: Merge Append  (cost=94092.25..121592.25 rows=1000000 width=8)
1E7: Merge Append  (cost=1106931.22..1381931.22 rows=10000000 width=8) (actual rows=10000000.00 loops=1)
1E8: Merge Append  (cost=14097413.40..16847413.40 rows=100000000 width=8) (actual rows=100000000.00 loops=1)
 
SET enable_sort = 'off';

EXPLAIN (COSTS ON) SELECT * FROM test ORDER BY y;

1E3: Sort  (cost=80.83..83.33 rows=1000 width=8)
1E4: Sort  (cost=863.39..888.39 rows=10000 width=8)
1E5: Sort  (cost=10253.82..10503.82 rows=100000 width=8)
1E6: Sort  (cost=119089.84..121589.84 rows=1000000 width=8)
1E7: Sort  (cost=1493651.33..1518651.33 rows=10000000 width=8) (actual rows=10000000.00 loops=1) - disk
1E8: Sort  (cost=16597384.88..16847384.88 rows=100000000 width=8) (actual rows=100000000.00 loops=1) - disk
*/

-- What about real timings?

/*
1E3: MergeAppend: 1.927 ms, Sort: 0.720 ms
1E4: MergeAppend: 10.090 ms, Sort: 7.583 ms
1E5: MergeAppend: 118.885 ms, Sort: 88.492 ms
1E6: MergeAppend: 1372.717 ms, Sort: 1106.184 ms
1E7: MergeAppend: 15103.893 ms, Sort: 13415.806 ms
1E8: MergeAppend: 176553.133 ms, Sort: 149458.787 ms
*/

PREPARE tst AS SELECT * FROM test ORDER BY y;
EXPLAIN (ANALYZE, COSTS ON, TIMING OFF, BUFFERS OFF) EXECUTE tst;

/*
Modified:

1E1: Merge Append  (cost=6.59..7.58 rows=20 width=8) (actual rows=10.00 loops=1) Execution Time: 0.508 ms
1E2: Merge Append  (cost=17.76..22.56 rows=101 width=8) (actual rows=100.00 loops=1) Execution Time: 0.457 ms
1E4: Merge Append  (cost=613.83..1088.83 rows=10000 width=8) (actual rows=10000.00 loops=1) Execution Time: 9.797 ms
1E6: Merge Append  (cost=94090.19..141590.19 rows=1000000 width=8) (actual rows=1000000.00 loops=1) Execution Time: 1317.099 ms
1E7: Merge Append  (cost=1106930.24..1581930.24 rows=10000000 width=8) (actual rows=10000000.00 loops=1) Execution Time: 15440.124 ms
1E8: Merge Append  (cost=14097410.90..18847410.90 rows=100000000 width=8) (actual rows=100000000.00 loops=1) Execution Time: 172893.067 ms
*/

/*
SiftDown modifications:

1E1: Sort  (cost=7.60..7.65 rows=19 width=8) (actual rows=10.00 loops=1)
1E3: Sort  (cost=80.83..83.33 rows=1000 width=8) (actual rows=1000.00 loops=1)
1E5: Sort  (cost=10254.82..10504.82 rows=100000 width=8) (actual rows=100000.00 loops=1)
1E7: Sort  (cost=1493652.33..1518652.33 rows=10000000 width=8) (actual rows=10000000.00 loops=1)
 */