#!/usr/bin/env python3
"""
Independent correctness oracle for the dec128 numeric representation.

Rather than diffing against stock PostgreSQL, this computes the expected result
with Python's `decimal` module at unlimited precision and applies dec128's
documented rules on top:

  * add/sub  -- exact; result scale is max(s1, s2)
  * multiply -- exact product at scale s1+s2; if that exceeds
                MAX_STORED_SCALE the result is rounded half-away-from-zero
                down to it
  * any result needing more than MAX_MANT_DIGITS significant digits must be
    rejected with "value overflows numeric format"
  * text output keeps exactly `scale` fractional digits

Comparing against an oracle rather than against stock is the stronger test:
stock and the patch could agree on a wrong answer, and stock's range is wider
so a straight diff drowns in expected range differences.

Usage: oracle-dec128.py PSQL_BINARY [PORT] [CASES]
"""
import random
import subprocess
import sys
from decimal import Decimal, getcontext, localcontext, ROUND_HALF_UP

MAX_STORED_SCALE = 31
MAX_MANT_DIGITS = 36

getcontext().prec = 200

PSQL = sys.argv[1] if len(sys.argv) > 1 else "psql"
PORT = sys.argv[2] if len(sys.argv) > 2 else "5432"
CASES = int(sys.argv[3]) if len(sys.argv) > 3 else 3000

random.seed(20260813)

SETUP = """
\\set ON_ERROR_STOP on
create or replace function try(expr text) returns text language plpgsql as $$
declare r text;
begin
  execute 'select (' || expr || ')::text' into r;
  return r;
exception when others then
  return 'ERR';
end$$;
"""


def run_sql(sql):
    """Run a script through psql, returning stdout lines."""
    p = subprocess.run(
        [PSQL, "-p", PORT, "-d", "postgres", "-X", "-A", "-t", "-q", "-f", "-"],
        input=sql, text=True, capture_output=True,
    )
    if p.returncode != 0:
        sys.exit("psql failed:\n" + p.stderr)
    return p.stdout.splitlines()


def digits_of(d):
    """Significant digits of a Decimal's unscaled integer form."""
    t = d.as_tuple()
    if t.exponent > 0:  # not produced here, but be explicit
        return len(t.digits) + t.exponent
    return len(t.digits)


def as_scaled(d, scale):
    """Mantissa of d when written with exactly `scale` fractional digits."""
    return int((d.scaleb(scale)).to_integral_value())


def fits(d, scale):
    """Does d, stored at `scale`, fit dec128?"""
    m = abs(as_scaled(d, scale))
    return scale <= MAX_STORED_SCALE and len(str(m)) <= MAX_MANT_DIGITS


def fmt(d, scale):
    """Decimal text with exactly `scale` fractional digits, as numeric_out does."""
    sign = "-" if d < 0 else ""
    m = abs(as_scaled(d, scale))
    s = str(m).rjust(scale + 1, "0")
    if scale == 0:
        return sign + s
    return sign + s[:-scale] + "." + s[-scale:]


def gen_operand():
    """A representable value, biased towards the boundaries that matter."""
    scale = random.choice(
        [0, 2, 2, 4, 15, 16, 17, 20, 20, 20, 30, 31, 31]
        + [random.randint(0, MAX_STORED_SCALE)]
    )
    ndig = random.randint(1, MAX_MANT_DIGITS)
    lo = 10 ** (ndig - 1) if ndig > 1 else 0
    mant = random.randint(lo, 10 ** ndig - 1)
    if random.random() < 0.4:
        mant = -mant
    return Decimal(mant).scaleb(-scale), scale


def expected_addsub(a, sa, b, sb, sub):
    scale = max(sa, sb)
    with localcontext() as ctx:
        ctx.prec = 200
        r = a - b if sub else a + b
    return (fmt(r, scale) if fits(r, scale) else "ERR")


