/*
 * Patch to test:
 * https://www.postgresql.org/message-id/2bc323df-0662-406a-8abf-dade726b31d8@gmail.com
 */

DROP FUNCTION IF EXISTS part_builder;
  
SET work_mem = '128MB';
SET plan_cache_mode = 'force_generic_plan';
SET max_parallel_workers_per_gather = 0;
SET enable_indexscan = 'off';
SET enable_bitmapscan = 'off';

CREATE FUNCTION part_builder(parts integer, size bigint) RETURNS VOID AS
$$
DECLARE
  i integer;
BEGIN
  DROP TABLE IF EXISTS test CASCADE;

  -- Remove shreds, if still exists
  FOR i IN 1..parts LOOP
    EXECUTE format('DROP TABLE IF EXISTS l%s', i);
  END LOOP;

  CREATE TEMP TABLE test (x real, y real DEFAULT random())
  PARTITION BY HASH (x);
  
  FOR i IN 1..parts LOOP
    EXECUTE format('CREATE TEMP TABLE l%s PARTITION OF test FOR VALUES WITH (modulus %s, remainder %s)', i, parts, i-1);
  END LOOP;
  
  INSERT INTO test (x) SELECT random() FROM generate_series(1,size);
  ANALYZE;
  ANALYZE test;
  CREATE INDEX ON test (y);
END $$ LANGUAGE PLPGSQL;

DO $$
DECLARE
  res text;
BEGIN
  FOR i IN 1..6 LOOP
    SET LOCAL client_min_messages = error;
    PERFORM part_builder(16, (10*pow(10,i))::bigint);
    EXPLAIN (COSTS ON) SELECT * FROM test ORDER BY y INTO res;
	SET client_min_messages = notice;
	raise notice '%', res;
  END LOOP;
END $$;

/*
-- RESULTS:

 Sort  (cost=20.82..21.07 rows=100 width=8)
NOTICE:  Sort  (cost=80.83..83.33 rows=1000 width=8)
NOTICE:  Sort  (cost=862.39..887.39 rows=10000 width=8)
NOTICE:  Sort  (cost=10256.82..10506.82 rows=100000 width=8)
NOTICE:  Sort  (cost=119090.84..121590.84 rows=1000000 width=8)
NOTICE:  Sort  (cost=1493653.33..1518653.33 rows=10000000 width=8)

 Merge Append  (cost=18.76..21.91 rows=100 width=8)
NOTICE:  Merge Append  (cost=56.25..87.75 rows=1000 width=8)
NOTICE:  Merge Append  (cost=613.83..928.83 rows=10000 width=8)
NOTICE:  Merge Append  (cost=7757.28..10907.28 rows=100000 width=8)
NOTICE:  Merge Append  (cost=94090.27..125590.27 rows=1000000 width=8)
NOTICE:  Merge Append  (cost=1106931.30..1421931.30 rows=10000000 width=8)

-- DIFFERENCE:

21.07	21.91	1.03986711
83.33	87.75	1.053042122
887.39	928.83	1.046698746
10506.8	10907.28	1.038116268
121590.84	125590.27	1.032892527
1518653.33	1421931.3	0.936310659
 */