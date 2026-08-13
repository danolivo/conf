CREATE EXTENSION dec64;

-- The wide tier is 16 bytes, and therefore by reference: a Datum holds 8.
SELECT typname, typlen, typbyval, typalign FROM pg_type
    WHERE typname IN ('dec64', 'dec128') ORDER BY 1;

--
-- Range and scale
--

-- 37 significant digits and 15 decimals; one more of either is refused.
SELECT '9999999999999999999999999999999999999'::dec128;
SELECT '-9999999999999999999999999999999999999'::dec128;
SELECT '1.123456789012345'::dec128;
SELECT '10000000000000000000000000000000000000'::dec128;
SELECT '1.1234567890123456'::dec128;

-- No NaN and no infinity, as in DuckDB's DECIMAL.
SELECT 'NaN'::dec128;
SELECT 'Infinity'::dec128;

-- The point of the wide tier: N(26.11) from the Russian FTS e-invoice schema
-- is the only normative money format that dec64 cannot hold.
CREATE TABLE fns(price dec128(26,11));
\d fns
INSERT INTO fns VALUES (123456789012345.12345678901);
SELECT price, scale(price) FROM fns;
INSERT INTO fns VALUES (1234567890123456.12345678901);
DROP TABLE fns;

-- Modifiers are checked against the wide limits.
CREATE TABLE bad(x dec128(38,2));
CREATE TABLE bad(x dec128(20,16));

--
-- Arithmetic
--

-- Scale rules match numeric and dec64: max for +/-, sum for *.
SELECT '1.50'::dec128 + '1.200'::dec128, '1.50'::dec128 - '1.200'::dec128,
       '1.50'::dec128 * '1.200'::dec128;

-- Exactness that binary floating point cannot reach.
SELECT '0.1'::dec128 + '0.1'::dec128 + '0.1'::dec128 - '0.3'::dec128 AS exactly_zero;
SELECT '0.70'::dec128 * '1.05'::dec128 AS sales_tax;

-- Division has no wider intermediate to borrow, so it runs long division one
-- digit at a time; the result is exact-typed at the widest scale.
SELECT '10.00'::dec128 / '3'::dec128, '1'::dec128 / '7'::dec128,
       '1'::dec128 / '8'::dec128, pg_typeof('1'::dec128 / '3'::dec128);
SELECT '-10.00'::dec128 / '3'::dec128, '10.00'::dec128 / '-3'::dec128;

-- Overflow is a loud error, never a silent wrap.
SELECT '9999999999999999999999999999999999999'::dec128 + '1'::dec128;
SELECT '9999999999999999999'::dec128 * '9999999999999999999'::dec128;
SELECT '0.00000001'::dec128 * '0.00000001'::dec128;
SELECT '1'::dec128 / '0'::dec128;

SELECT '10.00'::dec128 % '3'::dec128, -('1.50'::dec128), abs('-1.5'::dec128),
       sign('-1.5'::dec128);

--
-- Comparison
--

-- Equal magnitudes compare and hash alike regardless of scale.
SELECT '1.5'::dec128 = '1.500'::dec128, '1.5'::dec128 < '1.500'::dec128,
       '2'::dec128 > '1.99'::dec128;
SELECT dec128_hash('1.5'::dec128) = dec128_hash('1.500'::dec128) AS same_hash;

-- Comparison must never fail, even where aligning the scales would overflow:
-- the widest value brought to 15 decimals does not fit, but the answer is
-- still well defined.
SELECT '9999999999999999999999999999999999999'::dec128 > '0.000000000000001'::dec128,
       '-9999999999999999999999999999999999999'::dec128 < '0.000000000000001'::dec128;

-- Adding those same two does fail, and rightly so.
SELECT '9999999999999999999999999999999999999'::dec128 + '0.000000000000001'::dec128;

-- Mixed comparison with a decimal literal, which the grammar makes numeric.
SELECT '2.50'::dec128 = 2.5, 2.5 = '2.50'::dec128, '2.50'::dec128 > 2.4;
SELECT '2'::dec128 < 10, '2'::dec128 = 2;

--
-- Interaction between the tiers
--

-- dec64 widens into dec128 implicitly, so mixed expressions land in dec128.
SELECT pg_typeof('1.5'::dec64 + '2.5'::dec128), '1.5'::dec64 + '2.5'::dec128,
       '1.5'::dec64 = '1.500'::dec128;