def expected_mul(a, sa, b, sb):
    with localcontext() as ctx:
        ctx.prec = 200
        r = a * b
    scale = sa + sb
    if scale > MAX_STORED_SCALE:
        q = Decimal(1).scaleb(-MAX_STORED_SCALE)
        with localcontext() as ctx:
            ctx.prec = 200
            ctx.rounding = ROUND_HALF_UP  # half away from zero for signed input
            r = r.quantize(q)
        scale = MAX_STORED_SCALE
    return (fmt(r, scale) if fits(r, scale) else "ERR")


def lit(d, scale):
    return "'" + fmt(d, scale) + "'::numeric"


def check_div(label, expr, a, b, got):
    """Division is checked as a property, not against an expected string.

    Reproducing select_div_scale() in Python would just be a second copy of the
    same code, and a copy that agrees with the original proves nothing.  What
    actually matters is weaker and more useful: whatever scale the server
    chooses, the digits must be the correctly rounded quotient at that scale,
    and the scale must be one dec128 can store.
    """
    if got == "ERR":
        return None                      # genuine overflow; not checked here
    if "." in got:
        scale = len(got.split(".")[1])
    else:
        scale = 0
    if scale > MAX_STORED_SCALE:
        return f"scale {scale} exceeds {MAX_STORED_SCALE}"
    q = Decimal(got)
    with localcontext() as ctx:
        ctx.prec = 200
        exact = a / b
        err = abs(q - exact)
        half = Decimal(1).scaleb(-scale) / 2
    if err > half:
        return f"off by {err} at scale {scale}, tolerance {half}"
    return None


def main():
    cases = []          # (label, sql_expr, expected)
    div_cases = []      # (label, sql_expr, a, b)
    for _ in range(CASES):
        a, sa = gen_operand()
        b, sb = gen_operand()
        la, lb = lit(a, sa), lit(b, sb)
        cases.append((f"add {a}@{sa} + {b}@{sb}",
                      f"{la} + {lb}", expected_addsub(a, sa, b, sb, False)))
        cases.append((f"sub {a}@{sa} - {b}@{sb}",
                      f"{la} - {lb}", expected_addsub(a, sa, b, sb, True)))
        cases.append((f"mul {a}@{sa} * {b}@{sb}",
                      f"{la} * {lb}", expected_mul(a, sa, b, sb)))
        cases.append((f"out {a}@{sa}", la, fmt(a, sa)))
        # try() renders through ::text, so a boolean comes back as
        # 'true'/'false' rather than psql's 't'/'f'.
        cases.append((f"cmp {a}@{sa} ? {b}@{sb}",
                      f"({la} < {lb})",
                      "true" if a < b else "false"))
        if b != 0:
            div_cases.append((f"div {a}@{sa} / {b}@{sb}", f"{la} / {lb}", a, b))

    # Every case goes through try(), so an overflow error does not abort the
    # batch and lands as the literal string 'ERR' in the result column.
    sql = [SETUP]
    for _, expr, _ in cases:
        sql.append("select try('%s');" % expr.replace("'", "''"))
    for _, expr, _, _ in div_cases:
        sql.append("select try('%s');" % expr.replace("'", "''"))
    lines = run_sql("\n".join(sql))

    want_lines = len(cases) + len(div_cases)
    if len(lines) != want_lines:
        sys.exit(f"expected {want_lines} result lines, got {len(lines)}")

    bad = 0
    for (label, expr, want), got in zip(cases, lines[:len(cases)]):
        if got != want:
            bad += 1
            if bad <= 25:
                print(f"MISMATCH {label}\n  expr: {expr}\n  want: {want}\n  got : {got}")

    div_errs = 0
    for (label, expr, a, b), got in zip(div_cases, lines[len(cases):]):
        if got == "ERR":
            div_errs += 1
            continue
        why = check_div(label, expr, a, b, got)
        if why:
            bad += 1
            if bad <= 25:
                print(f"MISMATCH {label}\n  expr: {expr}\n  got : {got}\n  why : {why}")

    print(f"\n{len(cases)} exact cases + {len(div_cases)} divisions "
          f"({div_errs} of them overflowed), {bad} mismatches")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
