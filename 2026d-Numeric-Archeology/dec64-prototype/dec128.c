/*-------------------------------------------------------------------------
 *
 * dec128.c
 *		Wide tier of the fixed-point decimal family: 37 digits in 16 bytes.
 *
 * This is DuckDB's INT128 decimal tier, adapted to what PostgreSQL allows.
 * The differences from dec64 are all consequences of the width:
 *
 *	- 16 bytes cannot fit in a Datum, so the type is pass-by-reference and
 *	  every result costs a palloc.  That is the structural reason this tier
 *	  is several times slower than dec64, and it cannot be engineered away;
 *	  DuckDB pays the same tax in a different currency, where INT128 columns
 *	  scan roughly a hundred times slower than INT64 ones.
 *
 *	- the value is kept as two int64 halves rather than a bare __int128
 *	  field, because a datum is only 8-byte aligned and dereferencing a
 *	  misaligned __int128 is undefined behaviour.
 *
 *	- division cannot borrow a wider intermediate the way dec64 borrows
 *	  __int128, so it uses long division digit by digit (see
 *	  dec128_scaled_div).
 *
 * Scale occupies four bits, giving 0..15.  That is one bit more than dec64
 * spends and it is what makes the tier useful: the widest normative money
 * format, N(26.11) from the Russian FTS e-invoice schema, needs 11 decimal
 * places.  A wide tier capped at 7 decimals would not hold the only format
 * that requires a wide tier at all.
 *
 *-------------------------------------------------------------------------
 */
#include "postgres.h"

#include <ctype.h>
#include <math.h>

#include "catalog/namespace.h"
#include "catalog/pg_type.h"
#include "common/hashfn.h"
#include "fmgr.h"
#include "libpq/pqformat.h"
#include "nodes/makefuncs.h"
#include "nodes/miscnodes.h"
#include "nodes/nodeFuncs.h"
#include "nodes/supportnodes.h"
#include "utils/array.h"
#include "utils/builtins.h"
#include "utils/fmgrprotos.h"
#include "utils/lsyscache.h"
#include "utils/numeric.h"
#include "utils/sortsupport.h"

#include "dec_common.h"

/* typmod layout: (precision << 8) | scale, offset by VARHDRSZ as numeric does */
#define DEC128_TYPMOD_IS_VALID(t)	((t) >= (int32) VARHDRSZ)
#define DEC128_TYPMOD_PRECISION(t)	((((t) - VARHDRSZ) >> 8) & 0xffff)
#define DEC128_TYPMOD_SCALE(t)		(((t) - VARHDRSZ) & 0xff)
#define DEC128_MAKE_TYPMOD(p, s)	((((p) << 8) | (s)) + VARHDRSZ)

/* longest external text: sign, 37 digits, point, terminator */
#define DEC128_MAX_TEXT				(DEC128_MAX_PRECISION + 4)

/* 10^0 .. 10^37 */
static const __int128 dec128_pow10[DEC128_MAX_PRECISION + 1] = {
	1, 10, 100, 1000, 10000, 100000, 1000000, 10000000, 100000000,
	1000000000, 10000000000, 100000000000, 1000000000000,
	10000000000000, 100000000000000, 1000000000000000,
	10000000000000000, 100000000000000000, DEC_P18,
	DEC_P18 * 10, DEC_P18 * 100, DEC_P18 * 1000, DEC_P18 * 10000,
	DEC_P18 * 100000, DEC_P18 * 1000000, DEC_P18 * 10000000,
	DEC_P18 * 100000000, DEC_P18 * 1000000000, DEC_P18 * 10000000000,
	DEC_P18 * 100000000000, DEC_P18 * 1000000000000,
	DEC_P18 * 10000000000000, DEC_P18 * 100000000000000,
	DEC_P18 * 1000000000000000, DEC_P18 * 10000000000000000,
	DEC_P18 * 100000000000000000, DEC_P18 * DEC_P18,
	DEC_P18 * DEC_P18 * 10
};


/*
 * Report a value that does not fit the type.
 */
static pg_noinline void
dec128_out_of_range(void)
{
	ereport(ERROR,
			(errcode(ERRCODE_NUMERIC_VALUE_OUT_OF_RANGE),
			 errmsg("value out of range for type dec128"),
			 errdetail("dec128 holds at most %d significant digits.",
					   DEC128_MAX_PRECISION)));
}

/*
 * Report a required scale the encoding cannot represent.
 */
static pg_noinline void
dec128_scale_unsupported(int scale)
{
	ereport(ERROR,
			(errcode(ERRCODE_NUMERIC_VALUE_OUT_OF_RANGE),
			 errmsg("scale %d is out of range for type dec128", scale),
			 errdetail("dec128 supports at most %d fractional digits.",
					   DEC128_MAX_SCALE),
			 errhint("Round an operand to a smaller scale, or cast to numeric.")));
}

/*
 * Allocate a value from mantissa and scale, rejecting an out-of-range
 * mantissa.  Every result costs one palloc; that is the price of the width.
 */
static inline Dec128 *
dec128_pack(__int128 mant, int scale)
{
	Dec128	   *res;

	Assert(scale >= 0 && scale <= DEC128_MAX_SCALE);

	if (unlikely(mant > DEC128_MAX_MANT || mant < -DEC128_MAX_MANT))
		dec128_out_of_range();

	res = (Dec128 *) palloc(sizeof(Dec128));
	dec128_store(res, mant, scale);

	return res;
}

/*
 * Multiply by 10^n, reporting overflow rather than wrapping.
 */
static inline bool
dec128_try_scale_up(__int128 mant, int n, __int128 *result)
{
	Assert(n >= 0);

	if (unlikely(n > DEC128_MAX_PRECISION))
		return false;

	return !__builtin_mul_overflow(mant, dec128_pow10[n], result);
}

/*
 * Divide by 10^n, rounding half away from zero -- the commercial rule that
 * EC Regulation 1103/97 art. 5 and HMRC require, and the one numeric uses.
 */
static inline __int128
dec128_div_round(__int128 value, int n)
{
	__int128	div;
	__int128	half;

	Assert(n >= 0 && n <= DEC128_MAX_PRECISION);

	if (n == 0)
		return value;

	div = dec128_pow10[n];
	half = div / 2;

	return (value >= 0) ? (value + half) / div : (value - half) / div;
}

/*
 * Restate a value at a different scale, rounding half away from zero when the
 * new scale is smaller.
 */
static __int128
dec128_rescale_mant(__int128 mant, int scale, int newscale)
{
	__int128	res;

	if (newscale < 0 || newscale > DEC128_MAX_SCALE)
		dec128_scale_unsupported(newscale);

	if (newscale == scale)
		return mant;

	if (newscale > scale)
	{
		if (!dec128_try_scale_up(mant, newscale - scale, &res))
			dec128_out_of_range();
		return res;
	}

	return dec128_div_round(mant, scale - newscale);
}

/*
 * Bring two values to a common scale for addition-like operations.  Overflow
 * here is genuine: the exact result would need more digits than the type has.
 */
static inline int
dec128_align(const Dec128 *a, const Dec128 *b, __int128 *ma, __int128 *mb)
{
	int			sa = dec128_scale(a);
	int			sb = dec128_scale(b);

	*ma = dec128_mant(a);
	*mb = dec128_mant(b);

	if (likely(sa == sb))
		return sa;

	if (sa < sb)
	{
		if (unlikely(!dec128_try_scale_up(*ma, sb - sa, ma)))
			dec128_out_of_range();
		return sb;
	}

	if (unlikely(!dec128_try_scale_up(*mb, sa - sb, mb)))
		dec128_out_of_range();
	return sa;
}

/*
 * Compare two values.
 *
 * Unlike dec128_align(), comparison must never fail, and there is no wider
 * intermediate to widen into.  So instead of scaling one side up, the side
 * with the smaller scale is scaled with overflow detection, and if that
 * overflows the answer follows from the sign alone: a value that outgrows the
 * type when brought to the other's scale is larger in magnitude than anything
 * the other side can hold.
 */
static int
dec128_compare(const Dec128 *a, const Dec128 *b)
{
	int			sa = dec128_scale(a);
	int			sb = dec128_scale(b);
	__int128	ma = dec128_mant(a);
	__int128	mb = dec128_mant(b);
	__int128	scaled;

	if (likely(sa == sb))
		return (ma > mb) ? 1 : ((ma < mb) ? -1 : 0);

	if (sa < sb)
	{
		if (unlikely(!dec128_try_scale_up(ma, sb - sa, &scaled)))
			return (ma > 0) ? 1 : -1;
		ma = scaled;
	}
	else
	{
		if (unlikely(!dec128_try_scale_up(mb, sa - sb, &scaled)))
			return (mb > 0) ? -1 : 1;
		mb = scaled;
	}

	return (ma > mb) ? 1 : ((ma < mb) ? -1 : 0);
}

