# Slide 1. Title

Introduce myself. My primary interest is planner tuning for OLAP, HTAP and ERP-specific workloads.

Typically, the main difficulty in query tuning is not a specific query and its particular issue. The real problem is how to **generalise** the issue and come up with a common solution. That's why we need a method to detect and group problematic queries.

# Slide 2. Chapter 1: Origins of the idea

How did I come to this idea? It wasn't trivial.

# Slide 3. 31 December 2023

On New Year's Eve 2024, I got a message from an unknown user of the AQO extension. He complained about a segfault. ... AQO ...
We resolved it quickly enough, but in the end I was curious why they had picked up this open-source extension at all. And we had an interesting conversation.

# Slide 4. 12 January 2024

They said they used the PostgREST API and had performance issues with its auto-generated queries. My extension sped them up by a factor of two or more, and they rolled it out across their many servers.
At first, it was simply nice to know that someone was using a product I had spent so many nights designing. But on second thought, I realised there might be a turning point here: databases aren't that efficient under real workloads. That means that in the cloud, people spend a lot of resources — and consequently money — for nothing.
Let me show you the exact formula I arrived at.

# Slide 5. The query plan is a great source of savings

We need nothing but our minds and curiosity to save a massive amount of money. It may not be much per server, but multiply it by 5,000 servers, as the person from that chat said, and you get a great source of savings.
Yes, the main blocker for optimisation is complexity. So this is the gist of my current efforts and code: make query optimisation more **transparent and simple**.

Add a bit of AI sauce to this idea and we arrive at the solution: automate problem detection, then generalisation, then resolution by some handy machinery.

# Slide 6. Chapter 2: Blind spot

OK, now let's turn to the scope of the problem. Why do I think it is hard at all? Maybe we already have enough tools to solve it? Maybe we can find the issues manually?

# Slide 7. Is it easy to spot an optimisation problem?

Here I tried to show the amount of work you'd face if you decided to investigate query optimisation on a real system. These are the numbers of a typical ERP system: about 50 thousand distinct query IDs; an unmanageable number of long queries; calls and execution times vary wildly; long query texts, bushy join trees, and plans that are sometimes executed only partially because of executor runtime optimisations.
The query text is also rarely readable. You can work out what it does, of course, but you need a specific candidate in advance. So we need tooling. What do we have at the moment, then?

# Slide 8. Closing the blind spot in query statistics

The main tool and de facto standard is pg_stat_statements. It has lots of parameters and is pretty stable. Unfortunately, it monitors something quite different from what we need: it shows the queries that consume the most resources.
That's sound logic, but a big query may legitimately be expensive. Also, with thousands of queries, a single query (or even the top 100) doesn't add much to the overall picture.
Of course, we have other extensions: pg_qualstats, online_advisor, pganalyze and others. But each is designed to solve a specific issue, usually to find out what is wrong with one query by running EXPLAIN ANALYZE in a separate session. Our purpose is to detect and track problems on the fly, on a live system — to provide your AI monitor with sensors.

# Slide 9. Assessing the instance's potential

What exactly are these "sensors"? ...

