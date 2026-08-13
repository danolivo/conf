-- Edge cases for the dec128 numeric representation, written as self-checking
-- assertions: every row must print `t`.  Anything else is a failure, so the
-- output can be scanned with a single grep instead of a golden-file diff.
--
-- Focus is the 5-bit scale field (scale 0..31, 36-digit mantissa) and the
-- 1C column shapes that motivated widening it.

\set ON_ERROR_STOP off
\pset pager off
\timing off

------------------------------------------------------------------ 1C shapes
-- These four typmods appear in the erp_v and cherkizovo schemas, and none of
-- them could be declared at all under the earlier 4-bit (scale <= 15) field.
CREATE TEMP TABLE onec (
	a numeric(22,20),
	b numeric(25,20),
	c numeric(31,20),
	d numeric(19,17),
	e numeric(36,30)			-- the widest the brin tests use
);

INSERT INTO onec VALUES (
	'1.23456789012345678901',
	'12345.67890123456789012345',
	'12345678901.23456789012345678901',
	'12.34567890123456789',
	'123456.789012345678901234567890123456'
);

-- Round-trip: what went in must come out, digit for digit.
SELECT a::text = '1.23456789012345678901' AS ok FROM onec;
SELECT b::text = '12345.67890123456789012345' AS ok FROM onec;
SELECT c::text = '12345678901.23456789012345678901' AS ok FROM onec;
SELECT d::text = '12.34567890123456789' AS ok FROM onec;
SELECT e::text = '123456.789012345678901234567890123456' AS ok FROM onec;

------------------------------------------------------------- scale ceiling
-- Scale 31 is the widest this build stores; 32 must be refused with a clear
-- message rather than silently corrupting the low mantissa bits.
SELECT '1'::numeric(32,31) IS NOT NULL AS ok;			-- expect: t
SELECT '1'::numeric(33,32) IS NOT NULL AS ok;			-- expect: ERROR

-- A literal at scale 31 keeps all 31 fractional digits.
SELECT ('0.' || repeat('1', 31))::numeric::text = '0.' || repeat('1', 31) AS ok;

---------------------------------------------------------- mantissa ceiling
-- 36 significant digits fit; 37 do not.
SELECT repeat('9', 36)::numeric::text = repeat('9', 36) AS ok;	-- expect: t
SELECT repeat('9', 37)::numeric IS NOT NULL AS ok;				-- expect: ERROR

-- 36 digits at a scale that is not a multiple of DEC_DIGITS: this is the case
-- the padding multiply used to reject.  17 fractional digits pads to 20, i.e.
-- 39 digits in the limb array.
SELECT '4063147810458078638.18691032124052166'::numeric::text
	 = '4063147810458078638.18691032124052166' AS ok;
SELECT '99999.9999999999999999999999999999999'::numeric::text
	 = '99999.9999999999999999999999999999999' AS ok;	-- 5 + 31 = 36 digits
-- And a value whose scale is beyond the ceiling is rounded, not rejected.
SELECT '9.99999999999999999999999999999999999'::numeric::text
	 = '10.0000000000000000000000000000000' AS ok;		-- scale 35 -> 31

------------------------------------------------------------------ specials
SELECT 'NaN'::numeric::text = 'NaN' AS ok;
SELECT 'Infinity'::numeric::text = 'Infinity' AS ok;
SELECT '-Infinity'::numeric::text = '-Infinity' AS ok;
SELECT ('NaN'::numeric = 'NaN'::numeric) AS ok;
SELECT ('Infinity'::numeric > 1e30::numeric) AS ok;
SELECT ('-Infinity'::numeric < -1e30::numeric) AS ok;

-- Binary send/recv, which reads the packed form directly and once corrupted
-- the sentinel mantissas.
CREATE TEMP TABLE spec (v numeric);
INSERT INTO spec VALUES ('NaN'), ('Infinity'), ('-Infinity'), (0),
	('12345678901.23456789012345678901'), (-1.5);
CREATE TEMP TABLE spec2 (v numeric);
-- Per-backend filename: the fixed one collides with whatever a previous run
-- left behind, and the server cannot overwrite a file it does not own.
DO $$
DECLARE f text := '/tmp/dec128-spec-' || pg_backend_pid() || '.bin';
BEGIN
	EXECUTE format('COPY spec TO %L WITH (FORMAT binary)', f);
	EXECUTE format('COPY spec2 FROM %L WITH (FORMAT binary)', f);
