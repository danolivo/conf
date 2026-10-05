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

Another nuance is that 

# Slide 14. "Nuance No.3"

