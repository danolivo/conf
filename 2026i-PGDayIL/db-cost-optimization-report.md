# Оптимизация запросов к БД как способ экономии на облачном биллинге

Аналитический отчёт по итогам поиска статей, кейсов и технической документации.

---

## 1. Насколько распространена проблема неэффективности СУБД

Судя по собранному материалу, это не нишевая проблема отдельных компаний, а системная и повсеместно признанная тема:

- **Количественные оценки потерь.** По данным, приводимым в статье Xomnia, до 30% расходов на облачные хранилища данных уходит впустую из-за неоптимальных запросов. Ресурс Revefi называет диапазон 40–60% "предотвратимых" потерь в типичном окружении BigQuery/Snowflake. Это не единичные цифры — схожий порядок (20–40%) фигурирует и в других источниках подборки.
- **Реальные постмортемы с существенным эффектом.** Mixpanel — сокращение счёта за BigQuery на 80% после нахождения "дорогих" запросов; ChartMogul — минус 70% на Snowflake; Brocoders — минус 59% на RDS после апгрейда Postgres; Oreon IT — минус 38% облачного счёта у SaaS-платформы; Nordstrom (через followrabbit) — минус 47% на BigQuery. Разброс большой, но во всех случаях речь идёт не о процентах, а о десятках процентов экономии — то есть база для оптимизации была действительно велика.
- **Появление целой индустрии вокруг этой проблемы.** CloudZero, Revefi, Unravel Data, DoiT, followrabbit (Rabbit), Enteros, dbSeer и другие — это отдельный рынок FinOps-инструментов и консалтинга, выросший именно вокруг неэффективности БД и её влияния на облачный счёт. Наличие такого количества нишевых продуктов и агентств — косвенный, но сильный индикатор масштаба проблемы: рынок не появляется вокруг узкой боли, если она не массова.
- **Проблема не привязана к одной СУБД или платформе.** Она одинаково всплывает и в классическом OLTP (PostgreSQL/RDS, MS SQL), и в облачных DWH с принципиально другой моделью тарификации (BigQuery, Snowflake). Это говорит о структурном характере проблемы: она возникает из-за роста данных и накопления "исторических" решений в схеме и запросах, а не из специфики конкретного движка.

**Вывод:** неэффективность запросов — хронический, а не эпизодический источник издержек, который проявляется на любом масштабе (от e-commerce до финтеха и SaaS) и на любой архитектуре.

---

## 2. Только ли цена облачной БД — движитель исследований?

Нет. Цена — самый заметный и легко измеримый мотив, но в материалах отчётливо видно ещё несколько независимых драйверов:

1. **Производительность и пользовательский опыт.** В кейсе Oreon IT снижение облачного счёта на 38% шло рука об руку с падением P95-задержки с 2.1с до 480мс — то есть исходная мотивация была скорее в отклике приложения, а экономия — следствие. Похожая связка "быстрее → дешевле" видна в кейсе Mindbody (AWS): апгрейд ради задержки дал заодно и экономию.
2. **Масштабируемость и предсказуемость нагрузки.** Часть материалов (Sedai, AWS RDS-кейсы) описывает оптимизацию как способ выдержать рост нагрузки без постоянного вертикального апгрейда инстансов — то есть это вопрос архитектурной устойчивости, а не только счёта.
3. **Инженерное время и операционная нагрузка.** followrabbit приводит цифру — команда Nordstrom высвободила около 400 часов инженерного времени в месяц, перейдя от ручной оптимизации к постоянному процессу. Здесь движитель — не столько цена, сколько то, что ручной SQL-тюнинг отвлекает инженеров от продуктовой разработки.
4. **Устойчивость и надёжность.** Партиционирование, тюнинг autovacuum, connection pooling (PgBouncer/RDS Proxy) в кейсе Oreon IT снимали проблему блокировок и деградации на пике нагрузки — то есть речь о предотвращении инцидентов, а не только об оптимизации бюджета.
5. **Академический и инженерный интерес к самому оптимизатору.** Расширение AQO для PostgreSQL, статья на arXiv про адаптивные cost-модели, свежий тред на pgsql-hackers про новый GUC-параметр — это исследования качества планирования запросов как таковые, независимо от денежной стороны. Здесь мотивация — точность оценки кардинальности и качество плана, деньги вообще не упоминаются.
6. **Экологический аргумент.** Xomnia отдельно упоминает сокращение потребления вычислительных ресурсов как вклад в устойчивость (sustainability) — это скорее ESG-нарратив, чем чисто финансовый.
7. **Управленческое давление (FinOps/бюджет).** В части кейсов (edurev.in — учебные кейсы для AWS-сертификации) прямо фигурирует мандат CFO на сокращение расходов на конкретный процент — то есть в некоторых случаях это действительно чисто финансовое требование "сверху", а оптимизация запросов — инструмент его выполнения.

