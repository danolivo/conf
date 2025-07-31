/*
 * Patch to test:
 * https://www.postgresql.org/message-id/2bc323df-0662-406a-8abf-dade726b31d8@gmail.com
 */

DROP FUNCTION IF EXISTS part_builder;
  
SET work_mem = '1GB';
SET max_parallel_workers_per_gather = 0;
SET enable_indexscan = 'off';
SET enable_bitmapscan = 'off';

CREATE OR REPLACE FUNCTION part_builder(parts integer, size bigint) RETURNS VOID AS
$$
DECLARE
  i integer;
BEGIN
  DROP TABLE IF EXISTS test CASCADE;

  -- Remove shreds, if still exists
  FOR i IN 1..parts LOOP
    EXECUTE format('DROP TABLE IF EXISTS l%s', i);
  END LOOP;

  CREATE TABLE test (x real, y real DEFAULT random())
  PARTITION BY HASH (x);
  
  FOR i IN 1..parts LOOP
    EXECUTE format('CREATE TABLE l%s PARTITION OF test FOR VALUES WITH (modulus %s, remainder %s)', i, parts, i-1);
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
  FOR i IN 1..8 LOOP
    SET LOCAL client_min_messages = error;
    PERFORM part_builder(16, (10*pow(10,i))::bigint);
    EXPLAIN (COSTS ON) SELECT * FROM test ORDER BY y INTO res;
	SET client_min_messages = notice;
	raise notice '%', res;
  END LOOP;
END $$;
