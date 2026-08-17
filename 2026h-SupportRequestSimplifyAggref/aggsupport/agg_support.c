/*-------------------------------------------------------------------------
 *
 * agg_support.c
 *		Planner support function that drops a redundant ORDER BY from a
 *		sum()-like aggregate.
 *
 * Summation over an exact numeric type is order-insensitive, so sorting the
 * input cannot change the result and the sort can be removed.  That is not
 * true of float4/float8, where the summation order is observable, so those
 * are declined.
 *
 * Requires PostgreSQL 19+, where the planner issues
 * SupportRequestSimplifyAggref (commit 42473b3b31) for any aggregate whose
 * pg_proc.prosupport is set.  See agg_support--1.0.sql for the attach/detach
 * helpers that link this function to an aggregate, e.g. pg_catalog.sum().
 *
 *-------------------------------------------------------------------------
 */
#include "postgres.h"

#include "catalog/pg_aggregate.h"
#include "catalog/pg_type.h"
#include "fmgr.h"
#include "nodes/makefuncs.h"
#include "nodes/nodeFuncs.h"
#include "nodes/supportnodes.h"

PG_MODULE_MAGIC;

PG_FUNCTION_INFO_V1(sum_agg_support);

Datum
sum_agg_support(PG_FUNCTION_ARGS)
{
	Node	   *rawreq = (Node *) PG_GETARG_POINTER(0);

	if (IsA(rawreq, SupportRequestSimplifyAggref))
	{
		SupportRequestSimplifyAggref *req;
		Aggref	   *aggref;
		Aggref	   *newagg;
		ListCell   *lc;

		req = (SupportRequestSimplifyAggref *) rawreq;
		aggref = req->aggref;

		/*
		 * Plain aggregates only.  For an ordered-set or hypothetical-set
		 * aggregate the sort clause is what WITHIN GROUP means, and
		 * ordered_set_startup() reads aggorder at execution time, so removing
		 * it would break the aggregate rather than optimize it.
		 *
		 * We are named sum_agg_support for a reason: being attached to such
		 * an aggregate is a configuration error, not a case to handle, so be
		 * loud about it on assert-enabled builds.  Production builds must
		 * not crash in a support function and fail safe by declining.
		 */
		Assert(aggref->aggkind == AGGKIND_NORMAL);
		if (aggref->aggkind != AGGKIND_NORMAL)
			PG_RETURN_POINTER(NULL);

		/* Nothing to remove, and DISTINCT needs the sort anyway */
		if (aggref->aggorder == NIL || aggref->aggdistinct != NIL)
			PG_RETURN_POINTER(NULL);

		/*
		 * sum() takes exactly one argument; anything else means we are
		 * attached to the wrong aggregate — again a configuration error.
		 * The check also makes linitial_oid() below safe, since aggargtypes
		 * is NIL for a star aggregate such as count(*).
		 */
		Assert(list_length(aggref->aggargtypes) == 1);
		if (list_length(aggref->aggargtypes) != 1)
			PG_RETURN_POINTER(NULL);

		/*
		 * Reject inexact types, where the summation order is observable.
		 * aggtranstype is not filled in until preprocess_aggrefs(), which
		 * runs after us, so consult the declared argument type instead.
		 */
		switch (linitial_oid(aggref->aggargtypes))
		{
			case INT2OID:
			case INT4OID:
			case INT8OID:
			case NUMERICOID:
				break;
			default:
				PG_RETURN_POINTER(NULL);
		}

		/*
		 * Punt if any argument is resjunk, ie. it is present only to feed the
		 * ORDER BY, as in sum(x ORDER BY y).  Removing the sort would leave
		 * it unused, and rebuilding the argument list is more than this
		 * example needs.
		 */
		foreach(lc, aggref->args)
		{
			if (((TargetEntry *) lfirst(lc))->resjunk)
				PG_RETURN_POINTER(NULL);
		}

		/*
		 * Note: no check of agglevelsup is needed.  supportnodes.h warns
		 * about Aggrefs with agglevelsup > 0, but dropping a semantically
		 * inert ORDER BY is valid at any aggregation level.
		 */

		/*
		 * The API requires a new node; the original must not be modified.  A
		 * deep copy is wanted here, rather than the makeNode/memcpy shortcut
		 * some in-core support functions use, because we go on to modify the
		 * argument list.
		 */
		newagg = copyObject(aggref);
		newagg->aggorder = NIL;

		/*
		 * The sort-group references on the arguments existed only to be
		 * targets of that ORDER BY.  Left behind, they would make this call
		 * unequal to an identical one written without ORDER BY, and
		 * find_compatible_agg() would then evaluate the same aggregate twice.
		 * Clearing them is safe precisely because aggorder and aggdistinct
		 * are both gone.
		 */
		foreach(lc, newagg->args)
			((TargetEntry *) lfirst(lc))->ressortgroupref = 0;

		PG_RETURN_POINTER(newagg);
	}

	PG_RETURN_POINTER(NULL);
}
