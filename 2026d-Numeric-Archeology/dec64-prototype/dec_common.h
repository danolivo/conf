/*-------------------------------------------------------------------------
 *
 * dec_common.h
 *		Shared encoding for the fixed-point decimal tiers.
 *
 * Two types, one idea.  A value is a scaled integer whose scale travels
 * inside the value, in the low bits, because the type output function gets
 * only the datum -- PostgreSQL has no typmod-aware output path.
 *
 *		dec64	8 bytes, by value	 1 sign + 3 scale + 60 magnitude
 *							 18 significant digits, scale 0..7
 *		dec128	16 bytes, by reference	 1 sign + 4 scale + 123 magnitude
 *							 37 significant digits, scale 0..15
 *
 * The tiers mirror DuckDB's int64/int128 ladder, which one PostgreSQL type
 * cannot have because pg_type.typlen is a single value per type.  Here they
 * are two types, and the widening between them follows the convention core
 * already applies to smallint/integer/bigint: operators stay in their tier
 * and raise an error on overflow, aggregates widen.
 *
 * Why 18 and 37 rather than DuckDB's 38: one bit of each word is spent on
 * the scale.  For dec128 that bit buys scale up to 15, without which the
 * widest normative money format -- N(26.11) from the Russian FTS e-invoice
 * schema, 26 digits with 11 decimals -- would not fit at any precision.
 * A wide tier that cannot hold the only format needing it is not useful.
 *
 *-------------------------------------------------------------------------
 */
#ifndef DEC_COMMON_H
#define DEC_COMMON_H

#include "fmgr.h"

#ifndef HAVE_INT128
#error "the dec64/dec128 types require a native 128-bit integer type"
#endif

/* ----------------------------------------------------------------
 *						dec64
 * ----------------------------------------------------------------
 */

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

/* ----------------------------------------------------------------
 *						dec128
 * ----------------------------------------------------------------
 *
 * Stored as two 64-bit halves rather than a bare __int128 field: the datum is
 * only guaranteed 8-byte aligned (typalign 'd'), and dereferencing a
 * misaligned __int128 is undefined behaviour.  Two aligned loads and a shift
 * cost a couple of instructions and are always correct.
 */

typedef struct Dec128
{
	int64		hi;				/* high half of the packed value */
	uint64		lo;				/* low half; low 4 bits hold the scale */
} Dec128;

#define DEC128_MAX_SCALE		15
#define DEC128_MAX_PRECISION	37
#define DEC128_SCALE_BITS		4
#define DEC128_SCALE_MASK		((uint64) 0xf)

/* 10^18, the largest power of ten an int64 literal can carry */
#define DEC_P18					((__int128) INT64CONST(1000000000000000000))

/* 10^37, which needs 123 bits; 2^123 = 1.06 * 10^37, so it just fits */
#define DEC128_POW10_MAX		(DEC_P18 * DEC_P18 * 10)

/* widest mantissa the encoding holds */
#define DEC128_MAX_MANT			(DEC128_POW10_MAX - 1)

#define DatumGetDec128P(X)		((Dec128 *) DatumGetPointer(X))
#define Dec128PGetDatum(X)		PointerGetDatum(X)
#define PG_GETARG_DEC128_P(n)	DatumGetDec128P(PG_GETARG_DATUM(n))
#define PG_RETURN_DEC128_P(x)	PG_RETURN_POINTER(x)

/*
 * Unpack the stored halves into a 128-bit word.
 */
static inline __int128
dec128_packed(const Dec128 *v)
{
	return ((__int128) v->hi << 64) | (__int128) v->lo;
}

/*
 * Scale of a stored value.
 */
static inline int
dec128_scale(const Dec128 *v)
{
	return (int) (v->lo & DEC128_SCALE_MASK);
}

/*
 * Mantissa of a stored value.
 */
static inline __int128
dec128_mant(const Dec128 *v)
{
	return dec128_packed(v) >> DEC128_SCALE_BITS;
}

/*
 * Split a mantissa and scale back into the stored halves.
 */
static inline void
dec128_store(Dec128 *dst, __int128 mant, int scale)
{
	__int128	packed = ((__int128) mant << DEC128_SCALE_BITS) |
		(__int128) (unsigned int) scale;

	dst->hi = (int64) (packed >> 64);
	dst->lo = (uint64) packed;
}

/* powers of ten, shared by both tiers; defined in dec64.c */
extern const int64 dec64_pow10[DEC64_MAX_PRECISION + 1];

#endif							/* DEC_COMMON_H */
