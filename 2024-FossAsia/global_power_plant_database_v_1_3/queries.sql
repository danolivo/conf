EXPLAIN ANALYZE
SELECT * FROM power_plants
WHERE country = 'RUS';
	  
EXPLAIN ANALYZE
SELECT * FROM power_plants
WHERE
  country = 'RUS' AND country_long = 'Russia'
;

EXPLAIN ANALYZE
SELECT * FROM power_plants
WHERE
  country = 'RUS' AND owner IS NOT NULL
;

EXPLAIN ANALYZE
SELECT * FROM power_plants
WHERE
  country = 'RUS' AND owner IS NOT NULL AND
  country_long NOT LIKE 'United States of America'
;

EXPLAIN ANALYZE
SELECT * FROM power_plants
WHERE
  country = 'RUS' AND
  owner IS NOT NULL AND
  country_long NOT LIKE 'United States of America' AND
  owner NOT LIKE 'Tesla Inc.'
;

EXPLAIN ANALYZE
SELECT * FROM power_plants
WHERE
  country = 'RUS' AND
  owner IS NOT NULL AND
  country_long NOT LIKE 'United States of America' AND
  owner NOT LIKE 'Tesla Inc.' AND
  primary_fuel NOT LIKE 'Solar'
;

CREATE STATISTICS extstat (ndistinct,dependencies,mcv) ON country,owner,country_long,primary_fuel FROM power_plants;
DROP STATISTICS extstat;

CREATE STATISTICS extstat1 (ndistinct,dependencies,mcv) ON country,country_long FROM power_plants;
DROP STATISTICS extstat1;
ANALYZE;

EXPLAIN ANALYZE
SELECT owner FROM power_plants
WHERE
  country = 'RUS' AND
  primary_fuel = 'Solar'
;
CREATE INDEX idx2 ON power_plants(country, primary_fuel);
ANALYZE;
EXPLAIN ANALYZE
SELECT owner FROM power_plants
WHERE
  country = 'RUS' AND
  primary_fuel = 'Solar'
;

EXPLAIN ANALYZE
SELECT owner FROM power_plants
WHERE
  country = 'RUS' AND
  primary_fuel = 'Solar' AND
  country_long = 'United States of America'
;

CREATE INDEX idx1 ON power_plants(country, country_long);
ANALYZE;

DROP INDEX IF EXISTS idx1,idx2;
ANALYZE;