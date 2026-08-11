/* dec64--1.0.sql */

-- complain if the script is sourced by psql rather than CREATE EXTENSION
\echo Use "CREATE EXTENSION dec64" to load this file. \quit

-- ---------------------------------------------------------------------------
-- Type
-- ---------------------------------------------------------------------------

CREATE TYPE dec64;

CREATE FUNCTION dec64_in(cstring, oid, integer) RETURNS dec64
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION dec64_out(dec64) RETURNS cstring
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION dec64_recv(internal, oid, integer) RETURNS dec64
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION dec64_send(dec64) RETURNS bytea
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION dec64typmodin(cstring[]) RETURNS integer
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION dec64typmodout(integer) RETURNS cstring
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;

CREATE TYPE dec64 (
    INPUT = dec64_in,
    OUTPUT = dec64_out,
    RECEIVE = dec64_recv,
    SEND = dec64_send,
    TYPMOD_IN = dec64typmodin,
    TYPMOD_OUT = dec64typmodout,
    INTERNALLENGTH = 8,
    PASSEDBYVALUE,
    ALIGNMENT = double,
    STORAGE = plain,
    CATEGORY = 'N'
);

COMMENT ON TYPE dec64 IS
    'exact fixed-point decimal, 18 significant digits, up to 7 decimal places';

-- Length coercion: applied when a value is stored into dec64(p,s).
CREATE FUNCTION dec64(dec64, integer) RETURNS dec64
    AS 'MODULE_PATHNAME', 'dec64_scale_typmod'
    LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE CAST (dec64 AS dec64) WITH FUNCTION dec64(dec64, integer) AS IMPLICIT;

-- ---------------------------------------------------------------------------
-- Arithmetic
-- ---------------------------------------------------------------------------

CREATE FUNCTION dec64_add(dec64, dec64) RETURNS dec64
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION dec64_sub(dec64, dec64) RETURNS dec64
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION dec64_mul(dec64, dec64) RETURNS dec64
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION dec64_div(dec64, dec64) RETURNS dec64
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION dec64_mod(dec64, dec64) RETURNS dec64
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION dec64_uminus(dec64) RETURNS dec64
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION dec64_uplus(dec64) RETURNS dec64
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;

CREATE OPERATOR + (LEFTARG = dec64, RIGHTARG = dec64,
                   FUNCTION = dec64_add, COMMUTATOR = +);
CREATE OPERATOR - (LEFTARG = dec64, RIGHTARG = dec64,
                   FUNCTION = dec64_sub);
CREATE OPERATOR * (LEFTARG = dec64, RIGHTARG = dec64,
                   FUNCTION = dec64_mul, COMMUTATOR = *);
CREATE OPERATOR / (LEFTARG = dec64, RIGHTARG = dec64,
                   FUNCTION = dec64_div);
CREATE OPERATOR % (LEFTARG = dec64, RIGHTARG = dec64,
                   FUNCTION = dec64_mod);
CREATE OPERATOR - (RIGHTARG = dec64, FUNCTION = dec64_uminus);
CREATE OPERATOR + (RIGHTARG = dec64, FUNCTION = dec64_uplus);

-- ---------------------------------------------------------------------------
-- Comparison, ordering, hashing
-- ---------------------------------------------------------------------------

CREATE FUNCTION dec64_cmp(dec64, dec64) RETURNS integer
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION dec64_lt(dec64, dec64) RETURNS boolean
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION dec64_le(dec64, dec64) RETURNS boolean
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION dec64_eq(dec64, dec64) RETURNS boolean
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION dec64_ne(dec64, dec64) RETURNS boolean
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION dec64_ge(dec64, dec64) RETURNS boolean
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION dec64_gt(dec64, dec64) RETURNS boolean
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION dec64_hash(dec64) RETURNS integer
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION dec64_hash_extended(dec64, bigint) RETURNS bigint
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION dec64_sortsupport(internal) RETURNS void
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;

CREATE OPERATOR < (LEFTARG = dec64, RIGHTARG = dec64, FUNCTION = dec64_lt,
                   COMMUTATOR = >, NEGATOR = >=,
                   RESTRICT = scalarltsel, JOIN = scalarltjoinsel);
CREATE OPERATOR <= (LEFTARG = dec64, RIGHTARG = dec64, FUNCTION = dec64_le,
                    COMMUTATOR = >=, NEGATOR = >,
                    RESTRICT = scalarlesel, JOIN = scalarlejoinsel);
CREATE OPERATOR = (LEFTARG = dec64, RIGHTARG = dec64, FUNCTION = dec64_eq,
                   COMMUTATOR = =, NEGATOR = <>,
                   RESTRICT = eqsel, JOIN = eqjoinsel, HASHES, MERGES);
CREATE OPERATOR <> (LEFTARG = dec64, RIGHTARG = dec64, FUNCTION = dec64_ne,
                    COMMUTATOR = <>, NEGATOR = =,
                    RESTRICT = neqsel, JOIN = neqjoinsel);
CREATE OPERATOR >= (LEFTARG = dec64, RIGHTARG = dec64, FUNCTION = dec64_ge,
                    COMMUTATOR = <=, NEGATOR = <,
                    RESTRICT = scalargesel, JOIN = scalargejoinsel);
CREATE OPERATOR > (LEFTARG = dec64, RIGHTARG = dec64, FUNCTION = dec64_gt,
                   COMMUTATOR = <, NEGATOR = <=,
                   RESTRICT = scalargtsel, JOIN = scalargtjoinsel);

-- Both tiers share one btree operator family, so cross-tier comparisons can
-- drive index scans and merge joins, exactly as integer_ops does for
-- smallint/integer/bigint.
CREATE OPERATOR FAMILY dec_ops USING btree;

CREATE OPERATOR CLASS dec64_ops DEFAULT FOR TYPE dec64 USING btree
    FAMILY dec_ops AS
    OPERATOR 1 <,
    OPERATOR 2 <=,
    OPERATOR 3 =,
    OPERATOR 4 >=,
    OPERATOR 5 >,
    FUNCTION 1 dec64_cmp(dec64, dec64),
    FUNCTION 2 dec64_sortsupport(internal);

