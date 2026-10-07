# Slide 1. Title

Name myself, My primary interest - planner tuning for OLAP, HTAP and ERP-specific loads.

Typically, the main problem in query tuning is not a specific query and its problem - how to **generalize** the problem to invent a common solution - that's the exact problem. That's why we need a method to detect and group problematic queries.

# Slide 2.

How I have come to this idea? It wasn't trivial.

# Slide 3. 

On the eve of new year 2024, I've got a message from unknown user of the AQO extension. He complained about segfault. ... AQO ...
We resolved it quickly enoough, but at the end I was curious about why they took this open-source extension at all. And we had an interesting talk.

# Slide 4.

They said that they use PostgresT REST API and have issues with performance of auto-generated queries. My extension sped it up two or more times and they installed it across their multiple servers.
At first, it was actually nice to know that someone uses product to design which I spend a lot of nights. But after the second thought I realised that here is might be a turning point: DBs aren't quite effective on real load. That means being in the Cloud people spend a lot of resources and consequently money for nothing.
Let me show you the exact formula I came to.

# Slide 5.

we actually need only our mind and curiosity to save massive amount of money. May be it is not much for a server, but multiply it to 5000 servers like a person from previous dialogue said, and you'll have a great source of economy.
Yes - the main stopper for optimisation is complexity. So, this is the gist of current efforts and code - make query optimisation more **transparent and simple**.

Add into this idea an AI sauce and we come to the solution - automatise problem detection - the generalisation - then resolving by a handy machinery.

# Slide 6. "Blind spot"

Ok, now, let's turn to the scope of the problem. Why do I think it is hard at all? Maybe we already have enough tools to solve it? Maybe we can find issues manually?

# Slide 7. "One database statistics"

Here I tried to show the scope of the research you'll need to do if you decide to research on the query optimisation. This is a typical ERP system numbers - about 50 thousands different queryIds, quite unobservable scope of long queries; calls & execution times vary significantly, long query texts and bushy join trees and plans that sometimes only partially executed due to executor runtime optimisations.
Query text is also rarely readable - you can understand how it works, of course, but you should have specific candidate in advance. So, we need tooling - what is the current scope then?

# Slide 8. "Closing the blind spot in query statistics"

The main tool and de-facto standard is PGSS. Contains lots of parameters and pretty stable. Unfortunately, it monitors totally different stuff when we need to - it shows queries that spend more resources.
It is nice logic, but big queries might be legitimally bad. Also, on the scope of thousands queries one query (or even TOP-100) adds not much into the overall score.
Of course, we have other extensions, like qualstats, online advisor, pganalyze and others. But it always designed to solve some specific issue, usually find out what is wrong with the query executing EXPLAIN ANALYZE in a separate session. Our purpose - to detect and track problems on the fly, on life system - provide your AI monitor with sensors.

# Slide 9. "Assessing the instance’s potential"

What exactly are these "sensors" ...

So, we implemented all these sensors in a separate extension and called it track optimiser.

# Slide 10. "Postgres extension pg_track_optimizer"

It contains 11 metrics at the moment - and we think it might be extended in the future when more practice gained.
It is lightweight loadable extension - you can operate connection pooler's settings to introduce/remove it in the system dynamically.
It flushes gathered data to the disk to survive crash.
One of the practical issues - uniqueness of QueryID - sometimes not enough, sometimes too much unique. Both cases strike analysis. Here is a module that attempts to stabilise queryid and make it more semantic-depended than syntax-dependent.

Also, extension might add to each query instrumentation before the query starts, according to the level requested. Analysis has been made at the end of execution, as usual.

# Slide 11. "Domain Specifics"

This extension implements quite unusual features that visible in the UI and might strike new user. So, let's talk about specifics of the Domain and why extension looks a little unconventional.

# Slide 12. "Nuance No.1"

The first issue that you get stuck into analysing such a horde of queries is that they are different by structure, data touched and execution time.
Sometimes it is a bushy join tree that is quite pointedly extracts tiny set of rows from each table but executed slowly because of cartesian joins that blows up the number of rows. Sometimes it is tiny grouping that is disk intensive and calculates couple of aggregates over the whole table.
And we need to compare such queries on a basis of an "optimisation potential".

# Slide 13. "Nuance No.2"

Another nuance is that data we need to assess the quality of the optimiser's planning is not always meaningful.
For example, plan tree might be pruned or never executed at all. Here is an example when depending on the parameter most of nodes might not read even a single tuple or process quite a bushy tree.
Optimiser doesn't have a concept of never executed node or zero tuples produced. So, we can't just use zero tuples as 'real rows' value - the 'never executed' node doesn't formally depend on any parameter but might be executed for hours next time when parameter will be different.
Such speedup is a **runtime optimisation** that is out of the scope and we should skip it analyzing query result. So, that means that sometimes we might have no result for some monitoring parameters. That different compare to the PGSS.

