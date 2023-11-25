SELECT sr_id FROM sr_register_query(
  'UPDATE pgbench_accounts SET abalance = abalance + $1 WHERE aid = $2',
  'int', 'int') \gset
UPDATE pgbench_accounts SET abalance = abalance + 1 WHERE aid = 1;
SELECT sr_plan_freeze(:sr_id);
EXPLAIN UPDATE pgbench_accounts SET abalance = abalance + 43 WHERE aid = 42;

SELECT sr_id FROM sr_register_query(
	'SELECT abalance FROM pgbench_accounts WHERE aid = $1', 'int') \gset
SELECT abalance FROM pgbench_accounts WHERE aid = 1;
SELECT sr_plan_freeze(:sr_id);
EXPLAIN SELECT abalance FROM pgbench_accounts WHERE aid = -42;

SELECT sr_id AS srid3 FROM sr_register_query('
  UPDATE pgbench_tellers SET tbalance = tbalance + $2 WHERE tid = $1', 'int', 'int') \gset
SELECT sr_id AS srid4 FROM sr_register_query('
  UPDATE pgbench_branches SET bbalance = bbalance + $1 WHERE bid = $2', 'int', 'int') \gset
SELECT sr_id AS srid5 FROM sr_register_query('
  INSERT INTO pgbench_history (tid, bid, aid, delta, mtime)
  VALUES ($1, $2, $3, $4, CURRENT_TIMESTAMP)', 'int', 'int', 'int', 'int') \gset

UPDATE pgbench_tellers SET tbalance = tbalance + 1 WHERE tid = 1;
UPDATE pgbench_branches SET bbalance = bbalance + 1 WHERE bid = 1;
INSERT INTO pgbench_history (tid, bid, aid, delta, mtime) VALUES (1, 1, 1, 1, CURRENT_TIMESTAMP);

SELECT sr_plan_freeze(:srid3);
SELECT sr_plan_freeze(:srid4);
SELECT sr_plan_freeze(:srid5);

SELECT srid,queryid,query_string FROM sr_plan_storage;
