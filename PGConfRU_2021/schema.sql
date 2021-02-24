DROP TABLE IF EXISTS person,employees,positions;

CREATE TABLE person (
    id integer PRIMARY KEY,
    age integer,
    gender text,
	passport integer
);

CREATE TABLE employees (
	cid integer NOT NULL, -- company ID
	id integer REFERENCES person (id),
	position text
);

CREATE TABLE positions (
	id int PRIMARY KEY,
	name text
);

CREATE UNIQUE INDEX ON employees (id);
CREATE INDEX ON person (id, age);

INSERT INTO positions (id,name) VALUES
	(1, 'Truck driver'),
	(2, 'Manager'),
	(3, 'Helper'),
	(4, 'Dispatcher'),
	(5, 'Tractor driver');