/*
 * Count significant digits, for typmod precision checks.
 */
static int
dec128_digits(__int128 mant)
{
	unsigned __int128 u = (mant < 0) ? -(unsigned __int128) mant
		: (unsigned __int128) mant;
	int			i;

	for (i = 0; i < DEC128_MAX_PRECISION; i++)
	{
		if (u < (unsigned __int128) dec128_pow10[i + 1])
			return i + 1;
	}
	return DEC128_MAX_PRECISION + 1;
}

/*
 * Apply a typmod constraint: restate to the declared scale, then verify the
 * integer part fits in (precision - scale) digits.
 */
static Dec128 *
dec128_apply_typmod(__int128 mant, int scale, int32 typmod)
{
	int			precision;
	int			target;

	if (!DEC128_TYPMOD_IS_VALID(typmod))
		return dec128_pack(mant, scale);

	precision = DEC128_TYPMOD_PRECISION(typmod);
	target = DEC128_TYPMOD_SCALE(typmod);

	Assert(precision >= 1 && precision <= DEC128_MAX_PRECISION);
	Assert(target >= 0 && target <= precision);

	mant = dec128_rescale_mant(mant, scale, target);

	if (mant != 0 && dec128_digits(mant) > precision)
		ereport(ERROR,
				(errcode(ERRCODE_NUMERIC_VALUE_OUT_OF_RANGE),
				 errmsg("dec128 field overflow"),
				 errdetail("A field with precision %d, scale %d must round to an absolute value less than 10^%d.",
						   precision, target, precision - target)));

	return dec128_pack(mant, target);
}

/*
 * Render a mantissa and scale into a decimal string, returning the start of
 * the text within the caller's buffer.  Trailing zeros implied by the scale
 * are preserved, matching numeric's dscale behaviour.
 */
static char *
dec128_format(__int128 mant, int scale, char *buf, size_t buflen)
{
	char	   *cur = buf + buflen;
	bool		neg = (mant < 0);
	unsigned __int128 u = neg ? -(unsigned __int128) mant
		: (unsigned __int128) mant;
	int			i;

	Assert(buflen >= DEC128_MAX_TEXT);

	*(--cur) = '\0';

	for (i = 0; i < scale; i++)
	{
		*(--cur) = (char) ('0' + (int) (u % 10));
		u /= 10;
	}
	if (scale > 0)
		*(--cur) = '.';

	if (u == 0)
		*(--cur) = '0';
	else
	{
		while (u > 0)
		{
			*(--cur) = (char) ('0' + (int) (u % 10));
			u /= 10;
		}
	}
	if (neg)
		*(--cur) = '-';

	Assert(cur >= buf);

	return cur;
}

/*
 * Build the numeric equivalent.  Goes through the decimal text form: there is
 * no int128 counterpart to int64_div_fast_to_numeric() in core, and this path
 * is used per group or at plan time rather than per row -- the per-row case
 * is removed by the planner support function below.
 */
static Numeric
dec128_to_numeric(__int128 mant, int scale)
{
	char		buf[DEC128_MAX_TEXT];
	char	   *str = dec128_format(mant, scale, buf, sizeof(buf));

	return DatumGetNumeric(DirectFunctionCall3(numeric_in,
											   CStringGetDatum(str),
											   ObjectIdGetDatum(InvalidOid),
											   Int32GetDatum(-1)));
}


/* ----------------------------------------------------------------
 *						Input and output
 * ----------------------------------------------------------------
 */

PG_FUNCTION_INFO_V1(dec128_in);
PG_FUNCTION_INFO_V1(dec128_out);
PG_FUNCTION_INFO_V1(dec128_recv);
PG_FUNCTION_INFO_V1(dec128_send);
PG_FUNCTION_INFO_V1(dec128typmodin);
PG_FUNCTION_INFO_V1(dec128typmodout);
PG_FUNCTION_INFO_V1(dec128_scale_typmod);

/*
 * Parse the external text form: optional sign, digits, optional fraction.
 * No exponent notation, no NaN and no infinity -- as in DuckDB's DECIMAL.
 */
Datum
dec128_in(PG_FUNCTION_ARGS)
{
	char	   *str = PG_GETARG_CSTRING(0);
	int32		typmod = PG_GETARG_INT32(2);
	const char *p = str;
	__int128	mant = 0;
	int			scale = 0;
	int			digits = 0;
	bool		neg = false;
	bool		seen_digit = false;
	bool		in_frac = false;

	while (isspace((unsigned char) *p))
		p++;

	if (*p == '-')
	{
		neg = true;
		p++;
	}
	else if (*p == '+')
		p++;

	for (; *p != '\0'; p++)
	{
		if (*p == '.')
		{
			if (in_frac)
				goto bad_syntax;
			in_frac = true;
			continue;
		}
		if (!isdigit((unsigned char) *p))
			break;

		seen_digit = true;

		/* leading zeros do not consume the digit budget */
		if (mant != 0 || *p != '0')
		{
			if (unlikely(++digits > DEC128_MAX_PRECISION))
				dec128_out_of_range();
		}

		mant = mant * 10 + (*p - '0');

		if (in_frac && ++scale > DEC128_MAX_SCALE)
			dec128_scale_unsupported(scale);
	}

	while (isspace((unsigned char) *p))
		p++;

	if (*p != '\0' || !seen_digit)
		goto bad_syntax;

	PG_RETURN_DEC128_P(dec128_apply_typmod(neg ? -mant : mant, scale, typmod));

bad_syntax:
	ereport(ERROR,
			(errcode(ERRCODE_INVALID_TEXT_REPRESENTATION),
			 errmsg("invalid input syntax for type dec128: \"%s\"", str)));
	PG_RETURN_NULL();			/* unreachable */
}

/*
 * Render the value, keeping trailing zeros implied by the scale.
 */
Datum
dec128_out(PG_FUNCTION_ARGS)
{
	Dec128	   *v = PG_GETARG_DEC128_P(0);
	char		buf[DEC128_MAX_TEXT];
	char	   *str = dec128_format(dec128_mant(v), dec128_scale(v),
								    buf, sizeof(buf));

	PG_RETURN_CSTRING(pstrdup(str));
}

/*
 * Binary input: mantissa as two int64 halves, then the scale, so the wire
 * form does not depend on how the bits are packed internally.
 */
Datum
dec128_recv(PG_FUNCTION_ARGS)
{
	StringInfo	buf = (StringInfo) PG_GETARG_POINTER(0);
	int32		typmod = PG_GETARG_INT32(2);
	int64		hi = pq_getmsgint64(buf);
	uint64		lo = (uint64) pq_getmsgint64(buf);
	int			scale = (int) pq_getmsgint(buf, 2);
	__int128	mant = ((__int128) hi << 64) | (__int128) lo;

	if (scale < 0 || scale > DEC128_MAX_SCALE)
		ereport(ERROR,
				(errcode(ERRCODE_INVALID_BINARY_REPRESENTATION),
				 errmsg("invalid scale %d in external dec128 value", scale)));

	PG_RETURN_DEC128_P(dec128_apply_typmod(mant, scale, typmod));
}

/*
 * Binary output, matching dec128_recv().
 */
Datum
dec128_send(PG_FUNCTION_ARGS)
{
	Dec128	   *v = PG_GETARG_DEC128_P(0);
	__int128	mant = dec128_mant(v);
	StringInfoData buf;

	pq_begintypsend(&buf);
	pq_sendint64(&buf, (int64) (mant >> 64));
	pq_sendint64(&buf, (int64) (uint64) mant);
	pq_sendint16(&buf, (int16) dec128_scale(v));

	PG_RETURN_BYTEA_P(pq_endtypsend(&buf));
}

/*
 * Parse dec128(precision) or dec128(precision, scale).
 */
