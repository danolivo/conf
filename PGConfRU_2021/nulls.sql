\set citizens	100000
-- Switch off AQO
SET aqo.mode = 'disabled';
SET aqo.show_details = 'off';

-- Clear the tables, if needed.
TRUNCATE person,employees,disabled,aqo_data CASCADE;

-- Fill the person table with workers data.
INSERT INTO person (id,age,gender,passport)
	(SELECT q1.id,q1.age,
	 		CASE WHEN random()<0.25 THEN 'Female' ELSE 'Male' END,
	 		CASE WHEN (q1.age>18) THEN 1e5+random()*(1e6-1e5)::integer ELSE NULL END
	 FROM (SELECT *, prandom(20)+14 AS age FROM generate_series(1, :citizens) id) AS q1
	);

-- Add companies
INSERT INTO employees (cid,id,position)
	(SELECT random()*300::integer, *,
	 		CASE WHEN ceil(random()*5)=1 THEN 'Manager'
	 			 WHEN ceil(random()*5)=2 THEN 'Helper'
	 			 WHEN ceil(random()*5)=3 THEN 'Dispatcher'
	 			 WHEN ceil(random()*5)=4 THEN 'Tractor driver'
	 			 ELSE 'Truck driver'
	 		END
	 FROM generate_series(1,:citizens/10));

-- %5 of community are disabled
INSERT INTO disabled (person_id)
	(SELECT random() * :citizens FROM generate_series(1, :citizens * 0.05));

-- Refresh statistics
ANALYZE person,employees,disabled;

-- Try to see a number of unemployed
EXPLAIN (ANALYZE,TIMING OFF,BUFFERS OFF)
SELECT count(*) FROM (
	SELECT id,age,cid
	FROM person
	LEFT JOIN employees USING (id)
) AS q1 WHERE cid IS NULL;

-- Try to use this poorly-estimated query in another JOIN,
-- called 'See unemployed disabled people'
EXPLAIN (ANALYZE,TIMING OFF,BUFFERS OFF)
SELECT count(*) FROM disabled JOIN (
SELECT id,age FROM (
	SELECT id,age,cid
	FROM person
	LEFT JOIN employees USING (id)
) AS q1 WHERE cid IS NULL
) AS q2 ON person_id=id;

SET aqo.mode = 'learn';
TRUNCATE aqo_queries CASCADE;

--
-- Execute the query for some time
--
SELECT count(*) FROM disabled JOIN (SELECT id,age FROM (SELECT id,age,cid FROM person LEFT JOIN employees USING (id)) AS q1 WHERE cid IS NULL) AS q2 ON person_id=id;
SELECT count(*) FROM disabled JOIN (SELECT id,age FROM (SELECT id,age,cid FROM person LEFT JOIN employees USING (id)) AS q1 WHERE cid IS NULL) AS q2 ON person_id=id;
SELECT count(*) FROM disabled JOIN (SELECT id,age FROM (SELECT id,age,cid FROM person LEFT JOIN employees USING (id)) AS q1 WHERE cid IS NULL) AS q2 ON person_id=id;

-- 
-- See query execution plan with the AQO kbowledge
-- 
SET aqo.mode = 'frozen';
SET aqo.show_details = 'on';
SET aqo.show_hash = 'off';
EXPLAIN (ANALYZE,TIMING OFF,BUFFERS OFF)
SELECT count(*) FROM disabled JOIN (
SELECT id,age FROM (
	SELECT id,age,cid
	FROM person
	LEFT JOIN employees USING (id)
) AS q1 WHERE cid IS NULL
) AS q2 ON person_id=id;

-- 
-- Check: AQO doesn't interfere with planning in disabled mode.
-- 
SET aqo.mode = 'disabled';
EXPLAIN (ANALYZE,TIMING OFF,BUFFERS OFF)
SELECT count(*) FROM disabled JOIN (
SELECT id,age FROM (
	SELECT id,age,cid
	FROM person
	LEFT JOIN employees USING (id)
) AS q1 WHERE cid IS NULL
) AS q2 ON person_id=id;
