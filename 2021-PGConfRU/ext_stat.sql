-- Use extended statistics to take this dependency in account.
CREATE STATISTICS corr (dependencies) ON age, passport FROM person;
EXPLAIN (ANALYZE, SUMMARY OFF)
	SELECT id FROM person WHERE age<18 AND passport IS NOT NULL;