# Comparison of PostgreSQL Query Tree Rewriting Optimisation with Alternative Approaches

## Motivation

This report examines PostgreSQL's approach to query tree rewriting in the context of the broader database optimisation literature, with a specific focus on one question: **does PostgreSQL need to make its preprocessing transformations cost-aware, and if so, what are the viable paths?**

The question is not academic. Heuristic transformations — applied unconditionally before cost-based planning — form a significant part of PostgreSQL's optimiser pipeline. Some of these transformations (notably subquery flattening and sublink-to-join conversion) alter the structure of the query in ways that can either dramatically improve or dramatically worsen performance. The decision is irrevocable: once the transformation fires, the original form is discarded, and the cost-based planner never sees it. This means the optimiser may be locked into a suboptimal search space before cost estimation even begins.

We survey the theoretical foundations, examine how other systems address the same problem, and evaluate potential directions for PostgreSQL.

## 1. Theoretical Foundations of Query Rewriting

### 1.1 The System R Heritage

Modern cost-based query optimisation originates with Selinger et al. (1979), who introduced the dynamic programming algorithm for join enumeration and the concept of "interesting orders" in IBM's System R. The key architectural insight was separating *what* to compute (the relational algebra expression) from *how* to compute it (the physical access plan), and using a cost model to choose among physical alternatives.

PostgreSQL's optimiser is a direct descendant of this design. It uses Selinger-style dynamic programming for join enumeration (for small join counts) and evaluates physical alternatives — scan methods, join methods, sort strategies — using a cost model with tuneable parameters (`seq_page_cost`, `random_page_cost`, `cpu_tuple_cost`, etc.).

