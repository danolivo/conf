/*
 * The example of a table with a timestamp field
 */

DROP TABLE IF EXISTS test_2 CASCADE;
DEALLOCATE ALL;
SET plan_cache_mode = 'force_generic_plan';
SET enable_bitmapscan = 'off'; -- Just let our example be more simple

CREATE TABLE test_2 (
  id         serial PRIMARY KEY,
  start_date timestamp,
  payload    text DEFAULT 'Just a long text line'
);

-- SELECT current_timestamp;

INSERT INTO test_2 (start_date) (
  SELECT current_timestamp - (((random()*10000)::integer)::text || 'day') ::interval
  FROM generate_series(1,1E6)
);
CREATE INDEX ON test_2(start_date);
ANALYZE test_2;

EXPLAIN (ANALYZE, TIMING OFF, BUFFERS OFF, SUMMARY OFF)
SELECT * FROM test_2
WHERE
  start_date > '2025-06-30'::timestamp - '7 days'::interval;

/*
 Index Scan using test_2_start_date_idx on test_2  (cost=0.42..2848.96 rows=739 width=34) (actual rows=746.00 loops=1)
   Index Cond: (start_date > '2025-06-23 00:00:00'::timestamp without time zone)
   Index Searches: 1
*/

PREPARE tst3(timestamp) AS
SELECT * FROM test_2
WHERE start_date > $1 - '7 days'::interval;

EXPLAIN
EXECUTE tst3('2025-06-30'::timestamp);

/*
 Seq Scan on test_2  (cost=0.00..23334.00 rows=333333 width=34)
   Filter: (start_date > ($1 - '7 days'::interval))
*/