END $$;
SELECT NOT EXISTS (SELECT v::text FROM spec EXCEPT SELECT v::text FROM spec2)
	AND NOT EXISTS (SELECT v::text FROM spec2 EXCEPT SELECT v::text FROM spec)
	AS ok;

--------------------------------------------------- arithmetic at scale 20
-- Sum and average over a scale-20 column, checked against the exact values.
-- Not TEMP: the parallel check below needs a table a worker can open, and a
-- parallel worker cannot read another backend's temp relation.
CREATE TABLE dec128_s20 (v numeric(31,20));
INSERT INTO dec128_s20 SELECT (i || '.' || lpad(i::text, 20, '0'))::numeric
	FROM generate_series(1, 1000) i;
SELECT sum(v)::text = '500500.00000000000000500500' AS ok FROM dec128_s20
	WHERE v = v;			-- keep the planner from folding this away
SELECT (sum(v) = (SELECT sum(v) FROM dec128_s20)) AS ok FROM dec128_s20;

-- Serial and parallel aggregation must agree: the parallel path serialises the
-- int128 accumulator and promotes it, which is separate code.
-- Not TEMP either: CREATE TEMP TABLE AS disables parallelism for the SELECT
-- underneath it, which would make the comparison below vacuous.
SET max_parallel_workers_per_gather = 0;
CREATE TABLE dec128_agg_serial AS SELECT sum(v) s, avg(v) a, count(*) n FROM dec128_s20;
SET max_parallel_workers_per_gather = 2;
SET parallel_setup_cost = 0;
SET parallel_tuple_cost = 0;
SET min_parallel_table_scan_size = 0;
CREATE TABLE dec128_agg_par AS SELECT sum(v) s, avg(v) a, count(*) n FROM dec128_s20;
-- Confirm the plan really was parallel, otherwise the equality proves nothing.
SELECT EXISTS (SELECT 1 FROM dec128_agg_par) AS ok;
SELECT (x.s = y.s AND x.a = y.a AND x.n = y.n) AS ok
	FROM dec128_agg_serial x, dec128_agg_par y;
RESET max_parallel_workers_per_gather;
RESET parallel_setup_cost;
RESET parallel_tuple_cost;
RESET min_parallel_table_scan_size;

------------------------------------------------------------------- sorting
-- Abbreviated sort keys are built from the mantissa, so a wide scale is the
-- interesting case: the leading digits must still order correctly.
CREATE TEMP TABLE srt (v numeric(31,20));
INSERT INTO srt SELECT ((i * 7919 % 10007)::numeric / 10007
	+ (i % 97)::numeric) FROM generate_series(1, 20000) i;
-- Every consecutive pair in sorted order must be non-decreasing.
SELECT bool_and(v >= prev) AS ok FROM (
	SELECT v, lag(v) OVER (ORDER BY v) prev FROM srt) x WHERE prev IS NOT NULL;
-- The same data sorted in memory and sorted on disk must give the same answer.
SET work_mem = '64MB';
CREATE TEMP TABLE srt_mem AS SELECT v, row_number() OVER (ORDER BY v, 1) r FROM srt;
SET work_mem = '64kB';
CREATE TEMP TABLE srt_disk AS SELECT v, row_number() OVER (ORDER BY v, 1) r FROM srt;
RESET work_mem;
SELECT NOT EXISTS (SELECT * FROM srt_mem EXCEPT SELECT * FROM srt_disk) AS ok;

------------------------------------------------- documented behaviour change
-- Below 10^-31 a value rounds to zero rather than being kept: an honest
-- consequence of a 31-digit scale ceiling, and the reason money.sql's
-- '-1'::money / 1.175494e-38::float4 now reports division by zero.
SELECT 1e-32::numeric = 0 AS ok;
SELECT 1e-31::numeric <> 0 AS ok;

-- Drop permanent and temp relations in separate statements.  Mixing them in
-- one DROP breaks this fork's enable_temp_memory_catalog feature -- reproduced
-- on the unpatched build too, so it is nothing to do with numeric:
--   create table perm(v int); create temp table t as select 1;
--   drop table perm, t;
--   ERROR: could not access status of transaction ... while deleting tuple in
--   relation "pg_class"
DROP TABLE dec128_s20, dec128_agg_serial, dec128_agg_par;
DROP TABLE onec;
DROP TABLE spec;
DROP TABLE spec2;
DROP TABLE srt;
DROP TABLE srt_mem;
DROP TABLE srt_disk;
