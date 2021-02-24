\set citizens	1000
TRUNCATE person CASCADE;

-- Disable AQO
SET aqo.mode='disabled';
SET aqo.show_details = 'off';
SET aqo.show_hash = 'off';

-- Fill the 'person' table
INSERT INTO person (id,age,gender,passport)
	(SELECT q1.id,q1.age,
	 		CASE WHEN random()<0.25 THEN 'Female' ELSE 'Male' END,
	 		CASE WHEN (q1.age>16) THEN 1e5+random()*(1e6-1e5)::integer ELSE NULL END
	 FROM (SELECT *, prandom(20)+14 AS age FROM generate_series(1, :citizens) id) AS q1
	);

ANALYZE person;

-- See the query plan without AQO knowledge
EXPLAIN (ANALYZE,TIMING OFF)
	SELECT id FROM person WHERE age<18;
EXPLAIN (ANALYZE,TIMING OFF)
	SELECT id FROM person WHERE age<18 AND passport IS NOT NULL;

-- Use AQO 
SET aqo.mode='learn';
SET aqo.show_details = 'on';
SET aqo.show_hash = 'on';
TRUNCATE aqo_queries CASCADE;

-- Learn AQO on the executed query
EXPLAIN (ANALYZE,TIMING OFF)
	SELECT id FROM person WHERE age<18 AND passport IS NOT NULL;

-- Use AQO knowledge to predict correct values
EXPLAIN (ANALYZE,TIMING OFF)
	SELECT id FROM person WHERE age<18 AND passport IS NOT NULL;

-- Just repeat
SET aqo.mode='frozen';
EXPLAIN (ANALYZE,TIMING OFF)
	SELECT id FROM person WHERE age<18 AND passport IS NOT NULL;