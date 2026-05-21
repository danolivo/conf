# Polymorphic Reference Resolution in Relational Databases

## The Pattern

Many real-world data models contain references that can point to one of several
target entity types. An order line item may reference a physical product, a
digital download, a gift card, or a subscription. A CRM activity record may be
linked to a contact, a company, or a deal. An audit-log entry may refer to any
entity in the system.

Relational schemas have no native mechanism for such references. The most common
encoding uses a **discriminated foreign key** — two columns that together
identify the target table and the row within it:

```sql
CREATE TABLE order_lines (
    id          SERIAL PRIMARY KEY,
    order_id    INTEGER NOT NULL REFERENCES orders(id),
    item_type   VARCHAR(20) NOT NULL,   -- discriminator
    item_id     INTEGER NOT NULL,        -- polymorphic FK
    quantity    INTEGER NOT NULL
);
```

Here `item_type` might contain `'product'`, `'gift_card'`, or `'subscription'`,
and `item_id` holds the primary key of the corresponding table. No single
foreign-key constraint can enforce referential integrity across all three
targets, so the database engine treats `item_id` as an ordinary integer column.

To resolve the reference — for example, to retrieve the human-readable name of
whatever item was ordered — a query must join against every possible target
table, guarded by the discriminator:

```sql
SELECT
    ol.id,
    COALESCE(p.name, g.name, s.name) AS item_name
FROM order_lines ol
LEFT JOIN products      p ON ol.item_type = 'product'
                          AND ol.item_id = p.id
LEFT JOIN gift_cards    g ON ol.item_type = 'gift_card'
                          AND ol.item_id = g.id
LEFT JOIN subscriptions s ON ol.item_type = 'subscription'
                          AND ol.item_id = s.id;
```

For every row in `order_lines`, at most one of the three LEFT JOINs produces a
match; the other two return NULLs. As the number of target types grows, so does
the fan-out of LEFT JOINs. We refer to this query shape as the **polymorphic
reference resolution pattern**.


### Structural Invariants

The pattern has a precise structure that distinguishes it from an arbitrary
collection of outer joins:

1. **Mutual exclusion.** The discriminator predicates in the join conditions are
   pairwise disjoint: for any row in the base table, at most one join
   condition's discriminator predicate evaluates to true. In the example above,
   the predicates `item_type = 'product'`, `item_type = 'gift_card'`, and
   `item_type = 'subscription'` cannot be simultaneously true for a single row.
   This guarantees that at most one LEFT JOIN produces a match per base row.
   Note that if a row's discriminator value is not represented by any join in the
   query (e.g., `item_type = 'coupon'` with no corresponding join), or if
   the discriminator is NULL, zero joins match — the row passes through with
   all-NULL target columns. The invariant is "at most one," not "exactly one."

2. **Inner-key uniqueness.** The join key on each target table is its primary
   key (or at least a unique key). This is verifiable by the planner from
   catalog metadata (unique indexes). Combined with mutual exclusion, it ensures
   that each LEFT JOIN produces at most one match per base row, so no join
   duplicates rows.

3. **Column-usage constraint.** Every reference to a column from target table
   T_i — in the SELECT list, WHERE clause, ORDER BY, HAVING, or any other
   query clause — occurs within a COALESCE or CASE expression that evaluates
   to NULL when the discriminator does not select T_i. No target-table column
   is referenced outside such a collapsing expression. Furthermore, each
   collapsing expression must include a contributing column from every
   target table that participates in a LEFT JOIN in the query: if COALESCE
   includes `p.name` and `g.name`, it must also include `s.name` — unless
   the subscription join does not contribute a column to that collapsing
   expression at all. This completeness requirement ensures that removing
   a non-matching join does not alter the collapsing expression's result
   for any base row.

These three invariants together yield the following property, which is the
foundation for the optimisations developed in subsequent chapters.

**Proposition (join removal under polymorphic resolution).** *Given invariants
1–3, for a subset of base rows filtered by `discriminator = c_k` (matching
target table T_k), the LEFT JOINs to all other target tables T_i (where
c_i ≠ c_k) can be removed from the plan without changing any output row.*