Datum
dec128typmodin(PG_FUNCTION_ARGS)
{
	ArrayType  *ta = PG_GETARG_ARRAYTYPE_P(0);
	int32	   *tl;
	int			n;
	int32		precision;
	int32		scale;

	tl = ArrayGetIntegerTypmods(ta, &n);

	if (n != 1 && n != 2)
		ereport(ERROR,
				(errcode(ERRCODE_INVALID_PARAMETER_VALUE),
				 errmsg("invalid type modifier for dec128")));

	precision = tl[0];
	scale = (n == 2) ? tl[1] : 0;

	if (precision < 1 || precision > DEC128_MAX_PRECISION)
		ereport(ERROR,
				(errcode(ERRCODE_INVALID_PARAMETER_VALUE),
				 errmsg("dec128 precision %d must be between 1 and %d",
						precision, DEC128_MAX_PRECISION)));
	if (scale < 0 || scale > DEC128_MAX_SCALE)
		ereport(ERROR,
				(errcode(ERRCODE_INVALID_PARAMETER_VALUE),
				 errmsg("dec128 scale %d must be between 0 and %d",
						scale, DEC128_MAX_SCALE)));
	if (scale > precision)
		ereport(ERROR,
				(errcode(ERRCODE_INVALID_PARAMETER_VALUE),
				 errmsg("dec128 scale %d must not exceed precision %d",
						scale, precision)));

	PG_RETURN_INT32(DEC128_MAKE_TYPMOD(precision, scale));
}

/*
 * Render a typmod back as "(precision,scale)".
 */
Datum
dec128typmodout(PG_FUNCTION_ARGS)
{
	int32		typmod = PG_GETARG_INT32(0);
	char	   *res = (char *) palloc(32);

	if (DEC128_TYPMOD_IS_VALID(typmod))
		snprintf(res, 32, "(%d,%d)",
				 DEC128_TYPMOD_PRECISION(typmod), DEC128_TYPMOD_SCALE(typmod));
	else
		*res = '\0';

	PG_RETURN_CSTRING(res);
}

/*
 * Length coercion, invoked when a value is stored into dec128(p,s).
 */
Datum
dec128_scale_typmod(PG_FUNCTION_ARGS)
{
	Dec128	   *v = PG_GETARG_DEC128_P(0);
	int32		typmod = PG_GETARG_INT32(1);

	PG_RETURN_DEC128_P(dec128_apply_typmod(dec128_mant(v), dec128_scale(v),
										   typmod));
}


/* ----------------------------------------------------------------
 *						Arithmetic
 * ----------------------------------------------------------------
 */

PG_FUNCTION_INFO_V1(dec128_add);
PG_FUNCTION_INFO_V1(dec128_sub);
PG_FUNCTION_INFO_V1(dec128_mul);
PG_FUNCTION_INFO_V1(dec128_div);
PG_FUNCTION_INFO_V1(dec128_mod);
PG_FUNCTION_INFO_V1(dec128_uminus);
PG_FUNCTION_INFO_V1(dec128_uplus);
PG_FUNCTION_INFO_V1(dec128_abs);
PG_FUNCTION_INFO_V1(dec128_sign);

/*
 * dec128 + dec128.  Result scale is max(s1,s2); the result is not widened on
 * overflow, an error is raised instead.
 */
Datum
dec128_add(PG_FUNCTION_ARGS)
{
	Dec128	   *a = PG_GETARG_DEC128_P(0);
	Dec128	   *b = PG_GETARG_DEC128_P(1);
	__int128	ma,
				mb,
				r;
	int			scale = dec128_align(a, b, &ma, &mb);

	if (unlikely(__builtin_add_overflow(ma, mb, &r)))
		dec128_out_of_range();

	PG_RETURN_DEC128_P(dec128_pack(r, scale));
}

/*
 * dec128 - dec128.
 */
Datum
dec128_sub(PG_FUNCTION_ARGS)
{
	Dec128	   *a = PG_GETARG_DEC128_P(0);
	Dec128	   *b = PG_GETARG_DEC128_P(1);
	__int128	ma,
				mb,
				r;
	int			scale = dec128_align(a, b, &ma, &mb);

	if (unlikely(__builtin_sub_overflow(ma, mb, &r)))
		dec128_out_of_range();

	PG_RETURN_DEC128_P(dec128_pack(r, scale));
}

/*
 * dec128 * dec128.  Result scale is s1+s2 as the standard requires; a scale
 * beyond the encoding raises an error rather than rounding silently, which is
 * what DuckDB does at its own scale ceiling.
 */
Datum
dec128_mul(PG_FUNCTION_ARGS)
{
	Dec128	   *a = PG_GETARG_DEC128_P(0);
	Dec128	   *b = PG_GETARG_DEC128_P(1);
	int			scale = dec128_scale(a) + dec128_scale(b);
	__int128	prod;

	if (unlikely(scale > DEC128_MAX_SCALE))
		dec128_scale_unsupported(scale);

	if (unlikely(__builtin_mul_overflow(dec128_mant(a), dec128_mant(b), &prod)))
		dec128_out_of_range();

	PG_RETURN_DEC128_P(dec128_pack(prod, scale));
}

/*
 * Compute round(|a| * 10^shift / |b|) by long division, half away from zero.
 *
 * dec64 can form the shifted numerator in a wider type and divide once; here
 * there is no wider type, so the shift is applied one digit at a time to the
 * running remainder, which stays below the divisor and therefore never
 * overflows.  At most 2 * DEC128_MAX_SCALE iterations run.
 */
static unsigned __int128
dec128_scaled_div(unsigned __int128 a, unsigned __int128 b, int shift)
{
	unsigned __int128 num;
	unsigned __int128 q;
	unsigned __int128 r;
	int			i;

	Assert(b > 0);
	Assert(shift >= 0 && shift <= 2 * DEC128_MAX_SCALE);

	/*
	 * Fast path: if the shifted numerator still fits, one division does the
	 * whole job.  Money-sized mantissas are nowhere near 10^37, so this is
	 * what almost every real division takes; the digit-at-a-time loop below
	 * exists for operands that genuinely fill the type.  Without this the
	 * loop runs up to thirty 128-bit divisions per row, which is slower than
	 * numeric rather than faster.
	 */
	if (likely(!__builtin_mul_overflow(a, (unsigned __int128) dec128_pow10[shift],
									   &num)))
	{
		q = num / b;
		r = num % b;

		if (r * 2 >= b)
		{
			if (unlikely(__builtin_add_overflow(q, (unsigned __int128) 1, &q)))
				dec128_out_of_range();
		}
		return q;
	}

	q = a / b;
	r = a % b;

	for (i = 0; i < shift; i++)
	{
		if (unlikely(__builtin_mul_overflow(q, (unsigned __int128) 10, &q)))
			dec128_out_of_range();

		/* r < b <= 10^37, so r * 10 stays inside the unsigned range */
		r *= 10;
		q += r / b;
		r %= b;
	}

	/* round half away from zero; r * 2 cannot overflow since r < b */
	if (r * 2 >= b)
	{
		if (unlikely(__builtin_add_overflow(q, (unsigned __int128) 1, &q)))
			dec128_out_of_range();
	}

	return q;
}

/*
 * dec128 / dec128.  Unlike DuckDB, which returns DOUBLE from any division
 * involving a decimal, the result stays exact-typed at the widest scale the
 * encoding offers.  The scale depends only on the type, never on the data.
 */
Datum
dec128_div(PG_FUNCTION_ARGS)
{
	Dec128	   *a = PG_GETARG_DEC128_P(0);
	Dec128	   *b = PG_GETARG_DEC128_P(1);
	__int128	ma = dec128_mant(a);
	__int128	mb = dec128_mant(b);
	bool		neg = ((ma < 0) != (mb < 0));
	unsigned __int128 ua;
	unsigned __int128 ub;
	unsigned __int128 q;
	int			shift;

	if (unlikely(mb == 0))
		ereport(ERROR,
				(errcode(ERRCODE_DIVISION_BY_ZERO),
				 errmsg("division by zero")));

	ua = (ma < 0) ? -(unsigned __int128) ma : (unsigned __int128) ma;
	ub = (mb < 0) ? -(unsigned __int128) mb : (unsigned __int128) mb;

	shift = dec128_scale(b) + DEC128_MAX_SCALE - dec128_scale(a);
	Assert(shift >= 0 && shift <= 2 * DEC128_MAX_SCALE);

	q = dec128_scaled_div(ua, ub, shift);

	if (unlikely(q > (unsigned __int128) DEC128_MAX_MANT))
		dec128_out_of_range();

	PG_RETURN_DEC128_P(dec128_pack(neg ? -(__int128) q : (__int128) q,
								   DEC128_MAX_SCALE));
}

/*
 * dec128 % dec128, truncated toward zero as numeric's mod() is.
 */
Datum
dec128_mod(PG_FUNCTION_ARGS)
{
	Dec128	   *a = PG_GETARG_DEC128_P(0);
	Dec128	   *b = PG_GETARG_DEC128_P(1);
	__int128	ma,
				mb;
	int			scale = dec128_align(a, b, &ma, &mb);

	if (unlikely(mb == 0))
		ereport(ERROR,
				(errcode(ERRCODE_DIVISION_BY_ZERO),
				 errmsg("division by zero")));

	PG_RETURN_DEC128_P(dec128_pack(ma % mb, scale));
}

