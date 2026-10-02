-- Plans for the "why dimensionless metrics" slide.
-- psql -X -p 5431 -d postgres -f dimensionless.sql | python3 ../plantrim.py --keep-time
-- captured on PostgreSQL 18.6 (Homebrew release build), max_parallel_workers_per_gather = 0
SET max_parallel_workers_per_gather = 0;

-- left: several joins, correlated filter (city = zip) underestimated
CREATE TEMP TABLE orders AS
  SELECT g AS id, g % 1000 AS city, g % 1000 AS zip, (g % 5000) + 1 AS cust
  FROM generate_series(1, 1000000) g;
CREATE TEMP TABLE customers AS
  SELECT g AS id, g % 50 AS segment FROM generate_series(1, 5000) g;
CREATE TEMP TABLE payments AS
  SELECT g AS id, (g % 5000) + 1 AS cust FROM generate_series(1, 100000) g;

-- right: GROUP BY over a scan, correlated keys (page = referrer) overestimated
CREATE TEMP TABLE visits AS
  SELECT g AS id, g % 100 AS page, g % 100 AS referrer
  FROM generate_series(1, 20000) g;

ANALYZE orders, customers, payments, visits;

EXPLAIN (ANALYZE, BUFFERS OFF)
SELECT o.id, p.id
FROM orders o
  JOIN customers c ON c.id = o.cust
  JOIN payments p ON p.cust = c.id
WHERE o.city = 42 AND o.zip = 42;

EXPLAIN (ANALYZE, BUFFERS OFF)
SELECT page, referrer, count(*) FROM visits GROUP BY page, referrer;
