/*-------------------------------------------------------------------------
 *
 * dec64.c
 *		Exact fixed-point decimal type stored in a single machine word.
 *
 * DESIGN
 *
 * A dec64 value is one int64 Datum, passed by value:
 *
 *		bits 0..2	scale, 0..7 -- digits after the decimal point
 *		bits 3..63	mantissa, signed, |m| <= 10^18 - 1
 *
 * The value equals mantissa / 10^scale, which is the exact-numeric form the
 * SQL standard gives in subclause 4.5.2 (n * 10^-s).
 *
 * The scale is carried inside the value, not in the typmod, because the type
 * output function receives only the datum -- there is no typmod-aware output
 * path in PostgreSQL.  A typmod of the form dec64(precision, scale) is still
 * supported, but as a constraint applied on assignment, exactly as numeric
 * does it.
 *
 * The mantissa bound of 10^18 - 1 yields exactly 18 significant digits.  That
 * is not an arbitrary cut: ISO 20022 specifies totalDigits=18 for a monetary
 * amount, and the 1C DirectBank exchange format uses decimal(18,2).
 *
 * DIFFERENCES FROM DuckDB's DECIMAL
 *
 * The type follows DuckDB where the two systems face the same question:
 *
 *	- values are scaled integers, scale is a property of the type;
 *	- operators do not widen their result to dodge overflow, they raise an
 *	  error instead (DuckDB: "we don't automatically promote past the hugeint
 *	  boundary to avoid the large hugeint performance penalty");
 *	- aggregates do widen -- sum() accumulates in 128 bits and returns numeric;
 *	- there are no NaN and no infinity values;
 *	- multiplication produces scale s1+s2 and raises an error when that scale
 *	  cannot be represented, rather than silently rounding.
 *
 * It deliberately departs from DuckDB in one place.  DuckDB returns DOUBLE
 * from any division involving a decimal.  For a type whose reason to exist is
 * exactness of monetary values, silently yielding binary floating point from
 * "total / count" would be a trap, so dec64 division stays in dec64 at the
 * maximum available scale and rounds half away from zero -- the commercial
 * rule required by EC Regulation 1103/97 art. 5 and by HMRC.  Cast to double
 * explicitly if DuckDB's behaviour is wanted.
 *
 * There is no second physical tier (dec128).  PostgreSQL derives a type's
 * width from pg_type.typlen, which is one value per type, so DuckDB's
 * int16/int32/int64/int128 ladder cannot live inside a single type; and a
 * 16-byte type could not be passed by value, which is where nearly all of the
 * speed comes from.  numeric serves as the widening target for aggregates.
 *
 *-------------------------------------------------------------------------
 */
#include "postgres.h"

#include <ctype.h>
#include <limits.h>
#include <math.h>

#include "catalog/namespace.h"
#include "catalog/pg_type.h"
#include "common/hashfn.h"
#include "common/int.h"
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

PG_MODULE_MAGIC;

#ifndef HAVE_INT128
#error "dec64 requires a native 128-bit integer type"
#endif

StaticAssertDecl(sizeof(Datum) >= 8,
				 "dec64 is pass-by-value and needs a 64-bit Datum");

typedef int64 Dec64;

#define DEC64_MAX_SCALE			7
#define DEC64_MAX_PRECISION		18
#define DEC64_SCALE_BITS		3
#define DEC64_SCALE_MASK		((int64) 0x7)
#define DEC64_MAX_MANT			INT64CONST(999999999999999999)

#define DEC64_SCALE(v)			((int) ((v) & DEC64_SCALE_MASK))
#define DEC64_MANT(v)			((int64) (v) >> DEC64_SCALE_BITS)
#define DEC64_MAKE(m, s)		\
	((Dec64) (((uint64) (int64) (m) << DEC64_SCALE_BITS) | (uint64) (s)))

#define DatumGetDec64(X)		((Dec64) DatumGetInt64(X))
#define Dec64GetDatum(X)		Int64GetDatum((int64) (X))
#define PG_GETARG_DEC64(n)		DatumGetDec64(PG_GETARG_DATUM(n))
#define PG_RETURN_DEC64(x)		return Dec64GetDatum(x)

/* typmod layout: (precision << 8) | scale, offset by VARHDRSZ as numeric does */
#define DEC64_TYPMOD_IS_VALID(t)	((t) >= (int32) VARHDRSZ)
#define DEC64_TYPMOD_PRECISION(t)	((((t) - VARHDRSZ) >> 8) & 0xffff)
#define DEC64_TYPMOD_SCALE(t)		(((t) - VARHDRSZ) & 0xff)
#define DEC64_MAKE_TYPMOD(p, s)		((((p) << 8) | (s)) + VARHDRSZ)

/* 10^0 .. 10^18 */
static const int64 dec64_pow10[DEC64_MAX_PRECISION + 1] = {
	INT64CONST(1), INT64CONST(10), INT64CONST(100), INT64CONST(1000),
	INT64CONST(10000), INT64CONST(100000), INT64CONST(1000000),
	INT64CONST(10000000), INT64CONST(100000000), INT64CONST(1000000000),
	INT64CONST(10000000000), INT64CONST(100000000000),
	INT64CONST(1000000000000), INT64CONST(10000000000000),
	INT64CONST(100000000000000), INT64CONST(1000000000000000),
	INT64CONST(10000000000000000), INT64CONST(100000000000000000),
	INT64CONST(1000000000000000000)
};


/*
 * Report a value that does not fit the type.  Kept out of line so the callers
 * stay small enough for the compiler to keep the hot path tight.
 */
static pg_noinline void
dec64_out_of_range(void)
{
	ereport(ERROR,
			(errcode(ERRCODE_NUMERIC_VALUE_OUT_OF_RANGE),
			 errmsg("value out of range for type dec64"),
			 errdetail("dec64 holds at most %d significant digits.",
					   DEC64_MAX_PRECISION)));
}

/*
 * Report a required scale that the encoding cannot represent.
 */
static pg_noinline void
dec64_scale_unsupported(int scale)
{
	ereport(ERROR,
			(errcode(ERRCODE_NUMERIC_VALUE_OUT_OF_RANGE),
			 errmsg("scale %d is out of range for type dec64", scale),
			 errdetail("dec64 supports at most %d fractional digits.",
					   DEC64_MAX_SCALE),
			 errhint("Round an operand to a smaller scale, or cast to numeric.")));
}

/*
 * Assemble a value from mantissa and scale, rejecting an out-of-range
 * mantissa.  The scale is a programming-error check only; every caller is
 * expected to have validated it already.
 */
static inline Dec64
dec64_pack(int64 mant, int scale)
{
	Assert(scale >= 0 && scale <= DEC64_MAX_SCALE);

	if (unlikely(mant > DEC64_MAX_MANT || mant < -DEC64_MAX_MANT))
		dec64_out_of_range();

	return DEC64_MAKE(mant, scale);
}

/*
 * Same, for a 128-bit intermediate produced by multiplication or division.
 */
static inline Dec64
dec64_pack128(__int128 mant, int scale)
{
	Assert(scale >= 0 && scale <= DEC64_MAX_SCALE);

	if (unlikely(mant > (__int128) DEC64_MAX_MANT ||
				 mant < -(__int128) DEC64_MAX_MANT))
		dec64_out_of_range();

	return DEC64_MAKE((int64) mant, scale);
}

/*
 * Divide a 128-bit value by 10^n, rounding half away from zero.  That is the
 * rule EC Regulation 1103/97 art. 5 and HMRC VATREC12030 require, and the one
 * numeric's round_var() uses, so results agree with numeric.
 */
