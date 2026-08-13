CREATE EXTENSION dec64;

-- The type must be 8 bytes and passed by value; that is the whole point of it.
SELECT typlen, typbyval, typalign, typstorage FROM pg_type WHERE typname = 'dec64';

--
-- Input and output
--

-- Trailing zeros implied by the scale survive, as they do for numeric.
SELECT '0'::dec64, '1.50'::dec64, '-1.50'::dec64, '+2'::dec64, '  3.25  '::dec64;

-- Leading zeros do not consume the 18-digit budget.
SELECT '000000000000000000000001.5'::dec64;

-- The extremes of the range are accepted.
SELECT '999999999999999999'::dec64, '-999999999999999999'::dec64;
SELECT '99999999999.9999999'::dec64;

-- A 19th significant digit, an 8th decimal place, and malformed text are all rejected.
SELECT '1000000000000000000'::dec64;
SELECT '1.12345678'::dec64;
SELECT '1.2.3'::dec64;
SELECT 'abc'::dec64;
SELECT ''::dec64;

-- dec64 has no NaN and no infinity, following DuckDB's DECIMAL rather than numeric.
SELECT 'NaN'::dec64;
SELECT 'Infinity'::dec64;

--
-- Type modifiers
--

CREATE TABLE tm(a dec64(18,2), b dec64(10,4), c dec64(5), d dec64);
\d tm

-- Storing rescales to the declared scale, rounding half away from zero.
INSERT INTO tm VALUES (1.5, 1.5, 1.5, 1.5);
INSERT INTO tm VALUES (1.005, 1.00005, 1.5, 1.005);
SELECT * FROM tm ORDER BY a;

-- A value too wide for the declared precision is refused.
INSERT INTO tm VALUES (1.5, 1000000.0, 1.5, 1.5);

-- Rounding happens once, straight to the declared scale, never twice.
SELECT 0.4449::numeric::dec64(10,2) AS dec64, round(0.4449, 2) AS numeric;

-- Nonsensical modifiers are rejected at declaration time.
CREATE TABLE bad(x dec64(19,2));
CREATE TABLE bad(x dec64(10,8));
CREATE TABLE bad(x dec64(2,5));

DROP TABLE tm;

--
-- Arithmetic
--

-- Addition and subtraction carry the larger scale of the two operands.
SELECT '1.50'::dec64 + '1.20'::dec64, '1.50'::dec64 + '1.200'::dec64,
       '1.50'::dec64 - '1.200'::dec64;

-- Multiplication carries the sum of the scales, as the SQL standard requires.
SELECT '1.50'::dec64 * '1.200'::dec64, '2'::dec64 * '3'::dec64;

-- Binary floating point cannot do either of these; dec64 gets them exactly.
SELECT '0.1'::dec64 + '0.1'::dec64 + '0.1'::dec64 - '0.3'::dec64 AS exactly_zero;
SELECT '0.70'::dec64 * '1.05'::dec64 AS sales_tax;

-- Division stays exact-typed at the maximum scale, unlike DuckDB's DOUBLE.
SELECT '10.00'::dec64 / '3'::dec64, '1'::dec64 / '8'::dec64,
       pg_typeof('1'::dec64 / '3'::dec64);

-- Remainder truncates toward zero, and unary operators behave as expected.
SELECT '10.00'::dec64 % '3'::dec64, -('1.50'::dec64), +('1.50'::dec64),
       abs('-1.50'::dec64), sign('-1.50'::dec64), sign('0'::dec64);

-- Overflow is a loud error, never a silent widening or wraparound.
SELECT '999999999999999999'::dec64 + '1'::dec64;
SELECT '999999999'::dec64 * '999999999'::dec64 * '10'::dec64;

-- A product needing more than seven decimals is refused rather than rounded away.
SELECT '0.00001'::dec64 * '0.0001'::dec64;

SELECT '1'::dec64 / '0'::dec64;
SELECT '1'::dec64 % '0'::dec64;

--
-- Comparison
--

-- Values equal in magnitude compare equal regardless of their scale.
SELECT '1.5'::dec64 = '1.50'::dec64, '1.5'::dec64 < '1.50'::dec64,
       '1.5'::dec64 <= '1.50'::dec64, '1.5'::dec64 <> '1.51'::dec64,
       '2'::dec64 > '1.99'::dec64, '2'::dec64 >= '2.000'::dec64;

-- Comparing across the whole scale range must never fail: aligning the widest
-- mantissa up to seven decimals does not fit in 64 bits, but the answer is
-- perfectly well defined, and an ORDER BY that errored would be a plain bug.
SELECT '999999999999999999'::dec64 > '0.0000001'::dec64,
       '-999999999999999999'::dec64 < '0.0000001'::dec64,
       '999999999999999999'::dec64 = '999999999999999999'::dec64;

-- Adding across that same range does fail, and rightly so: the exact sum
-- would need 25 digits, which no dec64 can hold.
SELECT '999999999999999999'::dec64 + '0.0000001'::dec64;

-- Equal values must also hash alike, or hash joins would lose rows.
SELECT dec64_hash('1.5'::dec64) = dec64_hash('1.500'::dec64) AS same_hash;
SELECT count(*) FROM (SELECT DISTINCT v FROM
    (VALUES ('1.5'::dec64), ('1.50'::dec64), ('1.500'::dec64)) t(v)) s;

-- A bare decimal literal is numeric, so mixed comparison must resolve.
SELECT '2.50'::dec64 = 2.5, 2.5 = '2.50'::dec64, '2.50'::dec64 > 2.4,
       2.6 > '2.50'::dec64;

-- An integer literal must not make the comparison ambiguous.
SELECT '2'::dec64 < 10, '2'::dec64 = 2, 10 > '2'::dec64;

