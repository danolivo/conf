-- Clear the table, if needed.
SET aqo.mode = 'disabled';
TRUNCATE person,employees,aqo_data CASCADE;

-- Fill the person table with workers data.
INSERT INTO person (id,age,gender,passport)
	(SELECT q1.id,q1.age,
	 		CASE WHEN random()<0.25 THEN 'Female' ELSE 'Male' END,
	 		CASE WHEN (q1.age>18) THEN 1e5+random()*(1e6-1e5)::integer ELSE NULL END
	 FROM (SELECT *, prandom(20)+14 AS age FROM generate_series(1,100000) id) AS q1
	);

INSERT INTO employees (cid,id,position)
	(SELECT 1, *,
	 		CASE WHEN ceil(random()*5)=1 THEN 'Manager'
	 			 WHEN ceil(random()*5)=2 THEN 'Helper'
	 			 WHEN ceil(random()*5)=3 THEN 'Dispatcher'
	 			 WHEN ceil(random()*5)=4 THEN 'Tractor driver'
	 			 ELSE 'Truck driver'
	 		END
	 FROM generate_series(1,5));

ANALYZE person,employees;

EXPLAIN (ANALYZE,TIMING OFF,BUFFERS OFF)
	SELECT id,age FROM employees JOIN person USING (id) WHERE position='Manager' AND cid=1;

-- Add new companies
INSERT INTO employees (cid,id,position)
	(SELECT random()*300::integer, *,
	 		CASE WHEN ceil(random()*5)=1 THEN 'Manager'
	 			 WHEN ceil(random()*5)=2 THEN 'Helper'
	 			 WHEN ceil(random()*5)=3 THEN 'Dispatcher'
	 			 WHEN ceil(random()*5)=4 THEN 'Tractor driver'
	 			 ELSE 'Truck driver'
	 		END
	 FROM generate_series(6,10000));

-- Don't update statistics
EXPLAIN (ANALYZE,TIMING OFF,BUFFERS OFF)
	SELECT id,age FROM employees JOIN person USING (id) WHERE position='Manager' AND cid=1;

SET aqo.mode = 'learn';
SET aqo.show_details = on;


-- Learn at first step
EXPLAIN (ANALYZE,TIMING OFF,BUFFERS OFF)
	SELECT id,age FROM employees JOIN person USING (id) WHERE position='Manager' AND cid=1;

-- Use AQO data
EXPLAIN (ANALYZE,TIMING OFF,BUFFERS OFF)
	SELECT id,age FROM employees JOIN person USING (id) WHERE position='Manager' AND cid=1;