CREATE OPERATOR CLASS dec64_ops DEFAULT FOR TYPE dec64 USING hash AS
    OPERATOR 1 =,
    FUNCTION 1 dec64_hash(dec64),
    FUNCTION 2 dec64_hash_extended(dec64, bigint);

-- ---------------------------------------------------------------------------
-- Conversions
-- ---------------------------------------------------------------------------

-- Two-argument cast function: it needs the target typmod so that a numeric
-- with more fractional digits than dec64 holds is rounded once, straight to
-- the declared scale, instead of twice.
CREATE FUNCTION numeric_dec64(numeric, integer) RETURNS dec64
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION dec64_numeric(dec64) RETURNS numeric
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION int2_dec64(smallint) RETURNS dec64
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION int4_dec64(integer) RETURNS dec64
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION int8_dec64(bigint) RETURNS dec64
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION dec64_int2(dec64) RETURNS smallint
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION dec64_int4(dec64) RETURNS integer
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION dec64_int8(dec64) RETURNS bigint
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION float4_dec64(real) RETURNS dec64
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION float8_dec64(double precision) RETURNS dec64
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION dec64_float4(dec64) RETURNS real
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION dec64_float8(dec64) RETURNS double precision
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;

-- Casts from the integer types are assignment-only on purpose.  Making them
-- implicit would leave "amount < 10" ambiguous between dec64 < dec64 and
-- dec64 < numeric, since integer converts implicitly to numeric as well.
-- Mixed dec64/integer arithmetic is served by the operators below instead.
CREATE CAST (smallint AS dec64) WITH FUNCTION int2_dec64(smallint) AS ASSIGNMENT;
CREATE CAST (integer AS dec64) WITH FUNCTION int4_dec64(integer) AS ASSIGNMENT;
CREATE CAST (bigint AS dec64) WITH FUNCTION int8_dec64(bigint) AS ASSIGNMENT;

-- Everything else is narrowing or crosses the exact/approximate boundary, so
-- it needs at least an assignment context.
CREATE CAST (numeric AS dec64) WITH FUNCTION numeric_dec64(numeric, integer) AS ASSIGNMENT;
CREATE CAST (dec64 AS numeric) WITH FUNCTION dec64_numeric(dec64) AS IMPLICIT;
CREATE CAST (dec64 AS smallint) WITH FUNCTION dec64_int2(dec64) AS ASSIGNMENT;
CREATE CAST (dec64 AS integer) WITH FUNCTION dec64_int4(dec64) AS ASSIGNMENT;
CREATE CAST (dec64 AS bigint) WITH FUNCTION dec64_int8(dec64) AS ASSIGNMENT;
CREATE CAST (real AS dec64) WITH FUNCTION float4_dec64(real) AS ASSIGNMENT;
CREATE CAST (double precision AS dec64) WITH FUNCTION float8_dec64(double precision) AS ASSIGNMENT;
CREATE CAST (dec64 AS real) WITH FUNCTION dec64_float4(dec64) AS IMPLICIT;
CREATE CAST (dec64 AS double precision) WITH FUNCTION dec64_float8(dec64) AS IMPLICIT;

-- ---------------------------------------------------------------------------
-- Mixed dec64/integer arithmetic
--
-- Only the bigint width is declared: smallint and integer reach it through
-- core's implicit widening casts, and the candidate wins resolution because
-- it matches the dec64 operand exactly.  Without these, "amount * 2" would
-- decay into numeric arithmetic and lose the type.
-- ---------------------------------------------------------------------------

CREATE FUNCTION dec64_add_int8(dec64, bigint) RETURNS dec64
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION dec64_sub_int8(dec64, bigint) RETURNS dec64
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION dec64_mul_int8(dec64, bigint) RETURNS dec64
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION dec64_div_int8(dec64, bigint) RETURNS dec64
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION int8_add_dec64(bigint, dec64) RETURNS dec64
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION int8_sub_dec64(bigint, dec64) RETURNS dec64
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION int8_mul_dec64(bigint, dec64) RETURNS dec64
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION int8_div_dec64(bigint, dec64) RETURNS dec64
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;

CREATE OPERATOR + (LEFTARG = dec64, RIGHTARG = bigint,
                   FUNCTION = dec64_add_int8, COMMUTATOR = +);
CREATE OPERATOR + (LEFTARG = bigint, RIGHTARG = dec64,
                   FUNCTION = int8_add_dec64, COMMUTATOR = +);
CREATE OPERATOR - (LEFTARG = dec64, RIGHTARG = bigint,
                   FUNCTION = dec64_sub_int8);
CREATE OPERATOR - (LEFTARG = bigint, RIGHTARG = dec64,
                   FUNCTION = int8_sub_dec64);
CREATE OPERATOR * (LEFTARG = dec64, RIGHTARG = bigint,
                   FUNCTION = dec64_mul_int8, COMMUTATOR = *);
CREATE OPERATOR * (LEFTARG = bigint, RIGHTARG = dec64,
                   FUNCTION = int8_mul_dec64, COMMUTATOR = *);
CREATE OPERATOR / (LEFTARG = dec64, RIGHTARG = bigint,
                   FUNCTION = dec64_div_int8);
CREATE OPERATOR / (LEFTARG = bigint, RIGHTARG = dec64,
                   FUNCTION = int8_div_dec64);

-- ---------------------------------------------------------------------------
-- Cross-type comparison against numeric
--
-- An undecorated decimal literal is numeric, so without these "amount > 5.00"
-- would not resolve.  Comparison happens in numeric, which keeps operands
-- outside the dec64 range comparing correctly instead of erroring.
-- ---------------------------------------------------------------------------

CREATE FUNCTION dec64_numeric_cmp(dec64, numeric) RETURNS integer
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION numeric_dec64_cmp(numeric, dec64) RETURNS integer
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;

