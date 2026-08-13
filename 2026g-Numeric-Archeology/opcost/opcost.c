/*
 * opcost.c — measure the cost of a single operator support function.
 *
 * Everything the planner charges through procost * cpu_operator_cost happens
 * inside one call of the operator's function.  To measure that and nothing else,
 * this bypasses the executor entirely: the operands are built once, then the
 * function is invoked in a tight loop through FunctionCallInvoke, exactly the
 * path the expression interpreter uses.  No tuples are deformed, no relation is
 * touched, so there is no disk and no buffer traffic to confound the numbers.
 *
 *     select opcost_bench('int4eq'::regproc, 'int4'::regtype, '42', '42', 10000000);
 *
 * Returns nanoseconds per call.  Subtract opcost_overhead() for the loop and
 * call-setup floor if you want the function body alone; for setting procost the
 * floor should stay in, because cpu_operator_cost is meant to cover dispatch too.
 */
#include "postgres.h"

#include "fmgr.h"
#include "catalog/pg_collation.h"
#include "portability/instr_time.h"
#include "utils/builtins.h"
#include "utils/lsyscache.h"
#include "utils/memutils.h"
#include "utils/syscache.h"
#include "varatt.h"				/* VARATT_CAN_MAKE_SHORT etc; not in postgres.h since v17 */

PG_MODULE_MAGIC;

/*
 * Some comparison functions allocate (numeric_eq on a short-header input in an
 * unpatched build detoasts, which pallocs).  Well-behaved ones free what they
 * copied, but not all do, and 10^7 iterations leaves no room for optimism.  Run
 * the loop in a scratch context and reset it periodically; the reset is amortised
 * over RESET_EVERY calls and costs a fraction of a nanosecond per iteration.
 */
#define RESET_EVERY 65536

PG_FUNCTION_INFO_V1(opcost_bench);
PG_FUNCTION_INFO_V1(opcost_overhead);
PG_FUNCTION_INFO_V1(opcost_width);

/*
 * A type's input function returns a datum with a four-byte varlena header.  A
 * datum read back out of a tuple does not: heap_fill_tuple converts anything that
 * fits into the one-byte short form, and every numeric and reference in a 1C
 * table is small enough to qualify.
 *
 * That distinction decides which code path a comparison takes -- for a
 * short-header input, PG_GETARG_NUMERIC detoasts, and detoasting a short header
 * means palloc plus memcpy.  Benchmarking the input-function form therefore
 * measures the case the workload never has.  Convert to the stored form, exactly
 * as heap_fill_tuple would.
 */
static Datum
pack_short(Datum d, bool want_short, bool *converted)
{
	struct varlena *v = (struct varlena *) DatumGetPointer(d);
	struct varlena *packed;
	Size		len;

	*converted = false;
	if (!want_short || !VARATT_CAN_MAKE_SHORT(v))
		return d;

	len = VARATT_CONVERTED_SHORT_SIZE(v);
	packed = (struct varlena *) palloc(len);
	SET_VARSIZE_SHORT(packed, len);
	memcpy(VARDATA_SHORT(packed), VARDATA(v), len - VARHDRSZ_SHORT);
	*converted = true;
	return PointerGetDatum(packed);
}

