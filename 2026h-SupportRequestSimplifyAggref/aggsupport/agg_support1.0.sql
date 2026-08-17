\echo Use "CREATE EXTENSION agg_support" to load this file. \quit

CREATE FUNCTION sum_agg_support(internal) RETURNS internal
    AS 'MODULE_PATHNAME', 'sum_agg_support'
    LANGUAGE C STRICT;

-- A sum() over numeric with the support function attached.  Attaching to the
-- built-in pg_catalog.sum() would record a dependency from a pinned object on
-- this extension, making the extension undroppable, and would not survive
-- pg_upgrade; so demonstrate on an aggregate we own.
CREATE AGGREGATE mysum(numeric)
(
    SFUNC = numeric_add,
    STYPE = numeric,
    SUPPORT = sum_agg_support
);

CREATE AGGREGATE mysum(float8)
(
    SFUNC = float8pl,
    STYPE = float8,
    SUPPORT = sum_agg_support
);