CREATE FUNCTION dec64_numeric_lt(dec64, numeric) RETURNS boolean
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION dec64_numeric_le(dec64, numeric) RETURNS boolean
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION dec64_numeric_eq(dec64, numeric) RETURNS boolean
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION dec64_numeric_ne(dec64, numeric) RETURNS boolean
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION dec64_numeric_ge(dec64, numeric) RETURNS boolean
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION dec64_numeric_gt(dec64, numeric) RETURNS boolean
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;

CREATE FUNCTION numeric_dec64_lt(numeric, dec64) RETURNS boolean
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION numeric_dec64_le(numeric, dec64) RETURNS boolean
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION numeric_dec64_eq(numeric, dec64) RETURNS boolean
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION numeric_dec64_ne(numeric, dec64) RETURNS boolean
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION numeric_dec64_ge(numeric, dec64) RETURNS boolean
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION numeric_dec64_gt(numeric, dec64) RETURNS boolean
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;

CREATE OPERATOR < (LEFTARG = dec64, RIGHTARG = numeric, FUNCTION = dec64_numeric_lt,
                   COMMUTATOR = >, NEGATOR = >=,
                   RESTRICT = scalarltsel, JOIN = scalarltjoinsel);
CREATE OPERATOR <= (LEFTARG = dec64, RIGHTARG = numeric, FUNCTION = dec64_numeric_le,
                    COMMUTATOR = >=, NEGATOR = >,
                    RESTRICT = scalarlesel, JOIN = scalarlejoinsel);
CREATE OPERATOR = (LEFTARG = dec64, RIGHTARG = numeric, FUNCTION = dec64_numeric_eq,
                   COMMUTATOR = =, NEGATOR = <>,
                   RESTRICT = eqsel, JOIN = eqjoinsel, MERGES);
CREATE OPERATOR <> (LEFTARG = dec64, RIGHTARG = numeric, FUNCTION = dec64_numeric_ne,
                    COMMUTATOR = <>, NEGATOR = =,
                    RESTRICT = neqsel, JOIN = neqjoinsel);
CREATE OPERATOR >= (LEFTARG = dec64, RIGHTARG = numeric, FUNCTION = dec64_numeric_ge,
                    COMMUTATOR = <=, NEGATOR = <,
                    RESTRICT = scalargesel, JOIN = scalargejoinsel);
CREATE OPERATOR > (LEFTARG = dec64, RIGHTARG = numeric, FUNCTION = dec64_numeric_gt,
                   COMMUTATOR = <, NEGATOR = <=,
                   RESTRICT = scalargtsel, JOIN = scalargtjoinsel);

CREATE OPERATOR < (LEFTARG = numeric, RIGHTARG = dec64, FUNCTION = numeric_dec64_lt,
                   COMMUTATOR = >, NEGATOR = >=,
                   RESTRICT = scalarltsel, JOIN = scalarltjoinsel);
CREATE OPERATOR <= (LEFTARG = numeric, RIGHTARG = dec64, FUNCTION = numeric_dec64_le,
                    COMMUTATOR = >=, NEGATOR = >,
                    RESTRICT = scalarlesel, JOIN = scalarlejoinsel);
CREATE OPERATOR = (LEFTARG = numeric, RIGHTARG = dec64, FUNCTION = numeric_dec64_eq,
                   COMMUTATOR = =, NEGATOR = <>,
                   RESTRICT = eqsel, JOIN = eqjoinsel, MERGES);
CREATE OPERATOR <> (LEFTARG = numeric, RIGHTARG = dec64, FUNCTION = numeric_dec64_ne,
                    COMMUTATOR = <>, NEGATOR = =,
                    RESTRICT = neqsel, JOIN = neqjoinsel);
CREATE OPERATOR >= (LEFTARG = numeric, RIGHTARG = dec64, FUNCTION = numeric_dec64_ge,
                    COMMUTATOR = <=, NEGATOR = <,
                    RESTRICT = scalargesel, JOIN = scalargejoinsel);
CREATE OPERATOR > (LEFTARG = numeric, RIGHTARG = dec64, FUNCTION = numeric_dec64_gt,
                   COMMUTATOR = <, NEGATOR = <=,
                   RESTRICT = scalargtsel, JOIN = scalargtjoinsel);

-- Cross-type family members are registered once, at the end of this script.

-- ---------------------------------------------------------------------------
-- Rounding and inspection
-- ---------------------------------------------------------------------------

CREATE FUNCTION abs(dec64) RETURNS dec64
    AS 'MODULE_PATHNAME', 'dec64_abs'
    LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION sign(dec64) RETURNS dec64
    AS 'MODULE_PATHNAME', 'dec64_sign'
    LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION round(dec64) RETURNS dec64
    AS 'MODULE_PATHNAME', 'dec64_round'
    LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION round(dec64, integer) RETURNS dec64
    AS 'MODULE_PATHNAME', 'dec64_round_scale'
    LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION trunc(dec64) RETURNS dec64
    AS 'MODULE_PATHNAME', 'dec64_trunc'
    LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION trunc(dec64, integer) RETURNS dec64
    AS 'MODULE_PATHNAME', 'dec64_trunc_scale'
    LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION ceil(dec64) RETURNS dec64
    AS 'MODULE_PATHNAME', 'dec64_ceil'
    LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION ceiling(dec64) RETURNS dec64
    AS 'MODULE_PATHNAME', 'dec64_ceil'
    LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION floor(dec64) RETURNS dec64
    AS 'MODULE_PATHNAME', 'dec64_floor'
    LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION scale(dec64) RETURNS integer
    AS 'MODULE_PATHNAME', 'dec64_scale'
    LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;

-- ---------------------------------------------------------------------------
-- Aggregates
--
-- sum() and avg() accumulate in 128 bits and return numeric: a sum over many
-- rows routinely exceeds 18 digits, so it must widen.  This mirrors what core
-- already does for sum(bigint).
-- ---------------------------------------------------------------------------

