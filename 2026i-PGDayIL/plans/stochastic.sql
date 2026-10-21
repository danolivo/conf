-- Data for the "estimation is stochastic" slide: the table never changes,
-- only ANALYZE is repeated.  Writes plans/stochastic.csv for pgfplots.
-- cd plans && psql -X -p 5432 -d danolivo -f stochastic.sql
-- captured on the ~/pg instance (REL_18_STABLE, 18.6), default_statistics_target = 100
SET max_parallel_workers_per_gather = 0;
SELECT setseed(0.42);

-- 150 equally frequent values (10 000 rows each) compete for 100 MCV slots,
-- plus a long tail of 3.5 M rare values.
CREATE TEMP TABLE t AS
  SELECT (g % 150) + 1 AS x, g AS id FROM generate_series(1, 1500000) g
  UNION ALL
  SELECT 1000 + (random() * 1000000)::int, g FROM generate_series(1, 3500000) g;
CREATE INDEX ON t(x);

CREATE TEMP TABLE res(run int, in_mcv int, est float8, node text);
DO $$
DECLARE i int; j json;
BEGIN
  FOR i IN 1..40 LOOP
    ANALYZE t;
    EXECUTE 'EXPLAIN (FORMAT JSON) SELECT * FROM t WHERE x = 77' INTO j;
    INSERT INTO res SELECT i,
      (SELECT (77 = ANY(most_common_vals::text::int[]))::int
         FROM pg_stats WHERE tablename = 't' AND attname = 'x'),
      (j->0->'Plan'->>'Plan Rows')::float8,
      j->0->'Plan'->>'Node Type';
  END LOOP;
END $$;

SELECT count(*) AS actual FROM t WHERE x = 77;
SELECT node, in_mcv, count(*), min(est), max(est) FROM res GROUP BY 1, 2;
\copy (SELECT run, in_mcv, est, replace(node, ' ', '') AS node FROM res ORDER BY run) TO 'stochastic.csv' CSV HEADER
