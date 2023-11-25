-- Clear the table, if needed.
SET aqo.mode = 'disabled';
TRUNCATE person,employees CASCADE;

-- Fill the person table with workers data.
INSERT INTO person (id,age,gender,passport)
	(SELECT q1.id,q1.age,
	 		CASE WHEN random()<0.25 THEN 'Female' ELSE 'Male' END,
	 		CASE WHEN (q1.age>18) THEN 1e5+random()*(1e6-1e5)::integer ELSE NULL END
	 FROM (SELECT *, prandom(20)+14 AS age FROM generate_series(1,10000) id) AS q1
	);

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

--
-- Use nested loops to join small tables
--
EXPLAIN (ANALYZE)
	SELECT id,age FROM employees JOIN person USING (id) WHERE position='Manager'  ORDER BY age;

--
-- Company grows with time.
--
INSERT INTO employees (id,position)
	(SELECT *,
	 		CASE WHEN ceil(random()*5)=1 THEN 'Manager'
	 			 WHEN ceil(random()*5)=2 THEN 'Helper'
	 			 WHEN ceil(random()*5)=3 THEN 'Dispatcher'
	 			 WHEN ceil(random()*5)=4 THEN 'Tractor driver'
	 			 ELSE 'Truck driver'
	 		END
	 FROM generate_series(21,10000));

--
-- No good to use nested loops to join small tables
--
EXPLAIN (ANALYZE)
	SELECT employees.* FROM person JOIN employees USING (id) WHERE position='Manager';

--
-- Actualize statistics
--
ANALYZE person,employees;

-- Execute query without actual statistics.
EXPLAIN (ANALYZE)
	SELECT employees.* FROM person JOIN employees USING (id) WHERE position='Manager';

-- Use AQO
SET aqo.mode = 'learn';
SET aqo.show_details = 'on';
SET aqo.show_hash = 'on';

-- Clear all learning data.
TRUNCATE aqo_data;