CREATE FUNCTION dec64_accum(internal, dec64) RETURNS internal
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE PARALLEL SAFE;
CREATE FUNCTION dec64_combine(internal, internal) RETURNS internal
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE PARALLEL SAFE;
CREATE FUNCTION dec64_serialize(internal) RETURNS bytea
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION dec64_deserialize(bytea, internal) RETURNS internal
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION dec64_sum_final(internal) RETURNS numeric
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE PARALLEL SAFE;
CREATE FUNCTION dec64_avg_final(internal) RETURNS numeric
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE PARALLEL SAFE;
CREATE FUNCTION dec64_smaller(dec64, dec64) RETURNS dec64
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION dec64_larger(dec64, dec64) RETURNS dec64
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;

CREATE AGGREGATE sum(dec64) (
    SFUNC = dec64_accum,
    STYPE = internal,
    FINALFUNC = dec64_sum_final,
    COMBINEFUNC = dec64_combine,
    SERIALFUNC = dec64_serialize,
    DESERIALFUNC = dec64_deserialize,
    PARALLEL = SAFE
);

CREATE AGGREGATE avg(dec64) (
    SFUNC = dec64_accum,
    STYPE = internal,
    FINALFUNC = dec64_avg_final,
    COMBINEFUNC = dec64_combine,
    SERIALFUNC = dec64_serialize,
    DESERIALFUNC = dec64_deserialize,
    PARALLEL = SAFE
);

CREATE AGGREGATE min(dec64) (
    SFUNC = dec64_smaller,
    STYPE = dec64,
    COMBINEFUNC = dec64_smaller,
    SORTOP = <,
    PARALLEL = SAFE
);

CREATE AGGREGATE max(dec64) (
    SFUNC = dec64_larger,
    STYPE = dec64,
    COMBINEFUNC = dec64_larger,
    SORTOP = >,
    PARALLEL = SAFE
);

-- ---------------------------------------------------------------------------
-- Planner support for mixed comparison
--
-- "amount > 5.00" arrives as dec64 > numeric only because the grammar makes a
-- numeric out of an undecorated decimal literal.  When the literal is exactly
-- representable, rewrite the call to the same-type operator at plan time --
-- the same specialisation DuckDB performs when it binds an operator.
-- ---------------------------------------------------------------------------

CREATE FUNCTION dec64_cmp_support(internal) RETURNS internal
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;

ALTER FUNCTION dec64_numeric_lt(dec64, numeric) SUPPORT dec64_cmp_support;
ALTER FUNCTION dec64_numeric_le(dec64, numeric) SUPPORT dec64_cmp_support;
ALTER FUNCTION dec64_numeric_eq(dec64, numeric) SUPPORT dec64_cmp_support;
ALTER FUNCTION dec64_numeric_ne(dec64, numeric) SUPPORT dec64_cmp_support;
ALTER FUNCTION dec64_numeric_ge(dec64, numeric) SUPPORT dec64_cmp_support;
ALTER FUNCTION dec64_numeric_gt(dec64, numeric) SUPPORT dec64_cmp_support;
ALTER FUNCTION numeric_dec64_lt(numeric, dec64) SUPPORT dec64_cmp_support;
ALTER FUNCTION numeric_dec64_le(numeric, dec64) SUPPORT dec64_cmp_support;
ALTER FUNCTION numeric_dec64_eq(numeric, dec64) SUPPORT dec64_cmp_support;
ALTER FUNCTION numeric_dec64_ne(numeric, dec64) SUPPORT dec64_cmp_support;
ALTER FUNCTION numeric_dec64_ge(numeric, dec64) SUPPORT dec64_cmp_support;
ALTER FUNCTION numeric_dec64_gt(numeric, dec64) SUPPORT dec64_cmp_support;

-- ===========================================================================
-- dec128 — wide tier: 37 significant digits, up to 15 decimals, 16 bytes
--
-- The upper rung of DuckDB's int64/int128 ladder, which one PostgreSQL type
-- cannot hold because pg_type.typlen is a single value per type.  Here it is
-- a second type, and the widening between the tiers follows the convention
-- core already uses for smallint/integer/bigint.
--
-- Four bits of the word carry the scale, so the range is 37 digits rather
-- than DuckDB's 38.  That bit buys scale up to 15, without which the widest
-- normative money format — N(26.11) from the Russian FTS e-invoice schema —
-- would not fit at any precision.
-- ===========================================================================

CREATE TYPE dec128;

CREATE FUNCTION dec128_in(cstring, oid, integer) RETURNS dec128
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION dec128_out(dec128) RETURNS cstring
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION dec128_recv(internal, oid, integer) RETURNS dec128
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION dec128_send(dec128) RETURNS bytea
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION dec128typmodin(cstring[]) RETURNS integer
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION dec128typmodout(integer) RETURNS cstring
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;

CREATE TYPE dec128 (
    INPUT = dec128_in,
    OUTPUT = dec128_out,
    RECEIVE = dec128_recv,
    SEND = dec128_send,
    TYPMOD_IN = dec128typmodin,
    TYPMOD_OUT = dec128typmodout,
    INTERNALLENGTH = 16,
    ALIGNMENT = double,
    STORAGE = plain,
    CATEGORY = 'N'
);

COMMENT ON TYPE dec128 IS
    'exact fixed-point decimal, 37 significant digits, up to 15 decimal places';

CREATE FUNCTION dec128(dec128, integer) RETURNS dec128
    AS 'MODULE_PATHNAME', 'dec128_scale_typmod'
    LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE CAST (dec128 AS dec128) WITH FUNCTION dec128(dec128, integer) AS IMPLICIT;

-- Arithmetic ----------------------------------------------------------------

CREATE FUNCTION dec128_add(dec128, dec128) RETURNS dec128
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION dec128_sub(dec128, dec128) RETURNS dec128
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION dec128_mul(dec128, dec128) RETURNS dec128
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION dec128_div(dec128, dec128) RETURNS dec128
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION dec128_mod(dec128, dec128) RETURNS dec128
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION dec128_uminus(dec128) RETURNS dec128
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION dec128_uplus(dec128) RETURNS dec128
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;

CREATE OPERATOR + (LEFTARG = dec128, RIGHTARG = dec128,
                   FUNCTION = dec128_add, COMMUTATOR = +);
CREATE OPERATOR - (LEFTARG = dec128, RIGHTARG = dec128, FUNCTION = dec128_sub);
CREATE OPERATOR * (LEFTARG = dec128, RIGHTARG = dec128,
                   FUNCTION = dec128_mul, COMMUTATOR = *);
