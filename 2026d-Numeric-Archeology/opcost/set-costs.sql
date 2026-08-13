-- ===========================================================================
-- Set procost for comparison operators to their measured cost, relative to
-- int4eq = 1.  Measurements and method: RESULTS.md.
--
--     psql -d erp_v -f set-costs.sql        -- one database at a time
--
-- Requires superuser: these are system catalog functions.
--
-- Read before running:
--
--  * The change is per-database. Apply it to every database you plan a query in;
--    a new database created from template0 will not have it.
--  * pg_dump does not dump property changes to system objects, so this has to be
--    re-applied after a restore. That is why it is a script and not a migration.
--  * It changes plans, which is the point. Expect different qual ordering (the
--    planner orders conjuncts by cost, stably, so equal costs preserve the order
--    the client sent), different hash-vs-sort aggregation choices, and different
--    index-vs-seqscan crossovers. Measure before and after; do not assume.
--  * Values are for the *patched* numeric build. For upstream numeric code, use
--    the "A" column of RESULTS.md: numeric_eq 15, numeric_lt 15, numeric_cmp 15,
--    hash_numeric 10.
--
-- To undo everything: see the reset block at the end.
-- ===========================================================================

\set ON_ERROR_STOP on

-- --- numeric: 5-byte median value ----------------------------------------
-- Equality is 3.5 when the values match and 12.5 when they do not. A filter
-- mostly does not match, so charge the pessimistic figure; hash aggregation,
-- where equality mostly succeeds, will be overcharged a little.
ALTER FUNCTION pg_catalog.numeric_eq(numeric, numeric)  COST 12;
ALTER FUNCTION pg_catalog.numeric_ne(numeric, numeric)  COST 12;
ALTER FUNCTION pg_catalog.numeric_lt(numeric, numeric)  COST 11;
ALTER FUNCTION pg_catalog.numeric_le(numeric, numeric)  COST 11;
ALTER FUNCTION pg_catalog.numeric_gt(numeric, numeric)  COST 11;
ALTER FUNCTION pg_catalog.numeric_ge(numeric, numeric)  COST 11;
ALTER FUNCTION pg_catalog.numeric_cmp(numeric, numeric) COST 11;
ALTER FUNCTION pg_catalog.hash_numeric(numeric)         COST 8;

-- --- bytea: 17-byte reference --------------------------------------------
ALTER FUNCTION pg_catalog.byteaeq(bytea, bytea)  COST 6;
ALTER FUNCTION pg_catalog.byteane(bytea, bytea)  COST 6;
ALTER FUNCTION pg_catalog.bytealt(bytea, bytea)  COST 4;
ALTER FUNCTION pg_catalog.byteale(bytea, bytea)  COST 4;
ALTER FUNCTION pg_catalog.byteagt(bytea, bytea)  COST 4;
ALTER FUNCTION pg_catalog.byteage(bytea, bytea)  COST 4;
ALTER FUNCTION pg_catalog.byteacmp(bytea, bytea) COST 5;
ALTER FUNCTION pg_catalog.hashbytea(bytea)       COST 6;

-- --- timestamp and the hash functions of the cheap types -----------------
-- timestamp comparison really is as cheap as int4; only its hash is not.
ALTER FUNCTION pg_catalog.timestamp_hash(timestamp without time zone) COST 2;
ALTER FUNCTION pg_catalog.hashint4(integer)                           COST 2;

-- --- mvarchar and mchar: the case-insensitive operators 1C actually uses --
-- These are the 1C contrib types; adjust the schema if they are not in public.
DO $$
DECLARE
  fn text;
  cost int;
BEGIN
  FOR fn, cost IN
    SELECT * FROM (VALUES
      ('mvarchar_icase_eq(mvarchar, mvarchar)',  54),
      ('mvarchar_icase_ne(mvarchar, mvarchar)',  54),
      ('mvarchar_icase_lt(mvarchar, mvarchar)',  55),
      ('mvarchar_icase_le(mvarchar, mvarchar)',  55),
      ('mvarchar_icase_gt(mvarchar, mvarchar)',  55),
      ('mvarchar_icase_ge(mvarchar, mvarchar)',  55),
      ('mvarchar_icase_cmp(mvarchar, mvarchar)', 55),
      ('mvarchar_hash(mvarchar)',               142),
      ('mchar_icase_eq(mchar, mchar)',           42),
      ('mchar_icase_ne(mchar, mchar)',           42),
      ('mchar_icase_lt(mchar, mchar)',           43),
      ('mchar_icase_le(mchar, mchar)',           43),
      ('mchar_icase_gt(mchar, mchar)',           43),
      ('mchar_icase_ge(mchar, mchar)',           43),
      ('mchar_icase_cmp(mchar, mchar)',          44),
      ('mchar_hash(mchar)',                     157)
    ) AS t(fn, cost)
  LOOP
    BEGIN
      EXECUTE format('ALTER FUNCTION %s COST %s', fn, cost);
    EXCEPTION WHEN undefined_function THEN
      RAISE NOTICE 'skipped %, not present in this database', fn;
    END;
  END LOOP;
END $$;

-- --- verify ---------------------------------------------------------------
SELECT p.proname,
       pg_get_function_arguments(p.oid) AS args,
       p.procost
FROM pg_proc p
WHERE p.proname IN ('numeric_eq','numeric_lt','numeric_cmp','hash_numeric',
                    'byteaeq','bytealt','byteacmp','hashbytea',
                    'int4eq','timestamp_eq','timestamp_hash','hashint4',
                    'mvarchar_icase_eq','mvarchar_icase_cmp','mvarchar_hash',
                    'mchar_icase_eq','mchar_icase_cmp','mchar_hash')
ORDER BY p.procost DESC, p.proname;

-- ===========================================================================
-- Undo:
--
-- ALTER FUNCTION pg_catalog.numeric_eq(numeric, numeric) COST 1;
-- ... and so on for every function above; every one of them was 1 before.
--
-- Or, to reset everything this script could have touched:
--
--   DO $$
--   DECLARE r record;
--   BEGIN
--     FOR r IN SELECT oid::regprocedure AS f FROM pg_proc
--              WHERE proname IN ('numeric_eq','numeric_ne','numeric_lt','numeric_le',
--                   'numeric_gt','numeric_ge','numeric_cmp','hash_numeric',
--                   'byteaeq','byteane','bytealt','byteale','byteagt','byteage',
--                   'byteacmp','hashbytea','timestamp_hash','hashint4',
--                   'mvarchar_icase_eq','mvarchar_icase_ne','mvarchar_icase_lt',
--                   'mvarchar_icase_le','mvarchar_icase_gt','mvarchar_icase_ge',
--                   'mvarchar_icase_cmp','mvarchar_hash','mchar_icase_eq',
--                   'mchar_icase_ne','mchar_icase_lt','mchar_icase_le',
--                   'mchar_icase_gt','mchar_icase_ge','mchar_icase_cmp','mchar_hash')
--     LOOP EXECUTE format('ALTER FUNCTION %s COST 1', r.f); END LOOP;
--   END $$;
-- ===========================================================================