/*
 * Unary minus.  Cannot overflow: the mantissa range is symmetric.
 */
Datum
dec128_uminus(PG_FUNCTION_ARGS)
{
	Dec128	   *v = PG_GETARG_DEC128_P(0);

	PG_RETURN_DEC128_P(dec128_pack(-dec128_mant(v), dec128_scale(v)));
}

/*
 * Unary plus, so that "+x" parses.
 */
Datum
dec128_uplus(PG_FUNCTION_ARGS)
{
	PG_RETURN_DEC128_P(PG_GETARG_DEC128_P(0));
}

/*
 * Absolute value.
 */
Datum
dec128_abs(PG_FUNCTION_ARGS)
{
	Dec128	   *v = PG_GETARG_DEC128_P(0);
	__int128	mant = dec128_mant(v);

	PG_RETURN_DEC128_P(dec128_pack(mant < 0 ? -mant : mant, dec128_scale(v)));
}

/*
 * Sign: -1, 0 or 1 at scale 0.
 */
Datum
dec128_sign(PG_FUNCTION_ARGS)
{
	Dec128	   *v = PG_GETARG_DEC128_P(0);
	__int128	mant = dec128_mant(v);

	PG_RETURN_DEC128_P(dec128_pack(mant > 0 ? 1 : (mant < 0 ? -1 : 0), 0));
}


/* ----------------------------------------------------------------
 *				Comparison, hashing, sorting
 * ----------------------------------------------------------------
 */

PG_FUNCTION_INFO_V1(dec128_cmp);
PG_FUNCTION_INFO_V1(dec128_lt);
PG_FUNCTION_INFO_V1(dec128_le);
PG_FUNCTION_INFO_V1(dec128_eq);
PG_FUNCTION_INFO_V1(dec128_ne);
PG_FUNCTION_INFO_V1(dec128_ge);
PG_FUNCTION_INFO_V1(dec128_gt);
PG_FUNCTION_INFO_V1(dec128_hash);
PG_FUNCTION_INFO_V1(dec128_hash_extended);
PG_FUNCTION_INFO_V1(dec128_sortsupport);
PG_FUNCTION_INFO_V1(dec128_smaller);
PG_FUNCTION_INFO_V1(dec128_larger);

/*
 * Three-way comparison, the btree opclass support function.
 */
Datum
dec128_cmp(PG_FUNCTION_ARGS)
{
	PG_RETURN_INT32(dec128_compare(PG_GETARG_DEC128_P(0),
								   PG_GETARG_DEC128_P(1)));
}

#define DEC128_CMP_OP(fname, op) \
Datum \
fname(PG_FUNCTION_ARGS) \
{ \
	PG_RETURN_BOOL(dec128_compare(PG_GETARG_DEC128_P(0), \
								  PG_GETARG_DEC128_P(1)) op 0); \
}

DEC128_CMP_OP(dec128_lt, <)
DEC128_CMP_OP(dec128_le, <=)
DEC128_CMP_OP(dec128_eq, ==)
DEC128_CMP_OP(dec128_ne, !=)
DEC128_CMP_OP(dec128_ge, >=)
DEC128_CMP_OP(dec128_gt, >)

/*
 * Reduce to canonical form by dropping fractional trailing zeros, so that
 * equal values hash alike: 1.5 equals 1.50 and must hash the same.
 */
static void
dec128_canonical(const Dec128 *v, Dec128 *out)
{
	__int128	mant = dec128_mant(v);
	int			scale = dec128_scale(v);

	if (mant == 0)
	{
		dec128_store(out, 0, 0);
		return;
	}

	while (scale > 0 && (mant % 10) == 0)
	{
		mant /= 10;
		scale--;
	}

	dec128_store(out, mant, scale);
}

/*
 * Hash of the canonical form.
 */
Datum
dec128_hash(PG_FUNCTION_ARGS)
{
	Dec128		c;

	dec128_canonical(PG_GETARG_DEC128_P(0), &c);

	return hash_any((unsigned char *) &c, sizeof(Dec128));
}

/*
 * Extended hash, for hash partitioning.
 */
Datum
dec128_hash_extended(PG_FUNCTION_ARGS)
{
	uint64		seed = PG_GETARG_INT64(1);
	Dec128		c;

	dec128_canonical(PG_GETARG_DEC128_P(0), &c);

	return hash_any_extended((unsigned char *) &c, sizeof(Dec128), seed);
}

/*
 * Fast path comparator for tuplesort.
 */
static int
dec128_fast_cmp(Datum x, Datum y, SortSupport ssup)
{
	return dec128_compare(DatumGetDec128P(x), DatumGetDec128P(y));
}

/*
 * SortSupport entry point.
 */
Datum
dec128_sortsupport(PG_FUNCTION_ARGS)
{
	SortSupport ssup = (SortSupport) PG_GETARG_POINTER(0);

	ssup->comparator = dec128_fast_cmp;
	PG_RETURN_VOID();
}

/*
 * Transition function for min().
 */
Datum
dec128_smaller(PG_FUNCTION_ARGS)
{
	Dec128	   *a = PG_GETARG_DEC128_P(0);
	Dec128	   *b = PG_GETARG_DEC128_P(1);

	PG_RETURN_DEC128_P(dec128_compare(a, b) < 0 ? a : b);
}

/*
 * Transition function for max().
 */
Datum
dec128_larger(PG_FUNCTION_ARGS)
{
	Dec128	   *a = PG_GETARG_DEC128_P(0);
	Dec128	   *b = PG_GETARG_DEC128_P(1);

	PG_RETURN_DEC128_P(dec128_compare(a, b) > 0 ? a : b);
}


/* ----------------------------------------------------------------
 *						Conversions
 * ----------------------------------------------------------------
 */

PG_FUNCTION_INFO_V1(numeric_dec128);
PG_FUNCTION_INFO_V1(dec128_numeric);
PG_FUNCTION_INFO_V1(dec64_dec128);
PG_FUNCTION_INFO_V1(dec128_dec64);
PG_FUNCTION_INFO_V1(int2_dec128);
PG_FUNCTION_INFO_V1(int4_dec128);
PG_FUNCTION_INFO_V1(int8_dec128);
PG_FUNCTION_INFO_V1(dec128_int2);
PG_FUNCTION_INFO_V1(dec128_int4);
PG_FUNCTION_INFO_V1(dec128_int8);
PG_FUNCTION_INFO_V1(float4_dec128);
PG_FUNCTION_INFO_V1(float8_dec128);
PG_FUNCTION_INFO_V1(dec128_float4);
PG_FUNCTION_INFO_V1(dec128_float8);
PG_FUNCTION_INFO_V1(dec128_add_int8);
PG_FUNCTION_INFO_V1(dec128_sub_int8);
PG_FUNCTION_INFO_V1(dec128_mul_int8);
PG_FUNCTION_INFO_V1(dec128_div_int8);
PG_FUNCTION_INFO_V1(int8_add_dec128);
PG_FUNCTION_INFO_V1(int8_sub_dec128);
PG_FUNCTION_INFO_V1(int8_mul_dec128);
PG_FUNCTION_INFO_V1(int8_div_dec128);

/*
 * numeric -> dec128.  Two-argument cast function so that it receives the
 * target typmod and rounds once, straight to the declared scale, instead of
 * rounding to 15 places and then again to the column's scale.
 */
Datum
numeric_dec128(PG_FUNCTION_ARGS)
{
	Numeric		n = PG_GETARG_NUMERIC(0);
	int32		typmod = PG_GETARG_INT32(1);
	Datum		nd = NumericGetDatum(n);
	int			target;
	char	   *str;
	Datum		res;

	if (numeric_is_nan(n) || numeric_is_inf(n))
		ereport(ERROR,
				(errcode(ERRCODE_INVALID_PARAMETER_VALUE),
				 errmsg("cannot convert NaN or Infinity to dec128")));

	target = DEC128_TYPMOD_IS_VALID(typmod) ? DEC128_TYPMOD_SCALE(typmod)
		: DEC128_MAX_SCALE;
	Assert(target >= 0 && target <= DEC128_MAX_SCALE);

	if (DatumGetInt32(DirectFunctionCall1(numeric_scale, nd)) > target)
		nd = DirectFunctionCall2(numeric_round, nd, Int32GetDatum(target));

	str = DatumGetCString(DirectFunctionCall1(numeric_out, nd));
	res = DirectFunctionCall3(dec128_in, CStringGetDatum(str),
							  ObjectIdGetDatum(InvalidOid),
							  Int32GetDatum(typmod));
	pfree(str);

	PG_RETURN_DATUM(res);
}

