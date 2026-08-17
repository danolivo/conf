\echo Use "CREATE EXTENSION agg_support" to load this file. \quit

CREATE FUNCTION sum_agg_support(internal) RETURNS internal
    AS 'MODULE_PATHNAME', 'sum_agg_support'
    LANGUAGE C STRICT;

-- Attach the support function to an aggregate, e.g.:
--
--    SELECT agg_support_attach('pg_catalog.sum(numeric)'::regprocedure);
--
-- Stock PostgreSQL has no DDL for this: ALTER FUNCTION ... SUPPORT rejects
-- aggregates, and CREATE/ALTER AGGREGATE have no SUPPORT clause (a patch
-- adding one has been proposed:
-- https://www.postgresql.org/message-id/8f58c96d-d3c7-4c0f-9898-116f00eeaff6@gmail.com).
-- So we write the catalogs directly, mimicking what the DDL would do:
--
--   1. pg_proc.prosupport — makes the planner consult the support function;
--   2. a NORMAL pg_depend entry — forbids dropping the support function from
--      under a still-attached aggregate.  Without it, DROP EXTENSION would
--      leave a dangling prosupport OID behind, and every query using the
--      aggregate would fail to plan with "cache lookup failed".  With it,
--      the same DROP EXTENSION fails up front and the aggregate keeps
--      working; run agg_support_detach() first, then drop the extension.
--
-- Both functions run with the caller's rights: writing pg_proc/pg_depend
-- requires superuser anyway, no extra checks needed.
CREATE FUNCTION agg_support_attach(agg regprocedure) RETURNS void
LANGUAGE plpgsql AS $$
DECLARE
    supfn CONSTANT regproc := '@extschema@.sum_agg_support';
BEGIN
    IF (SELECT prokind FROM pg_catalog.pg_proc WHERE oid = agg) <> 'a' THEN
        RAISE EXCEPTION '% is not an aggregate', agg;
    END IF;
    IF (SELECT prosupport FROM pg_catalog.pg_proc WHERE oid = agg) <> 0 THEN
        RAISE EXCEPTION '% already has a support function', agg;
    END IF;

    UPDATE pg_catalog.pg_proc SET prosupport = supfn WHERE oid = agg;
    INSERT INTO pg_catalog.pg_depend
           (classid, objid, objsubid, refclassid, refobjid, refobjsubid, deptype)
    VALUES ('pg_catalog.pg_proc'::regclass, agg, 0,
            'pg_catalog.pg_proc'::regclass, supfn, 0, 'n');
END
$$;

CREATE FUNCTION agg_support_detach(agg regprocedure) RETURNS void
LANGUAGE plpgsql AS $$
DECLARE
    supfn CONSTANT regproc := '@extschema@.sum_agg_support';
BEGIN
    UPDATE pg_catalog.pg_proc SET prosupport = 0
     WHERE oid = agg AND prosupport = supfn;
    IF NOT FOUND THEN
        RAISE EXCEPTION '% is not attached to %', agg, supfn;
    END IF;

    DELETE FROM pg_catalog.pg_depend
     WHERE classid = 'pg_catalog.pg_proc'::regclass AND objid = agg
       AND objsubid = 0
       AND refclassid = 'pg_catalog.pg_proc'::regclass AND refobjid = supfn
       AND refobjsubid = 0 AND deptype = 'n';
END
$$;