*Proof sketch.* Consider any row r in the filtered subset. By mutual exclusion
(invariant 1), the join condition for each T_i (i ≠ k) evaluates to false on
r, so the LEFT JOIN to T_i produces NULL for all of T_i's columns. By
inner-key uniqueness (invariant 2), this null-extension does not duplicate r.
By the column-usage constraint (invariant 3), every reference to a column of
T_i occurs within a collapsing expression that evaluates to NULL when T_i does
not match. Removing the join to T_i eliminates T_i's NULL contribution from
each COALESCE or CASE; because COALESCE skips NULL arguments and CASE skips
non-matching branches, the expression's result is unchanged — the remaining
arguments still include T_k's contribution, guaranteed by the completeness
requirement. (If no matching row exists in T_k — a dangling reference — T_k's
contribution is itself NULL, so the collapsing expression yields NULL
regardless, the same result as the original with all joins present.) Since this holds for every row in the filtered
subset, the joins to T_i can be removed from the plan for that subset
entirely. At the plan level, removing a join means that Var nodes
referencing the removed relation's columns have no source. The
transformation therefore replaces each such Var with a NULL constant of the
appropriate type — which is exactly the value the LEFT JOIN would have
produced for non-matching rows. This substitution preserves the semantics of
both COALESCE expressions (which skip NULLs) and CASE expressions that test
target-table columns (whose branches evaluate to false when the column is
NULL). ∎

Note that the proposition establishes a *per-discriminator-value* removal
guarantee: given a specific filter `discriminator = c_k`, the non-matching
joins can be dropped. Exploiting this guarantee across all discriminator
values simultaneously — without requiring a separate plan per value — is the
central optimisation problem addressed in subsequent chapters.

This proposition applies to the flat SELECT case. When the polymorphic
resolution query is embedded inside a larger query with GROUP BY or aggregates,
the interaction between join removal and aggregate semantics requires additional
analysis. This work focuses on the non-aggregate case; the aggregate
interaction is noted as a direction for future work.

In some systems — notably large ERP platforms — the discriminator is not a
single column but a pair or triple of columns encoding the target schema, table,
and row identifier. The structural invariants hold identically; only the
discriminator's arity changes.


### Detection

For the optimiser to exploit these invariants, it must detect them in the query
tree. Inner-key uniqueness is straightforward: the planner can verify the
presence of a unique index on the inner side's join key from catalog metadata.
Mutual exclusion requires recognising that each LEFT JOIN's condition includes
an equality predicate comparing the same base-table column (or tuple of columns,
for multi-column discriminators) to a distinct constant (or tuple of constants).
For example, `ol.item_type = 'product'` in one join and `ol.item_type =
'gift_card'` in another. The planner can verify pairwise disjointness by
confirming that the constants (or constant tuples) are distinct and the
base-table column(s) are the same across all join conditions.

The column-usage constraint requires inspecting all query clauses (target list,
WHERE, ORDER BY, HAVING) and verifying that every column-reference node
(internally, a Var) for a target-table attribute appears only within a
COALESCE or CASE expression (internally, CoalesceExpr or CaseExpr) in which
each branch draws columns from exactly one target table and every target table
contributing columns is represented by a branch. The specific detection
algorithm and its integration into PostgreSQL's planner are described in
subsequent chapters; this section establishes the invariants that the detector
must verify.


## Where the Pattern Appears

The pattern is pervasive across application domains and frameworks. It arises
in two distinct forms that share the same query-level structure but differ in
their schema-level properties.

