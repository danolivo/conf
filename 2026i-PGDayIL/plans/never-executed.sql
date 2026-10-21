-- Plans for the "a node does not always run" slide.
-- psql -X -p 5432 -d danolivo -f never-executed.sql | python3 ../plantrim.py
-- captured on the ~/pg instance (REL_18_STABLE, 18.6), generic plan forced
SET max_parallel_workers_per_gather = 0;
SET plan_cache_mode = force_generic_plan;

CREATE TEMP TABLE orders AS
  SELECT g AS id, g % 1000 AS city, (g % 5000) + 1 AS cust
  FROM generate_series(1, 1000000) g;
CREATE TEMP TABLE customers AS
  SELECT g AS id FROM generate_series(1, 5000) g;
CREATE TEMP TABLE payments AS
  SELECT g AS id, (g % 5000) + 1 AS cust FROM generate_series(1, 100000) g;
ANALYZE orders, customers, payments;

PREPARE q(int, bool) AS
SELECT o.id, p.id
FROM orders o
  JOIN customers c ON c.id = o.cust
  JOIN payments p ON p.cust = c.id
WHERE o.city = $1 AND $2;

EXPLAIN (ANALYZE, TIMING OFF, BUFFERS OFF) EXECUTE q(42, true);
EXPLAIN (ANALYZE, TIMING OFF, BUFFERS OFF) EXECUTE q(42, false);
