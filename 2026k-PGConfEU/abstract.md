# Title:
Finding the invisible: spotting query planner issues before they appear

# Event:
PGConf.EU 2026, Valencia — Thursday, 22 October 2026, 15:55–16:25, Audit 3 (Postgres Internals, Intermediate)
https://www.postgresql.eu/events/pgconfeu2026/schedule/session/7926-finding-the-invisible-spotting-query-planner-issues-before-they-appear/

# Abstract:
PostgreSQL's query optimiser is highly advanced, but it can still make mistakes. Traditional monitoring tools, such as pg_stat_statements, track execution performance metrics, including CPU time, I/O, and duration. They don't show how far off the planner's predictions were.

A query that finishes in 100ms might seem fine, but if the planner expected 10000 rows and got 100, it may mean the query could have executed in 10ms if tuned. On a scale of millions of executions, it may yield a significant performance gain.

In this talk, I'll introduce pg_track_optimizer, an extension I built to spot planner errors in databases that handle many different queries. There, I calculate metrics that compare the planner's expectations to what really occurred.
