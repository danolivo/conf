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

-- Add first company
INSERT INTO employees (cid,id,position)
	(SELECT random()*300::integer, uid,
	 		CASE WHEN q1.age>16 THEN
				CASE WHEN ceil(random()*5)=1 THEN 'Manager'
	 				 WHEN ceil(random()*5)=2 THEN 'Helper'
	 				 WHEN ceil(random()*5)=3 THEN 'Dispatcher'
					 WHEN ceil(random()*5)=4 THEN 'Tractor driver'
					 ELSE 'Truck driver'
				END
	 		ELSE
	 			'Packer'
	 		END
	 FROM generate_series(1,:citizens/10) uid,
	 	  LATERAL (SELECT age FROM person WHERE person.id=uid LIMIT 1) q1
	);

INSERT INTO disabled (person_id)
	(SELECT random() * :citizens FROM generate_series(1, :citizens * 0.01));

-- Refresh statistics
ANALYZE person,employees,disabled;

EXPLAIN (ANALYZE,TIMING OFF,BUFFERS OFF)
	SELECT count(*) FROM person JOIN employees USING (id)
	WHERE age>50 AND position='Helper';

EXPLAIN (ANALYZE,TIMING OFF,BUFFERS OFF)
	SELECT count(*) FROM person JOIN employees USING (id)
	WHERE age<18 AND position='Helper';
