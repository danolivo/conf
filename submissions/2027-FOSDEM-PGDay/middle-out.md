# Beyond bottom-up: a plan refinement technique for the PostgreSQL planner

PostgreSQL builds query plans bottom-up, based on local, cost-based choices before it has the global picture. A surprising number of valuable optimisations fall outside what that model can express - not because they're hard to implement, but because the information needed to decide on them only appears after the relevant planning decisions have already been made. The planner literally can't cost them anything, so today each one is either skipped or hacked in an ad hoc way. A recent example is Bloom filters technique for hash joins, which is discussed right now on the hackers mailing list.

This talk proposes a unifying answer: one more pass, in the reverse (top-down) direction, run after the prospective plans are prepared. It walks the 'almost finalised' plan from the top and refines parts of it in a cost-based manner that might benefit from the upper-level decision knowledge.

To make it concrete, I have written the pg_middleout extension, which implements the simplest case: Memoize node on top of correlated scalar subqueries that the planner can't transform - a typical scenario in ERP databases, REST APIs, or AI-generated queries. We'll see why the planner can't cache them, then how the pg_middleout extension adds a Memoize node in a top-down pass using the cost-based approach.

45 min, Postgres Internals.