**Polymorphic associations (no referential integrity).** Ruby on Rails
popularised the term "polymorphic association," implemented as a `_type` / `_id`
column pair on the referencing table
(Ruby on Rails Guides, 2024;
https://guides.rubyonrails.org/association_basics.html). No foreign
key can be declared because the target table varies per row. When a query must
resolve the reference, the ORM generates discriminator-guarded LEFT JOINs
against all candidate target tables. Django's `django-polymorphic` library
uses the same approach and documents the query-count overhead it introduces
(django-polymorphic Documentation, 2024;
https://django-polymorphic.readthedocs.io/en/stable/performance.html). The
GitLab engineering handbook explicitly bans this form, citing the loss of
referential integrity and query-performance degradation observed in production
(GitLab Documentation, 2024;
https://docs.gitlab.com/development/database/polymorphic_associations/).

**Joined-table inheritance (with referential integrity).** Hibernate's
`@Inheritance(strategy = JOINED)` stores each subclass in a separate table
whose primary key is also a foreign key to the parent table. The discriminator
is stored in the parent table. Upon loading the base entity, Hibernate emits
LEFT OUTER JOINs to every subclass table in the hierarchy. Community reports
document queries with 30–40 LEFT OUTER JOINs from moderately deep hierarchies
(Hibernate Community, 2020;
https://discourse.hibernate.org/t/hibernate-joined-inheritance-onetoone-too-many-left-outer-joins/4625). Django's multi-table inheritance produces the
same structure. Unlike the polymorphic-association form, joined-table
inheritance does have referential integrity constraints between the parent and
subtype tables — but the resolution query is identical in shape.

PostgreSQL's own table inheritance (`INHERITS`) is a partial schema-level
solution to the same problem: queries against a parent table automatically
include rows from child tables without requiring explicit joins. However,
`INHERITS` has significant limitations — it does not enforce foreign-key
constraints on child tables, does not propagate unique constraints across the
hierarchy, and interacts poorly with some planner optimisations — which limits
its adoption for this use case.

**CRM platforms.** Salesforce exposes polymorphic lookup fields (`WhoId`,
`WhatId`) on the Activity object. A single `WhatId` field can reference an
Account, Opportunity, Campaign, or any of dozens of custom objects. Salesforce
provides the `TYPEOF` operator in SOQL specifically to handle polymorphic
resolution without requiring explicit joins for each target type
(Salesforce SOQL Reference, 2024;
https://developer.salesforce.com/docs/atlas.en-us.soql_sosl.meta/soql_sosl/sforce_api_calls_soql_relationships_and_polymorph_keys.htm).

**ERP systems.** Enterprise resource planning platforms routinely encode
cross-document references as discriminated foreign keys. When a general ledger
entry can reference an invoice, a purchase order, a payment, or a manual
journal, the reference is stored as a type–identifier pair. Reporting queries
against these schemas contain eight to twenty discriminator-guarded LEFT JOINs.


## Evidence of Real-World Cost

Quantitative benchmarks that isolate the polymorphic resolution pattern's
overhead in peer-reviewed literature are scarce. The quantitative evaluation
of the optimisations proposed in this work is presented in the evaluation
chapter that follows the optimisation chapters.
However, practitioner communities and framework documentation provide
substantial qualitative evidence that the cost is real.

Hibernate's community forum contains recurring threads in which developers
report that loading a single entity from a joined-inheritance hierarchy produces
queries with dozens of LEFT OUTER JOINs, and that these queries dominate
response time in read-heavy workloads (Hibernate Community, 2020). The
django-polymorphic documentation dedicates a section to performance
considerations, advising developers to use `.non_polymorphic()` when the
concrete type is not needed (django-polymorphic Documentation, 2024). GitLab's
prohibition on polymorphic associations is motivated explicitly by
query-performance degradation observed in production
(GitLab Documentation, 2024).

A related body of work establishes that multi-join queries are inherently
vulnerable to plan-quality degradation. Leis et al. (2015) demonstrated that
cardinality estimation errors compound multiplicatively across joins, often
reaching several orders of magnitude even on well-analysed tables. The
polymorphic resolution pattern, with its N outer joins, is exposed to this
compounding.


## Schema-Level Alternatives

The database literature offers several strategies for modelling type hierarchies
that avoid the discriminated foreign key. Teorey, Yang, and Fry proposed a systematic methodology for
mapping Enhanced Entity-Relationship generalisation hierarchies to relational
tables (Teorey et al., 1986). Fowler later catalogued three practitioner-oriented
patterns: Class Table Inheritance (a shared parent table with subtype tables
whose primary keys are foreign keys to the parent), Single Table Inheritance
(all subtypes collapsed into one wide table), and Concrete Table Inheritance
(fully independent tables per subtype, requiring UNION ALL for polymorphic
queries) (Fowler, 2002). Specific per-pattern cost trade-offs are discussed in
the Practical Notes section below.

Karwin dedicated a chapter of *SQL Antipatterns* to the discriminated foreign
key under the name "Polymorphic Associations," arguing that it sacrifices
referential integrity and query performance for schema simplicity (Karwin,
2010). He recommends the Class Table Inheritance approach — which he calls the
"Common Super-Table" — as the preferred alternative.

Despite these alternatives, the discriminated foreign key remains dominant in
practice. ORM frameworks generate it by default, and retroactive schema changes
in large production systems are prohibitively expensive. The optimisations
described in subsequent chapters therefore accept the schema as given and target
the query execution layer.


## How Database Systems Address the Performance Problem

The polymorphic resolution query is expensive because the executor probes N
inner tables for every outer row, even though at most one can match. Several
families of optimisations target this cost. This section surveys the relevant
techniques and identifies, for each, why it does not fully address the
polymorphic pattern.

### Outer-join theory

The algebraic foundation for optimising outer joins was established by
Galindo-Legaria and Rosenthal (1997), who developed rewrite rules for
simplifying and reordering outer joins within the relational algebra. Their
framework defines the conditions under which outer joins can be reordered,
associated, or converted to inner joins — providing the theoretical basis for
most outer-join optimisations in modern query planners. In an earlier paper,
Galindo-Legaria (1994) presented an algebraic framework using nullification
operators that represents the result of an outer join as the union of two disjoint
components: the matching (inner-join) rows and the non-matching rows padded
with NULLs.
This decomposition enables the optimiser to reason about each component
separately. For the polymorphic pattern, the decomposition is particularly
powerful: mutual exclusion guarantees that for at most one target table per
base row, the inner-join component is non-empty (and the null-padded
component is vacuous), while for all other target tables the inner-join
component is empty and only the null-padded component contributes. This means the
optimiser can, in principle, determine at the per-row level which join's
null-padded component is vacuous — a stronger conclusion than the general
framework can draw without the mutual exclusion invariant.

### Join elimination

If a LEFT JOIN is provably unnecessary — its output columns are not referenced
and it cannot duplicate rows — the optimiser can remove it entirely. PostgreSQL
has supported outer-join removal since version 9.0 for the case where the inner
side has a unique index on the join key
(Haas, 2010; http://rhaas.blogspot.com/2010/06/why-join-removal-is-cool.html). DB2 and Oracle apply join
elimination more aggressively, using referential-integrity metadata to remove
joins whose sole purpose was to validate a foreign-key relationship
(Pirahesh et al., 1992).

In the polymorphic pattern, however, every join contributes a column to the
COALESCE or CASE expression. None qualify for standard join elimination because
the output reference prevents removal. To exploit the pattern, a more
specialised analysis is needed — one that recognises the column-usage constraint
and the mutual exclusion invariant together.

### Predicate migration

Levy, Mumick, and Sagiv (1994) developed predicate move-around, a technique
that derives new predicates by migrating existing ones across query blocks.
Applied to the polymorphic pattern, predicate migration could in principle push
discriminator predicates from the join conditions down to the base-table scan,
restricting the set of rows that reach each join. However, predicate
move-around operates on the predicates already present in the query; the
polymorphic pattern's optimisation potential lies in recognising that entire
joins can be skipped for non-matching rows — a structural transformation beyond
predicate migration's scope.

### Sideways information passing

Sideways information passing (SIP) techniques construct filters from one side
of a join and push them to the scan of the other side. Bancilhon et al. (1986)
introduced Magic Sets for recursive Datalog queries; the technique was
subsequently adopted and generalised to the relational setting by other
researchers as a way of propagating bound values to restrict computation in
joining subgoals. Kandula et al. (2021) formalised a modern
variant as *data-induced predicates* — synthetic predicates derived from data
statistics on one table and applied to a joining table.

Applied to the polymorphic pattern, SIP could propagate discriminator values
from the base table to avoid probing inner tables whose type does not match.
However, the direction of information flow is inverted from the typical SIP
scenario: the useful filter (the discriminator value) lives on the outer side,
not the inner side.

### UNION ALL rewriting

The most direct approach to exploiting mutual exclusion is to rewrite the
N-way LEFT JOIN query into N separate queries, each restricted to one
discriminator value, and combine them with UNION ALL:

```sql
SELECT ol.id, p.name AS item_name
FROM order_lines ol
JOIN products p ON ol.item_id = p.id
WHERE ol.item_type = 'product'
UNION ALL
SELECT ol.id, g.name AS item_name
FROM order_lines ol
JOIN gift_cards g ON ol.item_id = g.id
WHERE ol.item_type = 'gift_card'
UNION ALL
SELECT ol.id, s.name AS item_name
FROM order_lines ol
JOIN subscriptions s ON ol.item_id = s.id
WHERE ol.item_type = 'subscription';
```

Each branch scans only the relevant subset of the base table and joins against
a single target table with an inner join, eliminating all fruitless probes.

This rewrite silently drops base rows whose discriminator value is not covered
by any branch. The original LEFT JOIN query preserves such rows with all-NULL
target columns. To restore semantic equivalence, a catch-all branch is needed:

```sql
UNION ALL
SELECT ol.id, NULL AS item_name
FROM order_lines ol
WHERE ol.item_type NOT IN ('product','gift_card','subscription')
   OR ol.item_type IS NULL;
```

(The `OR ol.item_type IS NULL` clause is necessary because `NOT IN` returns
NULL — not TRUE — when the left operand is NULL. This catch-all formulation
is correct for a single-column discriminator as long as the constant list
contains no NULLs, which holds here since the discriminator values are literal
strings. For multi-column discriminators, tuple `NOT IN` has more complex NULL
semantics; a `NOT EXISTS` formulation or an explicit `IS DISTINCT FROM` chain
is safer in the general case.)

With the catch-all branch included, the rewrite is semantically equivalent to
the original under the mutual exclusion and inner-key uniqueness invariants,
provided every `(discriminator, item_id)` pair resolves to an existing row in
the corresponding target table. If a dangling reference exists — e.g.,
`item_type = 'product'` but no product with that `item_id` — the original
LEFT JOIN preserves the base row with NULL target columns, whereas the
rewrite's INNER JOIN silently drops it. In the polymorphic-association form,
which lacks foreign-key constraints, dangling references are possible and
this distinction matters. Using LEFT JOINs instead of INNER JOINs in each
branch would preserve dangling references and make the rewrite fully
equivalent to the original, at the same base-table scan cost.
The rewrite is a common practitioner workaround and corresponds naturally to
the general strategy of decomposing a query by predicate values and combining
partial results.

The cost of this approach is that it requires N+1 scans of the base table
(one per target type plus the catch-all, or N+1 index scans if an index on
the discriminator exists), and the planner must optimise N+1 separate
subqueries rather than one. For large N, the planning
overhead and the repeated base-table access can outweigh the savings from
avoiding fruitless probes. The subsequent chapters explore optimisations that
achieve the same reduction in probe cost without requiring multiple base-table
scans.

### Adaptive query execution

Rather than committing to a single plan at optimisation time, adaptive executors
defer decisions to runtime. Graefe (1994) introduced the `choose-plan`
meta-operator, which selects among pre-compiled subplans based on runtime
conditions. Avnur and Hellerstein (2000) proposed Eddies, routing individual
tuples through operators adaptively. Oracle Database 12c implemented adaptive
plans in production, inserting statistics-collector nodes that trigger subplan
switches when observed cardinalities diverge from estimates
(Oracle Corporation, 2013;
https://www.oracle.com/technetwork/database/bi-datawarehousing/twp-optimizer-with-oracledb-12c-1963236.pdf).

Applied to the polymorphic pattern, an adaptive executor could route each outer
row only to its matching join operator, skipping the remaining N−1 probes
entirely. Oracle's adaptive joins and SQL Server's adaptive join selection
address a related problem — choosing between nested-loop and hash join at
runtime — but no current production system implements discriminator-aware
per-row routing that would skip non-matching joins altogether.

### Constraint exclusion

PostgreSQL's constraint exclusion mechanism is the closest existing feature to
what the polymorphic pattern requires. When scanning a partitioned table (or a
UNION ALL view over tables with CHECK constraints), the planner compares the
query's WHERE clause against each child table's CHECK constraint and excludes
children that provably cannot contain matching rows. The parallel to the
polymorphic pattern is direct: discriminator predicates play the role of CHECK
constraints, and target tables play the role of partitions. However, constraint
exclusion operates on the base table's children, not on the inner sides of LEFT
JOINs in an unpartitioned query. It cannot recognise that a LEFT JOIN to
`products` is unnecessary for rows where `item_type = 'gift_card'` unless the
base table is physically partitioned by discriminator — which, as discussed
above, requires schema changes that the optimisations in this work aim to avoid.

### The planner's search-space limitation

The polymorphic pattern exposes a limitation not in the planner's cost
estimates but in its search space. PostgreSQL's planner can often produce reasonable selectivity estimates
for each discriminator predicate from MCV statistics: for a nested-loop join
on `ol.item_type = 'product' AND ol.item_id = p.id`, the planner recognises
that only the fraction of `order_lines` rows where `item_type = 'product'`
will produce matches. When statistics are up to date, the per-join
cardinality estimates may be adequate.

What the planner cannot express is "skip this join entirely for rows where the
discriminator does not match." Within a single nested-loop node, the executor
must probe the inner side for every outer row; it cannot conditionally bypass
the probe based on the discriminator value. The result is that N−1 fruitless
probes are executed per row. For nested-loop joins with index probes, each
fruitless probe involves a B-tree traversal to a leaf page, a comparison that
fails, and a return — real I/O and CPU cost that accumulates across N target
tables. For hash joins the per-probe cost of a miss is lower (a hash lookup
that fails is O(1)), but the aggregate overhead across N joins and many rows
remains significant.

The fundamental issue is that the plan structure does not reflect the mutual
exclusion invariant. The planner's existing search space does not include plan
shapes that partition execution by discriminator value within a single scan of
the base table. Rao and Ross (1998) showed how to avoid redundant computation
across correlated subqueries by caching and reusing intermediate results
that remain unchanged across invocations — a conceptually related strategy,
though their work targets correlated subqueries rather than
discriminator-guarded outer joins. The optimisations presented in subsequent
chapters extend the planner's search space to include plan shapes that exploit
the polymorphic pattern's specific invariants.


## Interaction with EXISTS Subqueries

The polymorphic resolution query as presented so far contains no WHERE clause:
the base table is scanned in full and every row fans out through the N LEFT
JOINs. In practice, however, the query frequently includes an EXISTS subquery
that filters the base table — for example, restricting order lines to orders
placed in a particular date range or belonging to a specific customer:

```sql
SELECT
    ol.id,
    COALESCE(p.name, g.name, s.name) AS item_name
FROM order_lines ol
LEFT JOIN products      p ON ol.item_type = 'product'      AND ol.item_id = p.id
LEFT JOIN gift_cards    g ON ol.item_type = 'gift_card'     AND ol.item_id = g.id
LEFT JOIN subscriptions s ON ol.item_type = 'subscription'  AND ol.item_id = s.id
WHERE EXISTS (
    SELECT 1 FROM orders o
    WHERE o.id = ol.order_id
      AND o.placed_at >= '2024-01-01'
);
```

The EXISTS subquery in this example references only columns of the outer
(base) table — a common case in practice. The analysis below assumes this
property; an EXISTS that references target-table columns would be subject to
different pull-up rules and is not considered here. How the planner handles
the base-table-only EXISTS has a significant impact on performance, and the
outcome depends on whether the subquery is pulled up into a semi-join and on
the settings of `join_collapse_limit` and `from_collapse_limit`.

**Case 1: EXISTS kept as a SubPlan (no pull-up).** When the planner does not
convert the EXISTS into a semi-join — for example, because the subquery
contains features that prevent pull-up — it is typically evaluated as a
filter on or near the base-table scan (the planner pushes the qual down
because it references only base-table columns). Each `order_lines` row is
tested against the SubPlan before entering the join tree. Rows that fail the
EXISTS test are discarded immediately, so only qualifying rows reach the N
LEFT JOINs. This is the favourable case: the base-table filter reduces the
fan-out early.

**Case 2: EXISTS pulled up into a semi-join (within `join_collapse_limit`).**
PostgreSQL's planner normally converts a simple EXISTS subquery into a
semi-join. After pull-up, the semi-join's relation (`orders`) becomes one of
the base relations that the planner considers during join enumeration via
dynamic programming (or GEQO). The planner is free to evaluate all legal
join orderings, subject to the ordering constraints recorded in
`SpecialJoinInfo` structures for each outer join and semi-join. Because the
semi-join's clause references only `order_lines` columns, and the LEFT JOINs
also require `order_lines` on their outer side, the planner can in principle
place the semi-join early — joining `orders` to `order_lines` before any of
the LEFT JOINs. When selectivity estimates are accurate, the planner
typically does choose this early placement, and the filtering effect is
preserved. The risk in this case is not a structural inability to reorder but
rather that poor cardinality estimates (compounded across N joins, as
discussed earlier) may lead the planner to choose a suboptimal join order
that places the semi-join later than ideal.

**Case 3: `join_collapse_limit` exceeded.** The polymorphic resolution query
with N target tables already contains N+1 relations (the base table plus N
target tables). Adding the pulled-up semi-join brings the total to N+2. When
this exceeds `join_collapse_limit` (default 8 in PostgreSQL), the planner
preserves the syntactic `JOIN` nesting from the parser rather than flattening
all relations into a single list for exhaustive enumeration. The limit exists
because the number of join orderings grows super-exponentially with the number
of relations (Ono and Lohman, 1990), making exhaustive search impractical
beyond a modest count. The LEFT JOINs
form a left-deep `JoinExpr` tree that the planner processes as a unit,
joining them in their syntactic order. The semi-join's relation, having been
added to the top-level `FromExpr` during pull-up, sits outside this nested
block. The planner cannot interleave the semi-join into the un-flattened LEFT
JOIN chain — it can only join the semi-join to the block as a whole. The
result is that the semi-join is evaluated against the full output of the LEFT
JOIN chain: every base row passes through all N LEFT JOINs first, and only
then is the EXISTS condition tested. For large base tables with a selective
EXISTS predicate, this can degrade performance by orders of magnitude compared
to Case 1, because all N fruitless probes per row are executed before the
filter discards non-matching rows.

This interaction compounds the polymorphic pattern's inherent cost. A query
with 10 target types already has 11 relations; adding one EXISTS subquery
brings it to 12, well above the default `join_collapse_limit`. In ERP systems,
where both N and the number of filtering conditions are large, the planner's
inability to interleave the semi-join into the LEFT JOIN chain is a recurring
source of performance problems. The optimisations described in subsequent
chapters must account for this interaction: reducing N through join removal
also reduces the total relation count, potentially bringing it back within
`join_collapse_limit` and restoring the planner's ability to position the
semi-join advantageously.


## Practical Notes

The observations in this section are drawn from practitioner experience and
framework documentation rather than controlled experiments. They are included
because they are widely encountered in production systems and may help database
administrators and developers recognise and diagnose the pattern, but they
should not be treated as rigorously established results.

**Recognising the pattern in EXPLAIN output.** The telltale sign is a chain of
nested-loop LEFT JOINs where each inner side is an index scan on a different
table, and the join filter includes an equality predicate on the same
base-table column (the discriminator). The `EXPLAIN ANALYZE` output will show
that for each nested-loop node, the "rows removed by join filter" count is
close to the total number of outer rows — confirming that nearly every probe
is fruitless. For hash joins, the equivalent indicator is a large number of
rows entering the hash lookup with zero matches.

**Schema-alternative trade-offs in practice.** The schema alternatives
described earlier (Fowler, 2002; Karwin, 2010) each carry specific costs that
influence the choice in production systems. Class Table Inheritance (the
"Common Super-Table") preserves referential integrity but adds one join per
query and requires two writes per insert (one to the parent table, one to the
subtype table). Single Table Inheritance avoids joins entirely but produces a
wide, sparse table — columns belonging to other subtypes are NULL for any given
row, which can waste storage and complicate indexing. Concrete Table
Inheritance eliminates both joins and NULLs but requires UNION ALL across all
subtype tables for polymorphic queries, and schema changes to shared columns
must be propagated to every table independently.

**ORM-level workarounds.** Framework documentation describes several
application-level mitigations. Django's `django-polymorphic` library offers a
`.non_polymorphic()` queryset method that skips the subtype joins when the
concrete type is not needed
(django-polymorphic Documentation, 2024;
https://django-polymorphic.readthedocs.io/en/stable/performance.html).
Hibernate users can switch from `JOINED` to `SINGLE_TABLE` inheritance
strategy at the cost of a sparse table, or use lazy loading to defer subtype
resolution to individual entity access — trading N LEFT JOINs in one query for
N+1 separate queries, which may or may not be faster depending on access
patterns and caching. A Hibernate Community forum thread from 2024
documents developers encountering 30–40 LEFT OUTER JOINs from moderately deep
`JOINED` hierarchies and seeking exactly these workarounds
(https://discourse.hibernate.org/t/is-limiting-the-amount-of-joins-in-the-joined-strategy-possible/9654).

**When the problem matters most.** The performance impact of the polymorphic
pattern is most severe when three conditions coincide: the number of target
types N is large (above 8–10), the base table is large (millions of rows), and
the query is read-heavy with latency requirements. In such cases, even
index-backed nested-loop probes accumulate significant I/O: each fruitless
probe traverses a B-tree to a leaf, performs a comparison that fails, and
returns. Multiplied by N−1 fruitless probes per row and millions of rows, the
aggregate cost dominates query execution time.


## Summary

The polymorphic reference resolution pattern produces queries with a
characteristic N-way LEFT JOIN fan-out that grows linearly with the number of
target types. Its structural invariants — pairwise disjointness of
discriminator predicates, inner-key uniqueness, and the column-usage
constraint — distinguish it from arbitrary outer-join queries and enable
optimisations that general-purpose rewrite rules cannot exploit. Specifically,
the invariants guarantee that for any base row, the LEFT JOINs to non-matching
target tables can be removed without changing the output.

The pattern arises in two forms — polymorphic associations (without referential
integrity) and joined-table inheritance (with referential integrity) — and is
pervasive in ORM-generated schemas, CRM platforms, and ERP systems. Practitioner
evidence establishes that the resulting queries are a significant performance
burden as N grows.

Existing optimisations each address part of the problem: join elimination
requires unreferenced output columns and provable non-duplication
(Haas, 2010); outer-join rewriting
provides the algebraic framework but not the pattern-specific rules
(Galindo-Legaria and Rosenthal, 1997); predicate migration moves predicates but
cannot eliminate joins (Levy et al., 1994); sideways information passing
propagates filters in the wrong direction for this pattern (Kandula et al.,
2021); UNION ALL rewriting eliminates fruitless probes but requires multiple
base-table scans; constraint exclusion skips partitions but requires physical
partitioning of the base table; and adaptive execution could route tuples
per-row but no production system implements discriminator-aware routing
(Graefe, 1994; Oracle Corporation, 2013). None exploits the full set of
structural invariants within a single base-table scan. The problem is
compounded by EXISTS subqueries that, when pulled up into semi-joins, lose
their filtering effect on the base table — particularly when the total
relation count exceeds `join_collapse_limit` and the planner can no longer
reorder the semi-join to an optimal position.
The following chapters describe a series of PostgreSQL-specific optimisations
that target this gap.


## References

Avnur, R. and Hellerstein, J.M. (2000) 'Eddies: continuously adaptive query
processing', *Proceedings of the 2000 ACM SIGMOD International Conference on
Management of Data*, pp. 261–272. doi:10.1145/342009.335420.

Bancilhon, F., Maier, D., Sagiv, Y. and Ullman, J.D. (1986) 'Magic sets and
other strange ways to implement logic programs', *Proceedings of the Fifth ACM
SIGMOD-SIGACT Symposium on Principles of Database Systems (PODS)*,
pp. 1–15. doi:10.1145/6012.15399.

django-polymorphic Documentation (2024) *Performance Considerations*. Available
at: https://django-polymorphic.readthedocs.io/en/stable/performance.html.

Fowler, M. (2002) *Patterns of Enterprise Application Architecture*. Boston,
MA: Addison-Wesley.

Galindo-Legaria, C.A. (1994) 'Outerjoins as disjunctions', *Proceedings of
the 1994 ACM SIGMOD International Conference on Management of Data*,
pp. 348–358. doi:10.1145/191839.191908.

Galindo-Legaria, C.A. and Rosenthal, A. (1997) 'Outerjoin simplification and
reordering for query optimization', *ACM Transactions on Database Systems*,
22(1), pp. 43–73. doi:10.1145/244810.244812.

GitLab Documentation (2024) *Polymorphic Associations*. Available at:
https://docs.gitlab.com/development/database/polymorphic_associations/.

Graefe, G. (1994) 'Volcano — an extensible and parallel query evaluation
system', *IEEE Transactions on Knowledge and Data Engineering*, 6(1),
pp. 120–135. doi:10.1109/69.273032.

Haas, R. (2010) *Why Join Removal Is Cool* [Blog]. Available at:
http://rhaas.blogspot.com/2010/06/why-join-removal-is-cool.html.

Hibernate Community (2020) 'Hibernate joined inheritance @OneToOne: too many
left outer joins' [Forum thread]. Available at:
https://discourse.hibernate.org/t/hibernate-joined-inheritance-onetoone-too-many-left-outer-joins/4625.

Kandula, S., Orr, L. and Chaudhuri, S. (2021) 'Data-induced predicates for
sideways information passing in query optimizers', *The VLDB Journal*, 31(6).
doi:10.1007/s00778-021-00693-2.

Karwin, B. (2010) *SQL Antipatterns: Avoiding the Pitfalls of Database
Programming*. Raleigh, NC: Pragmatic Bookshelf.

Leis, V., Gubichev, A., Mirchev, A., Boncz, P., Kemper, A. and Neumann, T.
(2015) 'How good are query optimizers, really?', *Proceedings of the VLDB
Endowment*, 9(3), pp. 204–215. doi:10.14778/2850583.2850594.

Levy, A.Y., Mumick, I.S. and Sagiv, Y. (1994) 'Query optimization by predicate
move-around', *Proceedings of the 20th International Conference on Very Large
Data Bases (VLDB)*, pp. 96–107.

Ono, K. and Lohman, G.M. (1990) 'Measuring the complexity of join enumeration
in query optimization', *Proceedings of the 16th International Conference on
Very Large Data Bases (VLDB)*, pp. 314–325.

Oracle Corporation (2013) *Optimizer with Oracle Database 12c*
[White paper]. Available at:
https://www.oracle.com/technetwork/database/bi-datawarehousing/twp-optimizer-with-oracledb-12c-1963236.pdf.

Pirahesh, H., Hellerstein, J.M. and Hasan, W. (1992) 'Extensible/rule based
query rewrite optimization in Starburst', *Proceedings of the 1992 ACM SIGMOD
International Conference on Management of Data*, pp. 39–48.
doi:10.1145/130283.130294.

Rao, J. and Ross, K.A. (1998) 'Reusing invariants: a new strategy for correlated
queries', *Proceedings of the 1998 ACM SIGMOD International Conference on
Management of Data*, pp. 37–48. doi:10.1145/276304.276308.

Ruby on Rails Guides (2024) *Active Record Associations*. Available at:
https://guides.rubyonrails.org/association_basics.html.

Salesforce SOQL Reference (2024) *Understanding Relationship Fields and
Polymorphic Fields*. Available at:
https://developer.salesforce.com/docs/atlas.en-us.soql_sosl.meta/soql_sosl/sforce_api_calls_soql_relationships_and_polymorph_keys.htm.

Teorey, T.J., Yang, D. and Fry, J.P. (1986) 'A logical design methodology for
relational databases using the extended entity-relationship model', *ACM
Computing Surveys*, 18(2), pp. 197–222. doi:10.1145/7474.7475.