static inline __int128
dec64_div_round(__int128 value, int n)
{
	__int128	div;
	__int128	half;

	Assert(n >= 0 && n <= DEC64_MAX_PRECISION);

	if (n == 0)
		return value;

	div = (__int128) dec64_pow10[n];
	half = div / 2;

	return (value >= 0) ? (value + half) / div : (value - half) / div;
}

/*
 * Restate a value at a different scale, rounding half away from zero when the
 * new scale is smaller.  Raises an error if the result does not fit.
 */
static Dec64
dec64_rescale(Dec64 v, int newscale)
{
	int			scale = DEC64_SCALE(v);
	int64		mant = DEC64_MANT(v);
	__int128	res;

	if (newscale < 0 || newscale > DEC64_MAX_SCALE)
		dec64_scale_unsupported(newscale);

	if (newscale == scale)
		return v;

	if (newscale > scale)
		res = (__int128) mant * (__int128) dec64_pow10[newscale - scale];
	else
		res = dec64_div_round((__int128) mant, scale - newscale);

	return dec64_pack128(res, newscale);
}

/*
 * Bring two values to a common scale, returning that scale and storing the
 * restated mantissas.  Equal scales -- the overwhelmingly common case, since
 * a column has one declared scale -- cost a single predictable branch.
 */
static inline int
dec64_align(Dec64 a, Dec64 b, int64 *ma, int64 *mb)
{
	int			sa = DEC64_SCALE(a);
	int			sb = DEC64_SCALE(b);
	__int128	tmp;

	*ma = DEC64_MANT(a);
	*mb = DEC64_MANT(b);

	if (likely(sa == sb))
		return sa;

	if (sa < sb)
	{
		tmp = (__int128) *ma * (__int128) dec64_pow10[sb - sa];
		if (unlikely(tmp > (__int128) DEC64_MAX_MANT ||
					 tmp < -(__int128) DEC64_MAX_MANT))
			dec64_out_of_range();
		*ma = (int64) tmp;
		return sb;
	}

	tmp = (__int128) *mb * (__int128) dec64_pow10[sa - sb];
	if (unlikely(tmp > (__int128) DEC64_MAX_MANT ||
				 tmp < -(__int128) DEC64_MAX_MANT))
		dec64_out_of_range();
	*mb = (int64) tmp;
	return sa;
}

/*
 * Reduce a value to its canonical form by dropping fractional trailing zeros.
 * Equal values must hash alike, and 1.5 and 1.50 are equal, so hashing has to
 * canonicalise first.  Comparison does not need this because it aligns.
 */
static inline Dec64
dec64_canonical(Dec64 v)
{
	int64		mant = DEC64_MANT(v);
	int			scale = DEC64_SCALE(v);

	if (mant == 0)
		return DEC64_MAKE(0, 0);

	while (scale > 0 && (mant % 10) == 0)
	{
		mant /= 10;
		scale--;
	}

	return DEC64_MAKE(mant, scale);
}

/*
 * Count the significant digits of a mantissa, for typmod precision checks.
 */
static int
dec64_digits(int64 mant)
{
	uint64		u = (mant < 0) ? (uint64) (-mant) : (uint64) mant;
	int			i;

	for (i = 0; i < DEC64_MAX_PRECISION; i++)
	{
		if (u < (uint64) dec64_pow10[i + 1])
			return i + 1;
	}
	return DEC64_MAX_PRECISION + 1;
}

/*
 * Apply a typmod constraint: restate to the declared scale, then verify that
 * the integer part fits in (precision - scale) digits.  Mirrors the behaviour
 * of numeric's length coercion.
 */
static Dec64
dec64_apply_typmod(Dec64 v, int32 typmod)
{
	int			precision;
	int			scale;
	int64		mant;
	int			digits;

	if (!DEC64_TYPMOD_IS_VALID(typmod))
		return v;

	precision = DEC64_TYPMOD_PRECISION(typmod);
	scale = DEC64_TYPMOD_SCALE(typmod);

	Assert(precision >= 1 && precision <= DEC64_MAX_PRECISION);
	Assert(scale >= 0 && scale <= precision);

	v = dec64_rescale(v, scale);
	mant = DEC64_MANT(v);

	if (mant == 0)
		return v;

	digits = dec64_digits(mant);
	if (digits > precision)
		ereport(ERROR,
				(errcode(ERRCODE_NUMERIC_VALUE_OUT_OF_RANGE),
				 errmsg("dec64 field overflow"),
				 errdetail("A field with precision %d, scale %d must round to an absolute value less than %s%d.",
						   precision, scale,
						   "10^", precision - scale)));

	return v;
}


/* ----------------------------------------------------------------
 *						Input and output
 * ----------------------------------------------------------------
 */

PG_FUNCTION_INFO_V1(dec64_in);
PG_FUNCTION_INFO_V1(dec64_out);
PG_FUNCTION_INFO_V1(dec64_recv);
PG_FUNCTION_INFO_V1(dec64_send);
PG_FUNCTION_INFO_V1(dec64typmodin);
PG_FUNCTION_INFO_V1(dec64typmodout);
PG_FUNCTION_INFO_V1(dec64_scale_typmod);

/*
 * Parse the external text form: optional sign, digits, optional fractional
 * part.  No exponent notation, no NaN and no infinity -- following DuckDB's
 * DECIMAL rather than numeric here.
 */
Datum
dec64_in(PG_FUNCTION_ARGS)
{
	char	   *str = PG_GETARG_CSTRING(0);
	int32		typmod = PG_GETARG_INT32(2);
	const char *p = str;
	int64		mant = 0;
	int			scale = 0;
	int			digits = 0;
	bool		neg = false;
	bool		seen_digit = false;
	bool		in_frac = false;
	Dec64		result;

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
			if (unlikely(++digits > DEC64_MAX_PRECISION))
				dec64_out_of_range();
		}

		mant = mant * 10 + (*p - '0');

		if (in_frac && ++scale > DEC64_MAX_SCALE)
			dec64_scale_unsupported(scale);
	}

	while (isspace((unsigned char) *p))
		p++;

	if (*p != '\0' || !seen_digit)
		goto bad_syntax;

	result = dec64_pack(neg ? -mant : mant, scale);

	PG_RETURN_DEC64(dec64_apply_typmod(result, typmod));

bad_syntax:
	ereport(ERROR,
			(errcode(ERRCODE_INVALID_TEXT_REPRESENTATION),
			 errmsg("invalid input syntax for type dec64: \"%s\"", str)));
	PG_RETURN_NULL();			/* unreachable, keeps the compiler quiet */
}

/*
 * Render the value.  Trailing zeros implied by the scale are kept, so 1.50
 * prints as "1.50" -- the same significance rule numeric applies through its
 * dscale, and the customary presentation for monetary amounts.
 */
Datum
dec64_out(PG_FUNCTION_ARGS)
{
	Dec64		v = PG_GETARG_DEC64(0);
	int64		mant = DEC64_MANT(v);
	int			scale = DEC64_SCALE(v);
	char		buf[DEC64_MAX_PRECISION + 4];
	char	   *end = buf + sizeof(buf);
	char	   *cur = end;
	bool		neg = (mant < 0);
	uint64		u = neg ? (uint64) (-mant) : (uint64) mant;
	int			i;

	Assert(scale >= 0 && scale <= DEC64_MAX_SCALE);

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

	PG_RETURN_CSTRING(pnstrdup(cur, end - cur));
}