/*
 * dec128 -> numeric.
 */
Datum
dec128_numeric(PG_FUNCTION_ARGS)
{
	Dec128	   *v = PG_GETARG_DEC128_P(0);

	PG_RETURN_NUMERIC(dec128_to_numeric(dec128_mant(v), dec128_scale(v)));
}

/*
 * dec64 -> dec128.  Always exact: 18 digits fit in 37, scale 7 fits in 15.
 */
Datum
dec64_dec128(PG_FUNCTION_ARGS)
{
	Dec64		v = PG_GETARG_DEC64(0);

	PG_RETURN_DEC128_P(dec128_pack((__int128) DEC64_MANT(v), DEC64_SCALE(v)));
}

/*
 * dec128 -> dec64.  Narrowing: rounds the scale down when needed and rejects
 * a mantissa that does not fit.
 */
Datum
dec128_dec64(PG_FUNCTION_ARGS)
{
	Dec128	   *v = PG_GETARG_DEC128_P(0);
	int			scale = dec128_scale(v);
	__int128	mant = dec128_mant(v);

	if (scale > DEC64_MAX_SCALE)
	{
		mant = dec128_div_round(mant, scale - DEC64_MAX_SCALE);
		scale = DEC64_MAX_SCALE;
	}

	if (mant > (__int128) DEC64_MAX_MANT || mant < -(__int128) DEC64_MAX_MANT)
		ereport(ERROR,
				(errcode(ERRCODE_NUMERIC_VALUE_OUT_OF_RANGE),
				 errmsg("value out of range for type dec64"),
				 errdetail("dec64 holds at most %d significant digits.",
						   DEC64_MAX_PRECISION)));

	PG_RETURN_DEC64(DEC64_MAKE((int64) mant, scale));
}

/*
 * smallint -> dec128.
 */
Datum
int2_dec128(PG_FUNCTION_ARGS)
{
	PG_RETURN_DEC128_P(dec128_pack((__int128) PG_GETARG_INT16(0), 0));
}

/*
 * integer -> dec128.
 */
Datum
int4_dec128(PG_FUNCTION_ARGS)
{
	PG_RETURN_DEC128_P(dec128_pack((__int128) PG_GETARG_INT32(0), 0));
}

/*
 * bigint -> dec128.  Always exact: 19 digits fit in 37.
 */
Datum
int8_dec128(PG_FUNCTION_ARGS)
{
	PG_RETURN_DEC128_P(dec128_pack((__int128) PG_GETARG_INT64(0), 0));
}

/*
 * Round to an integral int64, half away from zero, as numeric's integer casts
 * do.  Raises an error if the result does not fit.
 */
static int64
dec128_to_int64(const Dec128 *v)
{
	__int128	r = dec128_div_round(dec128_mant(v), dec128_scale(v));

	if (r > (__int128) PG_INT64_MAX || r < (__int128) PG_INT64_MIN)
		ereport(ERROR,
				(errcode(ERRCODE_NUMERIC_VALUE_OUT_OF_RANGE),
				 errmsg("bigint out of range")));

	return (int64) r;
}

/*
 * dec128 -> smallint.
 */
Datum
dec128_int2(PG_FUNCTION_ARGS)
{
	int64		r = dec128_to_int64(PG_GETARG_DEC128_P(0));

	if (unlikely(r < PG_INT16_MIN || r > PG_INT16_MAX))
		ereport(ERROR,
				(errcode(ERRCODE_NUMERIC_VALUE_OUT_OF_RANGE),
				 errmsg("smallint out of range")));

	PG_RETURN_INT16((int16) r);
}

/*
 * dec128 -> integer.
 */
Datum
dec128_int4(PG_FUNCTION_ARGS)
{
	int64		r = dec128_to_int64(PG_GETARG_DEC128_P(0));

	if (unlikely(r < PG_INT32_MIN || r > PG_INT32_MAX))
		ereport(ERROR,
				(errcode(ERRCODE_NUMERIC_VALUE_OUT_OF_RANGE),
				 errmsg("integer out of range")));

	PG_RETURN_INT32((int32) r);
}

/*
 * dec128 -> bigint.
 */
Datum
dec128_int8(PG_FUNCTION_ARGS)
{
	PG_RETURN_INT64(dec128_to_int64(PG_GETARG_DEC128_P(0)));
}

/*
 * Convert a double through its shortest round-trip decimal form, so the
 * result matches what the float prints as rather than its binary expansion.
 */
static Dec128 *
dec128_from_float8(float8 f)
{
	char	   *str;
	Datum		res;

	if (isnan(f) || isinf(f))
		ereport(ERROR,
				(errcode(ERRCODE_INVALID_PARAMETER_VALUE),
				 errmsg("cannot convert NaN or Infinity to dec128")));

	str = DatumGetCString(DirectFunctionCall1(float8out, Float8GetDatum(f)));
	res = DirectFunctionCall3(numeric_in, CStringGetDatum(str),
							  ObjectIdGetDatum(InvalidOid), Int32GetDatum(-1));
	pfree(str);

	if (DatumGetInt32(DirectFunctionCall1(numeric_scale, res)) >
		DEC128_MAX_SCALE)
		res = DirectFunctionCall2(numeric_round, res,
								  Int32GetDatum(DEC128_MAX_SCALE));

	str = DatumGetCString(DirectFunctionCall1(numeric_out, res));
	res = DirectFunctionCall3(dec128_in, CStringGetDatum(str),
							  ObjectIdGetDatum(InvalidOid), Int32GetDatum(-1));
	pfree(str);

	return DatumGetDec128P(res);
}

/*
 * real -> dec128.
 */
Datum
float4_dec128(PG_FUNCTION_ARGS)
{
	PG_RETURN_DEC128_P(dec128_from_float8((float8) PG_GETARG_FLOAT4(0)));
}

/*
 * double precision -> dec128.
 */
Datum
float8_dec128(PG_FUNCTION_ARGS)
{
	PG_RETURN_DEC128_P(dec128_from_float8(PG_GETARG_FLOAT8(0)));
}

/*
 * dec128 -> real.
 */
Datum
dec128_float4(PG_FUNCTION_ARGS)
{
	Dec128	   *v = PG_GETARG_DEC128_P(0);

	PG_RETURN_FLOAT4((float4) ((float8) (double) dec128_mant(v) /
							   (float8) (double) dec128_pow10[dec128_scale(v)]));
}

/*
 * dec128 -> double precision.
 */
Datum
dec128_float8(PG_FUNCTION_ARGS)
{
	Dec128	   *v = PG_GETARG_DEC128_P(0);

	PG_RETURN_FLOAT8((float8) (double) dec128_mant(v) /
					 (float8) (double) dec128_pow10[dec128_scale(v)]);
}

/*
 * Mixed dec128/bigint arithmetic, so that "amount * 2" keeps its type.  Only
 * the bigint width is declared; smallint and integer reach it through core's
 * implicit widening casts.
 */
#define DEC128_INT8_OP(fname, impl) \
Datum \
fname(PG_FUNCTION_ARGS) \
{ \
	Dec128	   *n = dec128_pack((__int128) PG_GETARG_INT64(1), 0); \
	return DirectFunctionCall2(impl, PG_GETARG_DATUM(0), Dec128PGetDatum(n)); \
}

DEC128_INT8_OP(dec128_add_int8, dec128_add)
DEC128_INT8_OP(dec128_sub_int8, dec128_sub)
DEC128_INT8_OP(dec128_mul_int8, dec128_mul)
DEC128_INT8_OP(dec128_div_int8, dec128_div)

#define INT8_DEC128_OP(fname, impl) \
Datum \
fname(PG_FUNCTION_ARGS) \
{ \
	Dec128	   *n = dec128_pack((__int128) PG_GETARG_INT64(0), 0); \
	return DirectFunctionCall2(impl, Dec128PGetDatum(n), PG_GETARG_DATUM(1)); \
}

INT8_DEC128_OP(int8_add_dec128, dec128_add)
INT8_DEC128_OP(int8_sub_dec128, dec128_sub)
INT8_DEC128_OP(int8_mul_dec128, dec128_mul)
INT8_DEC128_OP(int8_div_dec128, dec128_div)


/* ----------------------------------------------------------------
 *				Cross-type comparison against numeric
 * ----------------------------------------------------------------
 */

PG_FUNCTION_INFO_V1(dec128_numeric_cmp);
PG_FUNCTION_INFO_V1(numeric_dec128_cmp);
PG_FUNCTION_INFO_V1(dec128_cmp_support);

