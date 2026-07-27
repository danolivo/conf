-- bench_shagg_init.sql
--
--   psql -v nrows=3000000 -f bench_shagg_init.sql
--
-- Shape mirrors tt4/tt4_dbl:
--   * 13 grouping columns: 9 constant, 4 carrying real cardinality
--     (17221 / 27 / 16 / 2 distinct — the measured n_distinct of the
--     original), mostly 17-byte bytea;
--   * distinct group count: for group id g in [0, ngroups), the tuple
--     (g%17221, g%27, g%16, g%2) is injective while ngroups <= lcm(...)
--     ~ 7.4M, so ngroups controls the exact group count (default 592000,
--     matching the original's 591,894 within a rounding hair);
--   * ~5 rows per group (nrows/ngroups), uniform — the original showed
--     no significant per-group skew;
--   * payload/width filler columns reproduce width~176-209;
--   * two sum variants: float8 (by-value shared-table path) and
--     numeric(15,2) (flat-state extension / stock internal-state
--     fallback).  Sum values are deterministic, so results are
--     comparable across runs and plan shapes.

\if :{?nrows} \else \set nrows 3000000 \endif
\if :{?ngroups} \else \set ngroups 592000 \endif

DROP TABLE IF EXISTS bench_shagg_dbl;
DROP TABLE IF EXISTS bench_shagg_num;

CREATE TABLE bench_shagg_dbl (
    f000 timestamp without time zone,
    f001tref bytea,
    f001rref bytea,
    f002 numeric(9,0),
    f003 boolean,
    f004 numeric(1,0),
    f005rref bytea,
    f006rref bytea,
    f007rref bytea,
    f008_type bytea,        -- const        (1 distinct)
    f008_rtref bytea,       -- 2 distinct, 5 bytes
    f008_rrref bytea,       -- 27 distinct, 17 bytes
    f009rref bytea,         -- const, 17 bytes
    f010rref bytea,         -- 17221 distinct, 17 bytes
    f011_type bytea,        -- const
    f011_rtref bytea,       -- const
    f011_rrref bytea,       -- const, 17 bytes
    f012 numeric(10,0),     -- const
    f013rref bytea,         -- const, 17 bytes
    f014rref bytea,         -- 16 distinct, 17 bytes
    f015rref bytea,         -- const, 17 bytes
    f016rref bytea,         -- const, 17 bytes
    v1 double precision, v2 double precision, v3 double precision,
    v4 double precision, v5 double precision, v6 double precision,
    v7 double precision
);

INSERT INTO bench_shagg_dbl
SELECT
    '2026-01-01'::timestamp + (i % 86400) * interval '1 second',
    decode(lpad(to_hex(i % 1000), 34, '0'), 'hex'),
    decode(lpad(to_hex(i % 977),  34, '0'), 'hex'),
    (i % 1000000)::numeric(9,0),
    (i % 2 = 0),
    (i % 2)::numeric(1,0),
    decode(lpad(to_hex(i % 971),  34, '0'), 'hex'),
    decode(lpad(to_hex(i % 967),  34, '0'), 'hex'),
    decode(lpad(to_hex(i % 953),  34, '0'), 'hex'),
    '\x0008'::bytea,
    decode(lpad(to_hex(g % 2),     10, '0'), 'hex'),
    decode(lpad(to_hex(g % 27),    34, '0'), 'hex'),
    '\x0000000000000000000000000000000000'::bytea,
    decode(lpad(to_hex(g % 17221), 34, '0'), 'hex'),
    '\x0000'::bytea,
    '\x0000000000'::bytea,
    '\x0000000000000000000000000000000000'::bytea,
    0::numeric(10,0),
    '\x0000000000000000000000000000000000'::bytea,
    decode(lpad(to_hex(g % 16),    34, '0'), 'hex'),
    '\x0000000000000000000000000000000000'::bytea,
    '\x0000000000000000000000000000000000'::bytea,
    ((i * 31 + 7)  % 100000) / 100.0,
    ((i * 37 + 11) % 100000) / 100.0,
    ((i * 41 + 13) % 100000) / 100.0,
    ((i * 43 + 17) % 100000) / 100.0,
    ((i * 47 + 19) % 100000) / 100.0,
    ((i * 53 + 23) % 100000) / 100.0,
    ((i * 59 + 29) % 100000) / 100.0
FROM (SELECT i, (i % :ngroups) AS g
      FROM generate_series(0, :nrows - 1) i) s;

-- numeric(15,2) twin: identical keys, sums as exact decimals
CREATE TABLE bench_shagg_num AS
SELECT f000, f001tref, f001rref, f002, f003, f004,
       f005rref, f006rref, f007rref,
       f008_type, f008_rtref, f008_rrref, f009rref, f010rref,
       f011_type, f011_rtref, f011_rrref, f012, f013rref,
       f014rref, f015rref, f016rref,
       v1::numeric(15,2) AS v1, v2::numeric(15,2) AS v2,
       v3::numeric(15,2) AS v3, v4::numeric(15,2) AS v4,
       v5::numeric(15,2) AS v5, v6::numeric(15,2) AS v6,
       v7::numeric(15,2) AS v7
FROM bench_shagg_dbl;

VACUUM ANALYZE bench_shagg_dbl, bench_shagg_num;

-- sanity: expected group count and rows/group
SELECT count(*) AS rows,
       count(DISTINCT (f008_rtref, f008_rrref, f010rref, f014rref)) AS groups
FROM bench_shagg_dbl;

CREATE EXTENSION shared_numeric_agg;