/*
 * Binary input: mantissa as int64 followed by scale as int16, so the wire
 * form does not depend on how the bits are packed internally.
 */
Datum
dec64_recv(PG_FUNCTION_ARGS)
{
	StringInfo	buf = (StringInfo) PG_GETARG_POINTER(0);
	int32		typmod = PG_GETARG_INT32(2);
	int64		mant = pq_getmsgint64(buf);
	int			scale = (int) pq_getmsgint(buf, 2);

	if (scale < 0 || scale > DEC64_MAX_SCALE)
		ereport(ERROR,
				(errcode(ERRCODE_INVALID_BINARY_REPRESENTATION),
				 errmsg("invalid scale %d in external dec64 value", scale)));

	PG_RETURN_DEC64(dec64_apply_typmod(dec64_pack(mant, scale), typmod));
}

/*
 * Binary output, matching dec64_recv().
 */
Datum
dec64_send(PG_FUNCTION_ARGS)
{
	Dec64		v = PG_GETARG_DEC64(0);
	StringInfoData buf;

	pq_begintypsend(&buf);
	pq_sendint64(&buf, DEC64_MANT(v));
	pq_sendint16(&buf, (int16) DEC64_SCALE(v));

	PG_RETURN_BYTEA_P(pq_endtypsend(&buf));
}

/*
 * Parse dec64(precision) or dec64(precision, scale).
 */
Datum
dec64typmodin(PG_FUNCTION_ARGS)
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
				 errmsg("invalid type modifier for dec64")));

	precision = tl[0];
	scale = (n == 2) ? tl[1] : 0;

	if (precision < 1 || precision > DEC64_MAX_PRECISION)
		ereport(ERROR,
				(errcode(ERRCODE_INVALID_PARAMETER_VALUE),
				 errmsg("dec64 precision %d must be between 1 and %d",
						precision, DEC64_MAX_PRECISION)));
	if (scale < 0 || scale > DEC64_MAX_SCALE)
		ereport(ERROR,
				(errcode(ERRCODE_INVALID_PARAMETER_VALUE),
				 errmsg("dec64 scale %d must be between 0 and %d",
						scale, DEC64_MAX_SCALE)));
	if (scale > precision)
		ereport(ERROR,
				(errcode(ERRCODE_INVALID_PARAMETER_VALUE),
				 errmsg("dec64 scale %d must not exceed precision %d",
						scale, precision)));

	PG_RETURN_INT32(DEC64_MAKE_TYPMOD(precision, scale));
}

/*
 * Render a typmod back as "(precision,scale)".
 */
Datum
dec64typmodout(PG_FUNCTION_ARGS)
{
	int32		typmod = PG_GETARG_INT32(0);
	char	   *res = (char *) palloc(32);

	if (DEC64_TYPMOD_IS_VALID(typmod))
		snprintf(res, 32, "(%d,%d)",
				 DEC64_TYPMOD_PRECISION(typmod), DEC64_TYPMOD_SCALE(typmod));
	else
		*res = '\0';

	PG_RETURN_CSTRING(res);
}

/*
 * Length coercion function, invoked when a value is stored into a column
 * declared dec64(p,s) or explicitly cast to it.
 */
Datum
dec64_scale_typmod(PG_FUNCTION_ARGS)
{
	Dec64		v = PG_GETARG_DEC64(0);
	int32		typmod = PG_GETARG_INT32(1);

	PG_RETURN_DEC64(dec64_apply_typmod(v, typmod));
}


/* ----------------------------------------------------------------
 *						Arithmetic
 * ----------------------------------------------------------------
 */

PG_FUNCTION_INFO_V1(dec64_add);
PG_FUNCTION_INFO_V1(dec64_sub);
PG_FUNCTION_INFO_V1(dec64_mul);
PG_FUNCTION_INFO_V1(dec64_div);
PG_FUNCTION_INFO_V1(dec64_mod);
PG_FUNCTION_INFO_V1(dec64_uminus);
PG_FUNCTION_INFO_V1(dec64_uplus);
PG_FUNCTION_INFO_V1(dec64_abs);
PG_FUNCTION_INFO_V1(dec64_sign);

/*
 * Addition.  Result scale is max(s1,s2), as in both numeric and DuckDB.  The
 * result is not widened on overflow; an error is raised instead.
 */
static inline Dec64
dec64_add_impl(Dec64 a, Dec64 b)
{
	int64		ma,
				mb,
				r;
	int			scale = dec64_align(a, b, &ma, &mb);

	if (unlikely(pg_add_s64_overflow(ma, mb, &r)))
		dec64_out_of_range();

	return dec64_pack(r, scale);
}

/*
 * Subtraction.  Result scale is max(s1,s2).
 */
static inline Dec64
dec64_sub_impl(Dec64 a, Dec64 b)
{
	int64		ma,
				mb,
				r;
	int			scale = dec64_align(a, b, &ma, &mb);

	if (unlikely(pg_sub_s64_overflow(ma, mb, &r)))
		dec64_out_of_range();

	return dec64_pack(r, scale);
}

/*
 * Multiplication.  The SQL standard fixes the result scale at s1+s2 and
 * dec64 honours that; when the sum exceeds the representable scale an error
 * is raised rather than rounding silently, matching DuckDB's behaviour at its
 * own scale ceiling.  Use round() to reduce an operand first if a lossy
 * result is intended.
 */
static inline Dec64
dec64_mul_impl(Dec64 a, Dec64 b)
{
	int			scale = DEC64_SCALE(a) + DEC64_SCALE(b);
	__int128	prod;

	if (unlikely(scale > DEC64_MAX_SCALE))
		dec64_scale_unsupported(scale);

	prod = (__int128) DEC64_MANT(a) * (__int128) DEC64_MANT(b);

	return dec64_pack128(prod, scale);
}

/*
 * Division.  Unlike DuckDB, which returns DOUBLE for every division involving
 * a decimal, the result stays exact-typed: it is produced at the maximum
 * representable scale and rounded half away from zero.  The scale depends
 * only on the type, never on the data, so a query cannot yield differently
 * scaled results for different rows.
 */
static inline Dec64
dec64_div_impl(Dec64 a, Dec64 b)
{
	int64		mb = DEC64_MANT(b);
	int			shift;
	__int128	num;
	__int128	q;
	__int128	half;

	if (unlikely(mb == 0))
		ereport(ERROR,
				(errcode(ERRCODE_DIVISION_BY_ZERO),
				 errmsg("division by zero")));

	/*
	 * q = a/b at scale S is  m1 * 10^(s2 + S - s1) / m2.  With s1,s2 in [0,7]
	 * and S = 7 the exponent lies in [0,14], so the numerator fits in 128 bits
	 * (10^18 * 10^14 = 10^32, well under the 1.7*10^38 limit).
	 */
	shift = DEC64_SCALE(b) + DEC64_MAX_SCALE - DEC64_SCALE(a);
	Assert(shift >= 0 && shift <= 2 * DEC64_MAX_SCALE);

	num = (__int128) DEC64_MANT(a) * (__int128) dec64_pow10[shift];

	/* round half away from zero */
	half = (mb < 0) ? -((__int128) mb / 2) : ((__int128) mb / 2);
	if (num >= 0)
		q = (num + half) / mb;
	else
		q = (num - half) / mb;

	return dec64_pack128(q, DEC64_MAX_SCALE);
}

/*
 * dec64 + dec64
 */
Datum
dec64_add(PG_FUNCTION_ARGS)
{
	PG_RETURN_DEC64(dec64_add_impl(PG_GETARG_DEC64(0), PG_GETARG_DEC64(1)));
}