**Вывод:** цена — главный публичный повод писать такие статьи (хорошо считается, легко показать "было/стало" в долларах), но реальные мотивы почти всегда смешанные: задержка, стабильность под нагрузкой, инженерное время и — отдельным пластом — чисто исследовательский интерес к качеству оптимизатора как таковому.

---

## 3. Основные приёмы, которые встречаются в материалах

### Уровень запроса
- Не использовать `SELECT *`, выбирать только нужные колонки (особенно критично для колоночных СУБД типа BigQuery — прямое влияние на объём сканируемых данных и, соответственно, счёт).
- Фильтровать (`WHERE`) как можно раньше и как можно ближе к источнику данных, до `JOIN`.
- Заменять `OR` по разным ветвям на `UNION ALL` из двух индексированных подзапросов.
- Не применять функции к колонкам, участвующим в партиционировании — это ломает partition pruning.
- Минимизировать вложенные подзапросы, использовать `EXISTS`/`IN` осознанно, избегать избыточных JOIN.

### Индексы и структура данных
- Точечные (partial), покрывающие (covering) и BRIN-индексы вместо повального B-tree на всё.
- Регулярный аудит и удаление неиспользуемых индексов (расходы на запись и хранение).
- Партиционирование больших таблиц (range/list) — в кейсе Oreon IT таблица на 1.2 млрд строк была партиционирована по месяцам.
- Денормализация "горячих" связей и материализованные представления для тяжёлых агрегаций.
- Вынос "холодных" исторических данных из основной СУБД во внешнее хранилище (кейс Arcesium: PostgreSQL → S3/Iceberg).

### Инфраструктура и конфигурация
- Пулинг соединений (PgBouncer, RDS Proxy) — снижает накладные расходы на переключение контекста.
- Тюнинг autovacuum на самых "горячих" таблицах.
- Rightsizing инстансов/warehouse (не держать r5.8xlarge под нагрузку, которая помещается в r6i.4xlarge).
- Auto-suspend/auto-scale для Snowflake-warehouse — вплоть до минимального интервала биллинга (60 секунд).
- Кэширование (Redis, BI Engine, connected sheets) для часто повторяющихся запросов.

### Планировщик и оптимизатор (в первую очередь PostgreSQL)
- Тюнинг planner cost constants (`seq_page_cost`, `random_page_cost`, `cpu_*_cost`) вместо грубого переключения `enable_*`-флагов.
- Регулярный `ANALYZE`, увеличение `default_statistics_target` для проблемных колонок.
- Адаптивная оптимизация запросов (AQO) — использование реальной статистики выполнения для коррекции оценок кардинальности без ручной подстройки GUC.
- Чтение и анализ `EXPLAIN (ANALYZE, BUFFERS)` как базовый диагностический процесс.

### Процесс и наблюдаемость (общее для всех платформ)
- Построение дашборда мониторинга трат по проектам/пользователям/запросам (это буквально основа методологии в кейсе Mixpanel).
- Регулярный разбор top costly queries через `pg_stat_statements`, `INFORMATION_SCHEMA.JOBS_BY_PROJECT` (BigQuery) или Query History (Snowflake).
- Алерты и resource monitors на аномальные всплески трат.
- Разделение warehouse/инстансов по типу нагрузки (аналитика, ETL, бэкфилы) с раздельными лимитами.

### Специфика облачных DWH (BigQuery/Snowflake) — отдельный класс приёмов
Здесь модель тарификации принципиально другая (оплата за просканированные байты или slot/credit-часы), поэтому приёмы смещены в сторону физического объёма сканирования, а не индексов:
- Партиционирование и кластеризация таблиц под конкретные предикаты фильтрации.
- Осознанный выбор on-demand vs capacity-based (slots/credits) тарификации под профиль нагрузки.
- Материализация промежуточных стадий трансформации (dbt-модели), чтобы не пересчитывать одно и то же.
- Важный нюанс из подборки: `LIMIT` в BigQuery не уменьшает объём сканируемых данных — экономят только `WHERE` по партиционированным/кластеризованным колонкам.