-- Widening is always exact; narrowing rounds the scale and may not fit.
SELECT ('1.5'::dec64)::dec128, ('1.50'::dec128)::dec64,
       ('1.123456789'::dec128)::dec64;
SELECT ('99999999999999999999'::dec128)::dec64;

--
-- Mixed dec128/integer arithmetic keeps the type
--

SELECT '2.50'::dec128 * 2, 2 * '2.50'::dec128, '10.00'::dec128 / 4,
       '2.50'::dec128 + 1, pg_typeof('2.50'::dec128 * 2);

--
-- Conversions
--

SELECT ('1.50'::dec128)::numeric, (1.5::numeric)::dec128,
       ('2.5'::dec128)::int, ('-2.5'::dec128)::int,
       ('1.25'::dec128)::float8, (2.5::float8)::dec128;
SELECT (1::bigint)::dec128, (9223372036854775807::bigint)::dec128;
SELECT ('NaN'::numeric)::dec128;
SELECT (1e40::numeric)::dec128;

-- Rounding once, straight to the declared scale, never twice.
SELECT 0.4449::numeric::dec128(10,2) AS dec128, round(0.4449, 2) AS numeric;

--
-- Rounding and inspection
--

SELECT round('2.345'::dec128, 2), round('-2.345'::dec128, 2),
       trunc('2.345'::dec128, 2), ceil('2.1'::dec128), floor('-2.1'::dec128),
       scale('2.345'::dec128);

--
-- Aggregates
--

CREATE TABLE agg(v dec128(26,11));
INSERT INTO agg SELECT (i % 1000) / 100.0 FROM generate_series(1, 10000) i;

-- Every aggregate must agree with the numeric equivalent to the last digit.
SELECT sum(v)::text, avg(v)::text, min(v)::text, max(v)::text, count(v) FROM agg
UNION ALL
SELECT sum(v::numeric)::text, avg(v::numeric)::text, min(v::numeric)::text,
       max(v::numeric)::text, count(v::numeric) FROM agg;

-- A dec128 value already fills the accumulator, so the running total spills
-- into an exact numeric carry instead of overflowing.  The result is still
-- exact and unbounded.
SELECT sum(v)::text FROM (SELECT '9999999999999999999999999999999999999'::dec128 v
                          FROM generate_series(1,100)) s;
SELECT avg(v)::text FROM (SELECT '9999999999999999999999999999999999999'::dec128 v
                          FROM generate_series(1,100)) s;

SELECT sum(v) IS NULL, avg(v) IS NULL, min(v) IS NULL FROM agg WHERE false;
SELECT sum(v)::text FROM (VALUES (NULL::dec128), ('1.5'::dec128)) t(v);
SELECT sum(v)::text FROM (VALUES ('1.5'::dec128), ('1.005'::dec128), ('2'::dec128)) t(v);

-- Partial aggregation across workers, including the spill path.
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
-- Indexes, ordering, plan-time constant folding
--

CREATE INDEX agg_btree ON agg(v);
CREATE INDEX agg_hash ON agg USING hash(v);
ANALYZE agg;

SET enable_seqscan = off;
EXPLAIN (COSTS OFF) SELECT count(*) FROM agg WHERE v = '5.00'::dec128;
EXPLAIN (COSTS OFF) SELECT count(*) FROM agg WHERE v > 5.00;
EXPLAIN (COSTS OFF) SELECT count(*) FROM agg WHERE v > 5.0000000000000001;
EXPLAIN (COSTS OFF) SELECT min(v) FROM agg;
SELECT count(*) FROM agg WHERE v > 5.00;
SELECT count(*) FROM agg WHERE v > 5.0000000000000001;
RESET enable_seqscan;

SELECT string_agg(v::text, ' ' ORDER BY v) FROM
    (VALUES ('-1.5'::dec128), ('0'::dec128), ('1.50'::dec128), ('10'::dec128),
            ('-10'::dec128), ('0.000000000000001'::dec128)) t(v);

--
-- Binary send/receive
--

CREATE TABLE bin(v dec128);
COPY (SELECT v FROM (VALUES ('1.50'::dec128),
                            ('-9999999999999999999999999999999999999'::dec128),
                            ('0.000000000000001'::dec128), ('0'::dec128)) t(v))
    TO '/tmp/dec128_test.bin' WITH (FORMAT binary);
COPY bin FROM '/tmp/dec128_test.bin' WITH (FORMAT binary);
SELECT v FROM bin ORDER BY v;

DROP TABLE bin;
DROP TABLE agg;
DROP EXTENSION dec64;