/*
 * Compare a dec128 against a numeric by promoting the dec128 side.
 */
static inline int
dec128_cmp_numeric(const Dec128 *a, Numeric b)
{
	Numeric		an = dec128_to_numeric(dec128_mant(a), dec128_scale(a));

	return DatumGetInt32(DirectFunctionCall2(numeric_cmp,
											 NumericGetDatum(an),
											 NumericGetDatum(b)));
}

/*
 * Three-way comparison, dec128 on the left.
 */
Datum
dec128_numeric_cmp(PG_FUNCTION_ARGS)
{
	PG_RETURN_INT32(dec128_cmp_numeric(PG_GETARG_DEC128_P(0),
									   PG_GETARG_NUMERIC(1)));
}

/*
 * Three-way comparison, numeric on the left.
 */
Datum
numeric_dec128_cmp(PG_FUNCTION_ARGS)
{
	PG_RETURN_INT32(-dec128_cmp_numeric(PG_GETARG_DEC128_P(1),
										PG_GETARG_NUMERIC(0)));
}

#define DEC128_NUM_CMP_OP(fname, op) \
PG_FUNCTION_INFO_V1(fname); \
Datum \
fname(PG_FUNCTION_ARGS) \
{ \
	PG_RETURN_BOOL(dec128_cmp_numeric(PG_GETARG_DEC128_P(0), \
									  PG_GETARG_NUMERIC(1)) op 0); \
}

DEC128_NUM_CMP_OP(dec128_numeric_lt, <)
DEC128_NUM_CMP_OP(dec128_numeric_le, <=)
DEC128_NUM_CMP_OP(dec128_numeric_eq, ==)
DEC128_NUM_CMP_OP(dec128_numeric_ne, !=)
DEC128_NUM_CMP_OP(dec128_numeric_ge, >=)
DEC128_NUM_CMP_OP(dec128_numeric_gt, >)

#define NUM_DEC128_CMP_OP(fname, op) \
PG_FUNCTION_INFO_V1(fname); \
Datum \
fname(PG_FUNCTION_ARGS) \
{ \
	PG_RETURN_BOOL(-dec128_cmp_numeric(PG_GETARG_DEC128_P(1), \
									   PG_GETARG_NUMERIC(0)) op 0); \
}

NUM_DEC128_CMP_OP(numeric_dec128_lt, <)
NUM_DEC128_CMP_OP(numeric_dec128_le, <=)
NUM_DEC128_CMP_OP(numeric_dec128_eq, ==)
NUM_DEC128_CMP_OP(numeric_dec128_ne, !=)
NUM_DEC128_CMP_OP(numeric_dec128_ge, >=)
NUM_DEC128_CMP_OP(numeric_dec128_gt, >)

/*
 * Convert a numeric to dec128 without raising an error, reporting whether the
 * value is representable exactly.  Parses the decimal text rather than doing
 * numeric arithmetic: it runs at plan time, and the text form already tells
 * us both the digit count and the scale.
 */
static bool
dec128_try_from_numeric(Numeric n, Dec128 *result)
{
	char	   *str;
	const char *p;
	__int128	mant = 0;
	int			scale = 0;
	int			digits = 0;
	bool		neg = false;
	bool		in_frac = false;

	if (numeric_is_nan(n) || numeric_is_inf(n))
		return false;

	str = DatumGetCString(DirectFunctionCall1(numeric_out,
											  NumericGetDatum(n)));
	p = str;

	if (*p == '-')
	{
		neg = true;
		p++;
	}

	for (; *p != '\0'; p++)
	{
		if (*p == '.')
		{
			if (in_frac)
				return false;
			in_frac = true;
			continue;
		}
		if (!isdigit((unsigned char) *p))
			return false;		/* exponent notation, or anything unexpected */

		if (mant != 0 || *p != '0')
		{
			if (++digits > DEC128_MAX_PRECISION)
				return false;
		}
		mant = mant * 10 + (*p - '0');

		if (in_frac && ++scale > DEC128_MAX_SCALE)
			return false;
	}

	pfree(str);

	dec128_store(result, neg ? -mant : mant, scale);
	return true;
}

/*
 * Map a cross-type comparison function name onto its operator symbol.
 */
static const char *
dec128_cmp_operator_name(const char *funcname)
{
	size_t		len = strlen(funcname);
	const char *suffix;

	if (len < 3)
		return NULL;
	suffix = funcname + len - 3;

	if (strcmp(suffix, "_lt") == 0)
		return "<";
	if (strcmp(suffix, "_le") == 0)
		return "<=";
	if (strcmp(suffix, "_eq") == 0)
		return "=";
	if (strcmp(suffix, "_ne") == 0)
		return "<>";
	if (strcmp(suffix, "_ge") == 0)
		return ">=";
	if (strcmp(suffix, "_gt") == 0)
		return ">";

	return NULL;
}

/*
 * Planner support for the mixed dec128/numeric comparison operators: fold a
 * representable numeric literal into a dec128 constant so the per-row work is
 * a 128-bit compare rather than building a Numeric.  This is the same
 * specialisation DuckDB performs when it binds an operator.
 */
Datum
dec128_cmp_support(PG_FUNCTION_ARGS)
{
	Node	   *rawreq = (Node *) PG_GETARG_POINTER(0);
	Node	   *ret = NULL;

	if (IsA(rawreq, SupportRequestSimplify))
	{
		SupportRequestSimplify *req = (SupportRequestSimplify *) rawreq;
		FuncExpr   *expr = req->fcall;
		Node	   *larg;
		Node	   *rarg;
		Node	   *numarg;
		Const	   *numconst;
		Oid			dectype;
		Oid			opno;
		Dec128	   *converted;
		char	   *funcname;
		const char *opname;
		char	   *nspname;
		Const	   *newconst;

		if (list_length(expr->args) != 2)
			PG_RETURN_POINTER(NULL);

		larg = (Node *) linitial(expr->args);
		rarg = (Node *) lsecond(expr->args);

		if (exprType(rarg) == NUMERICOID)
		{
			numarg = rarg;
			dectype = exprType(larg);
		}
		else
		{
			numarg = larg;
			dectype = exprType(rarg);
		}

		if (!IsA(numarg, Const))
			PG_RETURN_POINTER(NULL);
		numconst = (Const *) numarg;
		if (numconst->constisnull)
			PG_RETURN_POINTER(NULL);

		converted = (Dec128 *) palloc(sizeof(Dec128));
		if (!dec128_try_from_numeric(DatumGetNumeric(numconst->constvalue),
									 converted))
			PG_RETURN_POINTER(NULL);

		funcname = get_func_name(expr->funcid);
		if (funcname == NULL)
			PG_RETURN_POINTER(NULL);
		opname = dec128_cmp_operator_name(funcname);
		if (opname == NULL)
			PG_RETURN_POINTER(NULL);

		nspname = get_namespace_name(get_func_namespace(expr->funcid));
		if (nspname == NULL)
			PG_RETURN_POINTER(NULL);

		opno = OpernameGetOprid(list_make2(makeString(nspname),
										   makeString(pstrdup(opname))),
								dectype, dectype);
		if (!OidIsValid(opno))
			PG_RETURN_POINTER(NULL);

		newconst = makeConst(dectype, -1, InvalidOid, sizeof(Dec128),
							 Dec128PGetDatum(converted), false, false);

		if (numarg == rarg)
			ret = (Node *) make_opclause(opno, BOOLOID, false,
										 (Expr *) larg, (Expr *) newconst,
										 InvalidOid, InvalidOid);
		else
			ret = (Node *) make_opclause(opno, BOOLOID, false,
										 (Expr *) newconst, (Expr *) rarg,
										 InvalidOid, InvalidOid);
	}

	PG_RETURN_POINTER(ret);
}


/* ----------------------------------------------------------------
 *				Rounding and inspection
 * ----------------------------------------------------------------
 */

PG_FUNCTION_INFO_V1(dec128_round);
PG_FUNCTION_INFO_V1(dec128_round_scale);
PG_FUNCTION_INFO_V1(dec128_trunc);
PG_FUNCTION_INFO_V1(dec128_trunc_scale);
PG_FUNCTION_INFO_V1(dec128_ceil);
PG_FUNCTION_INFO_V1(dec128_floor);
PG_FUNCTION_INFO_V1(dec128_scale_fn);

/*
 * Truncate toward zero at the given scale.
 */
