# Binary, ternary, or is it actually quaternary logic in Postgres functions?
How an attempt to introduce a new optimisation ran into the problem of preserving `ERROR-freedom` of PostgreSQL functions.

## TL;DR

A fundamental principle of query optimisation is that the result must not depend on the plan. PostgreSQL enforces this in part by tracking function volatility: volatile expressions restrict where the optimiser may push predicates and sort keys. But volatility isn't the only way an expression can be plan-sensitive — a stable function can also throw a runtime error on inputs that a different plan would have filtered out.

In this post we explore the issue through the lens of a concrete optimisation — _outer join sort pushdown_ — which enables pushing Sort nodes below joins to benefit ORDER BY ... LIMIT queries. The problem it exposed, however, is more general and already latent in the core planner. We outline a solution based on extending PostgreSQL's existing planner support function (`prosupport`) machinery with a new request type that lets functions declare themselves unsafe for early evaluation. We'd welcome feedback and criticism from the community on this approach.

## Plan independence and function volatility

A query's result must not depend on how the planner chooses to execute it.
PostgreSQL's primary tool for guaranteeing this is
[**function volatility**](https://www.postgresql.org/docs/current/xfunc-volatility.html).
Every function is classified as IMMUTABLE, STABLE, or VOLATILE:

| Category   | Guarantee                                    |
|------------|----------------------------------------------|
| IMMUTABLE  | Same result forever for same inputs           |
| STABLE     | Same result within one statement               |
| VOLATILE   | May return different results each call         |

Volatility controls what the optimiser is allowed to do.  For VOLATILE
functions, the key rule is: the optimizer must not move the expression to a
place that changes how many times it gets evaluated.  A call to `random()` must
run once per row — collapsing it into a single pre-evaluated constant or
feeding it into an index condition would change the result.  STABLE and
IMMUTABLE expressions don't have this restriction: since their value doesn't
change (within a statement or ever), the optimizer can safely evaluate them
once and reuse the result, push them into index scans, or hoist them out of
loops.

A quick example makes the difference visible.  Say we have a table with a
timestamp index:

```sql
CREATE TABLE events (ts timestamptz, data text);
CREATE INDEX ON events (ts);
```

A filter using `now()` (STABLE) can be evaluated once and fed straight to the
index — the optimizer knows it won't change mid-statement:

```sql
EXPLAIN (COSTS OFF)
SELECT * FROM events WHERE ts > now() - interval '1 hour';
```
```
 Index Scan using events_ts_idx on events
   Index Cond: (ts > (now() - '01:00:00'::interval))
```

But throw in `random()` (VOLATILE) and the picture changes.  Now the expression
is different for every row, so the index is useless — the optimizer has to
scan everything and check the filter at runtime:

```sql
EXPLAIN (COSTS OFF)
SELECT * FROM events WHERE ts > now() - random() * interval '1 hour';
```
```
 Seq Scan on events
   Filter: (ts > (now() - (random() * '01:00:00'::interval)))
```

This works well for what it's designed to do: stop the optimizer from reusing
values that change between calls.  But it has a blind spot.

## The blind spot: stable functions that error

Take a type cast like `CAST(val AS integer)`.  It's IMMUTABLE — the conversion
from text to integer is deterministic, no dependencies on the environment.  Not
volatile, not set-returning, parallel-safe.  Every optimizer safety gate says
"go ahead."

But this cast is what we'll call a
[`"partial"` function](https://en.wikipedia.org/wiki/Partial_function)
(borrowing from mathematics): it throws a runtime error when the input isn't a
valid integer
(e.g., `'42.1'`).  Volatility says nothing about this.  The optimizer treats
the cast as freely movable — and can push it somewhere it sees inputs the
original plan would have filtered out.

This isn't a theoretical worry.  It already happens in vanilla PostgreSQL
through plain old predicate pushdown.  Here's an example:

```sql
CREATE TABLE raw_data (id integer PRIMARY KEY, val text);
CREATE TABLE numbers (id integer references raw_data(id));
INSERT INTO raw_data VALUES (1, '42'), (2, '42.1');
INSERT INTO numbers VALUES (1);
```

The subquery joins `raw_data` with `numbers`, producing only id=1 (val='42').
The outer query applies `CAST(val AS integer) > 0` to the join result.
Reading the query as written, you'd expect the cast to never see val='42.1' —
the join should filter it out first.  (The SQL standard doesn't actually
guarantee this — evaluation order is implementation-defined — but the query
text strongly suggests it.)

```sql
SELECT q.val FROM
  (SELECT val FROM raw_data JOIN numbers USING (id)) AS q(val)
WHERE CAST(val AS integer) > 0;
```

But the optimizer pushes the predicate into the `raw_data` scan:

```
 Hash Join
   Hash Cond: (numbers.id = raw_data.id)
   ->  Seq Scan on numbers
   ->  Hash
         ->  Seq Scan on raw_data
               Filter: ((val)::integer > 0)
```

That filter hits **every** `raw_data` row — including id=2 where val='42.1'.
Boom:

```
ERROR:  invalid input syntax for type integer: "42.1"
```

This is the classical relational algebra equivalence `σ_p(R ⋈ S) = σ_p(R) ⋈ S`.
It works when `p` only touches columns of `R` and is a `"total"` predicate —
defined for all inputs.  When `p` is `"partial"` — when it can error on some
inputs — the equivalence breaks: the left side errors on rows that the right
side would have quietly filtered away.

The optimizer has no way to know this.  The cast is IMMUTABLE, the predicate
only references `raw_data` columns, and the pushdown is perfectly valid under
standard relational algebra.  The trouble is that the algebra assumes all
expressions are `"total"`.

This isn't just a PostgreSQL quirk.  The SQL Server team documented the same
problem back in 2006 in their blog post
["Predicate ordering is not guaranteed"](https://techcommunity.microsoft.com/blog/sqlserver/predicate-ordering-is-not-guaranteed/383075):
a view that converts varchar to int only for certain row categories blows up
when the optimizer evaluates the conversion before the category filter.  Their
recommended workaround — use CASE expressions to guard the conversion — is
essentially a manual way for users to enforce `"totality"` at the query level.
The problem is well known across database engines; what's missing is a
systematic solution.

## A new optimisation that widened the gap

With that background, here's how a new optimisation
([branch](https://github.com/danolivo/pgdev/tree/enforce-presorted-scan-on-query-pathkeys))
made things worse.

### The idea: sorting before the join

Using the same tables, consider an ORDER BY ... LIMIT over a join:

```sql
SELECT * FROM raw_data JOIN numbers USING (id)
ORDER BY val
LIMIT 10;
```

Normally PostgreSQL sorts the entire join result, then grabs 10 rows:

```
 Limit
   ->  Sort
         Sort Key: raw_data.val
         ->  Hash Join
               Hash Cond: (raw_data.id = numbers.id)
               ->  Seq Scan on raw_data
               ->  Hash
                     ->  Seq Scan on numbers
```

Our optimisation pushes the Sort below the join.  If the inner side is small
or efficiently indexed, a NestLoop with a pre-sorted outer wins — and the
LIMIT can propagate down, enabling a top-N heapsort:

```
 Limit
   ->  Nested Loop
         ->  Sort
               Sort Key: raw_data.val
               ->  Seq Scan on raw_data
         ->  Seq Scan on numbers
               Filter: (id = raw_data.id)
```

When ORDER BY uses a plain column like `val`, this is perfectly safe — the Sort
just reorders rows the scan was already producing.  Faster query, same
semantics.  Everybody wins.

### Where it breaks

But what happens when ORDER BY uses a `"partial"` expression?

```sql
SELECT * FROM raw_data JOIN numbers USING (id)
ORDER BY CAST(val AS integer)
LIMIT 10;
```

Without the optimisation, this works fine: the INNER JOIN drops id=2 (no match
in `numbers`), and the Sort only sees val='42'.  With the optimisation, the
Sort gets pushed below the join — now it evaluates `CAST(val AS integer)` on
**every** `raw_data` row, including id=2, before the join gets a chance to
filter it out:

```
ERROR:  invalid input syntax for type integer: "42.1"
```

Same `"partial"`-function problem as with predicate pushdown, just triggered by
a different transformation.  The original plan would have eliminated the bad
row before the cast ran.  The new optimisation broke that by evaluating it
earlier.

## Why this matters in practice

These examples might look contrived, but they point to a real risk for
production systems.  A query that works today can start throwing errors after a
PostgreSQL upgrade — not because anyone changed the query or the data, but
because the optimizer got smarter.

Every major release brings new optimisations: join reordering heuristics,
incremental sort, Memoize, partitionwise joins.  Each one gives the optimizer
more freedom to rearrange the plan tree.  A query that survived for years
because the old planner always put the Sort above the join might blow up under
a newer planner that's clever enough to push it down.  The user sees a stable
query break on upgrade, with zero schema or data changes — and no obvious
explanation.

That's not a great look for a DBMS.  Whether a query succeeds or fails
shouldn't depend on which optimisations the planner happens to use.  When it
does, users lose trust in upgrades and start pinning plans or disabling
features — which defeats the whole point of having an optimizer.

To be fair, the SQL standard explicitly permits implementations to
differ on whether a query errors or succeeds, depending on evaluation order.
That's a remarkably honest admission — but from a user's perspective, it's cold
comfort.  The gap is real enough that even major DBMSes have to publish
[workaround guides](https://sqlsunday.com/2016/02/17/intermittent-conversion-issues/)
telling users how to protect themselves from optimizer-induced errors.

## The root cause: a missing dimension in function classification

The predicate pushdown and sort pushdown examples are really the same problem
in different clothes.  The optimizer applies transformations that are valid
under standard relational algebra — which assumes expressions are `"total"` —
but break when expressions can error.

PostgreSQL classifies functions along one axis: **volatility**.  But there's a
second, independent axis: `"totality"`.

In mathematics, a `"total"` function is defined for every element of its
domain.  A `"partial"` function may be undefined — i.e., it errors — for some
inputs:

| Function        | Volatility | Totality |
|-----------------|------------|----------|
| `abs(x)`        | IMMUTABLE  | `"total"`    |
| `x + y`         | IMMUTABLE  | `"partial"` (overflow) |
| `CAST(x AS int)`| IMMUTABLE  | `"partial"` (invalid format) |
| `x / y`         | IMMUTABLE  | `"partial"` (division by zero) |
| `x::regclass`   | STABLE     | `"partial"` (invalid name) |
| `random()`      | VOLATILE   | `"total"`    |

You might wonder: isn't `"partial"` just "more volatile than VOLATILE" — a
fourth step on the volatility ladder?  It's not.  Volatility is about **value
stability**: IMMUTABLE means "never changes," STABLE means "constant within a
statement," VOLATILE means "might differ on every call."  Each step tells the
optimizer **when** it may evaluate the expression — how aggressively it can
cache and reuse.

`"Totality"` asks a different question: **can the evaluation blow up?**  And
these two questions are genuinely independent:

- `random()` is maximally volatile but never fails.  The optimizer has to
  re-evaluate it every time, but that's always safe.
- `1/x` is immutable but can error.  The optimizer can cache it, push it into
  an index — and one bad input kills the query.

If `"partial"` were just "super-volatile," the optimizer would refuse to touch
these expressions at all — treating `CAST(val AS integer)` like `random()`.
But that's way too conservative.  The cast **is** deterministic; the optimizer
**should** cache it, use it in index conditions, pre-evaluate it with
constants.  We just don't want it moved somewhere it sees unfiltered data.

Bottom line: volatility controls **when** to evaluate (once? per row? per
call?).  `"Totality"` controls **where** to evaluate (above which filters?).
They're orthogonal dimensions, not points on the same scale.

## From ternary to quaternary logic

SQL already extends classical Boolean logic to handle one kind of
indeterminacy: **NULL**.  A comparison involving NULL produces UNKNOWN, giving
SQL its famous three-valued logic (TRUE, FALSE, UNKNOWN).

But runtime errors are a fourth case that this logic doesn't cover.  When
`CAST('42.1' AS integer)` runs, it doesn't produce TRUE, FALSE, or UNKNOWN —
it produces **ERROR**, which kills the entire query.

A quaternary logic would make ERROR a first-class truth value with explicit
propagation rules.  The key insight is that evaluation order matters — the left
operand is evaluated first, and short-circuiting can only help when the left
side already determines the result:

| Expression        | Result | Why |
|-------------------|--------|-----|
| `FALSE AND ERROR` | FALSE  | Left is FALSE — short-circuit, right never runs |
| `TRUE AND ERROR`  | ERROR  | Left is TRUE, must evaluate right — which errors |
| `TRUE OR ERROR`   | TRUE   | Left is TRUE — short-circuit, right never runs |
| `FALSE OR ERROR`  | ERROR  | Left is FALSE, must evaluate right — which errors |
| `ERROR AND FALSE` | ERROR  | Left errors before we get to the right |
| `ERROR OR TRUE`   | ERROR  | Left errors before we get to the right |
| `NOT ERROR`       | ERROR  | The operand errors |

Notice the asymmetry: `FALSE AND ERROR` is fine (FALSE short-circuits), but
`ERROR AND FALSE` isn't (the error fires first).  This matches how CASE
expressions work — the one SQL construct where the standard actually guarantees
left-to-right evaluation.

Under this logic, the predicate pushdown rule
`σ_p(R ⋈ S) = σ_p(R) ⋈ S` would come with a precondition: `p` must not
produce ERROR on any row of `R` that the join with `S` would eliminate.  For
`"total"` predicates that's automatic.  For `"partial"` ones, the optimizer
would need to either prove the precondition holds or skip the transformation.

Same story for sort pushdown: pushing a Sort below a join is only safe if the
sort expression is `"total"` — or if it's already being evaluated at the scan
level anyway (in which case the Sort just reorders rows without introducing any
new computation).

## What a solution might look like

PostgreSQL already has a mechanism designed for exactly this kind of problem:
**planner support functions** (`prosupport`).  Every `pg_proc` entry can
optionally point to a support function that the optimizer calls at planning
time to ask function-specific questions.  Today, support functions handle
things like custom selectivity estimates, cost overrides, row-count estimates
for set-returning functions, and simplification of function calls.

The infrastructure is already there.  A new request type —
`SupportRequestSafeEarlyEval`, say — would let a function tell the optimizer:
"don't evaluate me on unfiltered data."

```c
typedef struct SupportRequestSafeEarlyEval
{
    NodeTag     type;
    /* the function call being considered */
    FuncExpr   *funcexpr;
    /* support function sets this */
    bool        safe;       /* true = OK to push down */
} SupportRequestSafeEarlyEval;
```

The natural place to call it is `relation_can_be_sorted_early()` in
`equivclass.c` — the function that already serves as the central gatekeeper
for "can this expression be evaluated at a lower plan level?"  It already
checks for volatility, set-returning functions, and parallel safety.  A
prosupport call would slot in as a fourth check:

```c
/* existing checks */
if (ec->ec_has_volatile)         return false;
if (expression_returns_set(...)) continue;
if (!is_parallel_safe(...))      continue;

/* new: ask the function itself */
if (!expression_safe_for_early_eval((Node *) em->em_expr))
    continue;
```

What makes this elegant is that `relation_can_be_sorted_early()` is already
called from all the right places:

- **Sort pushdown** (`consider_enforce_ordered_scan`) — our optimisation
- **Gather Merge paths** (`generate_useful_gather_paths`) — parallel plans
- **FDW/custom-scan paths** (`get_useful_pathkeys_for_relation`)

So a single check in one function automatically protects every code path.  And
the same `expression_safe_for_early_eval()` walker could be called from
`distribute_qual_to_rels()` to protect predicate pushdown too — closing the
gap we demonstrated with the vanilla PostgreSQL example.

The prosupport approach has several advantages over a static catalog column:

- **No schema change** — no new `pg_proc` column, no catalog version bump.
- **Incremental adoption** — you add support functions to known `"partial"`
  functions one at a time.  Functions without one keep current behavior.
- **Extensibility** — extensions can register support functions for their own
  `"partial"` functions.

## Conclusion

The SQL standard is deliberately vague about expression evaluation order,
and database engines have inherited that vagueness as a practical problem:
queries can break when the optimizer rearranges expressions that look safe
but aren't.  As optimisers grow more sophisticated and explore larger plan
spaces, these incidents become more frequent — not less.

We believe PostgreSQL's existing `prosupport` machinery is the right place to
put the problem under at least partial control of DBAs.  A new `SupportRequestSafeEarlyEval` request type, checked in
`relation_can_be_sorted_early()`, would protect sort pushdown, parallel paths,
and FDW paths in one shot — and the same walker could extend to predicate
pushdown.  The approach requires no catalog changes, supports incremental
adoption, and is open to extensions.

We'd love to hear what the community thinks — especially about edge cases
we might have missed.  Feedback is welcome on the
[pgsql-hackers mailing list](https://www.postgresql.org/list/pgsql-hackers/).
