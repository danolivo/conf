EXPLAIN (ANALYZE, SUMMARY OFF)
	SELECT id FROM person WHERE age<18;
EXPLAIN (ANALYZE, SUMMARY OFF)
	SELECT id FROM person WHERE age<18 AND passport IS NOT NULL;

-- Use AQO 
SET aqo.mode='learn';
SET aqo.show_details = 'on';
SET aqo.show_hash = 'on';
TRUNCATE aqo_data;
EXPLAIN (ANALYZE, SUMMARY OFF)
	SELECT id FROM person WHERE age<18 AND passport IS NOT NULL;
EXPLAIN (ANALYZE, SUMMARY OFF)
	SELECT id FROM person WHERE age<18 AND passport IS NOT NULL;