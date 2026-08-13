\echo Use "CREATE EXTENSION opcost" to load this file. \quit

CREATE FUNCTION opcost_bench(func regproc,
                             typ regtype,
                             a text,
                             b text,
                             iters bigint DEFAULT 3000000,
                             collation oid DEFAULT NULL,
                             -- present the operands in the one-byte header form a
                             -- tuple would store, which is the form 1C data has
                             short_header boolean DEFAULT true)
RETURNS double precision
AS 'MODULE_PATHNAME', 'opcost_bench'
-- deliberately not STRICT: the collation argument defaults to NULL, and a strict
-- function would return NULL for every call. The C code checks the rest.
LANGUAGE C VOLATILE PARALLEL UNSAFE;

COMMENT ON FUNCTION opcost_bench(regproc, regtype, text, text, bigint, oid, boolean) IS
'nanoseconds per call of the given operator support function on the given pair of
operands, measured with the executor out of the way';

CREATE FUNCTION opcost_overhead(iters bigint DEFAULT 3000000)
RETURNS double precision
AS 'MODULE_PATHNAME', 'opcost_overhead'
LANGUAGE C STRICT VOLATILE PARALLEL UNSAFE;

COMMENT ON FUNCTION opcost_overhead(bigint) IS
'nanoseconds per iteration of the empty loop: the measurement floor';

CREATE FUNCTION opcost_width(typ regtype,
                             a text,
                             short_header boolean DEFAULT true)
RETURNS integer
AS 'MODULE_PATHNAME', 'opcost_width'
LANGUAGE C VOLATILE;

COMMENT ON FUNCTION opcost_width(regtype, text, boolean) IS
'width in bytes of the operand as the benchmark presents it, so a claim about
operand widths can be checked rather than trusted';