static Dec128 *
dec128_truncate_to(const Dec128 *v, int newscale)
{
	int			scale = dec128_scale(v);
	__int128	mant = dec128_mant(v);

	if (newscale < 0 || newscale > DEC128_MAX_SCALE)
		dec128_scale_unsupported(newscale);

	if (newscale >= scale)
		return dec128_pack(dec128_rescale_mant(mant, scale, newscale),
						   newscale);

	return dec128_pack(mant / dec128_pow10[scale - newscale], newscale);
}

/*
 * round(dec128): to zero decimal places, half away from zero.
 */
Datum
dec128_round(PG_FUNCTION_ARGS)
{
	Dec128	   *v = PG_GETARG_DEC128_P(0);

	PG_RETURN_DEC128_P(dec128_pack(dec128_rescale_mant(dec128_mant(v),
													   dec128_scale(v), 0), 0));
}

/*
 * round(dec128, int): to the given scale, half away from zero.
 */
Datum
dec128_round_scale(PG_FUNCTION_ARGS)
{
	Dec128	   *v = PG_GETARG_DEC128_P(0);
	int			newscale = PG_GETARG_INT32(1);

	if (newscale < 0 || newscale > DEC128_MAX_SCALE)
		dec128_scale_unsupported(newscale);

	PG_RETURN_DEC128_P(dec128_pack(dec128_rescale_mant(dec128_mant(v),
													   dec128_scale(v),
													   newscale), newscale));
}

/*
 * trunc(dec128): drop the fractional part.
 */
Datum
dec128_trunc(PG_FUNCTION_ARGS)
{
	PG_RETURN_DEC128_P(dec128_truncate_to(PG_GETARG_DEC128_P(0), 0));
}

/*
 * trunc(dec128, int): truncate toward zero at the given scale.
 */
Datum
dec128_trunc_scale(PG_FUNCTION_ARGS)
{
	PG_RETURN_DEC128_P(dec128_truncate_to(PG_GETARG_DEC128_P(0),
										  PG_GETARG_INT32(1)));
}

/*
 * ceil(dec128): smallest integral value not less than the argument.
 */
Datum
dec128_ceil(PG_FUNCTION_ARGS)
{
	Dec128	   *v = PG_GETARG_DEC128_P(0);
	int			scale = dec128_scale(v);
	__int128	mant = dec128_mant(v);
	__int128	q;

	if (scale == 0)
		PG_RETURN_DEC128_P(v);

	q = mant / dec128_pow10[scale];
	if (mant > 0 && (mant % dec128_pow10[scale]) != 0)
		q++;

	PG_RETURN_DEC128_P(dec128_pack(q, 0));
}

/*
 * floor(dec128): largest integral value not greater than the argument.
 */
Datum
dec128_floor(PG_FUNCTION_ARGS)
{
	Dec128	   *v = PG_GETARG_DEC128_P(0);
	int			scale = dec128_scale(v);
	__int128	mant = dec128_mant(v);
	__int128	q;

	if (scale == 0)
		PG_RETURN_DEC128_P(v);

	q = mant / dec128_pow10[scale];
	if (mant < 0 && (mant % dec128_pow10[scale]) != 0)
		q--;

	PG_RETURN_DEC128_P(dec128_pack(q, 0));
}

/*
 * scale(dec128): the number of fractional digits the value carries.
 */
Datum
dec128_scale_fn(PG_FUNCTION_ARGS)
{
	PG_RETURN_INT32(dec128_scale(PG_GETARG_DEC128_P(0)));
}


/* ----------------------------------------------------------------
 *						Aggregates
 * ----------------------------------------------------------------
 *
 * A dec128 value already fills 123 bits, so a 128-bit accumulator overflows
 * after a handful of extreme rows.  The state therefore carries a fast
 * 128-bit running total plus a numeric "carry": when the next addition would
 * overflow, the running total is flushed into the carry and reset.  For
 * realistic data the flush never happens and the per-row cost is a 128-bit
 * add; for adversarial data the result is still exact and unbounded.
 */

PG_FUNCTION_INFO_V1(dec128_accum);
PG_FUNCTION_INFO_V1(dec128_combine);
PG_FUNCTION_INFO_V1(dec128_serialize);
PG_FUNCTION_INFO_V1(dec128_deserialize);
PG_FUNCTION_INFO_V1(dec128_sum_final);
PG_FUNCTION_INFO_V1(dec128_avg_final);

typedef struct Dec128AggState
{
	__int128	sum;			/* fast running total, at "scale" */
	Numeric		carry;			/* exact overflow spill, NULL until needed */
	int64		count;			/* non-null rows accumulated */
	int			scale;			/* scale the running total is held at */
	bool		seen;			/* has any row been accumulated? */
} Dec128AggState;

/*
 * Fetch the aggregate state, creating it in the aggregate context on the
 * first call.
 */
static Dec128AggState *
dec128_agg_state(FunctionCallInfo fcinfo, int argno)
{
	Dec128AggState *state;
	MemoryContext aggctx;
	MemoryContext oldctx;

	if (!AggCheckCallContext(fcinfo, &aggctx))
		elog(ERROR, "aggregate function called in non-aggregate context");

	if (!PG_ARGISNULL(argno))
		return (Dec128AggState *) PG_GETARG_POINTER(argno);

	oldctx = MemoryContextSwitchTo(aggctx);
	state = (Dec128AggState *) palloc0(sizeof(Dec128AggState));
	MemoryContextSwitchTo(oldctx);

	return state;
}

/*
 * Move the 128-bit running total into the exact carry and reset it.  Runs in
 * the aggregate context so the carry survives the tuple context reset.
 */
static void
dec128_agg_flush(Dec128AggState *state, MemoryContext aggctx)
{
	MemoryContext oldctx;
	Numeric		part;

	oldctx = MemoryContextSwitchTo(aggctx);

	part = dec128_to_numeric(state->sum, state->scale);
	state->carry = state->carry == NULL ? part
		: DatumGetNumeric(DirectFunctionCall2(numeric_add,
											  NumericGetDatum(state->carry),
											  NumericGetDatum(part)));
	state->sum = 0;

	MemoryContextSwitchTo(oldctx);
}

/*
 * Add a quantity held at scale "vscale" into the accumulator, spilling to the
 * carry whenever 128 bits would not be enough.
 */
static void
dec128_agg_add(Dec128AggState *state, __int128 mant, int vscale,
			   MemoryContext aggctx)
{
	__int128	addend = mant;
	__int128	tmp;

	Assert(vscale >= 0 && vscale <= DEC128_MAX_SCALE);

	if (!state->seen)
	{
		state->sum = mant;
		state->scale = vscale;
		state->seen = true;
		return;
	}

	if (unlikely(vscale != state->scale))
	{
		if (vscale > state->scale)
		{
			/* lifting the running total may not fit; spill it first */
			if (__builtin_mul_overflow(state->sum,
									   dec128_pow10[vscale - state->scale],
									   &tmp))
			{
				dec128_agg_flush(state, aggctx);
				tmp = 0;
			}
			state->sum = tmp;
			state->scale = vscale;
		}
		else if (__builtin_mul_overflow(mant,
										dec128_pow10[state->scale - vscale],
										&addend))
		{
			/* the addend alone outgrows 128 bits at the running scale */
			dec128_agg_flush(state, aggctx);
			state->scale = vscale;
			state->sum = mant;
			return;
		}
	}

	if (unlikely(__builtin_add_overflow(state->sum, addend, &tmp)))
	{
		dec128_agg_flush(state, aggctx);
		state->sum = addend;
		return;
	}

	state->sum = tmp;
}

/*
 * Transition function for sum() and avg().
 */
Datum
dec128_accum(PG_FUNCTION_ARGS)
{
	Dec128AggState *state = dec128_agg_state(fcinfo, 0);
	MemoryContext aggctx;
	Dec128	   *v;

	if (PG_ARGISNULL(1))
		PG_RETURN_POINTER(state);

	(void) AggCheckCallContext(fcinfo, &aggctx);
	v = PG_GETARG_DEC128_P(1);
	dec128_agg_add(state, dec128_mant(v), dec128_scale(v), aggctx);
	state->count++;

	PG_RETURN_POINTER(state);
}

/*
 * Produce the exact total: carry plus whatever is still in the fast slot.
 */
static Numeric
dec128_agg_total(Dec128AggState *state)
{
	Numeric		part = dec128_to_numeric(state->sum, state->scale);

	if (state->carry == NULL)
		return part;

	return DatumGetNumeric(DirectFunctionCall2(numeric_add,
											   NumericGetDatum(state->carry),
											   NumericGetDatum(part)));
}

/*
 * Merge two partial states, for parallel aggregation.
 */