/*
 * dec64 - dec64
 */
Datum
dec64_sub(PG_FUNCTION_ARGS)
{
	PG_RETURN_DEC64(dec64_sub_impl(PG_GETARG_DEC64(0), PG_GETARG_DEC64(1)));
}

/*
 * dec64 * dec64
 */
Datum
dec64_mul(PG_FUNCTION_ARGS)
{
	PG_RETURN_DEC64(dec64_mul_impl(PG_GETARG_DEC64(0), PG_GETARG_DEC64(1)));
}

/*
 * dec64 / dec64
 */
Datum
dec64_div(PG_FUNCTION_ARGS)
{
	PG_RETURN_DEC64(dec64_div_impl(PG_GETARG_DEC64(0), PG_GETARG_DEC64(1)));
}

/*
 * Remainder, truncated toward zero as numeric's mod() is.  Result scale is
 * max(s1,s2).
 */
Datum
dec64_mod(PG_FUNCTION_ARGS)
{
	Dec64		a = PG_GETARG_DEC64(0);
	Dec64		b = PG_GETARG_DEC64(1);
	int64		ma,
				mb;
	int			scale = dec64_align(a, b, &ma, &mb);

	if (unlikely(mb == 0))
		ereport(ERROR,
				(errcode(ERRCODE_DIVISION_BY_ZERO),
				 errmsg("division by zero")));

	PG_RETURN_DEC64(dec64_pack(ma % mb, scale));
}

/*
 * Unary minus.  Cannot overflow: the mantissa range is symmetric.
 */
Datum
dec64_uminus(PG_FUNCTION_ARGS)
{
	Dec64		v = PG_GETARG_DEC64(0);

	PG_RETURN_DEC64(DEC64_MAKE(-DEC64_MANT(v), DEC64_SCALE(v)));
}

/*
 * Unary plus, provided so that "+x" parses.
 */
Datum
dec64_uplus(PG_FUNCTION_ARGS)
{
	PG_RETURN_DEC64(PG_GETARG_DEC64(0));
}

/*
 * Absolute value.
 */
Datum
dec64_abs(PG_FUNCTION_ARGS)
{
	Dec64		v = PG_GETARG_DEC64(0);
	int64		mant = DEC64_MANT(v);

	PG_RETURN_DEC64(DEC64_MAKE(mant < 0 ? -mant : mant, DEC64_SCALE(v)));
}

/*
 * Sign: -1, 0 or 1, at scale 0.
 */
Datum
dec64_sign(PG_FUNCTION_ARGS)
{
	Dec64		v = PG_GETARG_DEC64(0);
	int64		mant = DEC64_MANT(v);

	PG_RETURN_DEC64(DEC64_MAKE(mant > 0 ? 1 : (mant < 0 ? -1 : 0), 0));
}


/* ----------------------------------------------------------------
 *						Comparison, hashing, sorting
 * ----------------------------------------------------------------
 */

PG_FUNCTION_INFO_V1(dec64_cmp);
PG_FUNCTION_INFO_V1(dec64_lt);
PG_FUNCTION_INFO_V1(dec64_le);
PG_FUNCTION_INFO_V1(dec64_eq);
PG_FUNCTION_INFO_V1(dec64_ne);
PG_FUNCTION_INFO_V1(dec64_ge);
PG_FUNCTION_INFO_V1(dec64_gt);
PG_FUNCTION_INFO_V1(dec64_hash);
PG_FUNCTION_INFO_V1(dec64_hash_extended);
PG_FUNCTION_INFO_V1(dec64_sortsupport);
PG_FUNCTION_INFO_V1(dec64_smaller);
PG_FUNCTION_INFO_V1(dec64_larger);

/*
 * Compare two values.
 *
 * Alignment is done in 128 bits rather than through dec64_align(), because
 * comparison must never fail.  Bringing 999999999999999999 (scale 0) up to
 * scale 7 overflows int64, yet the comparison against 0.0000001 is perfectly
 * well defined -- and an ORDER BY that raises "value out of range" would be a
 * plain bug.  10^18 * 10^7 is far inside the 128-bit range, so the widened
 * form always fits.
 */
static inline int
dec64_compare(Dec64 a, Dec64 b)
{
	int			sa = DEC64_SCALE(a);
	int			sb = DEC64_SCALE(b);
	__int128	ma;
	__int128	mb;

	if (likely(sa == sb))
	{
		int64		la = DEC64_MANT(a);
		int64		lb = DEC64_MANT(b);

		return (la > lb) ? 1 : ((la < lb) ? -1 : 0);
	}

	ma = (__int128) DEC64_MANT(a);
	mb = (__int128) DEC64_MANT(b);

	if (sa < sb)
		ma *= (__int128) dec64_pow10[sb - sa];
	else
		mb *= (__int128) dec64_pow10[sa - sb];

	return (ma > mb) ? 1 : ((ma < mb) ? -1 : 0);
}

/*
 * Three-way comparison, the btree opclass support function.
 */
Datum
dec64_cmp(PG_FUNCTION_ARGS)
{
	PG_RETURN_INT32(dec64_compare(PG_GETARG_DEC64(0), PG_GETARG_DEC64(1)));
}

#define DEC64_CMP_OP(fname, op) \
Datum \
fname(PG_FUNCTION_ARGS) \
{ \
	PG_RETURN_BOOL(dec64_compare(PG_GETARG_DEC64(0), \
								 PG_GETARG_DEC64(1)) op 0); \
}

DEC64_CMP_OP(dec64_lt, <)
DEC64_CMP_OP(dec64_le, <=)
DEC64_CMP_OP(dec64_eq, ==)
DEC64_CMP_OP(dec64_ne, !=)
DEC64_CMP_OP(dec64_ge, >=)
DEC64_CMP_OP(dec64_gt, >)

/*
 * Hash.  Equal values must hash alike, and 1.5 equals 1.50, so the value is
 * canonicalised before hashing.
 */
Datum
dec64_hash(PG_FUNCTION_ARGS)
{
	Dec64		v = dec64_canonical(PG_GETARG_DEC64(0));

	return hash_any((unsigned char *) &v, sizeof(Dec64));
}

/*
 * Extended hash, for hash partitioning.
 */
Datum
dec64_hash_extended(PG_FUNCTION_ARGS)
{
	Dec64		v = dec64_canonical(PG_GETARG_DEC64(0));
	uint64		seed = PG_GETARG_INT64(1);

	return hash_any_extended((unsigned char *) &v, sizeof(Dec64), seed);
}

/*
 * Fast path comparator used by tuplesort, avoiding a function call per
 * comparison.
 */
static int
dec64_fast_cmp(Datum x, Datum y, SortSupport ssup)
{
	return dec64_compare(DatumGetDec64(x), DatumGetDec64(y));
}

/*
 * SortSupport entry point.
 */
Datum
dec64_sortsupport(PG_FUNCTION_ARGS)
{
	SortSupport ssup = (SortSupport) PG_GETARG_POINTER(0);

	ssup->comparator = dec64_fast_cmp;
	PG_RETURN_VOID();
}

/*
 * Transition function for min().
 */
Datum
dec64_smaller(PG_FUNCTION_ARGS)
{
	Dec64		a = PG_GETARG_DEC64(0);
	Dec64		b = PG_GETARG_DEC64(1);

	PG_RETURN_DEC64(dec64_compare(a, b) < 0 ? a : b);
}

/*
 * Transition function for max().
 */