--
-- Mixed dec64/integer arithmetic keeps the type
--

SELECT '2.50'::dec64 * 2, 2 * '2.50'::dec64, '10.00'::dec64 / 4,
       '2.50'::dec64 + 1, 1 - '2.50'::dec64,
       pg_typeof('2.50'::dec64 * 2);

--
-- Conversions
--

SELECT ('1.50'::dec64)::numeric, (1.5::numeric)::dec64,
       ('2.5'::dec64)::int, ('2.4'::dec64)::int, ('-2.5'::dec64)::int,
       ('1.25'::dec64)::float8, (2.5::float8)::dec64,
       (0.123456789::float8)::dec64;

SELECT (1::smallint)::dec64, (1::int)::dec64, (1::bigint)::dec64;

-- numeric values dec64 cannot represent are refused rather than mangled.
SELECT ('NaN'::numeric)::dec64;
SELECT (1e30::numeric)::dec64;

--
-- Rounding and inspection
--

SELECT round('2.345'::dec64, 2), round('-2.345'::dec64, 2), round('2.5'::dec64),
       trunc('2.345'::dec64, 2), trunc('-2.345'::dec64, 2), trunc('2.9'::dec64),
       ceil('2.1'::dec64), ceil('-2.1'::dec64),
       floor('2.9'::dec64), floor('-2.1'::dec64),
       scale('2.345'::dec64), scale('2'::dec64);

--
-- Aggregates
--

CREATE TABLE agg(v dec64(18,2));
INSERT INTO agg SELECT (i % 1000) / 100.0 FROM generate_series(1, 10000) i;

-- Every aggregate must agree with the numeric equivalent to the last digit.
SELECT sum(v)::text, avg(v)::text, min(v)::text, max(v)::text, count(v) FROM agg
UNION ALL
SELECT sum(v::numeric)::text, avg(v::numeric)::text, min(v::numeric)::text,
       max(v::numeric)::text, count(v::numeric) FROM agg;

-- sum() widens to numeric, because a sum over many rows outgrows 18 digits.
SELECT pg_typeof(sum(v)), pg_typeof(avg(v)), pg_typeof(min(v)) FROM agg;
SELECT sum(v)::text FROM (SELECT '999999999999999999'::dec64 v
                          FROM generate_series(1,3)) s;

-- Empty input and NULLs behave as SQL requires.
SELECT sum(v) IS NULL, avg(v) IS NULL, min(v) IS NULL, max(v) IS NULL
    FROM agg WHERE false;
SELECT sum(v)::text, count(v) FROM (VALUES (NULL::dec64), ('1.5'::dec64)) t(v);

-- Operands of different scale accumulate without losing digits.
SELECT sum(v)::text, avg(v)::text FROM
    (VALUES ('1.5'::dec64), ('1.005'::dec64), ('2'::dec64)) t(v);

-- Partial aggregation across workers must give the same answer as one process.
SET parallel_setup_cost = 0;
SET parallel_tuple_cost = 0;
SET min_parallel_table_scan_size = 0;
SET max_parallel_workers_per_gather = 2;
EXPLAIN (COSTS OFF) SELECT sum(v) FROM agg;
SELECT sum(v)::text FROM agg;
SET max_parallel_workers_per_gather = 0;
SELECT sum(v)::text FROM agg;
RESET parallel_setup_cost;
RESET parallel_tuple_cost;
RESET min_parallel_table_scan_size;
RESET max_parallel_workers_per_gather;

--
-- Indexes and ordering
--

CREATE INDEX agg_btree ON agg(v);
CREATE INDEX agg_hash ON agg USING hash(v);
ANALYZE agg;

SET enable_seqscan = off;
EXPLAIN (COSTS OFF) SELECT count(*) FROM agg WHERE v = '5.00'::dec64;
EXPLAIN (COSTS OFF) SELECT count(*) FROM agg WHERE v > 9.5;
EXPLAIN (COSTS OFF) SELECT min(v) FROM agg;
SELECT count(*) FROM agg WHERE v = '5.00'::dec64;
SELECT count(*) FROM agg WHERE v > 9.5;
RESET enable_seqscan;

-- A representable literal is folded into a dec64 constant at plan time, so
-- the per-row work is an integer compare; one that dec64 cannot hold exactly
-- is left alone, and the general cross-type path keeps the answer right.
EXPLAIN (COSTS OFF) SELECT count(*) FROM agg WHERE v > 5.00;
EXPLAIN (COSTS OFF) SELECT count(*) FROM agg WHERE v > 5.000000001;
EXPLAIN (COSTS OFF) SELECT count(*) FROM agg WHERE 5.00 < v;
SELECT count(*) FROM agg WHERE v > 5.00;
SELECT count(*) FROM agg WHERE v > 5.000000001;

-- Ordering must follow numeric value, not the packed representation.
SELECT string_agg(v::text, ' ' ORDER BY v) FROM
    (VALUES ('-1.5'::dec64), ('0'::dec64), ('1.50'::dec64), ('10'::dec64),
            ('-10'::dec64), ('0.0000001'::dec64)) t(v);

--
-- Binary send/receive
--

CREATE TABLE bin(v dec64);
COPY (SELECT v FROM (VALUES ('1.50'::dec64), ('-999999999999999999'::dec64),
                            ('0.0000001'::dec64), ('0'::dec64)) t(v))
    TO '/tmp/dec64_test.bin' WITH (FORMAT binary);
COPY bin FROM '/tmp/dec64_test.bin' WITH (FORMAT binary);
SELECT v FROM bin ORDER BY v;

DROP TABLE bin;
DROP TABLE agg;
DROP EXTENSION dec64;