CREATE OPERATOR / (LEFTARG = dec128, RIGHTARG = dec128, FUNCTION = dec128_div);
CREATE OPERATOR % (LEFTARG = dec128, RIGHTARG = dec128, FUNCTION = dec128_mod);
CREATE OPERATOR - (RIGHTARG = dec128, FUNCTION = dec128_uminus);
CREATE OPERATOR + (RIGHTARG = dec128, FUNCTION = dec128_uplus);

-- Comparison, ordering, hashing ---------------------------------------------

CREATE FUNCTION dec128_cmp(dec128, dec128) RETURNS integer
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION dec128_lt(dec128, dec128) RETURNS boolean
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION dec128_le(dec128, dec128) RETURNS boolean
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION dec128_eq(dec128, dec128) RETURNS boolean
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION dec128_ne(dec128, dec128) RETURNS boolean
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION dec128_ge(dec128, dec128) RETURNS boolean
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION dec128_gt(dec128, dec128) RETURNS boolean
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION dec128_hash(dec128) RETURNS integer
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION dec128_hash_extended(dec128, bigint) RETURNS bigint
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION dec128_sortsupport(internal) RETURNS void
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;

CREATE OPERATOR < (LEFTARG = dec128, RIGHTARG = dec128, FUNCTION = dec128_lt,
                   COMMUTATOR = >, NEGATOR = >=,
                   RESTRICT = scalarltsel, JOIN = scalarltjoinsel);
CREATE OPERATOR <= (LEFTARG = dec128, RIGHTARG = dec128, FUNCTION = dec128_le,
                    COMMUTATOR = >=, NEGATOR = >,
                    RESTRICT = scalarlesel, JOIN = scalarlejoinsel);
CREATE OPERATOR = (LEFTARG = dec128, RIGHTARG = dec128, FUNCTION = dec128_eq,
                   COMMUTATOR = =, NEGATOR = <>,
                   RESTRICT = eqsel, JOIN = eqjoinsel, HASHES, MERGES);
CREATE OPERATOR <> (LEFTARG = dec128, RIGHTARG = dec128, FUNCTION = dec128_ne,
                    COMMUTATOR = <>, NEGATOR = =,
                    RESTRICT = neqsel, JOIN = neqjoinsel);
CREATE OPERATOR >= (LEFTARG = dec128, RIGHTARG = dec128, FUNCTION = dec128_ge,
                    COMMUTATOR = <=, NEGATOR = <,
                    RESTRICT = scalargesel, JOIN = scalargejoinsel);
CREATE OPERATOR > (LEFTARG = dec128, RIGHTARG = dec128, FUNCTION = dec128_gt,
                   COMMUTATOR = <, NEGATOR = <=,
                   RESTRICT = scalargtsel, JOIN = scalargtjoinsel);

CREATE OPERATOR CLASS dec128_ops DEFAULT FOR TYPE dec128 USING btree
    FAMILY dec_ops AS
    OPERATOR 1 <, OPERATOR 2 <=, OPERATOR 3 =, OPERATOR 4 >=, OPERATOR 5 >,
    FUNCTION 1 dec128_cmp(dec128, dec128),
    FUNCTION 2 dec128_sortsupport(internal);

CREATE OPERATOR CLASS dec128_ops DEFAULT FOR TYPE dec128 USING hash AS
    OPERATOR 1 =,
    FUNCTION 1 dec128_hash(dec128),
    FUNCTION 2 dec128_hash_extended(dec128, bigint);

-- Conversions ---------------------------------------------------------------

CREATE FUNCTION numeric_dec128(numeric, integer) RETURNS dec128
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION dec128_numeric(dec128) RETURNS numeric
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION dec64_dec128(dec64) RETURNS dec128
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION dec128_dec64(dec128) RETURNS dec64
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION int2_dec128(smallint) RETURNS dec128
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION int4_dec128(integer) RETURNS dec128
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION int8_dec128(bigint) RETURNS dec128
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION dec128_int2(dec128) RETURNS smallint
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION dec128_int4(dec128) RETURNS integer
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION dec128_int8(dec128) RETURNS bigint
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION float4_dec128(real) RETURNS dec128
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION float8_dec128(double precision) RETURNS dec128
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION dec128_float4(dec128) RETURNS real
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION dec128_float8(dec128) RETURNS double precision
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;

-- dec64 widens into dec128 implicitly: 18 digits fit in 37, scale 7 in 15,
-- so the conversion is always exact.  The reverse is narrowing.
CREATE CAST (dec64 AS dec128) WITH FUNCTION dec64_dec128(dec64) AS IMPLICIT;
CREATE CAST (dec128 AS dec64) WITH FUNCTION dec128_dec64(dec128) AS ASSIGNMENT;

CREATE CAST (smallint AS dec128) WITH FUNCTION int2_dec128(smallint) AS ASSIGNMENT;
CREATE CAST (integer AS dec128) WITH FUNCTION int4_dec128(integer) AS ASSIGNMENT;
CREATE CAST (bigint AS dec128) WITH FUNCTION int8_dec128(bigint) AS ASSIGNMENT;
CREATE CAST (numeric AS dec128) WITH FUNCTION numeric_dec128(numeric, integer) AS ASSIGNMENT;
CREATE CAST (dec128 AS numeric) WITH FUNCTION dec128_numeric(dec128) AS IMPLICIT;
CREATE CAST (dec128 AS smallint) WITH FUNCTION dec128_int2(dec128) AS ASSIGNMENT;
CREATE CAST (dec128 AS integer) WITH FUNCTION dec128_int4(dec128) AS ASSIGNMENT;
CREATE CAST (dec128 AS bigint) WITH FUNCTION dec128_int8(dec128) AS ASSIGNMENT;
CREATE CAST (real AS dec128) WITH FUNCTION float4_dec128(real) AS ASSIGNMENT;
CREATE CAST (double precision AS dec128) WITH FUNCTION float8_dec128(double precision) AS ASSIGNMENT;
CREATE CAST (dec128 AS real) WITH FUNCTION dec128_float4(dec128) AS IMPLICIT;
CREATE CAST (dec128 AS double precision) WITH FUNCTION dec128_float8(dec128) AS IMPLICIT;