Datum
dec64_larger(PG_FUNCTION_ARGS)
{
	Dec64		a = PG_GETARG_DEC64(0);
	Dec64		b = PG_GETARG_DEC64(1);

	PG_RETURN_DEC64(dec64_compare(a, b) > 0 ? a : b);
}


/* ----------------------------------------------------------------
 *						Conversions
 * ----------------------------------------------------------------
 */

PG_FUNCTION_INFO_V1(numeric_dec64);
PG_FUNCTION_INFO_V1(dec64_numeric);
PG_FUNCTION_INFO_V1(int2_dec64);
PG_FUNCTION_INFO_V1(int4_dec64);
PG_FUNCTION_INFO_V1(int8_dec64);
PG_FUNCTION_INFO_V1(dec64_int2);
PG_FUNCTION_INFO_V1(dec64_int4);
PG_FUNCTION_INFO_V1(dec64_int8);
PG_FUNCTION_INFO_V1(float4_dec64);
PG_FUNCTION_INFO_V1(float8_dec64);
PG_FUNCTION_INFO_V1(dec64_float4);
PG_FUNCTION_INFO_V1(dec64_float8);

/*
 * Build a dec64 from an int64 at scale 0.
 */
static inline Dec64
dec64_from_int64(int64 v)
{
	if (unlikely(v > DEC64_MAX_MANT || v < -DEC64_MAX_MANT))
		dec64_out_of_range();

	return DEC64_MAKE(v, 0);
}

/*
 * Produce the numeric equivalent.
 *
 * This is on the hot path of every mixed dec64/numeric comparison, so it must
 * not go through the decimal text form: formatting and reparsing costs more
 * than the comparison it feeds.  int64_div_fast_to_numeric() builds the value
 * straight from the mantissa and sets numeric's dscale from the exponent,
 * which is exactly this type's scale.
 */
static Numeric
dec64_to_numeric(Dec64 v)
{
	int			scale = DEC64_SCALE(v);

	if (scale == 0)
		return int64_to_numeric(DEC64_MANT(v));

	return int64_div_fast_to_numeric(DEC64_MANT(v), scale);
}

/*
 * numeric -> dec64.  Rejects NaN and infinity, which dec64 cannot represent.
 *
 * This is a two-argument cast function so that it receives the target
 * typmod.  A numeric can carry far more fractional digits than dec64 holds,
 * and the length coercion only runs after the cast, so without the typmod
 * here the value would first be rounded to 7 places and then again to the
 * declared scale.  Rounding twice is not the same as rounding once -- 0.4449
 * would become 0.45 instead of 0.44 -- and for monetary data that is a
 * correctness bug, not a rounding preference.
 */
Datum
numeric_dec64(PG_FUNCTION_ARGS)
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
				 errmsg("cannot convert NaN or Infinity to dec64")));

	target = DEC64_TYPMOD_IS_VALID(typmod) ? DEC64_TYPMOD_SCALE(typmod)
		: DEC64_MAX_SCALE;
	Assert(target >= 0 && target <= DEC64_MAX_SCALE);

	if (DatumGetInt32(DirectFunctionCall1(numeric_scale, nd)) > target)
		nd = DirectFunctionCall2(numeric_round, nd, Int32GetDatum(target));

	str = DatumGetCString(DirectFunctionCall1(numeric_out, nd));
	res = DirectFunctionCall3(dec64_in, CStringGetDatum(str),
							  ObjectIdGetDatum(InvalidOid),
							  Int32GetDatum(typmod));
	pfree(str);

	PG_RETURN_DATUM(res);
}

/*
 * dec64 -> numeric.
 */
Datum
dec64_numeric(PG_FUNCTION_ARGS)
{
	PG_RETURN_NUMERIC(dec64_to_numeric(PG_GETARG_DEC64(0)));
}

/*
 * smallint -> dec64.
 */
Datum
int2_dec64(PG_FUNCTION_ARGS)
{
	PG_RETURN_DEC64(dec64_from_int64((int64) PG_GETARG_INT16(0)));
}

/*
 * integer -> dec64.
 */
Datum
int4_dec64(PG_FUNCTION_ARGS)
{
	PG_RETURN_DEC64(dec64_from_int64((int64) PG_GETARG_INT32(0)));
}

/*
 * bigint -> dec64.  Values beyond 18 digits do not fit and are rejected.
 */
Datum
int8_dec64(PG_FUNCTION_ARGS)
{
	PG_RETURN_DEC64(dec64_from_int64(PG_GETARG_INT64(0)));
}

/*
 * Mixed dec64/bigint arithmetic.
 *
 * These exist so that "amount * 2" keeps its type instead of decaying to
 * numeric.  Only the bigint width is provided: smallint and integer reach it
 * through the implicit widening casts core already has, and the resulting
 * candidate wins operator resolution because it matches the dec64 operand
 * exactly while the numeric alternative matches neither.
 *
 * Casts from the integer types to dec64 are deliberately assignment-only.  An
 * implicit one would make "amount < 10" ambiguous between dec64 < dec64 and
 * dec64 < numeric.
 */
#define DEC64_INT8_OP(fname, impl) \
PG_FUNCTION_INFO_V1(fname); \
Datum \
fname(PG_FUNCTION_ARGS) \
{ \
	Dec64		d = PG_GETARG_DEC64(0); \
	Dec64		n = dec64_from_int64(PG_GETARG_INT64(1)); \
	PG_RETURN_DEC64(impl(d, n)); \
}

DEC64_INT8_OP(dec64_add_int8, dec64_add_impl)
DEC64_INT8_OP(dec64_sub_int8, dec64_sub_impl)
DEC64_INT8_OP(dec64_mul_int8, dec64_mul_impl)
DEC64_INT8_OP(dec64_div_int8, dec64_div_impl)

#define INT8_DEC64_OP(fname, impl) \
PG_FUNCTION_INFO_V1(fname); \
Datum \
fname(PG_FUNCTION_ARGS) \
{ \
	Dec64		n = dec64_from_int64(PG_GETARG_INT64(0)); \
	Dec64		d = PG_GETARG_DEC64(1); \
	PG_RETURN_DEC64(impl(n, d)); \
}

INT8_DEC64_OP(int8_add_dec64, dec64_add_impl)
INT8_DEC64_OP(int8_sub_dec64, dec64_sub_impl)
INT8_DEC64_OP(int8_mul_dec64, dec64_mul_impl)
INT8_DEC64_OP(int8_div_dec64, dec64_div_impl)

/*
 * Round a value to an integral int64, half away from zero, as numeric's
 * integer casts do.
 */
static int64
dec64_to_int64(Dec64 v)
{
	return (int64) dec64_div_round((__int128) DEC64_MANT(v), DEC64_SCALE(v));
}

/*
 * dec64 -> smallint.
 */
Datum
dec64_int2(PG_FUNCTION_ARGS)
{
	int64		r = dec64_to_int64(PG_GETARG_DEC64(0));

	if (unlikely(r < PG_INT16_MIN || r > PG_INT16_MAX))
		ereport(ERROR,
				(errcode(ERRCODE_NUMERIC_VALUE_OUT_OF_RANGE),
				 errmsg("smallint out of range")));

	PG_RETURN_INT16((int16) r);
}

/*
 * dec64 -> integer.
 */
Datum
dec64_int4(PG_FUNCTION_ARGS)
{
	int64		r = dec64_to_int64(PG_GETARG_DEC64(0));

	if (unlikely(r < PG_INT32_MIN || r > PG_INT32_MAX))
		ereport(ERROR,
				(errcode(ERRCODE_NUMERIC_VALUE_OUT_OF_RANGE),
				 errmsg("integer out of range")));

	PG_RETURN_INT32((int32) r);
}

