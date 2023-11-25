SET aqo.mode = 'disabled';
SET aqo.show_details = 'off';
SET aqo.show_hash = 'off';
TRUNCATE aqo_data;  -- Clear all learning data.
TRUNCATE person,employees CASCADE; -- Clear the tables, if needed.

-- Fill the person table with citizens data.
INSERT INTO person (id,age,gender,passport)
	(SELECT q1.id,q1.age,
	 		CASE WHEN random()<0.25 THEN 'Female'
	 			 ELSE 'Male'
	 		END,
	 		CASE WHEN (q1.age>18) THEN 1e5+random()*(1e6-1e5)::integer
	 			 ELSE NULL
	 		END
	 FROM (SELECT *, prandom(20)+14 AS age FROM generate_series(1,100000) id) AS q1
	);

-- Fill company employers info. 
INSERT INTO employees (id,position)
	(SELECT *,
	 		CASE WHEN ceil(random()*5)=1 THEN 'Manager'
	 			 WHEN ceil(random()*5)=2 THEN 'Helper'
	 			 WHEN ceil(random()*5)=3 THEN 'Dispatcher'
	 			 WHEN ceil(random()*5)=4 THEN 'Tractor driver'
	 			 ELSE 'Truck driver'
	 		END
	 FROM generate_series(1,5));

ANALYZE person,employees;

EXPLAIN (ANALYZE)
	SELECT id,age FROM employees JOIN person USING (id) WHERE position='Manager';

INSERT INTO employees (id,position)
	(SELECT *,'Sales'
	 FROM generate_series(6,10000));

EXPLAIN (ANALYZE)
	SELECT id,age FROM employees JOIN person USING (id) WHERE position='Manager';
	
-- Use AQO
SET aqo.mode = 'learn';
SET aqo.show_details = 'on';
SET aqo.show_hash = 'on';

-- At first iteration we haven't any data
EXPLAIN (ANALYZE)
	SELECT id,age FROM employees JOIN person USING (id) WHERE position='Manager';
	
-- The query plan changes. This is caused by the knowledge of previous execution.
EXPLAIN (ANALYZE)
	SELECT id,age FROM employees JOIN person USING (id) WHERE position='Manager';

-- Now, AQO has the data for each plan node.
EXPLAIN (ANALYZE)
	SELECT id,age FROM employees JOIN person USING (id) WHERE position='Manager';

SET aqo.mode = 'frozen';
EXPLAIN (ANALYZE)
	SELECT id,age FROM employees JOIN person USING (id) WHERE position='Manager';
