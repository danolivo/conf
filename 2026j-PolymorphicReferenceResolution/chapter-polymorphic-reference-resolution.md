# Polymorphic Reference Resolution in Relational Databases

## The Pattern

Many real-world data models contain references that can point to one of several
target entity types. An order line item may reference a physical product, a
digital download, a gift card, or a subscription. A CRM activity record may be
linked to a contact, a company, or a deal. An ERP document entry may refer to
any of dozens of upstream document types.

In an object-oriented model this is natural: a field holds a reference to an
interface or a base class, and the runtime resolves the concrete type. Relational
schemas have no native mechanism for this. The most common encoding uses a
**discriminated foreign key** — two or three columns that together identify the
target table and the row within it:

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
    CASE
        WHEN ol.item_type = 'product'      THEN p.name
        WHEN ol.item_type = 'gift_card'    THEN g.name
        WHEN ol.item_type = 'subscription' THEN s.name
    END AS item_name
FROM order_lines ol
LEFT JOIN products      p ON ol.item_type = 'product'
                          AND ol.item_id = p.id
LEFT JOIN gift_cards    g ON ol.item_type = 'gift_card'
                          AND ol.item_id = g.id
LEFT JOIN subscriptions s ON ol.item_type = 'subscription'
                          AND ol.item_id = s.id;
