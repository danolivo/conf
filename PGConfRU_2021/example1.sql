DROP TABLE IF EXISTS person,employees;

CREATE TABLE person (
    id serial PRIMARY KEY,
    age integer,
    gender text,
	passport integer
);

CREATE TABLE employees (
	id integer REFERENCES person (id), -- Person ID
	position text
);

INSERT INTO person (age, gender, passport)
	(SELECT q1.age,
	 		CASE WHEN random()<0.25 THEN 'Female' ELSE 'Male' END,
	 		CASE WHEN (q1.age>18) THEN 1e5+random()*(1e6-1e5)::integer ELSE NULL END
	 FROM (SELECT prandom(10)+14 AS age FROM generate_series(1,1000)) AS q1
	);
	
ANALYZE person;

EXPLAIN ANALYZE SELECT id FROM person WHERE age<14;
EXPLAIN ANALYZE SELECT id FROM person WHERE age<18;
EXPLAIN ANALYZE SELECT id FROM person WHERE age<18 AND passport IS NOT NULL;