-- Mixed dec128/integer arithmetic --------------------------------------------

CREATE FUNCTION dec128_add_int8(dec128, bigint) RETURNS dec128
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION dec128_sub_int8(dec128, bigint) RETURNS dec128
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION dec128_mul_int8(dec128, bigint) RETURNS dec128
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION dec128_div_int8(dec128, bigint) RETURNS dec128
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION int8_add_dec128(bigint, dec128) RETURNS dec128
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION int8_sub_dec128(bigint, dec128) RETURNS dec128
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION int8_mul_dec128(bigint, dec128) RETURNS dec128
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION int8_div_dec128(bigint, dec128) RETURNS dec128
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;

CREATE OPERATOR + (LEFTARG = dec128, RIGHTARG = bigint,
                   FUNCTION = dec128_add_int8, COMMUTATOR = +);
CREATE OPERATOR + (LEFTARG = bigint, RIGHTARG = dec128,
                   FUNCTION = int8_add_dec128, COMMUTATOR = +);
CREATE OPERATOR - (LEFTARG = dec128, RIGHTARG = bigint, FUNCTION = dec128_sub_int8);
CREATE OPERATOR - (LEFTARG = bigint, RIGHTARG = dec128, FUNCTION = int8_sub_dec128);
CREATE OPERATOR * (LEFTARG = dec128, RIGHTARG = bigint,
                   FUNCTION = dec128_mul_int8, COMMUTATOR = *);
CREATE OPERATOR * (LEFTARG = bigint, RIGHTARG = dec128,
                   FUNCTION = int8_mul_dec128, COMMUTATOR = *);
CREATE OPERATOR / (LEFTARG = dec128, RIGHTARG = bigint, FUNCTION = dec128_div_int8);
CREATE OPERATOR / (LEFTARG = bigint, RIGHTARG = dec128, FUNCTION = int8_div_dec128);

-- Cross-type comparison against numeric --------------------------------------

CREATE FUNCTION dec128_numeric_cmp(dec128, numeric) RETURNS integer
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION numeric_dec128_cmp(numeric, dec128) RETURNS integer
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION dec128_numeric_lt(dec128, numeric) RETURNS boolean
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION dec128_numeric_le(dec128, numeric) RETURNS boolean
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION dec128_numeric_eq(dec128, numeric) RETURNS boolean
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION dec128_numeric_ne(dec128, numeric) RETURNS boolean
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION dec128_numeric_ge(dec128, numeric) RETURNS boolean
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION dec128_numeric_gt(dec128, numeric) RETURNS boolean
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION numeric_dec128_lt(numeric, dec128) RETURNS boolean
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION numeric_dec128_le(numeric, dec128) RETURNS boolean
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION numeric_dec128_eq(numeric, dec128) RETURNS boolean
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION numeric_dec128_ne(numeric, dec128) RETURNS boolean
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION numeric_dec128_ge(numeric, dec128) RETURNS boolean
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION numeric_dec128_gt(numeric, dec128) RETURNS boolean
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;

CREATE OPERATOR < (LEFTARG = dec128, RIGHTARG = numeric, FUNCTION = dec128_numeric_lt,
                   COMMUTATOR = >, NEGATOR = >=, RESTRICT = scalarltsel, JOIN = scalarltjoinsel);
CREATE OPERATOR <= (LEFTARG = dec128, RIGHTARG = numeric, FUNCTION = dec128_numeric_le,
                    COMMUTATOR = >=, NEGATOR = >, RESTRICT = scalarlesel, JOIN = scalarlejoinsel);
CREATE OPERATOR = (LEFTARG = dec128, RIGHTARG = numeric, FUNCTION = dec128_numeric_eq,
                   COMMUTATOR = =, NEGATOR = <>, RESTRICT = eqsel, JOIN = eqjoinsel, MERGES);
CREATE OPERATOR <> (LEFTARG = dec128, RIGHTARG = numeric, FUNCTION = dec128_numeric_ne,
                    COMMUTATOR = <>, NEGATOR = =, RESTRICT = neqsel, JOIN = neqjoinsel);
CREATE OPERATOR >= (LEFTARG = dec128, RIGHTARG = numeric, FUNCTION = dec128_numeric_ge,
                    COMMUTATOR = <=, NEGATOR = <, RESTRICT = scalargesel, JOIN = scalargejoinsel);
CREATE OPERATOR > (LEFTARG = dec128, RIGHTARG = numeric, FUNCTION = dec128_numeric_gt,
                   COMMUTATOR = <, NEGATOR = <=, RESTRICT = scalargtsel, JOIN = scalargtjoinsel);

CREATE OPERATOR < (LEFTARG = numeric, RIGHTARG = dec128, FUNCTION = numeric_dec128_lt,
                   COMMUTATOR = >, NEGATOR = >=, RESTRICT = scalarltsel, JOIN = scalarltjoinsel);
CREATE OPERATOR <= (LEFTARG = numeric, RIGHTARG = dec128, FUNCTION = numeric_dec128_le,
                    COMMUTATOR = >=, NEGATOR = >, RESTRICT = scalarlesel, JOIN = scalarlejoinsel);
CREATE OPERATOR = (LEFTARG = numeric, RIGHTARG = dec128, FUNCTION = numeric_dec128_eq,
                   COMMUTATOR = =, NEGATOR = <>, RESTRICT = eqsel, JOIN = eqjoinsel, MERGES);
CREATE OPERATOR <> (LEFTARG = numeric, RIGHTARG = dec128, FUNCTION = numeric_dec128_ne,
                    COMMUTATOR = <>, NEGATOR = =, RESTRICT = neqsel, JOIN = neqjoinsel);
CREATE OPERATOR >= (LEFTARG = numeric, RIGHTARG = dec128, FUNCTION = numeric_dec128_ge,
                    COMMUTATOR = <=, NEGATOR = <, RESTRICT = scalargesel, JOIN = scalargejoinsel);