*(The slide lists five levers: estimation error, selectivity of scans and joins, SubPlans' share of execution time, spilling, plan stability. Only the first sentence is in the notes so far.)*

So, we implemented all these sensors in a separate extension and called it pg_track_optimizer.

# Slide 10. Postgres extension pg_track_optimizer

It contains 11 metrics at the moment, and we think it may be extended in the future as we gain more practical experience.
It is a lightweight loadable extension: you can use your connection pooler's settings to add it to or remove it from the system dynamically.
It flushes the gathered data to disk so that it survives a restart.
One of the practical issues is the uniqueness of the query ID: sometimes it is not unique enough, sometimes too unique. Both cases hurt the analysis. So there is a module that attempts to stabilise the query ID and make it depend on the semantics rather than the syntax of the query.

Also, the extension can add instrumentation to each query before it starts, according to the requested level. The analysis is done at the end of execution, as usual.

# Slide 11. Chapter 3: Domain specifics

This extension has some rather unusual features that are visible in its interface and may puzzle a new user. So let's talk about the specifics of the domain and why the extension looks a little unconventional.

# Slide 12. Nuance 1: Queries are different

The first issue you run into when analysing such a horde of queries is that they differ in structure, in the data they touch and in execution time.
Sometimes it is a bushy join tree that precisely extracts a tiny set of rows from each table but runs slowly because of Cartesian joins that blow up the number of rows. Sometimes it is a tiny grouping query that is disk-intensive and calculates a couple of aggregates over the whole table.
And we need to compare such queries on the basis of their "optimisation potential".

# Slide 13. Nuance 2: Parameter might be in undefined state

Another nuance is that the data we need to assess the quality of the optimiser's planning is not always meaningful.
For example, a plan subtree may be pruned or never executed at all. Here is an example where, depending on the parameter, most of the nodes either don't read a single tuple or process quite a bushy tree.
The optimiser has no concept of a never-executed node or of zero tuples produced. So we can't just use zero tuples as the "actual rows" value: the "never executed" node formally doesn't depend on any parameter, but it may run for hours next time, when the parameter is different.
Such a speedup is a **runtime optimisation**; it is out of scope, and we should skip it when analysing the query result. That means we may sometimes have no value at all for some monitoring parameters. That's different from pg_stat_statements.

# Slide 14. Nuance 3: statistics' stochastic nature

And the third nuance is the stochastic nature of statistics. You may not change the data at all, but after running ANALYZE again you may see the query plan flip, and everything changes.
It may happen because the ndistinct statistic is not stable even in theory. But most probably it happens because of changes in the MCV list: a value may be pushed out of the list, and estimates shift in multiple places, especially in scan filters, as you can see here.

That's why specific estimation numbers are frequently not 100% reproducible, and we should rely on statistical values like the mean or the standard deviation.

# Slide 15. Two design decisions in pg_track_optimizer

So, after a series of attempts, we came to these two design decisions. First, make our metrics dimensionless.
Instead of using the execution time of a specific node, we divide it by the total execution time of the query; filtered rows we normalise by the number of actual rows returned. In short, we think in fractions instead of absolute numbers.
It may be the first attempt to do so in databases, but in physics this approach has served well for decades — let's try to adopt it.

*(The second decision — the custom `RStats` type: (count, mean, min, max, stddev), updated in place on every execution, so you see the plan is unstable, not just wrong — isn't covered in the notes.)*

# Slide 16. Chapter 4: How it works

Now let me turn to practice, explain the most important parameters and show how it actually works.

# Slide 17. How does it work in practice? (JOB)

To show how it works, I used the Join Order Benchmark. It is simple to use, contains over a hundred different queries, uses full scans as well as index scans, and with join trees of up to 16 joins it leaves plenty of room for wrong planner estimates.

# Slide 18. Cardinality estimation error

The first key parameter is the most natural one: the cardinality estimation error. It is based on comparing the planned and the actual number of rows at each plan node.
At the end of execution, the extension walks the PlanState tree and gathers the actual row counts. Then it calculates the relative error at each node, normalises it and sums these values up using a weighting factor.
The weighting factor is quite an important parameter. Plan nodes aren't all equal: a 2x estimation error in a scan may be less harmful than a 2x error in the output of a join. So, to combine them, we can weight by the execution time of the node, its cost, blocks read, and so on. Each weighting factor represents a different point of view on the query error, and I usually combine them in my analysis.

# Slide 19. How the estimation error criteria work

This slide shows an example of how I use this kind of metric. Here I intersected the top 10 by two kinds of estimation error coefficient: time-weighted and with no weighting at all. Out of all 113 queries, four end up in the intersection. The numbers themselves are dimensionless and don't mean much on their own; you just pick the highest ones or combine them with other metrics. Here I picked the query with the highest estimation error and looked into its heatmap.

# Slide 20. A look inside 28a.sql

On this heatmap, red means bad estimates. As you can see, the error arose once and then spread up the tree. If you look at the specific segment where the problem was found, you can see that the cause is a 4x misestimate on a plain table scan. And that error quickly turned into an almost 100x underestimate on the Hash Join right above it. I wouldn't be surprised if such a rapid growth of underestimation turned the joins further up into Nested Loops.

# Slide 21. Filter factors: scans and joins

That was a general-purpose metric that lets us identify planner slips. This one is much more practical. We want to know how actively our queries filter rows, because if a significant part of the work is filtering, it may make sense to restructure the physical layer of the database and pick the rows more precisely with an index.

Postgres gives us two ways to detect filtering: the number of tuples removed by a scan filter and by a join filter.

We take this parameter and keep the maximum across the plan. We could average it over the number of nodes, as we did with the planning error, but the idea here is just to highlight the painful spot. Indexes don't let us get rid of all filtering, so there is no reason to dilute the signal.

As you can see, we make it dimensionless: the fraction of filtered tuples relative to the rows returned, weighted by the fraction of the total execution time this node consumed.

# Slide 22. How the filter criteria work (step 1)

Here is an example. We usually take the filter metric together with the planner error to see whether the plan was badly planned in general. Take the top JOB query by scan factor. Its heatmap shows no significant planning errors, so there's no negative signal in general.
But let's dive into the filters to understand what caused such a big value of the metric.

# Slide 23. How the filter criteria work (step 2: the zoomed-in scan)

And now you can see that the Seq Scan removed almost 3 million rows to feed the join. Nothing is wrong with the estimates. With a proper index, we would scan it much faster.

Such cases are quite important: they show us directly where we can add an index, if we are OK with the DML overhead. The same technique lets us detect candidates among JOIN nodes as well. By adding indexes on filters and join clauses, we switch a SCAN node to an optimal Index Scan, and a JOIN node to a parameterised Nested Loop.

To understand how much this approach could add to the benchmark, I did something quite mechanical: I added indexes to satisfy the SCAN filters. After the benchmark had run, I added indexes to satisfy the most intensively filtering join clauses and ran the benchmark once more.

# Slide 24. Effect of the indexes found

And here you can see the speedup of the benchmark, sorted from the maximum speedup on the left to the minimum on the right.

You can see that join indexes are much more effective than scan indexes alone. Sometimes we cut the execution time a hundredfold. But at the other end of the graph you can see degraded queries. That's a consequence of aggressive plans: with Nested Loops, misestimates cost more than before.

# Slide 25. Join filtering EXPLAIN can't see (step 1)

*(Not covered in the notes. The slide: `big` (10^7 rows) ⋈ `small` (100 rows), result 1000 rows, no indexes. The Hash Join says nothing about the 9 999 000 rows of `big` it threw away; the forced Nested Loop reports "Rows Removed by Join Filter: 999 999 000" — compared pairs, not rows without a partner. 332 ms vs 20.8 s.)*

# Slide 26. Join filtering EXPLAIN can't see (step 2)

*(Not covered in the notes. The slide: same query after `CREATE INDEX idx ON big (x)`. Nested Loop with Index Scan: "rows=10.00 loops=100" — an average that hides that 90 probes returned nothing and 10 returned 100 rows each. 0.187 ms.)*

# Slide 27. Spilling of intermediate results

There is a general problem with work_mem. I have heard of some tricks and magic ratios, but generally, when you know that join trees in your database range from 1 to 50 joins, it is hard to predict how many nodes may need extra memory, and therefore what a safe limit should be.

That's why spilling to disk is inevitable: you just keep your instance safe.
Lots of nodes spill to disk: hashing, sorting, materialisation, even CTEs. Some nodes allocate memory but don't spill: Memoize, hashed INTERSECT, Bitmap Scan — they use other tricks to keep memory consumption bounded.
So we added a metric that lets you see whether a query spills a massive part of the data it processes to disk.

# Slide 28. How the spilling criterion works

Here is an example. The extension tracks the number of blocks each query spills to disk. Here we select the average number of blocks spilled per query, sorted by the ratio of spilled blocks to total blocks read.
This is less than pg_stat_statements provides, but by combining the two you can extract whatever detail you need: pg_stat_statements only shows you the total accumulated value, without the distribution.
By adjusting work_mem we can speed queries up — twofold in this example.

# Slide 29. What a bigger work_mem changes

But such an adjustment may have negative consequences: plans get more aggressive and more sensitive to optimiser mistakes. So this is not a blanket recommendation to make work_mem as big as possible.

# Slide 30. Chapter 5: Outcomes (the shortest one)

*(Not covered in the notes. Section divider.)*

# Slide 31. The useful bits

*(Not covered in the notes. The slide: 1) track the accumulated average error — on a tuned system, growth or a spike means losing efficiency; 2) watch the SCAN and JOIN filter factors — the metrics that expose missing indexes; 3) combine these metrics with pg_stat_statements — it may highlight queries that deserve a GENERIC/CUSTOM plan changeover. See also takeways.md for the intended takeaways.)*

# Slide 32. Questions?

*(Not covered in the notes. Contact card + QR code to the pg_track_optimizer repo.)*
