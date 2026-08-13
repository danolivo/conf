#!/usr/bin/env python3
"""
Analyse the Phase 4 benchmark output.

Deliberately stdlib-only: no numpy/scipy, so it runs on a bare VM without a
pip step that could fail halfway through and lose the run.

Statistics chosen to match what the spec asks for (distributions, not means):

  * median + MAD rather than mean + stdev, because query latency is
    right-skewed and a mean is dominated by the tail.
  * Mann-Whitney U (normal approximation with tie correction) rather than a
    t-test, because it assumes neither normality nor equal variance.
  * bootstrap 95% CI on the *ratio of medians*, because the decision is about
    effect size, and a p-value alone cannot distinguish "no effect" from
    "underpowered". A CI that brackets 1.0 tightly is evidence *for* no
    difference; a wide one just means more reps are needed.
"""
import csv
import math
import random
import sys
from collections import defaultdict

random.seed(20260811)  # reproducible CIs

BOOT = 10000


def median(xs):
    s = sorted(xs)
    n = len(s)
    if n == 0:
        return float("nan")
    m = n // 2
    return s[m] if n % 2 else (s[m - 1] + s[m]) / 2.0


def mad(xs):
    """Median absolute deviation, scaled to be comparable to a stdev."""
    m = median(xs)
    return 1.4826 * median([abs(x - m) for x in xs])


def mann_whitney_u(a, b):
    """Two-sided p-value, normal approximation with tie correction.

    Returns 1.0 for samples too small to say anything, rather than a
    misleadingly small number.
    """
    na, nb = len(a), len(b)
    if na < 5 or nb < 5:
        return 1.0

    combined = sorted([(v, 0) for v in a] + [(v, 1) for v in b])
    ranks = [0.0] * len(combined)
    tie_groups = []
    i = 0
    while i < len(combined):
        j = i
        while j + 1 < len(combined) and combined[j + 1][0] == combined[i][0]:
            j += 1
        avg_rank = (i + j) / 2.0 + 1.0
        for k in range(i, j + 1):
            ranks[k] = avg_rank
        if j > i:
            tie_groups.append(j - i + 1)
        i = j + 1

    ra = sum(r for r, (_, g) in zip(ranks, combined) if g == 0)
    ua = ra - na * (na + 1) / 2.0
    ub = na * nb - ua
    u = min(ua, ub)

    mu = na * nb / 2.0
    n = na + nb
    tie_corr = sum(t**3 - t for t in tie_groups)
    var = na * nb / 12.0 * ((n + 1) - tie_corr / float(n * (n - 1)))
    if var <= 0:
        return 1.0
    z = (u - mu) / math.sqrt(var)
    # two-sided normal tail
    return max(0.0, min(1.0, math.erfc(abs(z) / math.sqrt(2))))


def boot_ratio_ci(a, b, iters=BOOT, alpha=0.05):
    """Bootstrap CI for median(b)/median(a) -- i.e. dec128 relative to stock.

    <1 means dec128 is faster.
    """
    if not a or not b:
        return (float("nan"), float("nan"))
    ratios = []
    for _ in range(iters):
        ra = median([random.choice(a) for _ in a])
        rb = median([random.choice(b) for _ in b])
        if ra > 0:
            ratios.append(rb / ra)
    if not ratios:
        return (float("nan"), float("nan"))
    ratios.sort()
    lo = ratios[int((alpha / 2) * len(ratios))]
    hi = ratios[min(len(ratios) - 1, int((1 - alpha / 2) * len(ratios)))]
    return (lo, hi)


def linreg_slope(pairs):
    """Least-squares slope of y on x. Intercept (scan overhead) discarded."""
    n = len(pairs)
    if n < 2:
        return float("nan")
    sx = sum(p[0] for p in pairs)
    sy = sum(p[1] for p in pairs)
    sxx = sum(p[0] * p[0] for p in pairs)
    sxy = sum(p[0] * p[1] for p in pairs)
    den = n * sxx - sx * sx
    if den == 0:
        return float("nan")
    return (n * sxy - sx * sy) / den