CREATE OPERATOR > (LEFTARG = numeric, RIGHTARG = dec128, FUNCTION = numeric_dec128_gt,
                   COMMUTATOR = <, NEGATOR = <=, RESTRICT = scalargtsel, JOIN = scalargtjoinsel);

-- Cross-type family members are registered once, at the end of this script.

CREATE FUNCTION dec128_cmp_support(internal) RETURNS internal
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;

ALTER FUNCTION dec128_numeric_lt(dec128, numeric) SUPPORT dec128_cmp_support;
ALTER FUNCTION dec128_numeric_le(dec128, numeric) SUPPORT dec128_cmp_support;
ALTER FUNCTION dec128_numeric_eq(dec128, numeric) SUPPORT dec128_cmp_support;
ALTER FUNCTION dec128_numeric_ne(dec128, numeric) SUPPORT dec128_cmp_support;
ALTER FUNCTION dec128_numeric_ge(dec128, numeric) SUPPORT dec128_cmp_support;
ALTER FUNCTION dec128_numeric_gt(dec128, numeric) SUPPORT dec128_cmp_support;
ALTER FUNCTION numeric_dec128_lt(numeric, dec128) SUPPORT dec128_cmp_support;
ALTER FUNCTION numeric_dec128_le(numeric, dec128) SUPPORT dec128_cmp_support;
ALTER FUNCTION numeric_dec128_eq(numeric, dec128) SUPPORT dec128_cmp_support;
ALTER FUNCTION numeric_dec128_ne(numeric, dec128) SUPPORT dec128_cmp_support;
ALTER FUNCTION numeric_dec128_ge(numeric, dec128) SUPPORT dec128_cmp_support;
ALTER FUNCTION numeric_dec128_gt(numeric, dec128) SUPPORT dec128_cmp_support;

-- Rounding and inspection ----------------------------------------------------

CREATE FUNCTION abs(dec128) RETURNS dec128
    AS 'MODULE_PATHNAME', 'dec128_abs' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION sign(dec128) RETURNS dec128
    AS 'MODULE_PATHNAME', 'dec128_sign' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION round(dec128) RETURNS dec128
    AS 'MODULE_PATHNAME', 'dec128_round' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION round(dec128, integer) RETURNS dec128
    AS 'MODULE_PATHNAME', 'dec128_round_scale' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION trunc(dec128) RETURNS dec128
    AS 'MODULE_PATHNAME', 'dec128_trunc' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION trunc(dec128, integer) RETURNS dec128
    AS 'MODULE_PATHNAME', 'dec128_trunc_scale' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION ceil(dec128) RETURNS dec128
    AS 'MODULE_PATHNAME', 'dec128_ceil' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION ceiling(dec128) RETURNS dec128
    AS 'MODULE_PATHNAME', 'dec128_ceil' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION floor(dec128) RETURNS dec128
    AS 'MODULE_PATHNAME', 'dec128_floor' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION scale(dec128) RETURNS integer
    AS 'MODULE_PATHNAME', 'dec128_scale_fn' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;

-- Aggregates -----------------------------------------------------------------

CREATE FUNCTION dec128_accum(internal, dec128) RETURNS internal
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE PARALLEL SAFE;
CREATE FUNCTION dec128_combine(internal, internal) RETURNS internal
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE PARALLEL SAFE;
CREATE FUNCTION dec128_serialize(internal) RETURNS bytea
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION dec128_deserialize(bytea, internal) RETURNS internal
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION dec128_sum_final(internal) RETURNS numeric
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE PARALLEL SAFE;
CREATE FUNCTION dec128_avg_final(internal) RETURNS numeric
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE PARALLEL SAFE;
CREATE FUNCTION dec128_smaller(dec128, dec128) RETURNS dec128
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION dec128_larger(dec128, dec128) RETURNS dec128
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;

CREATE AGGREGATE sum(dec128) (
    SFUNC = dec128_accum, STYPE = internal, FINALFUNC = dec128_sum_final,
    COMBINEFUNC = dec128_combine, SERIALFUNC = dec128_serialize,
    DESERIALFUNC = dec128_deserialize, PARALLEL = SAFE
);
CREATE AGGREGATE avg(dec128) (
    SFUNC = dec128_accum, STYPE = internal, FINALFUNC = dec128_avg_final,
    COMBINEFUNC = dec128_combine, SERIALFUNC = dec128_serialize,
    DESERIALFUNC = dec128_deserialize, PARALLEL = SAFE
);
CREATE AGGREGATE min(dec128) (
    SFUNC = dec128_smaller, STYPE = dec128, COMBINEFUNC = dec128_smaller,
    SORTOP = <, PARALLEL = SAFE
);
CREATE AGGREGATE max(dec128) (
    SFUNC = dec128_larger, STYPE = dec128, COMBINEFUNC = dec128_larger,
    SORTOP = >, PARALLEL = SAFE
);

-- ===========================================================================
-- Cross-tier comparison, and the one family registration
--
-- Explicit dec64/dec128 operators are not a convenience: without them
-- "a = b" over one column of each tier is ambiguous, because dec128 = dec128,
-- dec64 = numeric and numeric = dec128 all match exactly one argument.  A
-- candidate matching both wins outright.  Core carries a full int2/int4/int8
-- matrix for the same reason.
--
-- They are deliberately NOT marked HASHES: the two tiers pack their bits
-- differently and so hash differently, and a hash join across them must go
-- through the widening cast.  MERGES is safe because both classes sit in one
-- btree family.
-- ===========================================================================