---

## 4. Все найденные ссылки

### Общие обзоры и практики
- [Cloud Cost Optimization: How to reduce your cloud bills?](https://medium.com/@chintan.j72/cloud-cost-optimization-how-to-reduce-your-cloud-bills-9869dd942732) — Medium
- [Slash Your Cloud Data Costs: 11 Proven SQL Optimization Techniques](https://xomnia.com/post/slash-your-cloud-data-costs-11-proven-sql-optimization-techniques/) — Xomnia
- [Best Practices for Optimizing Google Cloud SQL Costs in 2026](https://sedai.io/blog/optimizing-google-cloud-sql-in-2025) — Sedai
- [Database Optimization Strategies That Reduce Cloud Costs at Scale](https://iamops.io/database-optimization-strategies-that-reduce-cloud-costs-at-scale/) — iamops.io
- [SQL Query Optimization: 12 Techniques to Improve Performance](https://www.thoughtspot.com/data-trends/data-modeling/optimizing-sql-queries) — ThoughtSpot
- [Optimizing Cloud Database Costs with Intelligent SQL Performance Management](https://www.enteros.com/blog/database-performance-management/optimizing-cloud-database-costs-with-intelligent-sql-performance-management/) — Enteros
- [12 SQL Query Optimization Best Practices For Cloud Databases](https://www.scribd.com/document/821055104/12-sql-query-optimization-best-practices-for-cloud-databases) — Scribd

### PostgreSQL / AWS RDS: кейсы и гайды
- [Optimizing Performance — Tips and Tricks for RDS and Aurora: PostgreSQL on AWS [Part 4]](https://medium.com/@arunseetharaman/optimizing-performance-tips-and-tricks-for-rds-and-aurora-postgresql-on-aws-part-4-45256d3e627b) — Medium
- [We Upgraded Postgres and Cut Our Amazon RDS Bill by 59%](https://brocoders.com/blog/postgres-upgrade-reduce-aws-rds-costs/) — Brocoders
- [PostgreSQL Performance Optimisation Case Study](https://www.oreonit.com/case-studies/performance-tuning-saas-postgres-cost-optimization/) — Oreon IT
- [PostgreSQL on AWS RDS: A Proper Optimization Guide](https://goldlapel.com/grounds/replication-scaling-cloud/aws-rds-postgresql-optimization) — Gold Lapel
- [Case Studies: RDS Cost Optimization](https://edurev.in/t/519369/case-studies-rds-cost-optimization) — EduRev (учебные кейсы AWS SA)
- [AWS RDS Blog Insights: Performance Tuning](https://awsforengineers.com/blog/aws-rds-blog-insights-performance-tuning/) — AWS for Engineers
- [Optimizing PostgreSQL query performance](https://docs.aws.amazon.com/prescriptive-guidance/latest/postgresql-query-tuning/introduction.html) — AWS Prescriptive Guidance
- [How Mindbody improved query latency and optimized costs using Amazon Aurora PostgreSQL Optimized Reads](https://aws.amazon.com/blogs/database/how-mindbody-improved-query-latency-and-optimized-costs-using-amazon-aurora-postgresql-optimized-reads) — AWS Database Blog
- [Optimize and troubleshoot database performance in Amazon Aurora PostgreSQL by analyzing execution plans using CloudWatch Database Insights](https://aws.amazon.com/blogs/database/optimize-and-troubleshoot-database-performance-in-amazon-aurora-postgresql-by-analyzing-execution-plans-using-cloudwatch-database-insights/) — AWS Database Blog
- [How Cloudability boosted performance, simplified tuning, and lowered costs with Amazon Aurora](https://aws.amazon.com/blogs/database/how-cloudability-boosted-performance-simplified-tuning-and-lowered-costs-with-amazon-aurora) — AWS Database Blog
- [AWS Database Blog: Cloud Cost Optimization tag (Open Raven, RDS Consolidator и др.)](https://aws.amazon.com/blogs/database/category/business-intelligence/cloud-cost-optimization) — AWS Database Blog
- [How We Cut Our Database Costs by Moving Cold Data from PostgreSQL to Amazon S3](https://medium.com/arcesium-engineering-blog/how-we-cut-our-database-costs-by-moving-cold-data-from-postgresql-to-amazon-s3-c30ec77d4f3a) — Arcesium Engineering

### PostgreSQL: планировщик, cost-based optimizer, GUC
- [19.7. Query Planning](https://www.postgresql.org/docs/current/runtime-config-query.html) — официальная документация PostgreSQL
- [Understand Explain Plans in PostgreSQL](https://stormatics.tech/alis-planet-postgresql/understand-explain-plans-in-postgresql) — Stormatics
- [Optimizing SQL — Step 1: EXPLAIN Costs and Plans in PostgreSQL, Part 2](https://www.highgo.ca/2020/04/30/optimizing-sql-step-1-explain-costs-and-plans-in-postgresql-part-2/) — HighGo
- [aqo: Adaptive query optimization for PostgreSQL](https://github.com/postgrespro/aqo) — GitHub, postgrespro
- [\[PATCH\] Add a GUC parameter to control LIMIT clause path cost adjustment](https://www.postgresql.org/message-id/b64fb4cc-1fbe-4796-a79b-001b362138dc.mohen.lhy%40alibaba-inc.com) — pgsql-hackers
- [PostgreSQL 17 Performance Tuning: Understanding Optimizer Cost Parameters](https://medium.com/@jramcloud1/32-postgresql-17-performance-tuning-understanding-optimizer-cost-parameters-670e0de45b4a) — Medium
- [Adaptive Cost Model for Query Optimization](https://arxiv.org/html/2409.17136v1) — arXiv
- [Tuning query-related parameters (PostgreSQL High Performance Cookbook)](https://www.oreilly.com/library/view/postgresql-high-performance/9781785284335/ch02s08.html) — O'Reilly
- [Using the Cost Based Optimizer in YugabyteDB: How the New Query Planner Works](https://www.yugabyte.com/blog/yugabytedb-cost-based-optimizer/) — Yugabyte (для сравнения подхода в другой СУБД)

### Русскоязычные источники (Хабр и др.)
- [Оптимизация SQL запросов](https://habr.com/ru/articles/861604/) — Хабр
- [Rule-based оптимизация SQL-запросов](https://habr.com/ru/companies/cedrusdata/articles/578842/) — Хабр
- [Оптимизация SQL запросов или розыск опасных преступников (кейс Appbooster)](https://habr.com/ru/articles/509406/) — Хабр
- [Книга «SQL Server. Наладка и оптимизация для профессионалов»](https://habr.com/ru/companies/piter/articles/735424/) — Хабр
- [Анализ вариантов оптимизации ресурсоёмкого SQL-запроса: Вариант-2 «TUNING»](https://habr.com/ru/articles/971690/) — Хабр
- [Оптимизация SQL-запросов: снижение нагрузки на БД](https://tproger.ru/articles/sovety-po-optimizacii-sql-zaprosov-dlya-snizheniya-nagruzki-na-bd) — Tproger
- [Оптимизация запросов базы данных на примере B2B сервиса для строителей](https://habr.com/ru/articles/461071/) — Хабр
- [Оптимизация данных в MS SQL](https://habr.com/ru/articles/705656/) — Хабр
- [Оптимизация запроса и запрос оптимизации](https://habr.com/ru/articles/776398/) — Хабр
- [Инструмент для автоматической оптимизации SQL-запросов](https://habr.com/en/articles/938806) — Хабр

### BigQuery
- [How we cut BigQuery costs 80% by hunting costly queries](https://engineering.mixpanel.com/how-we-cut-bigquery-costs-by-80-by-identifying-and-optimizing-costly-query-patterns-1a297b46bd33) — Mixpanel Engineering
- [What are the best practices while using BigQuery?](https://www.educative.io/answers/what-are-the-best-practices-while-using-bigquery) — Educative
- [BigQuery: query and table optimization to save some money](https://dev.to/castnutt/bigquery-query-and-table-optimization-to-save-some-money-5cb) — DEV Community
- [Taking a practical approach to BigQuery cost monitoring](https://cloud.google.com/blog/products/data-analytics/taking-a-practical-approach-to-bigquery-cost-monitoring) — Google Cloud Blog
- [bigquery-optimization-queries (репозиторий готовых запросов для аудита costs)](https://github.com/two-inc/bigquery-optimization-queries) — GitHub, two-inc
- [Study Note 3.2.1: BigQuery Best Practices](https://dev.to/pizofreude/study-note-321-bigquery-best-practices-15o2) — DEV Community
- [Google Updates BigQuery With Better Cost Controls, Audit Logs And Improved Streaming API (2015, исторический контекст)](https://techcrunch.com/2015/12/15/big-query-predictable-cost) — TechCrunch
- [BigQuery Cost Optimization: Cut Spend, Keep Performance](https://www.doit.com/blog/bigquery-cost-optimization) — DoiT
- [How to reduce BigQuery costs without compromising performance](https://www.getdbt.com/blog/reduce-bigquery-costs) — dbt Labs
- [BigQuery Slot Cost Optimization Guide](https://www.revefi.com/blog/bigquery-slot-cost-explained) — Revefi
- [BigQuery Cost Optimization | Fix Your Queries Before You Touch the Pricing Model](https://www.usage.ai/blogs/gcp/bigquery-cost-optimization/) — Usage.ai
- [BigQuery Cost Optimization with slot management](https://medium.com/google-cloud/bigquery-cost-optimization-with-slot-management-e6eb50697265) — Google Cloud Community / Medium
- [Google BigQuery Cost Optimization: 7 Proven Strategies to Slash Your 2026 Cloud Bill](https://dev.to/tech_croc_f32fbb6ea8ed4/google-bigquery-cost-optimization-7-proven-strategies-to-slash-your-2026-cloud-bill-116e) — DEV Community
- [Google BigQuery Cost Optimization 2026](https://www.revefi.com/blog/google-bigquery-cost-optimization) — Revefi
- [The True Cost of Manual BigQuery Optimization: A FinOps Perspective (кейс Nordstrom)](https://followrabbit.ai/blog/the-true-cost-of-manual-bigquery-optimization-finops-perspective) — followrabbit.ai

### Snowflake
- [Snowflake Cost Optimization: A Practical Engineering Guide to Reducing Snowflake Costs](https://coalesce.io/data-insights/snowflake-cost-optimization-a-practical-engineering-guide-to-reducing-snowflake-costs/) — Coalesce
- [Snowflake Cost Optimization: How to Monitor And Reduce Your Snowflake Spend In 2026](https://www.cloudzero.com/blog/snowflake-cost-optimization/) — CloudZero
- [Optimizing Snowflake Use: Smart Strategies to Minimize Credit Consumption](https://www.useready.com/blog/optimizing-snowflake-use-smart-strategies-to-minimize-credit-consumption) — USEReady
- [How can Snowflake query optimization bring down my cloud costs?](https://www.unraveldata.com/insights/snowflake-query-optimization-costs/) — Unravel Data
- [How we reduced Snowflake costs by 70%: a practical optimization guide](https://chartmogul.com/blog/how-we-reduced-snowflake-costs-by-70-a-practical-optimization-guide/) — ChartMogul
- [Snowflake Innovates on Performance & Efficiency While Reducing Costs](https://www.snowflake.com/en/blog/snowflake-performance-efficiency-cost-savings/) — Snowflake
- [Snowflake Cost Optimization: The Complete 2026 Guide](https://www.revefi.com/blog/snowflake-cost-optimization) — Revefi
- [Snowflake Cost Optimization: 12 Proven](https://dataengineerhub.blog/articles/snowflake-cost-optimization-techniques-2026) — DataEngineer Hub

### Коммерческие листинги (справочно, не аналитический контент)
- [AWS RDS Performance Optimization (Perfsys)](https://aws.amazon.com/marketplace/pp/prodview-4jl5ozlmvzbwy) — маркетплейс, продажа консалтинга
- [Database Optimization (dbSeer)](https://aws.amazon.com/marketplace/pp/prodview-7gist2zolbwdi) — маркетплейс, продажа консалтинга

---

*Отчёт собран на основе веб-поиска 31 августа 2026 года. Часть материалов — маркетинговый контент вендоров FinOps-инструментов (CloudZero, Revefi, Unravel, DoiT и др.), это стоит учитывать при оценке объективности приводимых в них процентов экономии.*