def verdict(lo, hi, thresh=0.05):
    """Mechanical verdict from the CI, per README's decision rule."""
    if math.isnan(lo) or math.isnan(hi):
        return "no data"
    if hi < 1 - thresh:
        return f"FASTER ({(1-hi)*100:.0f}-{(1-lo)*100:.0f}% better)"
    if lo > 1 + thresh:
        return f"SLOWER ({(lo-1)*100:.0f}-{(hi-1)*100:.0f}% worse)"
    if lo > 1 - thresh and hi < 1 + thresh:
        return "no difference (within +/-5%)"
    return "inconclusive - raise REPS"


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else "results.csv"
    rows_arg = None

    data = defaultdict(list)          # (build,tier,query,ops) -> [ms]
    with open(path) as fh:
        for r in csv.DictReader(fh):
            data[(r["build"], r["tier"], r["query"], int(r["ops"]))].append(
                float(r["ms"])
            )

    meta = ""
    try:
        with open(path + ".meta") as fh:
            meta = fh.read()
            for line in meta.splitlines():
                if "rows=" in line:
                    for tok in line.split():
                        if tok.startswith("rows="):
                            rows_arg = int(tok.split("=")[1])
    except FileNotFoundError:
        pass

    out = []
    out.append("# Phase 4 benchmark results: dec128 numeric vs stock numeric\n")
    if meta:
        out.append("```\n" + meta.strip() + "\n```\n")

    out.append("\nRatio is dec128 / stock: **below 1.0 means dec128 is faster**.")
    out.append("CI is a bootstrap 95% interval on the ratio of medians.\n")

    # ---------------------------------------------------------------- Tier A
    a_queries = sorted({k[2] for k in data if k[1] == "A"})
    if a_queries:
        out.append("\n## Tier A - marginal cost per operation")
        out.append("\nSlope of execution time against operation count, so the "
                   "scan and aggregation overhead lands in the discarded "
                   "intercept. This is the control: if it shows nothing, the "
                   "rest is not worth reading.\n")
        if rows_arg:
            out.append(f"| op | stock ns/row | dec128 ns/row | ratio |")
            out.append("|---|---|---|---|")
            for qn in a_queries:
                slopes = {}
                for build in ("stock", "dec128"):
                    pairs = []
                    for (b, t, q, ops), vals in data.items():
                        if b == build and t == "A" and q == qn:
                            pairs.append((ops, median(vals)))
                    slopes[build] = linreg_slope(sorted(pairs))
                # ms for all rows -> ns for one row
                ns = {k: (v * 1e6) / rows_arg for k, v in slopes.items()}
                ratio = (ns["dec128"] / ns["stock"]
                         if ns.get("stock") else float("nan"))
                out.append(f"| {qn} | {ns['stock']:.2f} | {ns['dec128']:.2f} "
                           f"| {ratio:.2f}x |")

    # ------------------------------------------------------------ Tier B / P
    for tier, title in (("B", "Tier B - query level"),
                        ("D", "Tier D - sorts, grouping, windows"),
                        ("P", "Tier B(parallel) - 2 workers")):
        qs = sorted({k[2] for k in data if k[1] == tier})
        if not qs:
            continue
        out.append(f"\n## {title}\n")
        out.append("| query | stock ms (MAD) | dec128 ms (MAD) | ratio | "
                   "95% CI | p | verdict |")
        out.append("|---|---|---|---|---|---|---|")
        for qn in qs:
            a = [v for (b, t, q, _), vals in data.items()
                 if b == "stock" and t == tier and q == qn for v in vals]
            d = [v for (b, t, q, _), vals in data.items()
                 if b == "dec128" and t == tier and q == qn for v in vals]
            if not a or not d:
                continue
            ma, md = median(a), median(d)
            ratio = md / ma if ma else float("nan")
            lo, hi = boot_ratio_ci(a, d)
            p = mann_whitney_u(a, d)
            pstr = "<0.001" if p < 0.001 else f"{p:.3f}"
            out.append(
                f"| {qn} | {ma:.1f} ({mad(a):.1f}) | {md:.1f} ({mad(d):.1f}) "
                f"| {ratio:.2f}x | [{lo:.2f}, {hi:.2f}] | {pstr} "
                f"| {verdict(lo, hi)} |"
            )

    # ---------------------------------------------------------------- Tier C
    try:
        base = path[:-4] if path.endswith(".csv") else path
        with open(base + "-sizes.csv") as fh:
            sizes = defaultdict(dict)
            for r in csv.DictReader(fh):
                sizes[r["metric"]][r["build"]] = int(r["bytes"])
        out.append("\n## Tier C - storage and WAL\n")
        out.append("| metric | stock | dec128 | change |")
        out.append("|---|---|---|---|")
        for metric, per in sizes.items():
            s, d = per.get("stock"), per.get("dec128")
            if not s or not d:
                continue
            pct = (d / s - 1) * 100
            out.append(f"| {metric} | {s/2**20:.0f} MiB | {d/2**20:.0f} MiB "
                       f"| {pct:+.1f}% |")
    except FileNotFoundError:
        pass

    # ------------------------------------------------ within-engine cost of
    # exactness.  The DuckDB note argues cross-engine ratios are meaningless
    # and the honest comparison is numeric against the engine's own integer
    # types.  Do that here, on the patched build.
    def med(build, q):
        vals = [v for (b, t, qq, _), vs in data.items()
                if b == build and t == "B" and qq == q for v in vs]
        return median(vals) if vals else None

    pairs = [("sum(v)", "sum", "ref_money_sum", "ref_bigint_sum",
              "ref_float8_sum"),
             ("8 adds", "sum_8add", "ref_money_8add", "ref_bigint_8add", None),
             ("multiply by 2", "num_mul2", "ref_money_mul2", None, None)]
    rows = []
    for label, qn, qmoney, qbig, qf8 in pairs:
        for build in ("stock", "dec128"):
            n = med(build, qn)
            if n is None:
                continue
            cells = []
            for ref in (qmoney, qbig, qf8):
                r = med(build, ref) if ref else None
                cells.append(f"{n/r:.2f}x" if r else "-")
            rows.append((label, build, n, cells))
    if rows:
        out.append("\n## Cost of exactness, measured inside one engine\n")
        out.append("numeric divided by the engine's own reference types. "
                   "`money` is int64 pass-by-value with the scale in the "
                   "catalog, i.e. structurally what DuckDB does for "
                   "DECIMAL(18,2).\n")
        out.append("| operation | build | numeric ms | vs money | vs bigint | vs float8 |")
        out.append("|---|---|---|---|---|---|")
        for label, build, n, cells in rows:
            out.append(f"| {label} | {build} | {n:.1f} | " + " | ".join(cells) + " |")

    out.append("\n---\n")
    out.append("Reminder on interpretation: a single headline number would be "
               "misleading here, because the two builds do not differ "
               "uniformly - fixed-width storage makes arithmetic cheaper and "
               "makes unpacking a stored value more expensive. Read the per-"
               "query rows, and weight them by the real query mix before "
               "drawing a conclusion.")

    text = "\n".join(out) + "\n"
    with open("report.md", "w") as fh:
        fh.write(text)
    print(text)


if __name__ == "__main__":
    main()