/*
 * dec64 -> bigint.
 */
Datum
dec64_int8(PG_FUNCTION_ARGS)
{
	PG_RETURN_INT64(dec64_to_int64(PG_GETARG_DEC64(0)));
}

/*
 * Convert a double to dec64 via its shortest round-trip decimal form, so the
 * result matches what the float prints as rather than its binary expansion.
 */
static Dec64
dec64_from_float8(float8 f)
{
	char	   *str;
	Datum		res;

	if (isnan(f) || isinf(f))
		ereport(ERROR,
				(errcode(ERRCODE_INVALID_PARAMETER_VALUE),
				 errmsg("cannot convert NaN or Infinity to dec64")));

	str = DatumGetCString(DirectFunctionCall1(float8out, Float8GetDatum(f)));
	res = DirectFunctionCall3(numeric_in, CStringGetDatum(str),
							  ObjectIdGetDatum(InvalidOid), Int32GetDatum(-1));
	pfree(str);

	/*
	 * Round only when the shortest decimal form carries more fractional
	 * digits than dec64 can hold; otherwise 2.5 would come back as 2.5000000.
	 */
	if (DatumGetInt32(DirectFunctionCall1(numeric_scale, res)) >
		DEC64_MAX_SCALE)
		res = DirectFunctionCall2(numeric_round, res,
								  Int32GetDatum(DEC64_MAX_SCALE));

	str = DatumGetCString(DirectFunctionCall1(numeric_out, res));
	res = DirectFunctionCall3(dec64_in, CStringGetDatum(str),
							  ObjectIdGetDatum(InvalidOid), Int32GetDatum(-1));
	pfree(str);

	return DatumGetDec64(res);
}

/*
 * real -> dec64.
 */
Datum
float4_dec64(PG_FUNCTION_ARGS)
{
	PG_RETURN_DEC64(dec64_from_float8((float8) PG_GETARG_FLOAT4(0)));
}

/*
 * double precision -> dec64.
 */
Datum
float8_dec64(PG_FUNCTION_ARGS)
{
	PG_RETURN_DEC64(dec64_from_float8(PG_GETARG_FLOAT8(0)));
}

/*
 * dec64 -> real.
 */
Datum
dec64_float4(PG_FUNCTION_ARGS)
{
	Dec64		v = PG_GETARG_DEC64(0);

	PG_RETURN_FLOAT4((float4) ((float8) DEC64_MANT(v) /
							   (float8) dec64_pow10[DEC64_SCALE(v)]));
}

/*
 * dec64 -> double precision.
 */
Datum
dec64_float8(PG_FUNCTION_ARGS)
{
	Dec64		v = PG_GETARG_DEC64(0);

	PG_RETURN_FLOAT8((float8) DEC64_MANT(v) /
					 (float8) dec64_pow10[DEC64_SCALE(v)]);
}


/* ----------------------------------------------------------------
 *				Cross-type comparison against numeric
 * ----------------------------------------------------------------
 *
 * Provided so that "amount > 5.00" works without an explicit cast: an
 * undecorated decimal literal is numeric, and dec64 has no implicit cast to
 * it.  Comparison is done in numeric so that a numeric operand outside the
 * dec64 range compares correctly instead of erroring.
 */

PG_FUNCTION_INFO_V1(dec64_numeric_cmp);
PG_FUNCTION_INFO_V1(numeric_dec64_cmp);

/*
 * Compare a dec64 against a numeric, promoting the dec64 side.
 */
static inline int
dec64_cmp_numeric(Dec64 a, Numeric b)
{
	Numeric		an = dec64_to_numeric(a);

	return DatumGetInt32(DirectFunctionCall2(numeric_cmp,
											 NumericGetDatum(an),
											 NumericGetDatum(b)));
}

/*
 * Three-way comparison, dec64 on the left.
 */
Datum
dec64_numeric_cmp(PG_FUNCTION_ARGS)
{
	PG_RETURN_INT32(dec64_cmp_numeric(PG_GETARG_DEC64(0),
									  PG_GETARG_NUMERIC(1)));
}

/*
 * Three-way comparison, numeric on the left.
 */
Datum
numeric_dec64_cmp(PG_FUNCTION_ARGS)
{
	PG_RETURN_INT32(-dec64_cmp_numeric(PG_GETARG_DEC64(1),
									   PG_GETARG_NUMERIC(0)));
}

#define DEC64_NUM_CMP_OP(fname, op) \
PG_FUNCTION_INFO_V1(fname); \
Datum \
fname(PG_FUNCTION_ARGS) \
{ \
	PG_RETURN_BOOL(dec64_cmp_numeric(PG_GETARG_DEC64(0), \
									 PG_GETARG_NUMERIC(1)) op 0); \
}

DEC64_NUM_CMP_OP(dec64_numeric_lt, <)
DEC64_NUM_CMP_OP(dec64_numeric_le, <=)
DEC64_NUM_CMP_OP(dec64_numeric_eq, ==)
DEC64_NUM_CMP_OP(dec64_numeric_ne, !=)
DEC64_NUM_CMP_OP(dec64_numeric_ge, >=)
DEC64_NUM_CMP_OP(dec64_numeric_gt, >)

#define NUM_DEC64_CMP_OP(fname, op) \
PG_FUNCTION_INFO_V1(fname); \
Datum \
fname(PG_FUNCTION_ARGS) \
{ \
	PG_RETURN_BOOL(-dec64_cmp_numeric(PG_GETARG_DEC64(1), \
									  PG_GETARG_NUMERIC(0)) op 0); \
}

NUM_DEC64_CMP_OP(numeric_dec64_lt, <)
NUM_DEC64_CMP_OP(numeric_dec64_le, <=)
NUM_DEC64_CMP_OP(numeric_dec64_eq, ==)
NUM_DEC64_CMP_OP(numeric_dec64_ne, !=)
NUM_DEC64_CMP_OP(numeric_dec64_ge, >=)
NUM_DEC64_CMP_OP(numeric_dec64_gt, >)

PG_FUNCTION_INFO_V1(dec64_cmp_support);

/*
 * Convert a numeric to dec64 without raising an error, reporting whether the
 * value is representable exactly.  Used only at plan time, so it may take the
 * scenic route through numeric arithmetic.
 */
static bool
dec64_try_from_numeric(Numeric n, Dec64 *result)
{
	ErrorSaveContext escontext = {T_ErrorSaveContext};
	int32		scale;
	Numeric		scaled;
	int64		mant;

	if (numeric_is_nan(n) || numeric_is_inf(n))
		return false;

	scale = DatumGetInt32(DirectFunctionCall1(numeric_scale,
											  NumericGetDatum(n)));
	if (scale < 0 || scale > DEC64_MAX_SCALE)
		return false;

	/* n * 10^scale is integral by construction; refuse if it will not fit */
	scaled = numeric_mul_safe(n, int64_to_numeric(dec64_pow10[scale]),
							  (Node *) &escontext);
	if (SOFT_ERROR_OCCURRED(&escontext) || scaled == NULL)
		return false;

	mant = numeric_int8_safe(scaled, (Node *) &escontext);
	if (SOFT_ERROR_OCCURRED(&escontext))
		return false;

	if (mant > DEC64_MAX_MANT || mant < -DEC64_MAX_MANT)
		return false;

	*result = DEC64_MAKE(mant, scale);
	return true;
}

