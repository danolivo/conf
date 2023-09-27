DROP TABLE IF EXISTS a,b,c,d CASCADE;

set aqo.mode='disabled';

CREATE TABLE a (x int PRIMARY KEY);
CREATE TABLE b (x int PRIMARY KEY);
CREATE TABLE c (x int PRIMARY KEY);
CREATE TABLE d (x int PRIMARY KEY);

INSERT INTO a (SELECT gs.* FROM generate_series(1,1000) AS gs);
INSERT INTO b VALUES (44), (45);
INSERT INTO c VALUES (100);
INSERT INTO d (SELECT gs.* FROM generate_series(999,10001) AS gs);
ANALYZE a,b,c,d;

--Здесь большой overestimate, поскольку нет информации о количестве null-полей
explain (ANALYZE)
SELECT * FROM d JOIN a
  LEFT JOIN b
    LEFT JOIN c
    ON b.x=c.x
  ON a.x=b.x
ON a.x=d.x
WHERE (b.x IS NOT NULL OR c.x IS NOT NULL);

set aqo.mode='learn';

explain (ANALYZE)
SELECT * FROM d JOIN a
  LEFT JOIN b
    LEFT JOIN c
    ON b.x=c.x
  ON a.x=b.x
ON a.x=d.x
WHERE (b.x IS NOT NULL OR c.x IS NOT NULL);

explain (ANALYZE)
SELECT * FROM d JOIN a
  LEFT JOIN b
    LEFT JOIN c
    ON b.x=c.x
  ON a.x=b.x
ON a.x=d.x
WHERE (b.x IS NOT NULL OR c.x IS NOT NULL);

explain (ANALYZE)
SELECT * FROM d JOIN a
  LEFT JOIN b
    LEFT JOIN c
    ON b.x=c.x
  ON a.x=b.x
ON a.x=d.x
WHERE (b.x IS NOT NULL OR c.x IS NOT NULL);

set aqo.mode='frozen';

explain (ANALYZE)
SELECT * FROM d JOIN a
  LEFT JOIN b
    LEFT JOIN c
    ON b.x=c.x
  ON a.x=b.x
ON a.x=d.x
WHERE (b.x IS NOT NULL OR c.x IS NOT NULL);