**Reference:** Selinger, P.G., Astrahan, M.M., Chamberlin, D.D., Lorie, R.A., and Price, T.G. "Access Path Selection in a Relational Database Management System." SIGMOD, 1979. [https://dl.acm.org/doi/10.1145/582095.582099](https://dl.acm.org/doi/10.1145/582095.582099)

### 1.2 The Complexity of Join Ordering

The problem of finding the optimal join order is NP-hard in the general case (Ibaraki & Kameda, 1984). For *n* relations, the number of possible bushy join trees is super-exponential; even restricting to left-deep trees yields O(n!) orderings. Selinger's dynamic programming explores O(2^n) subsets, which is feasible for small *n* but becomes intractable beyond roughly 12–15 relations.

PostgreSQL addresses this with a two-tier strategy: exhaustive DP for queries with fewer than `geqo_threshold` relations (default 12), and the Genetic Query Optimiser (GEQO) — a randomised heuristic — for larger join counts. GEQO provides no optimality guarantees but runs in bounded time.

This complexity result is directly relevant to the rewriting question: **subquery flattening increases *n***, the number of relations in the join problem. A subquery with 4 tables flattened into a parent with 5 tables turns a 5-way DP problem into a 9-way problem — a jump from 2^5 = 32 subsets to 2^9 = 512. If *n* crosses the GEQO threshold, the optimiser switches from exact DP to a heuristic that may miss the optimal plan entirely.

**References:**
- Ibaraki, T. and Kameda, T. "On the Optimal Nesting Order for Computing N-Relational Joins." ACM Transactions on Database Systems, 9(3), 1984. [https://dl.acm.org/doi/10.1145/1270.1498](https://dl.acm.org/doi/10.1145/1270.1498)
- Moerkotte, G. and Neumann, T. "Analysis of Two Existing and One New Dynamic Programming Algorithm for the Generation of Optimal Bushy Join Trees without Cross Products." VLDB, 2006. [https://dl.acm.org/doi/10.5555/1182635.1164207](https://dl.acm.org/doi/10.5555/1182635.1164207)

### 1.3 Transformation-Based Enumeration Complexity

Pellenkoft, Galindo-Legaria & Kersten (1997) analysed the complexity of transformation-based join enumeration — the approach used by Cascades-style optimisers. They showed that naively applying commutativity and associativity rules generates an exponential number of duplicates, and that achieving the O(3^n) lower bound requires careful duplicate elimination. This result establishes that even within a Cascades memo, the search space is inherently exponential; the memo just represents it compactly.

**Reference:** Pellenkoft, A., Galindo-Legaria, C., and Kersten, M. "The Complexity of Transformation-Based Join Enumeration." VLDB, 1997. [https://dl.acm.org/doi/10.5555/645923.673661](https://dl.acm.org/doi/10.5555/645923.673661)

### 1.4 The Starburst Rule System

The Starburst project (Pirahesh, Hellerstein & Hasan, 1992) formalised the two-phase architecture: a rule-based rewriter transforms the query into a canonical form, then a cost-based optimiser selects the physical plan. Starburst's rewriter used production rules with pattern-action pairs, applied in a fixed sequence of "rule classes." The rewrite phase was explicitly cost-blind — rules fired based on structural pattern matching, not cost estimates.

This architecture crystallised the distinction between *logical* transformations (applied heuristically, before costing) and *physical* optimisation (cost-based). Most modern systems, including PostgreSQL, follow this two-phase pattern.

**Reference:** Pirahesh, H., Hellerstein, J.M., and Hasan, W. "Extensible/Rule Based Query Rewrite Optimization in Starburst." SIGMOD, 1992. [https://dl.acm.org/doi/10.1145/141484.130294](https://dl.acm.org/doi/10.1145/141484.130294)


## 2. The Cascades/Volcano Framework: Unifying Transformations and Costing

### 2.1 Core Architecture

The Volcano optimiser generator (Graefe & McKenna, 1993) and its successor, Cascades (Graefe, 1995), addressed a fundamental limitation of the Starburst model: by separating rewriting from costing, you lose the ability to cost-compare alternative logical forms. Cascades unifies logical transformations and physical implementations as *rules* within a single search space, encoded in a compact data structure called the *memo*.

Each memo *group* contains logically equivalent expressions. When a transformation rule fires, its result is added as a new expression in the appropriate group. The optimiser explores the space top-down, using branch-and-bound pruning: a cost upper bound is propagated downward, and any partial plan exceeding it is abandoned. Memoisation ensures that once a subproblem is solved, the result is reused.

**References:**
- Graefe, G. and McKenna, W.J. "The Volcano Optimizer Generator: Extensibility and Efficient Search." ICDE, 1993. [https://dl.acm.org/doi/10.5555/645478.757691](https://dl.acm.org/doi/10.5555/645478.757691)
- Graefe, G. "The Cascades Framework for Query Optimization." IEEE Data Engineering Bulletin, 18(3), 1995. [https://15721.courses.cs.cmu.edu/spring2016/papers/graefe-ieee1995.pdf](https://15721.courses.cs.cmu.edu/spring2016/papers/graefe-ieee1995.pdf)

### 2.2 Systems Using Cascades

Three major systems have been documented as using the Cascades framework:

**SQL Server.** The Cascades paper itself states the framework was built for SQL Server's optimiser. This is confirmed by Ding, Narasayya & Chaudhuri (2024), a Microsoft Research monograph on extensible optimisers.

**CockroachDB.** Described as a Cascades-style optimiser by Kimball (2018) and in the SIGMOD 2020 system paper by Taft et al.

**Greenplum (ORCA).** Soliman et al. (2014) explicitly state that ORCA is based on the Cascades framework.

**References:**
- Ding, B., Narasayya, V., and Chaudhuri, S. "Extensible Query Optimizers in Practice." Foundations and Trends in Databases, 14, 2024. [https://www.microsoft.com/en-us/research/publication/extensible-query-optimizers-in-practice/](https://www.microsoft.com/en-us/research/publication/extensible-query-optimizers-in-practice/)
- Kimball, A. "How We Built a Cost-Based SQL Optimizer." Cockroach Labs Blog, 2018. [https://www.cockroachlabs.com/blog/building-cost-based-sql-optimizer/](https://www.cockroachlabs.com/blog/building-cost-based-sql-optimizer/)
- Taft, R. et al. "CockroachDB: The Resilient Geo-Distributed SQL Database." SIGMOD, 2020. [https://dl.acm.org/doi/10.1145/3318464.3386134](https://dl.acm.org/doi/10.1145/3318464.3386134)
- Soliman, M.A. et al. "Orca: A Modular Query Optimizer Architecture for Big Data." SIGMOD, 2014. [https://dl.acm.org/doi/10.1145/2588555.2595637](https://dl.acm.org/doi/10.1145/2588555.2595637)

### 2.3 The Cross-Group Transformation Problem

The memo assumes each group is a self-contained equivalence class. Local transformations (join reordering, predicate pushdown within a subtree) respect this boundary — they add new expressions to existing groups without affecting other groups.

However, *structural* transformations — subquery pull-up, decorrelation, aggregate pushdown/pullup — violate group locality. Pulling a subquery above a join moves an operator from one group into a parent group, simultaneously changing the semantics of both. This creates a fundamental tension: either you perform these transformations inside the memo (risking complexity) or outside it (losing cost-awareness).

The strategies observed in practice are:

1. **Pre-memo normalisation** (SQL Server): perform disruptive transformations on the plain tree before the memo is built.
2. **New group creation** (ORCA): the transformation creates new groups rather than modifying existing ones; old groups remain intact.
3. **Multi-stage optimisation** (ORCA): transformations are partitioned into stages with timeouts, so the most disruptive rules run last.

No system we surveyed fully solves the problem of cost-comparing arbitrary structural transformations within the memo. This is an open challenge in the field.


## 3. SQL Server's Approach: The Apply Operator and Pre-Memo Normalisation

SQL Server's handling of subquery decorrelation is the best-documented industrial solution. The key papers are Galindo-Legaria & Joshi (2001) and Elhemali et al. (2007).

### 3.1 The Apply Operator

SQL Server introduces a logical operator called **Apply** — a correlated, parameterised join. The normalisation pipeline has three steps:

1. **Subquery removal:** SQL subqueries (creating mutual recursion between scalar and relational engines) are converted into explicit Apply operators.
2. **Apply removal (decorrelation):** Apply operators are transformed into regular joins, outer joins, or semijoins using algebraic identities describing how Apply distributes over Select, Project, Union, GroupBy, etc.
3. **Memo loading:** The decorrelated tree is loaded into the Cascades memo for cost-based exploration.

Steps 1–2 run on a plain operator tree — no memo, no cost model. The cross-group problem is avoided entirely.

### 3.2 Expression Categories

Elhemali et al. (2007) classify subquery expressions into categories by decorrelation tractability:

- **Category 1** (size-preserving): Always decorrelated during normalisation. Algebraically safe — the transformed tree has the same number of nodes.
- **Category 2** (size-exploding): Decorrelation requires exponential tree duplication. Left with Apply intact; handled case-by-case during cost-based optimisation.
- **Categories 3–4** (semantically opaque): Remain as Apply permanently and execute as parameterised nested loops.

### 3.3 Cost-Based Re-Introduction of Apply

After decorrelation, one of the alternatives the cost-based optimiser explores is *re-introducing Apply* — undoing the decorrelation if a correlated nested-loop plan turns out cheaper (e.g., when an index makes the inner side very selective). This partially compensates for the loss of cost comparison during normalisation.

Neumann & Kemper (2015) extended the algebraic framework for decorrelation to handle arbitrarily nested correlated subqueries, showing that the decorrelation approach is more general than previously assumed. Their work demonstrated that even deeply nested correlations can be unnested with polynomial overhead in most practical cases.

**References:**
- Galindo-Legaria, C. and Joshi, M. "Orthogonal Optimization of Subqueries and Aggregation." SIGMOD, 2001. [https://sigmodrecord.org/publications/sigmodRecord/0106/pdfs/Orthogonal%20Optimization%20of%20Subqueries%20and%20Aggregation.pdf](https://sigmodrecord.org/publications/sigmodRecord/0106/pdfs/Orthogonal%20Optimization%20of%20Subqueries%20and%20Aggregation.pdf)
- Elhemali, M., Galindo-Legaria, C., Grabs, T., and Joshi, M. "Execution Strategies for SQL Subqueries." SIGMOD, 2007. [https://www.csd.uoc.gr/~hy460/pdf/ExecutionStrategiesforSQLSubqueries.pdf](https://www.csd.uoc.gr/~hy460/pdf/ExecutionStrategiesforSQLSubqueries.pdf)
- Neumann, T. and Kemper, A. "Unnesting Arbitrary Queries." BTW, 2015. [https://cs.emis.de/LNI/Proceedings/Proceedings241/383.pdf](https://cs.emis.de/LNI/Proceedings/Proceedings241/383.pdf)


## 4. PostgreSQL's Query Rewriting Architecture

### 4.1 Overview

PostgreSQL follows the classical two-phase architecture inherited from POSTGRES (Stonebraker & Rowe, 1986) and System R: heuristic preprocessing followed by cost-based planning. The preprocessing is implemented as hardcoded C transformations — there is no formal rule engine, no memo structure, and no cost model involvement at this stage.

### 4.2 Preprocessing Transformations: A Complete Taxonomy

The preprocessing phase (`src/backend/optimizer/prep/` and early `subquery_planner()`) applies the following categories of transformations:

**Structurally safe (monotonically beneficial or semantics-preserving):**

- **Constant folding and expression simplification** (`eval_const_expressions`): Evaluates constant subexpressions at plan time, simplifies boolean logic, inlines simple SQL functions. This is unconditionally beneficial — it reduces work without changing the search space.
- **Predicate distribution** (`distribute_qual_to_rels`, `deconstruct_jointree`): Pushes WHERE conditions down to the lowest join level where all required relations are available. In the absence of unusual cost asymmetries, early filtering reduces intermediate result sizes.
- **Outer join reduction** (`reduce_outer_joins`): Converts LEFT/RIGHT JOINs to inner joins when WHERE clauses logically eliminate the possibility of null-extended rows. This *relaxes* a constraint, giving the cost-based planner strictly more freedom — it can still choose a plan that behaves like a left join if that happens to be cheapest.
- **Join removal** (`remove_useless_joins`): Eliminates joins that provably have no effect on the result (e.g., a LEFT JOIN to a table with a unique key whose columns are never referenced). Correctness is guaranteed by the uniqueness and non-use conditions.
- **Constraint exclusion and static partition pruning**: Eliminates child tables or partitions that provably contain no matching rows, based on CHECK constraints or partition bounds. This is a logical deduction — the pruned partitions literally cannot contribute rows.
- **Group-by simplification** (`remove_useless_groupby_columns`): Removes GROUP BY columns that are functionally dependent on a primary key (since PG16). Relies on functional dependency — the removed columns are provably redundant.
- **UNION ALL flattening** (`flatten_simple_union_all`): Merges nested UNION ALL trees into flat Append structures. This is a structural normalisation that does not change semantics or search space.

**Structurally risky (may increase or decrease plan quality):**

- **Subquery flattening** (`pull_up_subqueries`): Pulls simple subqueries from FROM into the parent query level, merging their relations into the parent's join problem. This increases *n* (the number of relations in the join enumeration problem), changes the available join orderings, and removes implicit materialization boundaries. The transformation is gated by safety checks (`is_safe_appendrel_member`, checks for volatile functions, set-returning functions, etc.) but **not by cost**.

- **Sublink-to-join conversion** (`convert_ANY_sublink_to_join`, `convert_EXISTS_sublink_to_join`): Transforms correlated IN/EXISTS/ANY subqueries in WHERE into semi-joins or anti-joins. This changes the execution strategy from "execute subquery per outer row (or as a hashed SubPlan)" to "add a semi-join to the join tree." PostgreSQL does in some cases generate both alternatives (the converted semi-join path vs. a SubPlan node), providing partial cost comparison — but the structural decision to pull up happens before the cost model is consulted, and the scope of the comparison is limited.

- **CTE inlining** (since PG12): Inlines non-recursive, single-reference CTEs into the main query rather than materialising them. Prior to PG12, all CTEs acted as optimisation fences — they were always materialised (Wartena, 2019). The change to inline by default can expose the CTE's tables to the parent's join optimisation (a potential win) but also removes the materialisation barrier (a potential loss if the CTE's output is expensive to recompute). Users can override with `MATERIALIZED`/`NOT MATERIALIZED` hints.

### 4.3 What PostgreSQL Does and Does Not Do (Recent Developments)

The gap between PostgreSQL and Cascades-style systems has been narrowing. Several transformations that were absent as recently as PostgreSQL 17 have since been added, while others remain missing.

**Now available:**

- **Eager aggregation** (PostgreSQL 19): PostgreSQL 19 introduces eager aggregation — pushing GROUP BY below joins to reduce intermediate result sizes before joining. This implements the core idea from Yan & Larson (1995). The feature is controlled by two GUC parameters: `enable_eager_aggregate` (on/off) and `min_eager_agg_group_size` (minimum estimated group count to trigger the transformation). Crucially, this is a *cost-based* transformation: the planner considers both the eager-aggregate path and the conventional aggregate-after-join path and picks the cheaper one. This represents a departure from PostgreSQL's usual pattern of cost-blind preprocessing — eager aggregation is evaluated during cost-based planning, not during heuristic rewriting.

- **Incremental sort for window functions** (PostgreSQL 18): PostgreSQL 18 added the ability to use incremental sort when evaluating window functions, partially addressing the rigidity of window function evaluation. When a query has multiple window functions with compatible PARTITION BY / ORDER BY clauses, incremental sort can exploit an existing partial ordering rather than performing a full re-sort. This does not constitute full window function reordering (the evaluation order remains fixed), but it significantly reduces sort overhead in practice.

**Still absent:**

- **Lazy aggregation**: The complementary transformation to eager aggregation — pulling GROUP BY above joins to expose more join orderings — is not implemented. Lazy aggregation (Yan & Larson, 1995; Chaudhuri & Shim, 1994) is useful when the aggregation is restrictive but the join selectivity is high; PostgreSQL does not consider this alternative.

- **Full window function reordering**: Reordering window function computations to share sorts or partitioning across different window specifications. PostgreSQL evaluates window functions in a fixed order determined by their PARTITION BY / ORDER BY clauses. Incremental sort (PG18) mitigates the cost but does not explore alternative evaluation orders.

- **Cost-informed decorrelation reversal**: Unlike SQL Server, PostgreSQL cannot re-introduce correlation (the Apply pattern) as a cost-based alternative after decorrelation. Once a sublink is converted to a semi-join, the correlated SubPlan form may still be available as an alternative *if* the conversion was partial, but there is no general mechanism for this. This remains the most significant gap relative to SQL Server's architecture.

**References:**
- Yan, W.P. and Larson, P.A. "Eager Aggregation and Lazy Aggregation." VLDB, 1995. [https://www.vldb.org/conf/1995/P345.PDF](https://www.vldb.org/conf/1995/P345.PDF)
- Chaudhuri, S. and Shim, K. "Including Group-By in Query Optimization." VLDB, 1994. [https://www.vldb.org/conf/1994/P354.PDF](https://www.vldb.org/conf/1994/P354.PDF)
- PostgreSQL 19 Release Notes. `enable_eager_aggregate` parameter. [https://www.postgresql.org/docs/devel/runtime-config-query.html](https://www.postgresql.org/docs/devel/runtime-config-query.html)
- Schönig, H.J. "Super fast aggregations in PostgreSQL 19." CYBERTEC, 2025. [https://www.cybertec-postgresql.com/en/super-fast-aggregations-in-postgresql-19/](https://www.cybertec-postgresql.com/en/super-fast-aggregations-in-postgresql-19/)


## 5. The Uncertainty Problem: Why It Matters

### 5.1 Cardinality Estimation Errors Amplify Transformation Risk

Leis et al. (2015) demonstrated empirically that cardinality estimation errors in production optimisers are pervasive and often dramatic — off by orders of magnitude. Their Join Order Benchmark (JOB) showed that these errors, rather than cost model inaccuracies or enumeration limitations, are the dominant factor behind poor plan quality.

This finding is directly relevant to the rewriting question. When PostgreSQL decides to flatten a subquery, it implicitly assumes that the larger join problem (with more relations) will be solved well by the cost-based planner. But if cardinality estimates for the newly-exposed joins are wrong — which Leis et al. show is likely for multi-way joins — the "optimised" plan after flattening may be worse than the original nested form, where each subquery was planned independently against a smaller, more tractable estimation problem.

In formal terms: partitioning the query into independently-planned subproblems (the pre-flattening state) reduces the *propagation* of estimation errors. Each subquery is a smaller estimation problem with fewer opportunities for error multiplication. Flattening merges these subproblems, creating a larger estimation surface where errors compound across more joins.

**Reference:** Leis, V., Gubichev, A., Mirchev, A., Boncz, P., Kemper, A., and Neumann, T. "How Good Are Query Optimizers, Really?" PVLDB, 9(3), 2015. [https://www.vldb.org/pvldb/vol9/p204-leis.pdf](https://www.vldb.org/pvldb/vol9/p204-leis.pdf)

### 5.2 The Materialization Barrier Effect

A subquery that is *not* flattened acts as an implicit materialisation barrier: the executor computes the subquery's result once and stores it. After flattening, this barrier vanishes. If the planner chooses a nested-loop join that rescans the former subquery's tables, performance can degrade severely — what was computed once may now be computed thousands of times.

This is not a theoretical concern. The PostgreSQL community has documented cases where `OFFSET 0` is added to subqueries specifically to prevent flattening and force materialisation — a manual workaround for the lack of cost-aware transformation control. Tom Lane confirmed on pgsql-general (2005) that the planner intentionally does not see through this no-op clause, because the trick is too useful to eliminate.

A closely related problem occurs when subquery flattening pushes the number of join items past `from_collapse_limit` (default 8) or `join_collapse_limit`. The PostgreSQL documentation explicitly acknowledges this: beyond the limit, the planner joins remaining tables in the order written, which may be arbitrarily bad. A concrete case from December 2024 documents a production query on PostgreSQL RDS where the 11th join — the most selective one — was not considered during join reordering because the default `join_collapse_limit` of 8 excluded it; the query ran for over a minute until the DBA raised the limit to 12.

**References:**
- Lane, T. "Re: How to force subquery scan?" pgsql-general, 2005. [https://www.postgresql.org/message-id/6303.1110987712@sss.pgh.pa.us](https://www.postgresql.org/message-id/6303.1110987712@sss.pgh.pa.us)
- PostgreSQL Documentation. "Controlling the Planner with Explicit JOIN Clauses." [https://www.postgresql.org/docs/current/explicit-joins.html](https://www.postgresql.org/docs/current/explicit-joins.html)
- "Using join_collapse_limit to solve PostgreSQL performance problem." Gluten Free SQL, 2024-12-31. [https://glutenfreesql.wordpress.com/2024/12/31/using-join_collapse_limit-to-solve-postgresql-performance-problem/](https://glutenfreesql.wordpress.com/2024/12/31/using-join_collapse_limit-to-solve-postgresql-performance-problem/)
- Schönig, H.J. "Subqueries and performance in PostgreSQL." CYBERTEC. [https://www.cybertec-postgresql.com/en/subqueries-and-performance-in-postgresql/](https://www.cybertec-postgresql.com/en/subqueries-and-performance-in-postgresql/)
- "Forcing Join Order in Postgres Using Optimization Barriers." pganalyze, 2024. [https://pganalyze.com/blog/5mins-postgres-forcing-join-order](https://pganalyze.com/blog/5mins-postgres-forcing-join-order)

### 5.3 Formal Characterisation of the Problem

The transformation uncertainty problem can be formalised as follows. Let *Q* be a query tree, and let *T* be a set of applicable heuristic transformations. Each transformation *t_i* ∈ *T* maps *Q* to a logically equivalent tree *t_i(Q)*. The cost-based optimiser produces a plan *P(Q')* for any tree *Q'*, with estimated cost *C_est(P(Q'))* and true cost *C_true(P(Q'))*.

The problem: we want to choose the subset *S* ⊆ *T* that minimises *C_true(P(S(Q)))*, where *S(Q)* denotes the application of all transformations in *S*. But we can only observe *C_est*, not *C_true*, and the estimation error *|C_est − C_true|* depends on *S(Q)* — different tree shapes have different estimation accuracy characteristics.

This is a decision problem under uncertainty where the quality of information available to the decision-maker (the cost model) *changes with the decision being made* (the choice of transformations). Standard optimisation theory offers no general solution for this class of problems without additional structure.


## 6. Alternative Approaches to Transformation Uncertainty

The literature offers several approaches that address transformation uncertainty, none of which PostgreSQL currently implements.

### 6.1 The Cascades Approach: Explore Both Forms

As described in Section 2, the Cascades memo can hold both the original and transformed expressions in the same group, letting the cost model choose. This is the theoretically cleanest solution for *local* transformations. For *structural* transformations (subquery pull-up, decorrelation), it breaks down because of the cross-group problem — even SQL Server falls back to heuristic normalisation for these cases (Section 3).

**Applicability to PostgreSQL:** Adopting a full Cascades-style memo would be a fundamental rewrite of the optimiser. The PostgreSQL community has historically preferred incremental, well-tested changes over architectural revolutions. The cost-benefit ratio is unclear: Cascades brings theoretical elegance but also implementation complexity (ORCA reports ~200 MB memory and ~4 seconds optimisation time per TPC-DS query — Soliman et al., 2014), and the cross-group problem means the hardest transformations still escape cost-based control.

### 6.2 Parametric Query Optimisation

Ioannidis et al. (1992, 1997) proposed parametric query optimisation (PQO): instead of optimising for a single set of parameter values, pre-compute optimal plans for all regions of the parameter space. At execution time, select the plan matching actual parameter values.

This idea is relevant to transformation uncertainty because the "parameters" can include cardinality estimates for the relations affected by a transformation. If flattening a subquery changes the join problem, one could precompute plans for both the flattened and non-flattened forms and choose at execution time based on actual intermediate result sizes.

**Applicability to PostgreSQL:** PQO has never been implemented in PostgreSQL. The main barrier is that the number of parameter-space regions can grow exponentially with the number of parameters. However, a restricted form — precomputing plans for "flattened" vs. "non-flattened" — involves only a binary choice per risky transformation, which is tractable.

**Reference:** Ioannidis, Y.E., Ng, R.T., Shim, K., and Sellis, T.K. "Parametric Query Optimization." VLDB Journal, 6(2), 1997. [https://link.springer.com/article/10.1007/s007780050037](https://link.springer.com/article/10.1007/s007780050037)

### 6.3 Progressive Optimisation (Re-Optimisation at Checkpoints)

Markl et al. (2004) proposed progressive optimisation (POP): the optimiser inserts CHECK operators into the plan that compare actual cardinalities against estimates during execution. If a significant deviation is detected, execution is halted and the remaining subplan is re-optimised using actual statistics.

This approach directly addresses the estimation error problem: instead of betting on one transformation's accuracy, you detect when the bet was wrong and recover.

**Applicability to PostgreSQL:** PostgreSQL has no re-optimisation mechanism. Adding one would require infrastructure to checkpoint execution state, re-invoke the planner mid-query, and resume execution with a new subplan. This is non-trivial but has been implemented in DB2 (where POP originated) and discussed for SQL Server.

**Reference:** Markl, V., Raman, V., Simmen, D., and Lohman, G. "Robust Query Processing through Progressive Optimization." SIGMOD, 2004. [https://dl.acm.org/doi/10.1145/1007568.1007642](https://dl.acm.org/doi/10.1145/1007568.1007642)

### 6.4 Robust Query Optimisation

Babcock & Chaudhuri (2005) proposed an approach where the optimiser explicitly reasons about estimation uncertainty and chooses plans that are robust — performing reasonably well across a range of possible cardinalities, rather than optimally for the single-point estimate. The optimiser trades peak performance for predictability.

This is directly applicable to transformation decisions: a "robust" transformation policy would avoid transformations that create high-variance plan quality, even if the expected (estimated) quality is better.

**Reference:** Babcock, B. and Chaudhuri, S. "Towards a Robust Query Optimizer: A Principled and Practical Approach." SIGMOD, 2005. [https://dl.acm.org/doi/10.1145/1066157.1066171](https://dl.acm.org/doi/10.1145/1066157.1066171)

### 6.5 Adaptive Query Processing: Eddies

Avnur & Hellerstein (2000) proposed *eddies*: a runtime mechanism that continuously reorders operators during execution based on observed throughput. Instead of committing to a fixed plan, the eddy routes tuples through operators adaptively, learning the best ordering on the fly.

The eddy approach is radical: it eliminates the distinction between optimisation time and execution time entirely. The cost of a transformation is never *estimated* — it is *observed*.

**Applicability to PostgreSQL:** Eddies require a fundamentally different execution engine (tuple-at-a-time routing through operators). PostgreSQL's Volcano-style iterator model would need significant modification. SkinnerDB (Trummer et al., 2019) demonstrated a practical system based on these ideas, using reinforcement learning to select join orders during execution with formal regret bounds — but it maintains no statistics and uses no cost model, representing a complete departure from PostgreSQL's architecture.

**References:**
- Avnur, R. and Hellerstein, J.M. "Eddies: Continuously Adaptive Query Processing." SIGMOD, 2000. [https://dl.acm.org/doi/10.1145/342009.335420](https://dl.acm.org/doi/10.1145/342009.335420)
- Trummer, I. et al. "SkinnerDB: Regret-Bounded Query Evaluation via Reinforcement Learning." SIGMOD, 2019. [https://dl.acm.org/doi/10.1145/3299869.3300088](https://dl.acm.org/doi/10.1145/3299869.3300088)

### 6.6 Learned Optimisers: LEO and Bao

**LEO** (Stillger et al., 2001) was the first production system to use feedback-driven optimisation. After executing a query, LEO compares actual cardinalities to estimates, computes adjustment factors, and applies them to future optimisations. This creates a closed feedback loop: the optimiser learns from its mistakes over repeated executions of similar queries.

**Bao** (Marcus et al., 2021) takes a different approach: instead of replacing the cost model, it uses a tree convolutional neural network combined with Thompson sampling (a bandit algorithm) to learn which sets of "query hints" (optimizer knobs — essentially, which transformations and physical strategies to enable/disable) produce the fastest plans. Bao operates *on top of* an existing optimiser, steering its decisions without replacing its infrastructure.

Bao is particularly relevant because it addresses the transformation uncertainty problem directly: it learns, from observed execution times, whether enabling or disabling specific transformations (subquery flattening, specific join methods, index usage) improves performance. The learned model captures correlations between query structure, data characteristics, and transformation effectiveness that the cost model cannot.

**Applicability to PostgreSQL:** Bao's architecture is designed to work with existing optimisers — it controls them via hint mechanisms rather than replacing them. PostgreSQL's `pg_hint_plan` extension provides a hint interface that could serve as the control surface. The main barriers are: (a) PostgreSQL has no built-in mechanism to collect plan execution feedback, and (b) the training infrastructure (neural network inference, Thompson sampling) would add runtime overhead.

**References:**
- Stillger, M., Lohman, G., Markl, V., and Kandil, M. "LEO — DB2's LEarning Optimizer." VLDB, 2001. [https://www.vldb.org/conf/2001/P019.pdf](https://www.vldb.org/conf/2001/P019.pdf)
- Marcus, R., Negi, P., Mao, H., Neumann, T., Kemper, A., and Tatbul, N. "Bao: Making Learned Query Optimization Practical." SIGMOD, 2021 (Best Paper). [https://dl.acm.org/doi/10.1145/3448016.3452838](https://dl.acm.org/doi/10.1145/3448016.3452838)


## 7. Comparison Summary

| Aspect | PostgreSQL | SQL Server (Cascades) | ORCA (Cascades) |
|--------|-----------|----------------------|-----------------|
| Architecture | Two-phase: heuristic rewrite + cost-based planning | Two-phase with Cascades: normalisation + memo-based cost optimisation | Cascades memo-based with exploration/implementation/optimisation phases |
| Rule formalisation | Hardcoded in C, no rule engine | Same tree-transformation infrastructure for both phases | Self-contained rule components, activatable/deactivatable |
| Subquery decorrelation | Heuristic preprocessing with safety checks | Normalisation before memo; Apply operator with algebraic identities | Exploration rules within memo; multi-stage with timeouts |
| Cost-aware transformations | No — preprocessing is cost-blind; cost comparison only for physical plan alternatives | Partial — decorrelation is heuristic, but Apply re-introduction is cost-based | Yes — exploration and implementation rules coexist in the same search space |
| Cross-group challenge | N/A (no memo) | Avoided by pre-memo normalisation | Managed via new group creation and multi-stage optimisation |
| Search space control | DP for small *n*, GEQO for large *n*; no transformation-level search | Branch-and-bound pruning, rule scheduling, memoisation, expression categories | Branch-and-bound, multi-stage with timeouts and cost thresholds, parallel scheduling |
| Feedback/learning | None | None documented in the public literature | None |
| Re-optimisation | None | Partial (Apply re-introduction during cost-based search) | Multi-stage allows early termination with acceptable plans |

### PostgreSQL's Niche: Strengths and Weaknesses

**Strengths:**
- *Simplicity and debuggability.* The hardcoded C transformations are straightforward to read, debug, and reason about. There is no rule-engine abstraction layer to navigate.
- *Predictability.* The heuristic preprocessing is deterministic and fast — no risk of optimisation timeouts or runaway memo expansion.
- *Low optimisation overhead.* PostgreSQL's planning time is typically measured in milliseconds, compared to seconds for ORCA (Soliman et al., 2014). For OLTP workloads where planning time matters, this is a significant advantage.
- *Independent subquery planning.* By *not* flattening complex subqueries, PostgreSQL often plans them independently, which limits estimation error propagation (per the analysis in Section 5.1).

**Weaknesses:**
- *Irrevocable heuristic decisions.* When subquery flattening or sublink-to-join conversion fires, the original form is discarded. If the transformation was harmful, the cost-based planner operates in a degraded search space with no awareness that a better space existed.
- *No transformation-level cost feedback.* The optimiser has no mechanism to learn that a specific transformation pattern produces poor plans.
- *Remaining transformation gaps.* Lazy aggregation, full window function reordering, and general decorrelation reversal are still absent. PostgreSQL 19 added eager aggregation (cost-based) and PostgreSQL 18 added incremental sort for window functions, narrowing the gap — but the search scope remains limited for queries where these missing transformations would help.
- *GEQO threshold interaction.* Subquery flattening can push the relation count past `geqo_threshold`, causing a qualitative change in the optimisation algorithm (from exact DP to randomised GEQO) that is invisible to the preprocessing phase.


## 8. Potential Directions for PostgreSQL

Based on the analysis above, we identify three directions ordered by increasing ambition and invasiveness.

### 8.1 Direction 1: Cost-Informed Transformation Gating (Low Invasiveness)

**Idea:** Before applying a risky transformation (subquery flattening, sublink-to-join), perform a cheap cost comparison: plan the query *both* with and without the transformation, compare estimated costs, and keep the cheaper form. This is not a full Cascades memo — it's a simple "try both, keep the winner" approach.

**Theoretical grounding:** This is a restricted form of parametric optimisation (Ioannidis et al., 1997) with a binary parameter space (transform vs. don't transform). The overhead is bounded: at most 2× planning time for each risky transformation, and the number of risky transformations per query is typically small (1–3).

**Practical considerations:** PostgreSQL already does something similar for SubPlan vs. semi-join in certain cases. Generalising this pattern would require infrastructure to "speculatively" apply a transformation, plan the result, and then backtrack if the original form is cheaper. The `subquery_planner` call is recursive, which provides a natural boundary for this speculation.

**Risk:** The cost estimate itself may be unreliable (per Leis et al., 2015), so the comparison may choose the wrong form. But the expected outcome is still better than unconditional application: even a noisy cost signal is better than no signal.

### 8.2 Direction 2: Execution Feedback for Transformation Decisions (Medium Invasiveness)

**Idea:** Record which transformations were applied and the resulting plan's execution time. Over repeated executions, build a profile of which transformation patterns help and which hurt. Use this profile to inform future transformation decisions.

**Theoretical grounding:** This follows the LEO approach (Stillger et al., 2001) adapted to transformation decisions rather than cardinality estimates. The feedback loop requires: (a) a way to identify "the same query with different transformations" across executions, and (b) storage for execution feedback keyed by query template + transformation set.

**Practical considerations:** PostgreSQL's `pg_stat_statements` already identifies query templates. Extending it to record which preprocessing transformations were applied, and using this data to gate future transformations, would be a natural evolution. The main engineering challenge is the backtracking mechanism: if feedback suggests a transformation should *not* be applied, PostgreSQL needs the ability to skip it for specific query templates.

### 8.3 Direction 3: Bandit-Based Transformation Selection (High Invasiveness)

**Idea:** Treat transformation selection as a multi-armed bandit problem, following the Bao approach (Marcus et al., 2021). Each "arm" is a transformation policy (a specific subset of enabled preprocessing transformations). The bandit algorithm learns which arm is best for each query class by observing execution times.

**Theoretical grounding:** Thompson sampling (the algorithm Bao uses) provides a formal regret bound: the cumulative excess cost over the optimal policy grows as O(√(T log T)) over T queries. This means the system converges to the best transformation policy with provable efficiency.

**Practical considerations:** This requires (a) a hint or knob mechanism to enable/disable individual preprocessing transformations, (b) execution time collection, and (c) inference infrastructure for the bandit model. The first requirement is partially met by existing GUC parameters; the others are new. The main concern is tail latency — the bandit must explore suboptimal policies to learn, and a bad exploration choice can cause a severe regression for a single query.


## 9. Conclusions

PostgreSQL's heuristic preprocessing occupies a specific — and defensible — niche in the design space. For the majority of queries, unconditional application of well-chosen transformations produces good results with minimal planning overhead. The system's simplicity, predictability, and low optimisation latency are genuine strengths, particularly for OLTP and mixed workloads.

However, the analysis reveals a structural vulnerability: the two risky transformations (subquery flattening and sublink-to-join conversion) make irrevocable decisions that can degrade plan quality, and the optimiser has no mechanism to detect or recover from these degradations. The theoretical framework (Section 5.3) shows that this is a decision problem under uncertainty where the quality of the decision-maker's information changes with the decision — a fundamentally hard problem.

The evidence from the literature suggests that **Direction 1 (cost-informed gating)** offers the best risk/reward ratio for PostgreSQL: it addresses the most common failure mode (transformation produces a worse plan than the original), requires bounded overhead (at most 2× planning time per risky transformation), and does not require new infrastructure beyond speculation/backtracking in `subquery_planner`. Directions 2 and 3 are more powerful but require new execution-feedback infrastructure that PostgreSQL currently lacks.

The key insight from the cross-system comparison is that **no production system fully solves this problem**. Even SQL Server, with its Cascades framework, falls back to heuristic normalisation for the most disruptive transformations. The pragmatic conclusion is that PostgreSQL does not need a Cascades-style rewrite to address transformation uncertainty — targeted cost-informed gating for the specific transformations that cause regressions would address the bulk of the problem with proportionate engineering effort.


## 10. References

1. Avnur, R. and Hellerstein, J.M. "Eddies: Continuously Adaptive Query Processing." SIGMOD, 2000. [https://dl.acm.org/doi/10.1145/342009.335420](https://dl.acm.org/doi/10.1145/342009.335420)

2. Babcock, B. and Chaudhuri, S. "Towards a Robust Query Optimizer: A Principled and Practical Approach." SIGMOD, 2005. [https://dl.acm.org/doi/10.1145/1066157.1066171](https://dl.acm.org/doi/10.1145/1066157.1066171)

3. Chaudhuri, S. and Shim, K. "Including Group-By in Query Optimization." VLDB, 1994. [https://www.vldb.org/conf/1994/P354.PDF](https://www.vldb.org/conf/1994/P354.PDF)

4. Ding, B., Narasayya, V., and Chaudhuri, S. "Extensible Query Optimizers in Practice." Foundations and Trends in Databases, 14, 2024. [https://www.microsoft.com/en-us/research/publication/extensible-query-optimizers-in-practice/](https://www.microsoft.com/en-us/research/publication/extensible-query-optimizers-in-practice/)

5. Elhemali, M., Galindo-Legaria, C., Grabs, T., and Joshi, M. "Execution Strategies for SQL Subqueries." SIGMOD, 2007. [https://www.csd.uoc.gr/~hy460/pdf/ExecutionStrategiesforSQLSubqueries.pdf](https://www.csd.uoc.gr/~hy460/pdf/ExecutionStrategiesforSQLSubqueries.pdf)

6. Galindo-Legaria, C. and Joshi, M. "Orthogonal Optimization of Subqueries and Aggregation." SIGMOD, 2001. [https://sigmodrecord.org/publications/sigmodRecord/0106/pdfs/Orthogonal%20Optimization%20of%20Subqueries%20and%20Aggregation.pdf](https://sigmodrecord.org/publications/sigmodRecord/0106/pdfs/Orthogonal%20Optimization%20of%20Subqueries%20and%20Aggregation.pdf)

7. Graefe, G. "The Cascades Framework for Query Optimization." IEEE Data Engineering Bulletin, 18(3), 1995. [https://15721.courses.cs.cmu.edu/spring2016/papers/graefe-ieee1995.pdf](https://15721.courses.cs.cmu.edu/spring2016/papers/graefe-ieee1995.pdf)

8. Graefe, G. and McKenna, W.J. "The Volcano Optimizer Generator: Extensibility and Efficient Search." ICDE, 1993. [https://dl.acm.org/doi/10.5555/645478.757691](https://dl.acm.org/doi/10.5555/645478.757691)

9. Ibaraki, T. and Kameda, T. "On the Optimal Nesting Order for Computing N-Relational Joins." ACM TODS, 9(3), 1984. [https://dl.acm.org/doi/10.1145/1270.1498](https://dl.acm.org/doi/10.1145/1270.1498)

9a. Lane, T. "Re: How to force subquery scan?" pgsql-general mailing list, 2005-03-16. [https://www.postgresql.org/message-id/6303.1110987712@sss.pgh.pa.us](https://www.postgresql.org/message-id/6303.1110987712@sss.pgh.pa.us)

10. Ioannidis, Y.E., Ng, R.T., Shim, K., and Sellis, T.K. "Parametric Query Optimization." VLDB Journal, 6(2), 1997. [https://link.springer.com/article/10.1007/s007780050037](https://link.springer.com/article/10.1007/s007780050037)

11. Kimball, A. "How We Built a Cost-Based SQL Optimizer." Cockroach Labs Blog, 2018. [https://www.cockroachlabs.com/blog/building-cost-based-sql-optimizer/](https://www.cockroachlabs.com/blog/building-cost-based-sql-optimizer/)

12. Leis, V., Gubichev, A., Mirchev, A., Boncz, P., Kemper, A., and Neumann, T. "How Good Are Query Optimizers, Really?" PVLDB, 9(3), 2015. [https://www.vldb.org/pvldb/vol9/p204-leis.pdf](https://www.vldb.org/pvldb/vol9/p204-leis.pdf)

13. Marcus, R., Negi, P., Mao, H., Neumann, T., Kemper, A., and Tatbul, N. "Bao: Making Learned Query Optimization Practical." SIGMOD, 2021. [https://dl.acm.org/doi/10.1145/3448016.3452838](https://dl.acm.org/doi/10.1145/3448016.3452838)

14. Markl, V., Raman, V., Simmen, D., and Lohman, G. "Robust Query Processing through Progressive Optimization." SIGMOD, 2004. [https://dl.acm.org/doi/10.1145/1007568.1007642](https://dl.acm.org/doi/10.1145/1007568.1007642)

15. Moerkotte, G. and Neumann, T. "Analysis of Two Existing and One New Dynamic Programming Algorithm for the Generation of Optimal Bushy Join Trees without Cross Products." VLDB, 2006. [https://dl.acm.org/doi/10.5555/1182635.1164207](https://dl.acm.org/doi/10.5555/1182635.1164207)

16. Neumann, T. and Kemper, A. "Unnesting Arbitrary Queries." BTW, 2015. [https://cs.emis.de/LNI/Proceedings/Proceedings241/383.pdf](https://cs.emis.de/LNI/Proceedings/Proceedings241/383.pdf)

17. Pellenkoft, A., Galindo-Legaria, C., and Kersten, M. "The Complexity of Transformation-Based Join Enumeration." VLDB, 1997. [https://dl.acm.org/doi/10.5555/645923.673661](https://dl.acm.org/doi/10.5555/645923.673661)

18. Pirahesh, H., Hellerstein, J.M., and Hasan, W. "Extensible/Rule Based Query Rewrite Optimization in Starburst." SIGMOD, 1992. [https://dl.acm.org/doi/10.1145/141484.130294](https://dl.acm.org/doi/10.1145/141484.130294)

19. Selinger, P.G., Astrahan, M.M., Chamberlin, D.D., Lorie, R.A., and Price, T.G. "Access Path Selection in a Relational Database Management System." SIGMOD, 1979. [https://dl.acm.org/doi/10.1145/582095.582099](https://dl.acm.org/doi/10.1145/582095.582099)

20. Soliman, M.A. et al. "Orca: A Modular Query Optimizer Architecture for Big Data." SIGMOD, 2014. [https://dl.acm.org/doi/10.1145/2588555.2595637](https://dl.acm.org/doi/10.1145/2588555.2595637)

21. Stillger, M., Lohman, G., Markl, V., and Kandil, M. "LEO — DB2's LEarning Optimizer." VLDB, 2001. [https://www.vldb.org/conf/2001/P019.pdf](https://www.vldb.org/conf/2001/P019.pdf)

22. Taft, R. et al. "CockroachDB: The Resilient Geo-Distributed SQL Database." SIGMOD, 2020. [https://dl.acm.org/doi/10.1145/3318464.3386134](https://dl.acm.org/doi/10.1145/3318464.3386134)

23. Trummer, I. et al. "SkinnerDB: Regret-Bounded Query Evaluation via Reinforcement Learning." SIGMOD, 2019. [https://dl.acm.org/doi/10.1145/3299869.3300088](https://dl.acm.org/doi/10.1145/3299869.3300088)

24. Yan, W.P. and Larson, P.A. "Eager Aggregation and Lazy Aggregation." VLDB, 1995. [https://www.vldb.org/conf/1995/P345.PDF](https://www.vldb.org/conf/1995/P345.PDF)
