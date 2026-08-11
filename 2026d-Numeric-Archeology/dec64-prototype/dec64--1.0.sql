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

CREATE OPERATOR CLASS dec64_ops DEFAULT FOR TYPE dec64 USING btree AS
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

-- Register the cross-type members so an index on a dec64 column can still be
-- used when the comparison value arrives as numeric.
ALTER OPERATOR FAMILY dec64_ops USING btree ADD
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
    FUNCTION 1 (numeric, numeric) numeric_cmp(numeric, numeric);

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
