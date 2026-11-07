# Trust, but Diff: Proving Two PostgreSQL Tables Are Identical

The major upgrade is done, logical replication is up to date, and monitoring looks good. But are the tables on both sides really identical? This question often comes up after a migration, before moving traffic to a logical replica, and more often now in multi-region setups where data is spread across several nodes. Still, the Postgres community has surprisingly few tools to help answer it.

The most straightforward way is to compare rows one by one. Any smarter method needs to do better than that. In this talk, I’ll share ways to compare tables quickly while using limited CPU, memory, and network resources. I’ll also show benchmarks against existing tools and the basic row-by-row approach.

I’ll also cover hidden issues that can make comparisons unreliable, like false positives, where identical data looks different, and false negatives, where real differences go unnoticed. Finally, I’ll talk about comparing a primary and a replica on the fly, when there’s no maintenance window available.

45 min, DBA