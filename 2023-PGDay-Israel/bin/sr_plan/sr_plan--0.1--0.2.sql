/* contrib/sr_plan/sr_plan--0.1--0.2.sql */

-- complain if script is sourced in psql, rather than via CREATE EXTENSION
\echo Use "ALTERT EXTENSION sr_plan UPDATE TO '0.2'" to load this file. \quit

/*
 *  Extension VIEW to query storage of frozen plans.
 */
DROP VIEW sr_plan_storage;
DROP FUNCTION sr_plan_storage;
CREATE OR REPLACE FUNCTION sr_plan_storage(
	OUT srid			int,
	OUT dbid			oid,
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

--
-- Remove all records in the sr_plan storage for the specified database.
-- Return number of rows removed.
--
CREATE FUNCTION sr_plan_reset(dbid oid) RETURNS bigint
AS 'MODULE_PATHNAME' LANGUAGE C PARALLEL SAFE;
COMMENT ON FUNCTION sr_plan_reset(oid) IS
'Reset all data gathered by sr_plan for the specified database';

/*
 * Return number of usages of each frozen statement across all backends of the
 * instance.
 */
DROP FUNCTION sr_plan_fs_counter;
CREATE FUNCTION sr_plan_fs_counter()
RETURNS TABLE (
  sr_id integer,
  db_id oid,
  counter bigint
)
AS 'MODULE_PATHNAME', 'sr_plan_fs_counter'
LANGUAGE C VOLATILE STRICT;