CREATE FUNCTION dec64_dec128_cmp(dec64, dec128) RETURNS integer
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION dec128_dec64_cmp(dec128, dec64) RETURNS integer
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION dec64_dec128_lt(dec64, dec128) RETURNS boolean
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION dec64_dec128_le(dec64, dec128) RETURNS boolean
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION dec64_dec128_eq(dec64, dec128) RETURNS boolean
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION dec64_dec128_ne(dec64, dec128) RETURNS boolean
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION dec64_dec128_ge(dec64, dec128) RETURNS boolean
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION dec64_dec128_gt(dec64, dec128) RETURNS boolean
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION dec128_dec64_lt(dec128, dec64) RETURNS boolean
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION dec128_dec64_le(dec128, dec64) RETURNS boolean
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION dec128_dec64_eq(dec128, dec64) RETURNS boolean
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION dec128_dec64_ne(dec128, dec64) RETURNS boolean
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION dec128_dec64_ge(dec128, dec64) RETURNS boolean
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;
CREATE FUNCTION dec128_dec64_gt(dec128, dec64) RETURNS boolean
    AS 'MODULE_PATHNAME' LANGUAGE C IMMUTABLE STRICT PARALLEL SAFE;

CREATE OPERATOR < (LEFTARG = dec64, RIGHTARG = dec128, FUNCTION = dec64_dec128_lt,
                   COMMUTATOR = >, NEGATOR = >=, RESTRICT = scalarltsel, JOIN = scalarltjoinsel);
CREATE OPERATOR <= (LEFTARG = dec64, RIGHTARG = dec128, FUNCTION = dec64_dec128_le,
                    COMMUTATOR = >=, NEGATOR = >, RESTRICT = scalarlesel, JOIN = scalarlejoinsel);
CREATE OPERATOR = (LEFTARG = dec64, RIGHTARG = dec128, FUNCTION = dec64_dec128_eq,
                   COMMUTATOR = =, NEGATOR = <>, RESTRICT = eqsel, JOIN = eqjoinsel, MERGES);
CREATE OPERATOR <> (LEFTARG = dec64, RIGHTARG = dec128, FUNCTION = dec64_dec128_ne,
                    COMMUTATOR = <>, NEGATOR = =, RESTRICT = neqsel, JOIN = neqjoinsel);
CREATE OPERATOR >= (LEFTARG = dec64, RIGHTARG = dec128, FUNCTION = dec64_dec128_ge,
                    COMMUTATOR = <=, NEGATOR = <, RESTRICT = scalargesel, JOIN = scalargejoinsel);
CREATE OPERATOR > (LEFTARG = dec64, RIGHTARG = dec128, FUNCTION = dec64_dec128_gt,
                   COMMUTATOR = <, NEGATOR = <=, RESTRICT = scalargtsel, JOIN = scalargtjoinsel);

CREATE OPERATOR < (LEFTARG = dec128, RIGHTARG = dec64, FUNCTION = dec128_dec64_lt,
                   COMMUTATOR = >, NEGATOR = >=, RESTRICT = scalarltsel, JOIN = scalarltjoinsel);
CREATE OPERATOR <= (LEFTARG = dec128, RIGHTARG = dec64, FUNCTION = dec128_dec64_le,
                    COMMUTATOR = >=, NEGATOR = >, RESTRICT = scalarlesel, JOIN = scalarlejoinsel);
CREATE OPERATOR = (LEFTARG = dec128, RIGHTARG = dec64, FUNCTION = dec128_dec64_eq,
                   COMMUTATOR = =, NEGATOR = <>, RESTRICT = eqsel, JOIN = eqjoinsel, MERGES);
CREATE OPERATOR <> (LEFTARG = dec128, RIGHTARG = dec64, FUNCTION = dec128_dec64_ne,
                    COMMUTATOR = <>, NEGATOR = =, RESTRICT = neqsel, JOIN = neqjoinsel);
CREATE OPERATOR >= (LEFTARG = dec128, RIGHTARG = dec64, FUNCTION = dec128_dec64_ge,
                    COMMUTATOR = <=, NEGATOR = <, RESTRICT = scalargesel, JOIN = scalargejoinsel);
CREATE OPERATOR > (LEFTARG = dec128, RIGHTARG = dec64, FUNCTION = dec128_dec64_gt,
                   COMMUTATOR = <, NEGATOR = <=, RESTRICT = scalargtsel, JOIN = scalargtjoinsel);

ALTER OPERATOR FAMILY dec_ops USING btree ADD
    OPERATOR 1 < (dec64, numeric),
    OPERATOR 2 <= (dec64, numeric),
    OPERATOR 3 = (dec64, numeric),
    OPERATOR 4 >= (dec64, numeric),
    OPERATOR 5 > (dec64, numeric),
    FUNCTION 1 dec64_numeric_cmp(dec64, numeric),
    OPERATOR 1 < (numeric, dec64),
    OPERATOR 2 <= (numeric, dec64),
    OPERATOR 3 = (numeric, dec64),
    OPERATOR 4 >= (numeric, dec64),
    OPERATOR 5 > (numeric, dec64),
    FUNCTION 1 numeric_dec64_cmp(numeric, dec64),
    OPERATOR 1 < (dec128, numeric),
    OPERATOR 2 <= (dec128, numeric),
    OPERATOR 3 = (dec128, numeric),
    OPERATOR 4 >= (dec128, numeric),
    OPERATOR 5 > (dec128, numeric),
    FUNCTION 1 dec128_numeric_cmp(dec128, numeric),
    OPERATOR 1 < (numeric, dec128),
    OPERATOR 2 <= (numeric, dec128),
    OPERATOR 3 = (numeric, dec128),
    OPERATOR 4 >= (numeric, dec128),
    OPERATOR 5 > (numeric, dec128),
    FUNCTION 1 numeric_dec128_cmp(numeric, dec128),
    OPERATOR 1 < (dec64, dec128),
    OPERATOR 2 <= (dec64, dec128),
    OPERATOR 3 = (dec64, dec128),
    OPERATOR 4 >= (dec64, dec128),
    OPERATOR 5 > (dec64, dec128),
    FUNCTION 1 dec64_dec128_cmp(dec64, dec128),
    OPERATOR 1 < (dec128, dec64),
    OPERATOR 2 <= (dec128, dec64),
    OPERATOR 3 = (dec128, dec64),
    OPERATOR 4 >= (dec128, dec64),
    OPERATOR 5 > (dec128, dec64),
    FUNCTION 1 dec128_dec64_cmp(dec128, dec64),
    FUNCTION 1 (numeric, numeric) numeric_cmp(numeric, numeric);
