/* contrib/sr_plan/sr_plan--0.1.sql */

-- complain if script is sourced in psql, rather than via CREATE EXTENSION
\echo Use "CREATE EXTENSION sr_plan" to load this file. \quit

/*
 *  Extension VIEW to query storage of frozen plans.
 */
CREATE OR REPLACE FUNCTION sr_plan_storage(
	OUT srid			int,
	OUT valid			boolean,
	OUT query_string	text,
	OUT queryId			bigint,
	OUT paramtypes		regtype [],
	OUT query			text,
	OUT plan			text
)
RETURNS setof record
AS 'MODULE_PATHNAME', 'sr_plan_storage'
LANGUAGE C STRICT VOLATILE;

CREATE VIEW sr_plan_storage AS
	SELECT * FROM sr_plan_storage();


/*
 * Register parameterized query in the sr_plan extension.
 * query_string - query text with $<number> as a placeholder for a parameter.
 * regtype - array of types of input parameters. Null is allowed. Postgres
 * will try to deduce type of each not defined parameter.
 *
 * After registering and until freezing, each statement execution will create
 * new generic plan.
 * Returns an unique ID of this registered query.
 */

/* The case for constant queries. */
CREATE FUNCTION sr_register_query(query_string text,
								  OUT sr_id integer,
								  OUT query_id bigint)
RETURNS record
AS 'MODULE_PATHNAME', 'sr_register_query'
LANGUAGE C VOLATILE STRICT PARALLEL UNSAFE;

/* The case for parameterized queries. */
CREATE FUNCTION sr_register_query(query_string text, VARIADIC regtype [],
								  OUT sr_id integer,
								  OUT query_id bigint)
RETURNS record
AS 'MODULE_PATHNAME', 'sr_register_query'
LANGUAGE C VOLATILE STRICT PARALLEL UNSAFE;

/*
 * Show registered query internals. Shows all (even invalid or non-frozen)
 * statements in current backend. For DEBUG purposes.
 */
CREATE FUNCTION sr_show_registered_query(srId integer)
RETURNS TABLE (
  sr_id integer, -- ID of the sr_plan storage entry.
  query_id bigint,
  fs_isfrozen boolean, -- Is sr_plan statement frozen?
  fs_isvalid boolean, -- Frozen statement entry is valid ?
  ps_is_valid boolean, -- Plan source in the memory cache is valid?
  query_string text,
  query_list text, -- serialized representation of parsed and rewritten query tree.
  param_types regtype []
) AS 'MODULE_PATHNAME', 'sr_show_registered_query'
LANGUAGE C VOLATILE STRICT;

/*
 *
 */
CREATE FUNCTION sr_plan_freeze(srId integer)
RETURNS bool
AS 'MODULE_PATHNAME', 'sr_plan_freeze'
LANGUAGE C VOLATILE STRICT PARALLEL UNSAFE;

/*
 * Drop all frozen plans and reload it from a storage.
 */
CREATE FUNCTION sr_reload_frozen_plancache()
RETURNS bool
AS 'MODULE_PATHNAME', 'reload_frozen_plancache'
LANGUAGE C VOLATILE STRICT PARALLEL UNSAFE;

CREATE FUNCTION sr_plan_remove(sr_id int) RETURNS bool
AS 'MODULE_PATHNAME', 'sr_plan_remove'
LANGUAGE C STRICT PARALLEL UNSAFE;

--
-- Remove all records in the sr_plan storage for the current database.
-- Return number of rows removed.
--
CREATE FUNCTION sr_plan_reset() RETURNS bigint
AS 'MODULE_PATHNAME' LANGUAGE C PARALLEL UNSAFE;
COMMENT ON FUNCTION sr_plan_reset() IS
'Reset all data gathered by sr_plan for the current database';

/*
 * Return number of usages of each frozen statement across all backends of the
 * instance.
 */
CREATE FUNCTION sr_plan_fs_counter()
RETURNS TABLE (
  sr_id integer,
  counter bigint
)
AS 'MODULE_PATHNAME', 'sr_plan_fs_counter'
LANGUAGE C VOLATILE STRICT;