# Slide 14. "Nuance No.3"

And the third nuance is stochastic nature of statistics. Sometimes you may not change data at all. But executing ANALYZE again you might see the query plan flip when everything changes.
It might happen because ndistinct statistic is not stable in theory. But most probably it happens due to changes in MCV list: some value might be pushed out of the list and estimations in multiple places shifts, especially related to scan filters as you can see here.

That's why concrete estimation numbers frequently aren't 100% reproducible. And we should rely on something stochastic like average value or standard deviation.

# Slide 15. "Two design decisions"

So, after a series of attempts we came to these two design decisions. First of all, make our metrics dimensionless.
This way instead of using execution time for specific node, we divide it by total execution time of the query, filtered rows we normalize on the number of actual rows returned. That's all looks like to use terms of fractions instead of absolute numbers.
It might be the first attempt to do so in databases, but in physics such an approach serves well for decades - let's try to adopt it.

# Slide 16. "How it works"

Now, let me turn to practice, explain the most important parameters and show how it actually works.

# Slide 17, "JOB"

To show how it works I used the Join Order Benchmark - it is simple to use, contains  a hundred of different queries, uses full scans as well as index scans and on 16-join query tree leaves a room for wrong planner estimates.

# Slide 18. "Cardinality estimation error"

The first key parameter is the most natural one - cardinality estimation error. It is based on the comparison of planned and actual rows number at each plan node.
On the execution end it walks through the plan state tree and gathers number of actual rows. Afterwards, it calculates relative error, normalising it with an algorithm and summarises these values based on some weighting factor.
Weighting factor is quite an important parameter. Plan nodes aren't the same: 2x error in estimation if scan operator maybe less harmful that 2x estimation error of join output. So, to combine it we can use weighting bassed on execution time of specific node, cost of the node, blocks read, etc. Each weighting factor represents different point of view on the query error and I usually combine them in my analysis.

# Slide 19. "How to use it"

This slide represents an example how I use this sort metrics. Here you can see I intersected TOP-10 on two types of estimation error coefficient: time weighed and without weighting factor at all. Over all 113 queries we have four entries at intersection. Numbers itself, are dimensionless and provide you with not much meaning - you can just pick the highest ones or combine them with other metrics. Here I pick the query with highest estimation error and looked into the heatmap.

# Slide 20. "A look inside .."

Red color means bad estimations on this heatmap. As you can visually see, an error has been raised once and spread upper by the tree. Look into the specific segment where the problem has been found you can see that the reasin is x4 misestimation on a plain table scan. And error quickly transformed to 10x underestimation error on the immediate upper HashJoin. I wonder if such a quick grow of underestimation error will turn the following JOINs to NestLoops.

# Slide 21. "Filtering activities"

It was like a general purpose metrics that let us identify planner mishaps (slips). This one much more practical. We want to know how actively our queries filter rows. Because if significant part of the work is filtering - maybe it makes sense to restructure physical layer of the database and pick it more precisely by an index.

There are two ways to detect filtering that postgres provides to us: the number of tuples removed by scan and join filter.

We take this parameter and save maximum number throughout the plan. We might average it on the number of nodes as we did with planning error, but the idea here is just to highlight the painful place. Indexes don't allow us to get rid of all filterings, so, no reason to reduce the signal.

As you can see, we make it dimensionless and show a fraction of filtered tuples in the whole set of rows taken and weight it on a fraction of total execution time that this node consumed.

# Slide 22. "How filtering works"

Here is an example - we usually take filtering metrics with planner error to see if this plan planned badly in general. Take upper query of the JOB benchmark according to scan factor. Heatmap of this query shows no significant planning errors. So - no negative signal in general.
But, let's dive into the filters to understand what's caused such a big value of the metric.

# Slide 23. "Reveal the issue"

And now you can see that SeqScan removed almost 3mln rows to perform the JOIN. Nothing is wrong with estimations. With proper index we would scan it much faster.

Such cases quite important - they directly show us where we can add an index if OK with DML overhead. The same technique enables us to detect candidate scan and for JOIN nodes. Adding an index on filters and join clauses we switch SCAN node to optimal index scan, and JOIN node  to parameterised NestLoop.

To understand how much this approach might add to this benchmark I made quite a formal thing: added indexes to satisfy SCAN filters. After the  benchmark passed, I added indexes to satisfy intensively filtering join  clauses. And performed benchmark one more time.

# Slide 24. "Effect of indexes"

And here you can see speedup of this benchmark - sorted from maximum speedup on the left side to the minimum speedup on the right one.

You can see that join indexes much more effective than just scan indexes. Sometimes we reduced execution time 100 times. But at the other end of this graph you can see degraded queries - it is consequence of aggressive query plans: with NestLoops misestimations cost more than before.