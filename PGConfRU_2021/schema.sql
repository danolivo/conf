DROP TABLE IF EXISTS person,employees,disabled;

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

CREATE UNIQUE INDEX ON employees (id);
CREATE INDEX ON person (id, age);

CREATE TABLE disabled (
	person_id integer REFERENCES person (id)
	-- private medical data can go here
);