/*
 * Map a cross-type comparison function name onto its operator symbol.
 * Returns NULL if the name is not one this support function handles.
 */
static const char *
dec64_cmp_operator_name(const char *funcname)
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
 * Planner support for the mixed dec64/numeric comparison operators.
 *
 * This is the same move DuckDB makes when it binds an operator: look at what
 * the operands really are and substitute a cheaper implementation.  Here the
 * common shape is "amount > 5.00", where the literal is numeric only because
 * that is what the SQL grammar makes of an undecorated decimal constant.  If
 * the constant is representable in dec64 exactly, the comparison is rewritten
 * to the same-type operator, which is an integer compare rather than a
 * per-row numeric construction.
 *
 * When the constant does not fit -- too many decimals, out of range, NaN --
 * nothing is rewritten and the general cross-type path stands, so semantics
 * never depend on this optimisation firing.
 */
Datum
dec64_cmp_support(PG_FUNCTION_ARGS)
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
		Oid			dec64oid;
		Oid			opno;
		Dec64		converted;
		char	   *funcname;
		const char *opname;
		char	   *nspname;
		Const	   *newconst;

		if (list_length(expr->args) != 2)
			PG_RETURN_POINTER(NULL);

		larg = (Node *) linitial(expr->args);
		rarg = (Node *) lsecond(expr->args);

		/* exactly one side is numeric; that is the one we hope is constant */
		if (exprType(rarg) == NUMERICOID)
		{
			numarg = rarg;
			dec64oid = exprType(larg);
		}
		else
		{
			numarg = larg;
			dec64oid = exprType(rarg);
		}

		if (!IsA(numarg, Const))
			PG_RETURN_POINTER(NULL);
		numconst = (Const *) numarg;
		if (numconst->constisnull)
			PG_RETURN_POINTER(NULL);

		if (!dec64_try_from_numeric(DatumGetNumeric(numconst->constvalue),
									&converted))
			PG_RETURN_POINTER(NULL);

		funcname = get_func_name(expr->funcid);
		if (funcname == NULL)
			PG_RETURN_POINTER(NULL);
		opname = dec64_cmp_operator_name(funcname);
		if (opname == NULL)
			PG_RETURN_POINTER(NULL);

		/*
		 * Look the operator up in the schema that owns the function, not
		 * through search_path: the extension may not be on it.
		 */
		nspname = get_namespace_name(get_func_namespace(expr->funcid));
		if (nspname == NULL)
			PG_RETURN_POINTER(NULL);

		opno = OpernameGetOprid(list_make2(makeString(nspname),
										   makeString(pstrdup(opname))),
								dec64oid, dec64oid);
		if (!OidIsValid(opno))
			PG_RETURN_POINTER(NULL);

		newconst = makeConst(dec64oid, -1, InvalidOid, sizeof(int64),
							 Dec64GetDatum(converted), false, true);

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
 *						Rounding and truncation
 * ----------------------------------------------------------------
 */

PG_FUNCTION_INFO_V1(dec64_round);
PG_FUNCTION_INFO_V1(dec64_round_scale);
PG_FUNCTION_INFO_V1(dec64_trunc);
PG_FUNCTION_INFO_V1(dec64_trunc_scale);
PG_FUNCTION_INFO_V1(dec64_ceil);
PG_FUNCTION_INFO_V1(dec64_floor);
PG_FUNCTION_INFO_V1(dec64_scale);

/*
 * Truncate toward zero at the given scale.
 */
static Dec64
dec64_truncate_to(Dec64 v, int newscale)
{
	int			scale = DEC64_SCALE(v);
	int64		mant = DEC64_MANT(v);

	if (newscale < 0 || newscale > DEC64_MAX_SCALE)
		dec64_scale_unsupported(newscale);

	if (newscale >= scale)
		return dec64_rescale(v, newscale);

	return dec64_pack(mant / dec64_pow10[scale - newscale], newscale);
}

/*
 * round(dec64): to zero decimal places, half away from zero.
 */
Datum
dec64_round(PG_FUNCTION_ARGS)
{
	PG_RETURN_DEC64(dec64_rescale(PG_GETARG_DEC64(0), 0));
}

/*
 * round(dec64, int): to the given scale, half away from zero.  This is the
 * rounding rule EC 1103/97 art. 5, HMRC and NK RF art. 52 p. 6 all require.
 */
Datum
dec64_round_scale(PG_FUNCTION_ARGS)
{
	PG_RETURN_DEC64(dec64_rescale(PG_GETARG_DEC64(0), PG_GETARG_INT32(1)));
}

/*
 * trunc(dec64): drop the fractional part.
 */
Datum
dec64_trunc(PG_FUNCTION_ARGS)
{
	PG_RETURN_DEC64(dec64_truncate_to(PG_GETARG_DEC64(0), 0));
}

/*
 * trunc(dec64, int): truncate toward zero at the given scale.
 */
Datum
dec64_trunc_scale(PG_FUNCTION_ARGS)
{
	PG_RETURN_DEC64(dec64_truncate_to(PG_GETARG_DEC64(0), PG_GETARG_INT32(1)));
}

/*
 * ceil(dec64): smallest integral value not less than the argument.
 */
Datum
dec64_ceil(PG_FUNCTION_ARGS)
{
	Dec64		v = PG_GETARG_DEC64(0);
	int			scale = DEC64_SCALE(v);
	int64		mant = DEC64_MANT(v);
	int64		q;

	if (scale == 0)
		PG_RETURN_DEC64(v);

	q = mant / dec64_pow10[scale];
	if (mant > 0 && (mant % dec64_pow10[scale]) != 0)
		q++;

	PG_RETURN_DEC64(dec64_pack(q, 0));
}

/*
 * floor(dec64): largest integral value not greater than the argument.
 */
Datum
dec64_floor(PG_FUNCTION_ARGS)
{
	Dec64		v = PG_GETARG_DEC64(0);
	int			scale = DEC64_SCALE(v);
	int64		mant = DEC64_MANT(v);
	int64		q;

	if (scale == 0)
		PG_RETURN_DEC64(v);

	q = mant / dec64_pow10[scale];
	if (mant < 0 && (mant % dec64_pow10[scale]) != 0)
		q--;

	PG_RETURN_DEC64(dec64_pack(q, 0));
}

/*
 * scale(dec64): the number of fractional digits carried by the value.
 */
Datum
dec64_scale(PG_FUNCTION_ARGS)
{
	PG_RETURN_INT32(DEC64_SCALE(PG_GETARG_DEC64(0)));
}


/* ----------------------------------------------------------------
 *						Aggregates
 * ----------------------------------------------------------------
 *
 * sum() and avg() accumulate in 128 bits and return numeric, which is the
 * same "step up a tier" behaviour core applies to sum(bigint).  A dec64 sum
 * of many rows will routinely exceed 18 digits, so it must not stay in dec64.
 */

PG_FUNCTION_INFO_V1(dec64_accum);
PG_FUNCTION_INFO_V1(dec64_combine);
PG_FUNCTION_INFO_V1(dec64_serialize);
PG_FUNCTION_INFO_V1(dec64_deserialize);
PG_FUNCTION_INFO_V1(dec64_sum_final);
PG_FUNCTION_INFO_V1(dec64_avg_final);

/*
 * Transition state shared by sum() and avg(): a 128-bit accumulator held at
 * the widest scale seen so far, plus the row count.
 */
typedef struct Dec64AggState
{
	__int128	sum;			/* running total, at scale "scale" */
	int64		count;			/* number of non-null rows accumulated */
	int			scale;			/* scale the accumulator is held at */
	bool		seen;			/* has any row been accumulated? */
} Dec64AggState;