Datum
opcost_bench(PG_FUNCTION_ARGS)
{
	Oid			funcoid = PG_GETARG_OID(0);
	Oid			typoid = PG_GETARG_OID(1);
	char	   *astr = text_to_cstring(PG_GETARG_TEXT_PP(2));
	char	   *bstr = text_to_cstring(PG_GETARG_TEXT_PP(3));
	int64		iters = PG_GETARG_INT64(4);
	Oid			collation = PG_NARGS() > 5 && !PG_ARGISNULL(5)
		? PG_GETARG_OID(5) : DEFAULT_COLLATION_OID;
	bool		want_short = !(PG_NARGS() > 6 && !PG_ARGISNULL(6)) ||
		PG_GETARG_BOOL(6);

	Oid			typinput;
	Oid			typioparam;
	Datum		d1;
	Datum		d2;
	FmgrInfo	flinfo;
	LOCAL_FCINFO(callinfo, 2);
	MemoryContext scratch;
	MemoryContext oldcxt;
	instr_time	start;
	instr_time	stop;
	int64		i;
	volatile int64 sink = 0;

	/*
	 * Not STRICT, because the collation argument defaults to NULL and a strict
	 * function would then return NULL for every call.  So check the arguments
	 * that really are required.
	 */
	if (PG_ARGISNULL(0) || PG_ARGISNULL(1) || PG_ARGISNULL(2) ||
		PG_ARGISNULL(3) || PG_ARGISNULL(4))
		ereport(ERROR,
				(errcode(ERRCODE_NULL_VALUE_NOT_ALLOWED),
				 errmsg("func, typ, a, b and iters must not be null")));

	if (iters <= 0)
		ereport(ERROR,
				(errcode(ERRCODE_INVALID_PARAMETER_VALUE),
				 errmsg("iterations must be positive")));

	/* Build the two operands once, outside the timed region. */
	getTypeInputInfo(typoid, &typinput, &typioparam);
	d1 = OidInputFunctionCall(typinput, astr, typioparam, -1);
	d2 = OidInputFunctionCall(typinput, bstr, typioparam, -1);

	/*
	 * Present the operands the way a tuple would, unless asked not to.  For a
	 * pass-by-value type this is a no-op.
	 */
	if (!get_typbyval(typoid))
	{
		bool		c1;
		bool		c2;

		d1 = pack_short(d1, want_short, &c1);
		d2 = pack_short(d2, want_short, &c2);
		if (want_short && !(c1 && c2))
			elog(NOTICE, "operands not convertible to short header (too wide?), "
				 "measuring the four-byte form");
	}

	fmgr_info(funcoid, &flinfo);
	InitFunctionCallInfoData(*callinfo, &flinfo, 2, collation, NULL, NULL);

	scratch = AllocSetContextCreate(CurrentMemoryContext, "opcost scratch",
									ALLOCSET_SMALL_SIZES);
	oldcxt = MemoryContextSwitchTo(scratch);

	/* Warm the instruction and data caches; the first call is never typical. */
	for (i = 0; i < 1000; i++)
	{
		callinfo->args[0].value = d1;
		callinfo->args[0].isnull = false;
		callinfo->args[1].value = d2;
		callinfo->args[1].isnull = false;
		callinfo->isnull = false;
		sink += (int64) FunctionCallInvoke(callinfo);
	}
	MemoryContextReset(scratch);

	INSTR_TIME_SET_CURRENT(start);
	for (i = 0; i < iters; i++)
	{
		callinfo->args[0].value = d1;
		callinfo->args[0].isnull = false;
		callinfo->args[1].value = d2;
		callinfo->args[1].isnull = false;
		callinfo->isnull = false;
		sink += (int64) FunctionCallInvoke(callinfo);

		if ((i & (RESET_EVERY - 1)) == RESET_EVERY - 1)
			MemoryContextReset(scratch);
	}
	INSTR_TIME_SET_CURRENT(stop);

	MemoryContextSwitchTo(oldcxt);
	MemoryContextDelete(scratch);

	INSTR_TIME_SUBTRACT(stop, start);

	/* keep the compiler from deciding the loop was pointless */
	if (sink == INT64_MIN)
		elog(DEBUG5, "impossible");

	PG_RETURN_FLOAT8(INSTR_TIME_GET_DOUBLE(stop) * 1e9 / (double) iters);
}

/*
 * How wide the operand actually is, in the form being benchmarked.  Reporting
 * this alongside a timing keeps an argument about widths honest: the value the
 * benchmark compares is the value whose size this returns.
 */
Datum
opcost_width(PG_FUNCTION_ARGS)
{
	Oid			typoid = PG_GETARG_OID(0);
	char	   *astr = text_to_cstring(PG_GETARG_TEXT_PP(1));
	bool		want_short = PG_ARGISNULL(2) ? true : PG_GETARG_BOOL(2);
	Oid			typinput;
	Oid			typioparam;
	Datum		d;
	bool		converted;
	int16		typlen;
	bool		typbyval;

	getTypeInputInfo(typoid, &typinput, &typioparam);
	d = OidInputFunctionCall(typinput, astr, typioparam, -1);

	get_typlenbyval(typoid, &typlen, &typbyval);
	if (typlen > 0)
		PG_RETURN_INT32(typlen);

	d = pack_short(d, want_short, &converted);
	PG_RETURN_INT32((int32) VARSIZE_ANY(DatumGetPointer(d)));
}

/*
 * The same loop with no function call: the floor imposed by the loop itself and
 * by the timer, so that a caller can tell how much of a small number is real.
 */
Datum
opcost_overhead(PG_FUNCTION_ARGS)
{
	int64		iters = PG_GETARG_INT64(0);
	instr_time	start;
	instr_time	stop;
	int64		i;
	volatile int64 sink = 0;

	INSTR_TIME_SET_CURRENT(start);
	for (i = 0; i < iters; i++)
		sink += i;
	INSTR_TIME_SET_CURRENT(stop);
	INSTR_TIME_SUBTRACT(stop, start);

	PG_RETURN_FLOAT8(INSTR_TIME_GET_DOUBLE(stop) * 1e9 / (double) iters);
}
