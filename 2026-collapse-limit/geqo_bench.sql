--
-- Benchmark: GEQO optimizer planning time vs. number of joined tables.
--
-- generate_ring(n) creates n tables t_1 .. t_n arranged in a ring:
--   t_i(id PK, next_id FK -> t_{i+1})
--   t_n(id PK, next_id FK -> t_1)
--
-- Then a single query joins all n tables along the foreign-key chain.
--

SET join_collapse_limit = 512;

BEGIN;

-- Cleanup helper: drop all tables created by previous runs.
CREATE OR REPLACE FUNCTION drop_ring(n int) RETURNS void AS $$
DECLARE
  i int;
BEGIN
  FOR i IN 1..n LOOP
    EXECUTE format('DROP TABLE IF EXISTS t_%s CASCADE', i);
  END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Generate n tables forming a ring of foreign keys.
CREATE OR REPLACE FUNCTION generate_ring(n int) RETURNS void AS $$
DECLARE
  i   int;
  nxt int;
BEGIN
  -- 1. Create all tables (PK only first).
  FOR i IN 1..n LOOP
    EXECUTE format(
      'CREATE TABLE t_%s (id int PRIMARY KEY, next_id int NOT NULL)', i);
  END LOOP;

  -- 2. Add foreign-key constraints: t_i.next_id -> t_{i+1}.id, last -> first.
  FOR i IN 1..n LOOP
    nxt := CASE WHEN i < n THEN i + 1 ELSE 1 END;
    EXECUTE format(
      'ALTER TABLE t_%s ADD CONSTRAINT t_%s_fk FOREIGN KEY (next_id) REFERENCES t_%s(id)',
      i, i, nxt);
  END LOOP;

  -- 3. Insert a small amount of data so the planner has statistics.
/*  FOR i IN 1..n LOOP
    nxt := CASE WHEN i < n THEN i + 1 ELSE 1 END;
    EXECUTE format(
      'INSERT INTO t_%s SELECT g, g FROM generate_series(1, 100) g', i);
    EXECUTE format('ANALYZE t_%s', i);
  END LOOP;*/
END;
$$ LANGUAGE plpgsql;

-- Build and return an EXPLAIN ANALYZE query that joins all n tables.
CREATE OR REPLACE FUNCTION build_join_query(n int) RETURNS text AS $$
DECLARE
  sql  text;
  i    int;
  nxt  int;
BEGIN
  sql := 'SELECT count(*) FROM t_1';
  FOR i IN 2..n LOOP
    sql := sql || format(' JOIN t_%s ON t_%s.id = t_%s.next_id', i, i, i - 1);
  END LOOP;
  -- Close the ring: last table's next_id references t_1.
  sql := sql || format(' WHERE t_%s.next_id = t_1.id', n);
  RETURN sql;
END;
$$ LANGUAGE plpgsql;

-- Run the benchmark for a given number of tables.
-- Returns planning time/memory and execution time.
CREATE OR REPLACE FUNCTION bench_geqo(n int) RETURNS TABLE(tables_count    int,
                                                            planning_ms    float8,
                                                            planning_mem_kb int8,
                                                            execution_ms   float8) AS $$
DECLARE
  qry    text;
  line   text;
  p_time float8;
  p_mem  int8;
  e_time float8;
BEGIN
  -- Prepare the ring.
  PERFORM generate_ring(n);

  qry := build_join_query(n);

  -- MEMORY option (PG 17+) reports planner memory usage.
  FOR line IN EXECUTE 'EXPLAIN (ANALYZE, MEMORY, FORMAT TEXT) ' || qry LOOP
    IF line ~ 'Planning Time' THEN
      p_time := substring(line FROM '[\d.]+')::float8;
    END IF;
    IF line ~ 'Memory Used' THEN
      p_mem := substring(line FROM '[\d.]+')::int8;
    END IF;
    IF line ~ 'Execution Time' THEN
      e_time := substring(line FROM '[\d.]+')::float8;
    END IF;
  END LOOP;

  PERFORM drop_ring(n);
  RETURN QUERY SELECT n, p_time, p_mem, e_time;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- Usage example: benchmark for 4, 8, 12, 16, 20, 24 tables.
-- ============================================================
\echo '=== GEQO planning-time benchmark ==='
\echo ''

-- SELECT drop_ring(4);
-- SELECT generate_ring(4);

\o output.txt

SELECT * FROM bench_geqo(4);
SELECT * FROM bench_geqo(8);
SELECT * FROM bench_geqo(16);
SELECT * FROM bench_geqo(24);
SELECT * FROM bench_geqo(32);
SELECT * FROM bench_geqo(40);
SELECT * FROM bench_geqo(48);
SELECT * FROM bench_geqo(56);
SELECT * FROM bench_geqo(64);
SELECT * FROM bench_geqo(72);
SELECT * FROM bench_geqo(80);
SELECT * FROM bench_geqo(88);
SELECT * FROM bench_geqo(96);
SELECT * FROM bench_geqo(104);
SELECT * FROM bench_geqo(112);
SELECT * FROM bench_geqo(120);
SELECT * FROM bench_geqo(128);
SELECT * FROM bench_geqo(136);
SELECT * FROM bench_geqo(144);
SELECT * FROM bench_geqo(152);
SELECT * FROM bench_geqo(160);

SELECT * FROM bench_geqo(168);
SELECT * FROM bench_geqo(176);
SELECT * FROM bench_geqo(184);
SELECT * FROM bench_geqo(192);
SELECT * FROM bench_geqo(200);
SELECT * FROM bench_geqo(208);
SELECT * FROM bench_geqo(216);

SELECT * FROM bench_geqo(224);
SELECT * FROM bench_geqo(232);
SELECT * FROM bench_geqo(240);
SELECT * FROM bench_geqo(248);
SELECT * FROM bench_geqo(256);



\o

ROLLBACK;
