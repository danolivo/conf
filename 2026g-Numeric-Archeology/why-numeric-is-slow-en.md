# Why is PostgreSQL's `numeric` type so slow?

The `numeric` type has existed in Postgres for more than 25 years. Over that time it has been through a great many optimizations and refinements. And yet operations on this type — aggregation in particular — still look rather inefficient.

Since the PostgreSQL community usually fixes problems that have a more or less simple and obvious solution, let's find out whether `numeric` has some structural limitations that stop the DBMS operators for this type from working faster.

To make the investigation more visual, let's also trace how DuckDB solves the same tasks — luckily, AI agents have made source-code analysis and testing much easier.

One thing to keep in mind here: DuckDB is built exclusively for OLAP queries. That means, as I [noted earlier](https://www.pgedge.com/blog/why-is-numeric-so-popular-in-postgresql-databases), it places weaker demands on the exactness of operations — and, as you will see below, it actively uses this to make query execution more efficient.

### Contents

- [The teaser](#teaser)
- [Four decisions Postgres pays for](#choices)
- [How an exact decimal type is built inside](#format)
  * [The `numeric` implementation in PostgreSQL](#format-postgres)
  * [The `DECIMAL` implementation in DuckDB](#format-duckdb)
- [Pass by value or by reference](#datum)
- [Tuple deforming](#deform)
- [The scale of an intermediate result](#scale)
  * [Managing the precision of intermediate results in `numeric`](#scale-postgres)
  * [Managing the precision of intermediate results in `decimal`](#scale-duckdb)
- [The cost of being decimal](#decimal-cost)
- [Where we are going](#conclusion)

### The teaser

So as not to make empty claims, let me draw your attention to the two EXPLAINs below. The first one groups the rows of a table by a set of 12 columns of type `numeric`.

```
 Finalize HashAggregate  (actual time=4320 rows=591894 loops=1)
   Group Key: _q_000_f_010rref, _q_000_f_008_rrref, ...
   Batches: 1  Memory Usage: 1835033kB
   Buffers: shared hit=111632
   ->  Gather  (actual time=1441 rows=1582591 loops=1)
         Buffers: shared hit=111632
         ->  Partial HashAggregate  (actual time=868 rows=263765.17 loops=6)
               Group Key: _q_000_f_010rref, _q_000_f_008_rrref, ...
               Batches: 1  Memory Usage: 704537kB
               ->  Parallel Seq Scan on tt4 t2  (actual time=68 rows=500000.00 loops=6)
 Execution Time: 4512.880 ms
```

The second is exactly the same query, but the columns have type `double precision`: for the sake of the test we have neglected exactness.

```
 Finalize HashAggregate  (actual time=1553 rows=591894 loops=1)
   Group Key: _q_000_f_008_type, _q_000_f_008_rtref, ...
   Batches: 1  Memory Usage: 196641kB
   Buffers: shared hit=125000
   ->  Gather  (actual time=596 rows=1577001 loops=1)
         Buffers: shared hit=125000
         ->  Partial HashAggregate  (actual time=337 rows=262833 loops=6)
               Group Key: _q_000_f_008_type, _q_000_f_008_rtref, ...
               Batches: 1  Memory Usage: 90145kB
               Buffers: shared hit=125000
               ->  Parallel Seq Scan on tt4_dbl t2  (actual time=28 rows=500000 loops=6)
 Execution Time: 1620.060 ms
```

Almost a threefold speedup! Note that the `double precision` variant had to scan more disk pages (125 thousand versus 111 thousand). However, aggregation over `numeric` needs 9 times more memory. What is the reason for such a negative effect on performance after 25+ years of optimizing this type? Can it be reduced somehow, or removed altogether? Let's dig into the fundamentals and try to understand what is going on.

It would seem the question is about decimal arithmetic. However, three independent attempts to make a fast decimal type as an extension — [pgDecimal](https://github.com/okbob/pgDecimal) by Pavel Stehule, [pgdecimal2](https://github.com/vitesse-ftian/pgdecimal) by Feng Tian, and [fixeddecimal](https://github.com/2ndQuadrant/fixeddecimal) by 2ndQuadrant — have stalled, although each of them did speed up the arithmetic. So it is not only about arithmetic, and the situation is a bit more complicated.

### Four decisions Postgres pays for

Before diving into a complex construction, it is useful to see the problem as a whole.

[Every](https://www.pgedge.com/blog/why-is-numeric-so-popular-in-postgresql-databases) well-known DBMS has an exact decimal type, and those that have a fast one made it fast in a very similar way: the value is stored as an ordinary integer, and the decimal point lives separately, in the column description. This is (probably) how `DECIMAL` works in SQL Server, DuckDB and ClickHouse, and how decimal works in Arrow and Parquet. PostgreSQL went another way, deliberately taking the following key decisions:

1. **The representation does not depend on the declaration.** Everyone else picks the width of the value from the declared precision: a narrow number takes two to four bytes, a wide one eight or sixteen. In PostgreSQL the width is a property of the type, not of the column, so `numeric` has to be variable-length.

2. **The scale lives in the value, not in the column description.** That is why `1.5` and `1.50` differ even in a `numeric` column for which no scale is specified.

3. **The scale of a result is computed from the data, not in advance.** How many digits a division produces depends on the numbers themselves, not only on their types.

4. **A flexible upper bound on precision.** Formally `numeric` does have a limit — 131072 digits before the decimal point and 16383 after — but no practical value comes anywhere near it: room for the result is allocated by what came out, not by the declaration, and getting an overflow error at runtime is practically impossible.

Taken separately, each decision looks reasonable, and almost every one is dictated by the exactness requirements typical of various industries. But each has a price, and what follows is about what this price is made of. Each of the next sections takes one item of this list: [representation](#format) covers the first; [passing by value](#datum) and [tuple deforming](#deform) are its consequences; [the scale of an intermediate result](#scale) covers the second and the third; [the cost of being decimal](#decimal-cost) is what remains even if you give up all four.

I will compare against the popular DuckDB mostly for contrast. It took exactly the opposite decisions on all four points, and against that contrast one can see exactly where Postgres loses performance. And yes, its code is free to read and analyze.

**A short glossary of PostgreSQL internals**

| Term    | Meaning                                                                        |
| ------- | ------------------------------------------------------------------------------ |
| varlena | a variable-length value: first a header with the length, then the data         |
| detoast | unpacking a value before working with it                                       |
| `Datum` | the machine word in which a value travels through the query executor           |
| typmod  | the precision and scale declared in the schema, like `(15,2)`                  |
| dscale  | how many digits after the decimal point to print — stored in the value itself  |
| deform  | splitting a table row into separate columns                                    |

### How an exact decimal type is built inside

#### The `numeric` implementation in PostgreSQL

General-purpose processors count in binary, and `0.1` in binary is an infinite repeating fraction — exactly like `1/3` in decimal. So `double precision` stores not `0.1` but the nearest representable binary number, and the famous `0.1 + 0.2` gives `0.30000000000000004`.

However, money (meters of cable in a warehouse, utility bills) is counted in decimal: cents, interest rates and rounding rules are written down in decimal digits. This is exactly what an exact decimal type is for — so that `0.1` is exactly `0.1`, and rounding happens at the digit the regulation talks about.

Hence the first decision: the digits stored are decimal. By itself it dictates neither the width of the value nor the position of the decimal point — `DECIMAL` in DuckDB is decimal too, and fixed-width at the same time — but this is where the design of `numeric` starts.

**Digits, but not one at a time.** It would be naive to spend a byte per digit (although an artifact of such a representation [can be found](https://github.com/postgres/postgres/blob/REL_18_STABLE/src/backend/utils/adt/numeric.c#L78) in the PostgreSQL code): a byte holds a number up to 255, and we would write 0–9 into it. PostgreSQL takes two bytes per group and stores a number from 0 to 9999 in it. The result is positional notation in base 10000 — the same as the familiar base-10 notation, only there are ten thousand "digits" instead of ten.

Why exactly [10000](https://github.com/postgres/postgres/blob/REL_18_STABLE/src/backend/utils/adt/numeric.c#L96)? It comes from the long-multiplication algorithm: the product of two "digits" has to fit into an `int`, and purely arithmetically any even base below `sqrt(INT_MAX)` ≈ 46341 would do. Among those, a power of ten is chosen — with it, printing and rounding to a decimal digit stay trivial — and the largest such power is exactly 10000.

**Finding where the fraction starts.** Storing the position of the decimal point as "so many digits from the start" is inconvenient: very large and very small numbers would accumulate long chains of zeros. Instead, a **weight** is stored — the position of the very first "digit", counted in powers of 10000. The value of the number is restored by the following formula:

```
value = digit[0]·10000^weight + digit[1]·10000^(weight−1) + digit[2]·10000^(weight−2) + …
```

For example, `123456.00` looks like this:

```
digits:     12        3456
power:    10000¹  ·  10000⁰            weight = 1
          120000  +    3456   =  123456
```

The benefit shows on small numbers: `0.0000000012` is one "digit" `1200` with weight `−3`, not a pile of zeros.

**How to print it: dscale.** Here things get unfamiliar. The numbers `1.5` and `1.50` are equal but print differently, while their "digits" are the same. So the difference has to be stored separately — that is what `dscale` is for, meaning "how many digits after the decimal point to show":

```
1.5     digits: [1, 5000]   weight: 0   dscale: 1   →  prints "1.5"
1.50    digits: [1, 5000]   weight: 0   dscale: 2   →  prints "1.50"
```

Byte for byte these are different values, yet comparison is obliged to treat them as equal. Various difficulties stem from this. For example, comparison and hashing must ignore `dscale`, while printing must remember it.

Note that the above holds for a value declared as plain `numeric`. In a `numeric(15,2)` column, the cast on write sets `dscale = 2` for both values, and they become identical byte for byte.

**Sign and special values.** There is no separate place for the sign — it hides in the [two high bits](https://github.com/postgres/postgres/blob/REL_18_STABLE/src/backend/utils/adt/numeric.c#L167) of the header, together with the format flag:

```
00 → positive           NUMERIC_POS
01 → negative           NUMERIC_NEG
10 → short format       NUMERIC_SHORT
11 → special value      NUMERIC_SPECIAL — NaN, +Infinity, −Infinity
```

Special values have no digits at all — only the two-byte header remains (three bytes in a tuple, six as a standalone value). And as a bonus: zeros at both ends of the number are dropped, so `1.0000` is stored as a single "digit" `1` with `dscale = 4`.

**Packing.** There is a so-called [packed storage format](https://github.com/postgres/postgres/blob/REL_18_STABLE/src/backend/utils/adt/numeric.c#L108) for a `numeric` value. If the number of digits is small (no more than ~62), a one-byte length header is used and the value is stored without alignment. Longer numbers use the standard four-byte header. Each particular value can be in either of these two formats. The operators working on `numeric` expect the standard header, so every function must be ready at any moment to "unpack" an incoming number with a one-byte header into the standard representation.

Clearly, in most practical applications the numbers are short. So the unpacking is usually performed on every number — and that means, among other things, a dynamic allocation of extra memory plus a copy.

The positive side effect is this: small `numeric` values are sometimes cheaper to store than even `bigint` — their "packed" representation can be noticeably shorter than eight bytes, as [`pg_column_size`](https://www.postgresql.org/docs/current/functions-admin.html#FUNCTIONS-ADMIN-DBSIZE) shows:

```sql
CREATE TABLE t(x numeric(15,2));
INSERT INTO t VALUES (123456.00);

SELECT pg_column_size(x) FROM t;              -- 7
SELECT pg_column_size(123456.00::numeric);    -- 10
```

As a result, a `numeric` value is a small self-sufficient structure: a format flag, a sign, a weight, a scale and a chain of base-10000 "digits". It can tell everything about itself — both what it equals and how to print it — and therefore it can sit in a column about which nothing is declared except the word `numeric`.

On the one hand, this speaks of reliability and the ability to control data integrity; on the other, of extra costs for storage and processing. To understand how it could have been done differently, let's look at the approach of DuckDB, which, because of its different application area, can afford to be more aggressive in implementing an exact decimal type.

#### The `DECIMAL` implementation in DuckDB

Starting from the same point as PostgreSQL — exact decimal values are needed — DuckDB went down the road of storing decimal numbers as integers. `DECIMAL(15,2)` with the value `123456.00` is stored as the integer `12345600`. And that's it. No base-10000 digits, no weight, no `dscale`:

```
value = integer / 10^scale
```

The decimal point exists only at the moment of printing. Here is the wording from the [MonetDB documentation](https://www.monetdb.org/documentation/user-guide/sql-manual/data-types/base-types/), which is where this construction came to DuckDB from:
> "The decimal types are represented as fixed length integers, whose decimal point is produced during result rendering."

The scale thus becomes a property of the column type. Let's check on a live DuckDB:

```sql
select typeof(1.5), typeof(1.50), typeof(1.500);
--     DECIMAL(2,1)  DECIMAL(3,2)  DECIMAL(4,3)
```

The distinction that PostgreSQL keeps in `dscale` inside the value, DuckDB keeps in the type name. Different spellings of the same number are different types, not different bytes. The consequence shows up immediately once you put them into one column:

```sql
CREATE TABLE t AS SELECT * FROM (VALUES (1.5),(1.50),(1.500)) v(x);
-- column type: DECIMAL(4,3)
-- values:      '1.500', '1.500', '1.500'
```

So the column has one type, hence one scale and one printed form. The same three values in a `numeric` column would keep `dscale` 1, 2 and 3 and print differently.

This way, the optimal representation format for a number can be chosen in advance — and DuckDB makes active use of this, implementing a ladder of carriers: `INT16`, `INT32`, `INT64`, `INT128` for precision up to 4, 9, 18 and 38 digits. The ladder is described in the [documentation](https://duckdb.org/docs/stable/sql/data_types/numeric) and defined in the code by a single set of specializations, [`decimal.hpp`](https://github.com/duckdb/duckdb/blob/main/src/include/duckdb/common/types/decimal.hpp):
> "Internally, decimals are represented as integers depending on their specified `WIDTH`"

The choice is made once, at query planning time; after that a monomorphic function over a concrete integer runs in the loop. The width is visible from outside too: when exporting to [Parquet](https://github.com/apache/parquet-format/blob/master/LogicalTypes.md#decimal), `DECIMAL(15,2)` is written with the physical type `INT64`, while `DECIMAL(20,2)` is already a byte array. The 18 and 38 boundaries in Parquet and DuckDB coincide not by accident: both systems run into the same machine integers.

As a result, the number is stored in an ordinary byte representation. And although such a number may take more space than a packed `numeric`, the basic arithmetic (addition and multiplication) for it is much simpler.

However, a fixed format means a hard ceiling on the maximum value. And, apparently for this reason — to reach the industry-standard 38 digits — DuckDB has no special values `NaN`, `+Infinity`, `−Infinity`. Going over the 38-digit ceiling means a runtime error.

### Pass by value or by reference

Inside PostgreSQL every value travels as a [`Datum`](https://www.postgresql.org/docs/current/xfunc-c.html#XFUNC-C-BASETYPE) — a machine word, eight bytes on a 64-bit platform. If a type fits into these eight bytes, it is passed *by value*: a `bigint` lives right inside the `Datum`, that is, in fact in a processor register. If it does not fit, a pointer is passed. The type becomes *pass-by-reference*.

A `numeric` value is always passed by reference. So the result of every arithmetic operation on `numeric` has to be put somewhere, which implies a [memory allocation](https://github.com/postgres/postgres/blob/master/src/backend/utils/mmgr/README) per operation. Let's compare what this means for addition:

```
bigint:   a + b  →  one instruction, result in a register

numeric:  a + b  →  align the scales
                 →  add
                 →  check the limits
                 →  palloc for the result
                 →  write the result to memory
```

Moreover, even if we constrained the `numeric` implementation but kept the very idea of the approach — a large scale and a flexible bound on the intermediate result — the value would still not fit into eight bytes and would not start being passed by value. Thomas Munro noticed exactly this obstacle in 2017, discussing DECFLOAT in the thread ["Decimal64 and Decimal128"](https://www.postgresql.org/message-id/CAEepm%3D1-roLc59TdBQPvZQQBbNs-sFRjri-HySQ2B8GSuTD7oQ%40mail.gmail.com):
> "DECFLOAT(9) [= 32 bit] and DECFLOAT(17) [= 64 bit] could in theory be passed by value. Of course we don't have a way to make those pass-by-value and yet pass DECFLOAT(34) [= 128 bit] by reference! That is where I got stuck last time I was interested in this subject, because that seems like the place where we would stand to gain a bunch of performance, and yet the limited technical factors seems to be very well baked into Postgres."

DuckDB chose a different path. The physical carrier is selected by the declared width of the column.

| width | carrier | bytes |
| ----- | ------- | ----- |
| 1–4   | INT16   | 2     |
| 5–9   | INT32   | 4     |
| 10–18 | INT64   | 8     |
| 19–38 | INT128  | 16    |

At precision up to 18 digits the value lands in a machine integer: no `Datum`, no pointer, no `palloc`. How cheap this is can be seen from a measurement on 20 million rows (M4 Pro, single thread): `SUM` over `DECIMAL(18,2)` — 8.7 ms, over `BIGINT` — 8.5 ms. The ratio is 1.02: **there is no surcharge for being decimal at all**; the scale lives in the catalog, and at runtime this is an ordinary int64.

However, already on `DECIMAL(19,2)`, on exactly the same data, the benchmark shows ~880 ms. A 100-fold jump at the 18/19-digit boundary. So the payment is not for decimal logic but for the width of the value. In this case, then, DuckDB is fast mostly because it has int64 underneath.

In PostgreSQL the length of a type and the way it is passed (by reference or by value) are characteristics of the type, written in the system catalog, not properties of the column. So a storage ladder inside `numeric` cannot be built in the current architecture at all.

### Tuple deforming

Before comparing anything, the values have to be taken out of the row. This operation is called *deform*, and for `numeric` it is more expensive too.

A row in PostgreSQL is a header, a NULL bitmap, and then the column values one after another, with no separators. To reach the twentieth column you need to know its offset from the start. If all columns are fixed-width, the offset is computed arithmetically and cached in the table descriptor — once, for its entire lifetime:

```
20 int4 columns — the offsets are known in advance

┌────┬────┬────┬────┬────┬─── … ───┬────┐
│ c1 │ c2 │ c3 │ c4 │ c5 │         │c20 │
└────┴────┴────┴────┴────┴─── … ───┴────┘
  0    4    8   12   16              76

offset of c20 = 19 × 4 — computed and cached once.
```

If the width is variable, this doesn't work. The rule is written right in the [code](https://github.com/postgres/postgres/blob/master/src/backend/access/common/tupdesc.c) that builds the table descriptor: cache offsets only up to the first column of non-fixed length. The comment there says exactly that — "don't cache offsets beyond fixed-width attributes". And this is precisely the `numeric` case. The offset cache breaks off at the first such column, and every offset after it has to be recomputed, reading the header of every preceding value:

```
20 numeric columns — every value has its own length

┌──────┬─────┬────────┬──────┬─── … ───┬─────┐
│  c1  │ c2  │   c3   │  c4  │         │ c20 │
└──────┴─────┴────────┴──────┴─── … ───┴─────┘
  0      7     12       21              ???

to find the offset of c20, read the headers of c1…c19 — on every row, again.
```

This, by the way, is the aspect that is being actively worked on in core right now, although from the other side. David Rowley spent two development cycles on deform: commit [`d28dff3f`](https://github.com/postgres/postgres/commit/d28dff3f) (PostgreSQL 18) replaced the 104-byte `FormData_pg_attribute` in the table descriptor with a 16-byte [`CompactAttribute`](https://github.com/postgres/postgres/blob/REL_18_STABLE/src/include/access/tupdesc.h) and gave "~10% TPS on OLAP aggregation over a 16-column table, up to ~25%", because fewer cache lines are touched during deforming. The follow-up — ["More speedups for tuple deformation"](https://www.postgresql.org/message-id/CAApHDvpoFjaj3+w_jD5uPnGazaw41A71tVJokLDJg2zfcigpMQ@mail.gmail.com) — was committed to PostgreSQL 19: 21% on average, up to 44%. Tellingly, half of the test cases in that benchmark differ in exactly one thing: whether the first column is `INT` or `TEXT`. So the effect of a variable-length column on performance is noticed in the community.

But this does not remove the cause itself. Variable length is a direct consequence of the decision, back in 1998, that `numeric` must hold numbers of arbitrary precision. In other words, by making `numeric` a fixed-length type we could make tuple traversal a little cheaper.

DuckDB has no notion of tuple deforming at all, since storage is columnar. A value is addressed by an index into an array, and no offsets need computing. However, they have some analogue of this problem too. With compression enabled (and it is enabled by default), DuckDB shows a large difference between scanning `DECIMAL(18,2)` and `DECIMAL(19,2)` columns. On the query:

```
count(*) where v > 5.00
```

the average execution time is 5–7 ms for the "narrow" and ~380 ms for the "wide" storage variant. If compression is switched off ([`SET force_compression='uncompressed'`](https://duckdb.org/docs/stable/configuration/overview)), this gap disappears. Since there is practically no arithmetic here, the only thing that can play a role is unpacking int128, which turns out to be a fairly expensive operation.

So in both engines, delivering the value to the operation costs more than the operation itself. For Postgres it is deform, for them it is decompression; what they share is that the payment is for width and storage format, not for arithmetic.

On the other hand, the integer representation opens access to fast operations, and the result comes out counter-intuitive — worth keeping in mind every time someone advises "take float, it's faster". On top of that, decimal columns in DuckDB get [BitPacking](https://duckdb.org/2022/10/28/lightweight-compression#bit-packing), while `DOUBLE` gets the more expensive [ALP](https://dl.acm.org/doi/10.1145/3626717).

So "exactness costs resources" is rather a property of a particular implementation than a property of exact decimal arithmetic.

### The scale of an intermediate result

We have covered the rules of packing, representation and storage. However, in a query plan the original values are used only as input for operations whose precision and scale can differ a lot from the input. This, in turn, determines the computational cost and the amount of extra memory needed to store intermediate results. How do our two subjects handle this question?

#### Managing the precision of intermediate results in `numeric`

With `bigint` everything is simple: the result of an operation on two `bigint`s is either a `bigint` or an overflow error. There is no third option, so there is exactly one check — the processor's overflow flag.

With `numeric` this won't do:

- multiplying two numbers of 32 significant digits each gives up to 64 digits;
- division may not terminate at all — `1/3` in decimal notation is infinite.

So **every** operation must have a rounding policy. And rounding breaks the familiar algebraic properties: a sum stays associative, but a product after rounding does not. Hence the restrictions on reordering operations in aggregates and on parallelization.

In PostgreSQL the scale of an arithmetic result is derived from the data as follows:

```sql
select 1.5 + 1.50;    -- 3.00        (2 digits)
select 2.0 * 3.00;    -- 6.000       (3 digits)
select 10.0 / 4;      -- 2.5000000000000000   (16 digits)
```

Here it follows the SQL standard — for addition the result scale is the maximum of the argument scales, for multiplication their sum. And what about division?

```sql
select 1 / 3::numeric;         -- 0.33333333333333333333    (20 digits)
select 1000000 / 3::numeric;   -- 333333.333333333333       (12 digits)
select 0.001 / 3::numeric;     -- 0.00033333333333333333    (20 digits)
```

The number of digits after the decimal point differs, although the argument types are the same. The scale for division is chosen so that there are at least 16 significant digits.

**A comment from the [PostgreSQL sources](https://github.com/postgres/postgres/blob/REL_18_STABLE/src/backend/utils/adt/numeric.c)** (see `select_div_scale`)
> The result scale of a division isn't specified in any SQL standard. For PostgreSQL we select a result scale that will give at least NUMERIC_MIN_SIG_DIGITS significant digits, so that numeric gives a result no less accurate than float8; but use a scale not less than either input's display scale.

Why might the scale of intermediate results matter at all? I became interested in this aspect after the paper ["The FastLanes Compression Layout"](https://www.vldb.org/pvldb/vol16/p2132-afroozeh.pdf), PVLDB 2023, and in particular after the following sentence:
> "We think scans in next-gen database systems should not decompress columns eagerly to their SQL type, which often is a wide integer (e.g., a decimal stored in 64-bits), but rather to the smallest type that makes the values processable by query operators."

That is, a specialized internal representation of values in the executor could potentially bring a profit both in memory and through efficient arithmetic operations. Given the number of transitional states in a complex query tree, the effect could be considerable.

Since every particular column value in PostgreSQL has its own scale, the result of an arithmetic operation is determined dynamically each time, at execution. At planning time one could try to predict the maximum precision and scale for addition and multiplication, but for the other operations that is rather difficult: an upper bound gives far too large numbers. At the same time, Postgres cannot fix a single scale for the result of each operation in advance — the semantics of `numeric` do not allow it:

```sql
select 1.0 = 1.00;                              -- true
select (1.0)::text = (1.00)::text;              -- false
select hash_numeric(1.0) = hash_numeric(1.00);  -- true
```

Having fixed the scale, we would lose the distinction. For most applications this may turn out to be unimportant, but in any case such "nailing down" of the scale can only be done within a different, new data type.

Thus the uncertainty of scale leads to extra overhead: comparison must first bring both numbers to a common scale, and the hash must be computed not from the bytes but from the canonical form of the number.

And this in turn means that operations on `numeric` have a fundamental data-dependent branch. And a data-dependent branch is what the processor and the compiler hate most. Uniform code like "compare a hundred numbers in a row" the processor can execute in batches, several values per cycle (SIMD), and the branch predictor never misses on it. As soon as an "if the scales differ, align first" appears inside, batches are no longer possible, and every mispredicted branch costs tens of cycles. For `bigint` the compiler can unroll the comparison into two or three instructions; for `numeric` it is forced to leave a full function with branches.

By the way, about aggregates. The intermediate state of `sum(numeric)` may not be a value of the same type — the sum grows with the number of rows. Internally a separate structure, [`NumericSumAccum`](https://github.com/postgres/postgres/blob/REL_18_STABLE/src/backend/utils/adt/numeric.c#L354), was invented for this. The comment on it explains the design better than any retelling:
> It uses 32-bit integers to store the digits, instead of the normal 16-bit integers (with NBASE=10000). This way, we can safely accumulate up to NBASE - 1 values without propagating carry, before risking overflow of any of the digits.

And the second half of the same comment:
> Positive and negative values are accumulated separately, in 'pos_digits' and 'neg_digits'.

That is, carries are done not on every row but once per 9999 values, and positives and negatives accumulate in two separate buffers. It is no accident that `sum(bigint)` returns `numeric` — for the very same reason.

#### Managing the precision of intermediate results in `decimal`

In DuckDB the scale of an operation is computed and fixed at planning time:

```sql
select typeof(1.8), typeof(1.9), typeof(1.8*1.9), 1.8*1.9;
-- DECIMAL(2,1)  DECIMAL(2,1)  DECIMAL(4,2)  3.42
```

Architecturally this became possible because the type is attached to the result column rather than stored in the value: at runtime, intermediate values travel in a batch that has one type — the scale is stored once, not with every number.

So the precise formulation of the difference is this. `numeric` is a self-describing value: it carries everything needed to compare it, add it and print it, and therefore it can sit in a column declared simply as `numeric`, with no precision at all. `DECIMAL` in DuckDB is a self-describing type, and the type is attached not only to the column but to every node of the expression tree; it never descends into the value. That is why there is no parameterless `DECIMAL` there — if you omit the parameters, `DECIMAL(18,3)` is substituted.

So how did DuckDB manage what PostgreSQL did not? A bold and innovative-minded team of developers?

Not quite — DuckDB did not solve the scale problem; it cancelled it.

For addition and multiplication the result scale is computed from the declared scales of the operands and is known at binding time: `+` gives `max(s1,s2)`, `*` gives `s1+s2`. Not a single look at the data; the planner knows the width of the result exactly. The price is that the scale is preserved but the precision is not: the result width is pressed against the boundary of the inputs' physical container, just to avoid moving to the expensive tier. A comment in the DuckDB sources explains the decision [as follows](https://github.com/duckdb/duckdb/blob/v1.5.5/src/function/scalar/operator/arithmetic.cpp#L218):
> we don't automatically promote past the hugeint boundary to avoid the large hugeint performance penalty

Once more, because you don't believe it on first reading: "we do not widen past the hugeint boundary in order to avoid the large hugeint performance penalty".

Multiplication has type inference [of its own](https://github.com/duckdb/duckdb/blob/v1.5.5/src/function/scalar/operator/arithmetic.cpp#L836) — and there stands exactly the same limit on `MAX_WIDTH_INT64`, only without an explanatory comment. In the plainest terms and by example, the result scale comes out like this:

```
DECIMAL(18,2) * DECIMAL(18,2)  →  DECIMAL(18,4)   ← should be 36,4
DECIMAL(20,2) * DECIMAL(20,2)  →  DECIMAL(38,4)   ← input is already int128, the rule did not fire
```

What does this mean in practice? Let's see.

```sql
SELECT cast(999999999999999999 AS decimal(18,0)) * cast(999999999999999999 AS decimal(18,0));
-- Out of Range Error: Overflow in multiplication of DECIMAL(18)
```

That is, a formally correct query fails with a runtime error, because the engine sacrificed exactness and reliability for the sake of speed.

And for division no scale is chosen at all — division goes to floating point. The [documentation](https://duckdb.org/docs/stable/sql/data_types/numeric#arithmetic-and-internal-representation) says so directly, in the section "Arithmetic and Internal Representation":
> Division of fixed-point decimals does not typically produce numbers with finite decimal expansion. Therefore, DuckDB uses approximate floating-point arithmetic for all divisions that involve fixed-point decimals and accordingly returns floating-point data types.

Let's look at what types are computed for specific operations:

```
typeof(DECIMAL(10,2) / DECIMAL(10,2))  →  DOUBLE          1/3 = 0.3333333333333333
typeof(AVG(DECIMAL(10,2)))             →  DOUBLE
typeof(DECIMAL(10,2) % DECIMAL(10,2))  →  DECIMAL(10,2)   the remainder stays exact
```

So `AVG` over a money column in DuckDB is a double. EU Regulation 1103/97 with its "shall not be rounded or truncated" is not satisfied on such a type. All the work `numeric` does to determine the division scale carefully and predictably, DuckDB simply does not do — and along with it loses exact decimal division, which cannot be recovered in this design.

The general lesson from this pair of decisions will be useful to anyone planning a fixed width: unifying the scale and capping the precision of operations are things that look reasonable separately but together lead to a potentially big problem.

### The cost of being decimal

Everything discussed above follows from the four decisions: they could have been taken differently. What comes next cannot be. Counting in decimal on binary hardware means constantly multiplying and dividing by powers of ten, and nobody gets rid of this work. It can only be moved: either into the arithmetic or into the output.

`numeric` pays in arithmetic and prints almost for free. DuckDB and MonetDB are the other way round: for them, as the MonetDB documentation says, the decimal point is "produced during result rendering". It is the same bill, paid in different places. What follows is what it consists of, and why the choice of where to pay matters more than it seems.

**Where the multiplications by ten come from.** To add `1.5` and `1.50`, they must first be brought to the same scale: the first number has one digit after the point, the second has two, so `15` has to be multiplied by `10` to get `150`, and only then added. Shifting a value by one digit is multiplying by 10, by two digits — by 100, by **k** digits — by 10^k. Here k is the number of decimal digits the value has to be shifted by.

Rounding is the same thing, only in the other direction: `round(x, 2)` for a number with five digits after the point is "divide by 10³, round, multiply back", that is, k = 3.

And here is the main point: k is never written in the query. When aligning scales it is the difference between the `dscale` of two values; when rounding it is the difference between the value's `dscale` and the requested precision. Both become known only when the numbers are already in hand.

The processor does not like division: it is the slowest of the arithmetic instructions, tens of cycles. So compilers avoid it — if the code says `x / 1000`, the compiler replaces the division with a multiplication by a "magic" constant and a shift, and that is already a few cycles. But the trick only works when the divisor is written right in the code: the compiler must see the concrete number to compute that constant for it. And in `numeric` the code says not "divide by 1000" but "divide by ten to the power k" — so the power has to be taken from a table and a general, slow multiplication performed. Or, if it is a division, a real division.

**What `numeric` gets for this.** Printing is almost free: the digits already lie in decimal groups of four, and [`numeric_out`](https://github.com/postgres/postgres/blob/REL_18_STABLE/src/backend/utils/adt/numeric.c#L816) simply writes them out into a string. With a binary coefficient this won't work — there, printing is exactly the chain of divisions by a power of ten, the very operation we just feared. And here is what matters in this trade: output happens on every returned row, while arithmetic happens only if the query has arithmetic. A `SELECT` without computations prints everything and computes nothing.

So every time someone suggests "just store numeric as int128", it is worth asking whether they have counted the side effects.

**And what if we do store it in a 128-bit integer?** This is what all the "fast numeric" projects look like. Two pieces of news await them.

The first is good, but not as good as it seems. On both mass-market architectures the processor works with 64-bit numbers, and the compiler assembles 128-bit ones out of them. Multiplication assembles cheaply — three ordinary multiplications and two additions, all inlined right into the code. But there is no "128 by 128" division in the instruction set: on x86-64 the widest is [`divq`](https://www.felixcloutier.com/x86/div), a 128-by-64 division, and it faults if the quotient doesn't fit into 64 bits. So the compiler turns a division of two 128-bit numbers into a call to the library function [`__udivti3`](https://gcc.gnu.org/onlinedocs/gccint/Integer-library-routines.html).

Thus division is not something that gets fixed by moving to int128. What speeds up is not the division algorithm but everything around it: `palloc`, unpacking the short header, computing the result scale. But exactly the same things speed up addition too — so division has nothing to do with it.

The second piece of news is bad, and it is about the ceiling. To divide exactly with scale s, one has to compute `a · 10^s / b` — the dividend is first widened by s digits. `numeric` simply grows its digit array at this point. int128 has only 38 digits for everything, and there is nowhere to grow:

```
DECIMAL(18,2) / DECIMAL(18,2), result with 6 digits
    → dividend 18 + 6 = 24 digits → int64 is too small, int128 needed

DECIMAL(38,2) / DECIMAL(38,2), result with 6 digits
    → dividend 38 + 6 = 44 digits → even int128 is too small
```

The working condition comes out like this: the precision of the arguments plus the scale of the result must not exceed 38. Anything that doesn't fit requires either an int256 in the intermediate computation, or a runtime error, or a `double`. DuckDB, being an analytical DBMS, can afford this; a DBMS for everyday banking transactions hardly can. So exact decimal division and a hard ceiling combine poorly in principle.

DuckDB suffers less for the simple reason that it touches powers of ten less often. Multiplication and division by 10^k are needed only when aligning scales, and whether the scales match is known already at binding time, from the declared types. If they match, the loop degenerates into ordinary integer addition, and all the decimal-ness disappears from the hot path.

Next comes a trick that anyone who does decide to build a fast `numeric` must remember. An overflow check is a branch per element, and it gets in the way of vectorization. The DuckDB optimizer [tries to prove](https://github.com/duckdb/duckdb/blob/v1.5.5/src/function/scalar/operator/arithmetic.cpp) from the column's min/max statistics that overflow is impossible here (see `PropagateNumericStats`), and, if it succeeds, swaps the operator implementation for a version without the check. After that, what remains in the loop is an unconditional integer addition, which the compiler vectorizes automatically. This is what makes exact decimal arithmetic cheap.

And a final detail, after which the cost of being decimal looks quite different. In DuckDB a change of *width* costs about as much as a change of *scale* does in PostgreSQL. `DECIMAL(9,2) * DECIMAL(9,2)` gives `DECIMAL(18,4)`, the result crosses the int32 → int64 boundary, and both operands have to be cast: 40.0 ms against 13.9 ms for `DECIMAL(18,2)`, whose result stays in int64. The narrow type turned out three times slower than the wide one.

Summing up, there are no cheap decimal types — there are types whose expensive case happens less often. `numeric` is built so that the expensive case happens almost always: the scales come from the data, so alignment is needed constantly. DuckDB is built so that the expensive case happens at the container boundary — less often, but when it does, it is paid threefold.

### Where we are going

Let's return to where we started. Now, for each of the technical decisions, the price the DBMS has to pay becomes clear:

| decision                                       | what we pay with                                                                                                                              |
| ---------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------- |
| The representation does not depend on the declaration | variable length: a `palloc` per operation, unpacking the short header, the offset cache breaking off during tuple deforming            |
| The scale lives in the value                   | comparison and hashing must align scales — a data-dependent branch where `bigint` has a single instruction                                     |
| The result scale is derived from the data      | the size of an intermediate result is unknown until runtime; hence also the specialized `NumericSumAccum` optimization for aggregates          |
| The ceiling is pushed beyond the horizon       | room for the result is allocated by fact, not by declaration                                                                                  |

So the `numeric` format pays for powers of ten in arithmetic and prints almost for free. And the proposal "let's store numeric as int128" does not look very promising, since division will not get much cheaper from it, printing will get more expensive, and exact division will hit a ceiling beyond which it simply does not exist. Under the current paradigm of the exact decimal type, optimizations should be sought not so much in the arithmetic as in the wrapping around it — `palloc`, unpacking, scale computation.

So the diagnosis is made: `numeric` is slow not because of decimal arithmetic but because of four deliberate decisions, each backed by a sound argument. What to do about it, and whether anything can be done at all, is a question for further research.