Datum
dec128_combine(PG_FUNCTION_ARGS)
{
	Dec128AggState *state1 = dec128_agg_state(fcinfo, 0);
	Dec128AggState *state2;
	MemoryContext aggctx;
	MemoryContext oldctx;
	Numeric		total2;

	if (PG_ARGISNULL(1))
		PG_RETURN_POINTER(state1);

	state2 = (Dec128AggState *) PG_GETARG_POINTER(1);
	if (!state2->seen)
		PG_RETURN_POINTER(state1);

	if (!state1->seen)
	{
		state1->scale = state2->scale;
		state1->seen = true;
	}

	/*
	 * Merging through the exact form keeps this simple and correct; it runs
	 * once per worker, not once per row.
	 */
	if (!AggCheckCallContext(fcinfo, &aggctx))
		elog(ERROR, "aggregate function called in non-aggregate context");

	oldctx = MemoryContextSwitchTo(aggctx);
	total2 = dec128_agg_total(state2);
	state1->carry = state1->carry == NULL ? total2
		: DatumGetNumeric(DirectFunctionCall2(numeric_add,
											  NumericGetDatum(state1->carry),
											  NumericGetDatum(total2)));
	MemoryContextSwitchTo(oldctx);

	state1->count += state2->count;

	PG_RETURN_POINTER(state1);
}

/*
 * Serialise the state for shipping from a parallel worker.  The running total
 * is folded into the carry first, so the wire form is just a numeric plus the
 * bookkeeping.
 */
Datum
dec128_serialize(PG_FUNCTION_ARGS)
{
	Dec128AggState *state;
	StringInfoData buf;
	char	   *total;

	if (!AggCheckCallContext(fcinfo, NULL))
		elog(ERROR, "aggregate function called in non-aggregate context");

	state = (Dec128AggState *) PG_GETARG_POINTER(0);

	total = state->seen
		? DatumGetCString(DirectFunctionCall1(numeric_out,
											  NumericGetDatum(dec128_agg_total(state))))
		: pstrdup("0");

	pq_begintypsend(&buf);
	pq_sendint64(&buf, state->count);
	pq_sendint32(&buf, state->scale);
	pq_sendbyte(&buf, state->seen ? 1 : 0);
	pq_sendcountedtext(&buf, total, strlen(total));

	PG_RETURN_BYTEA_P(pq_endtypsend(&buf));
}

/*
 * Rebuild a state shipped by dec128_serialize().
 */
Datum
dec128_deserialize(PG_FUNCTION_ARGS)
{
	bytea	   *sstate = PG_GETARG_BYTEA_PP(0);
	Dec128AggState *state;
	StringInfoData buf;
	MemoryContext aggctx;
	MemoryContext oldctx;
	const char *total;
	int			len;

	if (!AggCheckCallContext(fcinfo, &aggctx))
		elog(ERROR, "aggregate function called in non-aggregate context");

	initStringInfo(&buf);
	appendBinaryStringInfo(&buf, VARDATA_ANY(sstate),
						   VARSIZE_ANY_EXHDR(sstate));

	oldctx = MemoryContextSwitchTo(aggctx);
	state = (Dec128AggState *) palloc0(sizeof(Dec128AggState));

	state->count = pq_getmsgint64(&buf);
	state->scale = pq_getmsgint(&buf, 4);
	state->seen = (pq_getmsgbyte(&buf) != 0);
	total = pq_getmsgtext(&buf, pq_getmsgint(&buf, 4), &len);

	if (state->scale < 0 || state->scale > DEC128_MAX_SCALE)
		elog(ERROR, "invalid scale %d in serialized dec128 state",
			 state->scale);

	if (state->seen)
		state->carry = DatumGetNumeric(DirectFunctionCall3(numeric_in,
														   CStringGetDatum(total),
														   ObjectIdGetDatum(InvalidOid),
														   Int32GetDatum(-1)));
	MemoryContextSwitchTo(oldctx);

	pq_getmsgend(&buf);
	pfree(buf.data);

	PG_RETURN_POINTER(state);
}

/*
 * Final function for sum(): returns numeric, since a total over many rows
 * outgrows even 37 digits.
 */
Datum
dec128_sum_final(PG_FUNCTION_ARGS)
{
	Dec128AggState *state;

	if (!AggCheckCallContext(fcinfo, NULL))
		elog(ERROR, "aggregate function called in non-aggregate context");

	state = PG_ARGISNULL(0) ? NULL : (Dec128AggState *) PG_GETARG_POINTER(0);
	if (state == NULL || !state->seen)
		PG_RETURN_NULL();

	PG_RETURN_NUMERIC(dec128_agg_total(state));
}

/*
 * Final function for avg(): the total divided by the count, in numeric.
 */
Datum
dec128_avg_final(PG_FUNCTION_ARGS)
{
	Dec128AggState *state;
	Numeric		count;

	if (!AggCheckCallContext(fcinfo, NULL))
		elog(ERROR, "aggregate function called in non-aggregate context");

	state = PG_ARGISNULL(0) ? NULL : (Dec128AggState *) PG_GETARG_POINTER(0);
	if (state == NULL || state->count == 0)
		PG_RETURN_NULL();

	count = DatumGetNumeric(DirectFunctionCall1(int8_numeric,
												Int64GetDatum(state->count)));

	PG_RETURN_DATUM(DirectFunctionCall2(numeric_div,
										NumericGetDatum(dec128_agg_total(state)),
										NumericGetDatum(count)));
}


/* ----------------------------------------------------------------
 *				Cross-tier comparison: dec64 against dec128
 * ----------------------------------------------------------------
 *
 * Without these, "a = b" over one column of each tier is ambiguous: the
 * planner sees dec128 = dec128 (widening the left), dec64 = numeric and
 * numeric = dec128 as equally good candidates, each matching exactly one
 * argument.  Declaring the pair explicitly gives a candidate that matches
 * both, which resolution prefers -- the same reason core carries a full
 * int2/int4/int8 operator matrix rather than relying on the widening casts.
 */

PG_FUNCTION_INFO_V1(dec64_dec128_cmp);
PG_FUNCTION_INFO_V1(dec128_dec64_cmp);

/*
 * Compare a dec64 against a dec128 by widening the narrow side on the stack.
 * The widening is always exact, so no rounding question arises.
 */
static inline int
dec64_cmp_dec128(Dec64 a, const Dec128 *b)
{
	Dec128		wide;

	dec128_store(&wide, (__int128) DEC64_MANT(a), DEC64_SCALE(a));

	return dec128_compare(&wide, b);
}

/*
 * Three-way comparison, dec64 on the left.
 */
Datum
dec64_dec128_cmp(PG_FUNCTION_ARGS)
{
	PG_RETURN_INT32(dec64_cmp_dec128(PG_GETARG_DEC64(0),
									 PG_GETARG_DEC128_P(1)));
}

/*
 * Three-way comparison, dec128 on the left.
 */
Datum
dec128_dec64_cmp(PG_FUNCTION_ARGS)
{
	PG_RETURN_INT32(-dec64_cmp_dec128(PG_GETARG_DEC64(1),
									  PG_GETARG_DEC128_P(0)));
}

#define DEC64_DEC128_OP(fname, op) \
PG_FUNCTION_INFO_V1(fname); \
Datum \
fname(PG_FUNCTION_ARGS) \
{ \
	PG_RETURN_BOOL(dec64_cmp_dec128(PG_GETARG_DEC64(0), \
									PG_GETARG_DEC128_P(1)) op 0); \
}

DEC64_DEC128_OP(dec64_dec128_lt, <)
DEC64_DEC128_OP(dec64_dec128_le, <=)
DEC64_DEC128_OP(dec64_dec128_eq, ==)
DEC64_DEC128_OP(dec64_dec128_ne, !=)
DEC64_DEC128_OP(dec64_dec128_ge, >=)
DEC64_DEC128_OP(dec64_dec128_gt, >)

#define DEC128_DEC64_OP(fname, op) \
PG_FUNCTION_INFO_V1(fname); \
Datum \
fname(PG_FUNCTION_ARGS) \
{ \
	PG_RETURN_BOOL(-dec64_cmp_dec128(PG_GETARG_DEC64(1), \
									 PG_GETARG_DEC128_P(0)) op 0); \
}

DEC128_DEC64_OP(dec128_dec64_lt, <)
DEC128_DEC64_OP(dec128_dec64_le, <=)
DEC128_DEC64_OP(dec128_dec64_eq, ==)
DEC128_DEC64_OP(dec128_dec64_ne, !=)
DEC128_DEC64_OP(dec128_dec64_ge, >=)
DEC128_DEC64_OP(dec128_dec64_gt, >)