```

For every row in `order_lines`, at most one of the three LEFT JOINs produces a
match; the other two are guaranteed to return NULLs. As the number of target
types grows, so does the fan-out of LEFT JOINs. Queries against production ERP
schemas routinely contain eight to twenty such joins.

We refer to this query shape — a base table joined to N target tables via
discriminator-guarded LEFT JOINs, collapsed by a CASE expression — as the
**polymorphic reference resolution pattern**.


## Where the Pattern Appears

The pattern is pervasive across application domains.

**ERP and accounting systems.** 1C:Enterprise, one of the most widely deployed
ERP platforms in Russia and CIS countries, encodes all cross-document references
as a triple of bytea columns (`_TYPE`, `_RTRef`, `_RRRef`) and generates
exactly this query shape for reporting views. SAP and Oracle E-Business Suite
use analogous structures for generic document references.

**E-commerce platforms.** Order line items, payment transactions, and discount
rules frequently reference polymorphic targets. Drupal Commerce models line
items with an explicit type discriminator that can represent products, shipping
charges, or coupons (Drupal Commerce Documentation, 2015).

**Object-relational mapping frameworks.** Ruby on Rails popularised the term
"polymorphic association," implemented as a `_type` / `_id` column pair
(Ruby on Rails Guides, 2024). Hibernate's joined-table inheritance strategy
generates outer joins across all subclass tables with a runtime type check
(Bauer and King, 2006). SQLAlchemy, Django, and Entity Framework all support
variants of the same pattern.

**CRM platforms.** Salesforce exposes polymorphic lookup fields (`WhoId`,
`WhatId`) on the Activity object, resolvable via the `TYPEOF` operator in
their query language (Salesforce SOQL Reference, 2024).


## Schema-Level Alternatives

The database literature offers several strategies for modelling type hierarchies
in relational schemas. Teorey, Yang, and Fry formalised the mapping of
Enhanced Entity-Relationship generalisation hierarchies to relational tables
(Teorey et al., 1986). Fowler later catalogued three practitioner-oriented
patterns (Fowler, 2002):

- **Class Table Inheritance** (called "Common Super-Table" by Karwin, 2010).
  A shared parent table holds a surrogate key and common attributes; each
  subtype has its own table whose primary key is also a foreign key to the
  parent. Any reference simply points to the parent table, eliminating the
  discriminator column and enabling standard foreign-key constraints. The
  cost is an extra join per access and a write to two tables per insert.

- **Single Table Inheritance.** All subtypes are collapsed into one wide table
  with a type column and many nullable columns. References become ordinary
  foreign keys. Query resolution is trivial, but the table is sparse and
  may grow unwieldy.

- **Concrete Table Inheritance.** Each subtype is a fully independent table
  with no shared parent. Polymorphic queries require UNION ALL across all
  subtype tables.

Karwin dedicated a full chapter of *SQL Antipatterns* to the discriminated
foreign key under the name "Polymorphic Associations," arguing that it
sacrifices referential integrity and query performance for schema simplicity
(Karwin, 2010). The GitLab engineering handbook explicitly prohibits the pattern
in their codebase for the same reasons (GitLab Documentation, 2024).

Despite these alternatives, the discriminated foreign key remains dominant in
practice — particularly in ORM-generated schemas and large ERP platforms where
retroactive schema changes are prohibitively expensive.


## How Database Systems Address the Performance Problem

The polymorphic resolution query is expensive for two reasons: (1) the executor
probes N inner tables for every outer row, even though at most one can match;
(2) the planner cannot push selectivity from inner tables back to the outer
scan. Several families of optimisations target one or both of these costs.

**Join elimination.** If a LEFT JOIN is provably unnecessary — its columns are
not referenced in the output and it cannot duplicate rows — the optimiser can
remove it entirely. PostgreSQL has supported outer-join removal since version
9.0 for the case where the inner side has a unique index on the join key
(Haas, 2010). DB2 and Oracle apply join elimination more aggressively, using
referential-integrity metadata (Pirahesh et al., 1992). However, in the
polymorphic pattern every join contributes a column to the CASE expression, so
none qualify for removal in the general case.

**Sideways information passing (SIP).** SIP techniques construct filters from
one side of a join and push them down to the scan of the other side. Bloom
filters built from the inner (dimension) table can be injected into the outer
(fact) table scan, eliminating rows that cannot have a join partner before they
reach the join operator. The Vertica system implements SIP filters that
propagate all the way down to base-table scan nodes (Vertica Systems, 2012).
A recent formalisation introduces *data-induced predicates* — synthetic
predicates derived from data statistics on one table and applied to a joining
table (Kandula et al., 2021). Apache Spark implements a production variant
as Dynamic Partition Pruning and runtime Bloom filter injection since version
3.0 (Spark Documentation, 2020). PostgreSQL has discussed but not yet committed
Bloom filter pushdown patches for hash and merge joins.

**Adaptive query execution.** Rather than committing to a single plan at
optimisation time, adaptive executors defer decisions to runtime. Graefe's
Volcano system introduced the `choose-plan` meta-operator, which selects among
pre-compiled subplans based on runtime conditions (Graefe, 1994). Avnur and
Hellerstein's Eddies route individual tuples through operators adaptively,
enabling per-row plan variation (Avnur and Hellerstein, 2000). Oracle Database
12c implemented adaptive plans in production, inserting statistics-collector
nodes that trigger subplan switches when observed cardinalities diverge from
estimates (Oracle Corporation, 2013). Applied to the polymorphic pattern, an
adaptive executor could in principle route each outer row only to its matching
join operator, skipping the others entirely — though no current system
implements this specific optimisation.

**Partition-wise joins.** If the base table is list-partitioned on the
discriminator column, each partition contains rows for exactly one target type.
A partition-wise join then pairs each partition with only its corresponding
target table, and the remaining N−1 joins are pruned at plan time. PostgreSQL
supports partition-wise joins since version 11 (Langote, 2018). This approach
is highly effective but requires the schema to be designed — or retroactively
restructured — with partitioning in mind.

**Star transformation.** Oracle's star transformation rewrites a fact-to-many-dimensions join into bitmap semi-join predicates, probing bitmap
indexes on the fact table's foreign-key columns to retrieve only the matching
rows before performing the final joins (Oracle Corporation, 2003). The
polymorphic resolution query is structurally analogous to a star join, with
the base table as the fact and each target table as a dimension.


## Summary

The polymorphic reference resolution pattern is a direct consequence of the
impedance mismatch between polymorphic object references and the relational
model. It produces queries with a characteristic N-way LEFT JOIN fan-out that
grows linearly with the number of target types. While schema-level solutions
exist (Teorey et al., 1986; Fowler, 2002; Karwin, 2010), they are often
impractical for established systems. Existing query optimisations — join
elimination, SIP, adaptive execution, partition-wise joins, and star
transformation — each address part of the problem, but no production system
currently combines them into a holistic optimisation for this specific query
shape. The following chapters describe a series of PostgreSQL-specific
optimisations that target this gap.


## References

Avnur, R. and Hellerstein, J.M. (2000) 'Eddies: continuously adaptive query
processing', *Proceedings of the 2000 ACM SIGMOD International Conference on
Management of Data*, pp. 261–272. doi:10.1145/342009.335420.

Bauer, C. and King, G. (2006) *Java Persistence with Hibernate*. Greenwich,
CT: Manning Publications.

Drupal Commerce Documentation (2015) *Commerce Line Items*. Available at:
https://mglaman.gitbooks.io/getting-cozy-with-drupal-commerce/.

Fowler, M. (2002) *Patterns of Enterprise Application Architecture*. Boston,
MA: Addison-Wesley.

GitLab Documentation (2024) *Polymorphic Associations*. Available at:
https://docs.gitlab.com/ee/development/database/polymorphic_associations.html.

Graefe, G. (1994) 'Volcano — an extensible and parallel query evaluation
system', *IEEE Transactions on Knowledge and Data Engineering*, 6(1),
pp. 120–135. doi:10.1109/69.273032.

Haas, R. (2010) *Why Join Removal Is Cool* [Blog]. Available at:
http://rhaas.blogspot.com/2010/06/why-join-removal-is-cool.html.

Kandula, S., Orr, L. and Chaudhuri, S. (2021) 'Data-induced predicates for
sideways information passing in query optimizers', *The VLDB Journal*, 31(6).
doi:10.1007/s00778-021-00693-2.

Karwin, B. (2010) *SQL Antipatterns: Avoiding the Pitfalls of Database
Programming*. Raleigh, NC: Pragmatic Bookshelf.

Langote, A. (2018) *Partition-wise join for join between (declaratively)
partitioned tables* [PostgreSQL patch]. Available at:
https://www.postgresql.org/message-id/CAFjFpRfQ8GrQvzp3jA2wnLqrHmaXna-urjm_UY9BqXj=EaDTSA@mail.gmail.com.

Oracle Corporation (2003) *Data Warehousing Optimizations and Techniques*.
Available at:
https://docs.oracle.com/cd/F49540_01/DOC/server.815/a67781/c20c_joi.htm.

Oracle Corporation (2013) *Optimizer with Oracle Database 12c Release 2*
[White paper]. Available at:
https://www.oracle.com/technetwork/database/bi-datawarehousing/twp-optimizer-with-oracledb-12c-1963236.pdf.

Pirahesh, H., Hellerstein, J.M. and Hasan, W. (1992) 'Extensible/rule based
query rewrite optimization in Starburst', *Proceedings of the 1992 ACM SIGMOD
International Conference on Management of Data*, pp. 39–48.
doi:10.1145/130283.130294.

Ruby on Rails Guides (2024) *Active Record Associations*. Available at:
https://guides.rubyonrails.org/association_basics.html.

Salesforce SOQL Reference (2024) *Understanding Relationship Fields and
Polymorphic Fields*. Available at:
https://developer.salesforce.com/docs/atlas.en-us.soql_sosl.meta/soql_sosl/sforce_api_calls_soql_relationships_and_polymorph_keys.htm.

Spark Documentation (2020) *Adaptive Query Execution: Speeding Up Spark SQL at
Runtime*. Available at:
https://www.databricks.com/blog/2020/05/29/adaptive-query-execution-speeding-up-spark-sql-at-runtime.html.

Teorey, T.J., Yang, D. and Fry, J.P. (1986) 'A logical design methodology for
relational databases using the extended entity-relationship model', *ACM
Computing Surveys*, 18(2), pp. 197–222. doi:10.1145/7474.7475.

Vertica Systems (2012) *Sideways Information Passing* [Patent
WO2012170049A1]. Available at:
https://patents.google.com/patent/WO2012170049A1/en.