/*
 * Fetch the aggregate state, creating it in the aggregate context on first
 * call.
 */
static Dec64AggState *
dec64_agg_state(FunctionCallInfo fcinfo, int argno)
{
	Dec64AggState *state;
	MemoryContext aggctx;
	MemoryContext oldctx;

	if (!AggCheckCallContext(fcinfo, &aggctx))
		elog(ERROR, "aggregate function called in non-aggregate context");

	if (!PG_ARGISNULL(argno))
		return (Dec64AggState *) PG_GETARG_POINTER(argno);

	oldctx = MemoryContextSwitchTo(aggctx);
	state = (Dec64AggState *) palloc0(sizeof(Dec64AggState));
	MemoryContextSwitchTo(oldctx);

	return state;
}

/*
 * Add a 128-bit quantity held at scale "vscale" into the accumulator,
 * normalising whichever side carries the smaller scale.
 */
static void
dec64_agg_add(Dec64AggState *state, __int128 mant, int vscale)
{
	Assert(vscale >= 0 && vscale <= DEC64_MAX_SCALE);

	if (!state->seen)
	{
		state->sum = mant;
		state->scale = vscale;
		state->seen = true;
		return;
	}

	if (likely(vscale == state->scale))
		state->sum += mant;
	else if (vscale > state->scale)
	{
		state->sum *= (__int128) dec64_pow10[vscale - state->scale];
		state->sum += mant;
		state->scale = vscale;
	}
	else
		state->sum += mant * (__int128) dec64_pow10[state->scale - vscale];
}

/*
 * Transition function for sum() and avg().
 */
Datum
dec64_accum(PG_FUNCTION_ARGS)
{
	Dec64AggState *state = dec64_agg_state(fcinfo, 0);
	Dec64		v;

	if (PG_ARGISNULL(1))
		PG_RETURN_POINTER(state);

	v = PG_GETARG_DEC64(1);
	dec64_agg_add(state, (__int128) DEC64_MANT(v), DEC64_SCALE(v));
	state->count++;

	PG_RETURN_POINTER(state);
}

/*
 * Merge two partial states, for parallel aggregation.
 */
Datum
dec64_combine(PG_FUNCTION_ARGS)
{
	Dec64AggState *state1 = dec64_agg_state(fcinfo, 0);
	Dec64AggState *state2;

	if (PG_ARGISNULL(1))
		PG_RETURN_POINTER(state1);

	state2 = (Dec64AggState *) PG_GETARG_POINTER(1);
	if (!state2->seen)
		PG_RETURN_POINTER(state1);

	dec64_agg_add(state1, state2->sum, state2->scale);
	state1->count += state2->count;

	PG_RETURN_POINTER(state1);
}

/*
 * Serialise the state so a parallel worker can ship it to the leader.
 */
Datum
dec64_serialize(PG_FUNCTION_ARGS)
{
	Dec64AggState *state;
	StringInfoData buf;
	int64		hi;
	uint64		lo;

	if (!AggCheckCallContext(fcinfo, NULL))
		elog(ERROR, "aggregate function called in non-aggregate context");

	state = (Dec64AggState *) PG_GETARG_POINTER(0);

	hi = (int64) (state->sum >> 64);
	lo = (uint64) (state->sum & (__int128) UINT64_MAX);

	pq_begintypsend(&buf);
	pq_sendint64(&buf, hi);
	pq_sendint64(&buf, (int64) lo);
	pq_sendint64(&buf, state->count);
	pq_sendint32(&buf, state->scale);
	pq_sendbyte(&buf, state->seen ? 1 : 0);

	PG_RETURN_BYTEA_P(pq_endtypsend(&buf));
}

/*
 * Rebuild a state shipped by dec64_serialize().
 */
Datum
dec64_deserialize(PG_FUNCTION_ARGS)
{
	bytea	   *sstate = PG_GETARG_BYTEA_PP(0);
	Dec64AggState *state;
	StringInfoData buf;
	int64		hi;
	uint64		lo;
	MemoryContext aggctx;
	MemoryContext oldctx;

	if (!AggCheckCallContext(fcinfo, &aggctx))
		elog(ERROR, "aggregate function called in non-aggregate context");

	initStringInfo(&buf);
	appendBinaryStringInfo(&buf, VARDATA_ANY(sstate),
						   VARSIZE_ANY_EXHDR(sstate));

	oldctx = MemoryContextSwitchTo(aggctx);
	state = (Dec64AggState *) palloc0(sizeof(Dec64AggState));
	MemoryContextSwitchTo(oldctx);

	hi = pq_getmsgint64(&buf);
	lo = (uint64) pq_getmsgint64(&buf);
	state->sum = ((__int128) hi << 64) | (__int128) lo;
	state->count = pq_getmsgint64(&buf);
	state->scale = pq_getmsgint(&buf, 4);
	state->seen = (pq_getmsgbyte(&buf) != 0);

	pq_getmsgend(&buf);
	pfree(buf.data);

	if (state->scale < 0 || state->scale > DEC64_MAX_SCALE)
		elog(ERROR, "invalid scale %d in serialized dec64 state", state->scale);

	PG_RETURN_POINTER(state);
}

/*
 * Render a 128-bit mantissa held at "scale" as a numeric.
 */
static Numeric
dec64_int128_to_numeric(__int128 value, int scale)
{
	char		buf[64];
	char	   *end = buf + sizeof(buf);
	char	   *cur = end;
	unsigned __int128 u;
	bool		neg = (value < 0);
	int			i;

	Assert(scale >= 0 && scale <= DEC64_MAX_SCALE);

	u = neg ? (unsigned __int128) (-value) : (unsigned __int128) value;

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

	return DatumGetNumeric(DirectFunctionCall3(numeric_in,
											   CStringGetDatum(cur),
											   ObjectIdGetDatum(InvalidOid),
											   Int32GetDatum(-1)));
}

/*
 * Final function for sum(): returns numeric, or NULL for an empty input.
 */
Datum
dec64_sum_final(PG_FUNCTION_ARGS)
{
	Dec64AggState *state;

	if (!AggCheckCallContext(fcinfo, NULL))
		elog(ERROR, "aggregate function called in non-aggregate context");

	state = PG_ARGISNULL(0) ? NULL : (Dec64AggState *) PG_GETARG_POINTER(0);
	if (state == NULL || !state->seen)
		PG_RETURN_NULL();

	PG_RETURN_NUMERIC(dec64_int128_to_numeric(state->sum, state->scale));
}

/*
 * Final function for avg(): the sum divided by the count, computed in
 * numeric so the quotient keeps numeric's full division scale.
 */
Datum
dec64_avg_final(PG_FUNCTION_ARGS)
{
	Dec64AggState *state;
	Numeric		total;
	Numeric		count;

	if (!AggCheckCallContext(fcinfo, NULL))
		elog(ERROR, "aggregate function called in non-aggregate context");

	state = PG_ARGISNULL(0) ? NULL : (Dec64AggState *) PG_GETARG_POINTER(0);
	if (state == NULL || state->count == 0)
		PG_RETURN_NULL();

	total = dec64_int128_to_numeric(state->sum, state->scale);
	count = DatumGetNumeric(DirectFunctionCall1(int8_numeric,
												Int64GetDatum(state->count)));

	PG_RETURN_DATUM(DirectFunctionCall2(numeric_div,
										NumericGetDatum(total),
										NumericGetDatum(count)));
}
