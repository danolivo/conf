# Пристрелочный проход планировщика: каталог оптимизаций

Рабочий документ. Гипотеза: планировщик планирует один раз; каждый узел, которому не хватило информации, оставляет аннотацию; если аннотаций набралось достаточно — проход по готовому плану собирает недостающие факты, привязывает их к узлам и планирование запускается повторно.

Ниже — каталог того, что от этого выиграет. Один раздел — одна оптимизация.

---

## 0. Механизм

### 0.1. Чего именно не хватает

Четыре разных дефицита, и лечатся они по-разному. Смешивать их нельзя.

**(a) Требуемые физические свойства** — порядок, уникальность, параметризация, «сгруппированность». Имеют частичный порядок, прунятся, ложатся на Cascades-овские required properties. У PostgreSQL для двух из них канал вниз уже есть: `root->query_pathkeys` (через `standard_qp_callback`) и `required_outer`. Остальные — нет.

**(b) Контекстные факты** — сколько строк реально спросят, сколько раз пересканируют, будет ли над узлом фильтр, какой join-метод выберут выше. Это не свойства пути; это свойства контекста. Добавить их измерением в `add_path()` нельзя — получится 2^n.

**(c) Окончательное размещение выражений** — какие qual'ы сядут на узел, какие уплывут выше как join filter. Частично решается в `distribute_qual_to_rels()`, окончательно — в `create_nestloop_plan()` (разбиение на `joinclauses`/`otherclauses`), `select_mergejoin_clauses()`, `create_hashjoin_plan()` и `setrefs.c` (qpqual). То есть **после** костинга.

**(d) Статистика противоположной стороны** — селективности считаются по одной релации за раз, корреляция через границу join'а не видна.

Пристрелочный проход адресует (b), (c) и (d). Для (a) правильный инструмент другой — расширение механизма pathkeys на другие свойства (UniqueKeys и т.п.), и это отдельная работа.

### 0.2. Форма аннотации

```c
typedef enum PlannerGapKind
{
    GAP_FINAL_QUALSET,   /* окончательный набор qual'ов на узле и над ним */
    GAP_ROW_BOUND,       /* верхняя граница числа запрошенных строк */
    GAP_LOOP_COUNT,      /* фактическое число пересканирований */
    GAP_ATTR_SET,        /* окончательный набор нужных атрибутов */
    GAP_JOIN_METHOD,     /* метод join'а, выбранный выше */
    GAP_CONSUMER_ORDER,  /* окончательный порядок, нужный потребителю */
    GAP_SIBLING_STATS    /* статистика противоположной стороны join'а */
} PlannerGapKind;

typedef struct PlannerGap
{
    PlannerGapKind kind;
    Relids         rel;        /* к чему относится */
    void          *payload;    /* что именно нужно */
    Cost           optimistic; /* стоимость, если факт окажется благоприятным */
    Cost           pessimistic;/* стоимость, если нет (это то, что ушло в add_path) */
} PlannerGap;
```

Триггер второго прохода: `sum(pessimistic - optimistic) > K * total_plan_cost`. То есть не «набралось много аннотаций», а «потенциальная выгода велика относительно стоимости плана». Иначе на OLTP-нагрузке с коротким планом мы будем перепланировать из-за одной копеечной аннотации.

### 0.3. Ключ привязки

Аннотация должна пережить перепланирование. `RelOptInfo *` не переживёт. `Relids` переживёт — это индексы в rtable, выведенные из jointree.

Отсюда следует конкретное требование: проход по готовому плану обязан уметь отобразить `Plan *` обратно в `Relids` планировщика. Это нетривиально: пустой скан вырождается в голый `Result` без relids, а `setrefs.c` выбрасывает тривиальные `SubqueryScan`/`Append`/`MergeAppend`.

**Эта инфраструктура уже написана.** Работа Роберта Хааса над `pg_plan_advice` (PG19) решала ровно эту задачу: relids на `Result`-узлах, список выброшенных узлов в `PlannedStmt`, имена подзапросов, назначаемые до планирования, запись плоского rtable.
Треды: [plan shape work](https://www.postgresql.org/message-id/CA+TgmoZxQO8svE_vtNCkEubnCYrnrCEnhftdbkdZ496Nfhg=wQ@mail.gmail.com), [RFC: extensible planner state](https://www.postgresql.org/message-id/CA+TgmoYWKHU2hKr62Toyzh-kTDEnMDeLw7gkOOnjL-TnOUq0kQ@mail.gmail.com), [pg_plan_advice](https://www.postgresql.org/message-id/CA+TgmoZ-Jh1T6QyWoCODMVQdhTUPYkaZjWztzP1En4=ZHoKPzw@mail.gmail.com). Плюс `PlannedStmt.extension_state`, `planner_setup_hook`/`planner_shutdown_hook` и `ExplainState` в `planner()` (коммит `c83ac02ec73`).

### 0.4. Механика перепланирования

Второй прогон не требует изобретать «сброс выведенных структур»: он тоже уже есть. Коммит Тома Лейна [«Perform join removal by editing the query's jointree»](https://www.postgresql.org/message-id/E1x020n-00000002XCr-0lpe@gemulon.postgresql.org) (август 2026, бэкпорт в v16) переделал удаление join'ов именно на схему «отредактировать `root->parse->jointree`, затем заставить `query_planner()` выбросить всё, что он из jointree вывел, и вывести заново». Цитата из коммита:

> «do the removals by editing root->parse->jointree (which is a far simpler and more stable representation than the derived data), and then have query_planner() discard everything it computed from the jointree and derive it over again. This requires quite a bit less code... For typical cases it can actually save a bit of planning time, though in cases where we have to iterate the derivation loop many times it does add some time.»

То есть цикл повторного вывода в `query_planner()` уже написан, отлажен и бэкпортирован. Пристрелочный проход становится ещё одной причиной войти в этот цикл — с аннотациями, положенными в `root` перед входом.

### 0.5. Дисциплина, которую надо заложить сразу

Из чужого опыта (раздел 20) — четыре правила, нарушение каждого убивало похожие механизмы:

1. **Разведка не должна ходить за данными.** Главный урок Oracle — не «оптимизировать дважды дорого», а «сэмплировать во время парса дорого». Механизм CBQT, который оптимизирует запрос по разу на каждое состояние трансформации, у Oracle остался включённым по умолчанию; выключили adaptive statistics, чья разведка означала рекурсивный SQL к реальным блокам данных. Разбор — раздел 20.5.
2. **Разведка не должна переживать запрос.** Второй убийца у Oracle — персистентность: SQL Plan Directives привязаны не к statement'у, а к выражению запроса, поэтому одна директива начинает облагать налогом hard parse всех остальных запросов, трогающих те же колонки.
3. **Цена платится в планировании, окупается в исполнении.** Это остаётся верным и для нас. Нужен порог по оценочной стоимости плана, а не по числу аннотаций: патологическая нагрузка — ровно та, где много дешёвых запросов, каждый из которых честно поставил по одной аннотации.
4. **Откат и выключатель с первого дня.** SQL Server верифицирует каждую обратную связь на следующем исполнении и откатывается при регрессии; персистит только подтверждённое. Snowflake: «we do no harm» — каждый добавленный агрегат сам себя отключает в рантайме. У нас: `enable_planner_second_pass` (по умолчанию `off` до накопления опыта) плюс порог `planner_second_pass_cost_threshold`.

### 0.6. Формат разделов

Каждый раздел: теория → тред в hackers → пример → как работает сейчас → как будет → что собирает проход → альтернативные СУБД.

---

# Группа A. Не хватает окончательного набора фильтров

---

## 1. Memoize с `single_row` для SEMI/ANTI JOIN

**Теория.** Частный случай semi-join reduction: при semi-join внутренняя сторона на каждый внешний кортеж нужна ровно в одном экземпляре, поэтому кэш может хранить по одной строке на ключ.

**Hackers.**
- [Memoize ANTI and SEMI JOIN inner](https://www.postgresql.org/message-id/60bf8d26-7c7e-4915-b544-afdb9020011d@gmail.com), 2025 — исходное предложение.
- [Найденный контрпример](https://www.postgresql.org/message-id/95586c5d-2632-4f1c-bfb9-4c391f260de4@gmail.com): «How can we be sure that semi or anti-join needs only one tuple? ... Unfortunately, we only have such a guarantee in the plan creation stage (maybe even setrefs.c). So, it seems we need to invent an approach like AlternativeSubplan.»
- Предшествующий баг того же класса: [«Postgres 16.1 - Bug: cache entry already complete»](https://www.postgresql.org/message-id/CAApHDvoBTZzooXsH4hqtQ4cNJxuYZe=hakPcLSPZP9-NkfaSjQ@mail.gmail.com), 2024, Дэвид Роули дословно: *«we only figure out what will become the "Join Filter" in create_nestloop_path(), which is slightly too late as we create the MemoizePath before creating the NestLoopPath.»* Он написал фикс, дублирующий логику `create_nestloop_path()` внутри `get_memoize_path()`, и сам же его отверг: при наличии Join Filter вместе с unique-join skip-to-next-outer запись кэша нельзя пометить завершённой никогда, то есть фикс меняет неверный результат на сплошные промахи.
- Корректностный инцидент: [BUG #17213](https://www.postgresql.org/message-id/17213-988ed34b225a2862@postgresql.org) — Merge Semi Join + Memoize возвращает 0 строк вместо 2; в плане с `enable_memoize=off` виден `Join Filter: (u1.id = superfluous.id)`, и именно он делает кэш некорректным.

**Пример.**

```sql
SELECT * FROM t1
WHERE EXISTS (SELECT 1 FROM t2 WHERE t2.a = t1.a) AND t1.b > 0;
-- после pull-up sublink получаем SEMI JOIN;
-- если часть условия не уехала в индекс, она садится в Join Filter,
-- и NestLoop вынужден просить у inner больше одной строки
ERROR:  cache entry already complete
```

**Как сейчас.** `get_memoize_path()` вызывается из `try_nestloop_path()` **до** `create_nestloop_path()`. `singlerow` выставляется по `extra->inner_unique`. Разбиение join-условий на «ушедшие в параметризацию inner'а» и «оставшиеся join-фильтром» происходит позже — окончательно в `create_nestloop_plan()`, где из `joinrestrictinfo` вычитаются клаузы, уже использованные как параметризованные квалы, и остаток становится `otherclauses`. Итог: `single_row` для SEMI/ANTI запрещён целиком.

**Как будет.** Memoize-путь создаётся в оптимистичном варианте (`single_row = true`) с аннотацией. Второй проход смотрит на построенный `NestLoop` и проверяет: пуст ли `Plan.qual`, пуст ли остаток `joinqual` сверх того, что покрыто ключами кэша. Если пусто — оптимистичный вариант подтверждается, и на втором планировании `get_memoize_path()` уже знает, что `single_row` легален. Если нет — аннотация гасится и путь строится консервативно.

**Что собирает проход.**

| поле | содержимое |
|---|---|
| `kind` | `GAP_FINAL_QUALSET` |
| `rel` | relids inner-релации |
| `payload` | `{ outer_relids, join_type, cache_keys }` |
| собирается | `Join->joinqual ∖ cache_keys`, `Plan->qual` на NestLoop; плюс те же множества у всех NestLoop выше по цепочке до ближайшего материализующего узла |
| вердикт | оба множества пусты → `single_row` разрешён |

**Альтернативные СУБД.**

| движок | аналог | есть ли проблема | почему |
|---|---|---|---|
| SQL Server | Lazy Index Spool | **нет** | Варианты «со spool / с index spool / без spool» — это отдельные group expressions в memo, порождаемые правилом `ApplyToNL` и реализуемые `BuildSpool`. Предикат является скалярным потомком самого spool (видно в TF 8619/8621). Ретрофита нет по конструкции. Плата — агрессивный прунинг по promise value и намеренно заниженная оценка rewind'ов у index spool, «иначе оптимизатор выбирал бы его слишком часто» ([sql.kiwi](https://www.sql.kiwi/2019/09/nested-loops-joins-performance-spools/), [устройство index spool](https://www.sql.kiwi/2025/02/lazy-index-spool/)) |
| DB2 / Starburst | нет оператора | **архитектурно невозможна** | Ломан (SIGMOD'88): предикаты — это property плана (`PREDS`), входящее в ключ поиска, а разбиение на pushed-down / join-applied / residual — **аргументы правила**, порождающего inner-план. Дословно: *«the predicates to be applied by the inner stream are parameters, not required attributes»*, и обоснование — чтобы не заниматься *«retrofitting a FILTER LOLEPOP to existing plans»*. Это буквальное описание того, что делает PostgreSQL, отвергнутое в 1988 году. В продукте дожило как `EXPLAIN_PREDICATE.HOW_APPLIED` со значением `RESID` ([IBM](https://www.ibm.com/docs/en/db2/11.5.0?topic=tables-explain-predicate)) |
| MariaDB | Subquery cache | **нет** | Ключуется на *весь* список корреляционных параметров, residual-условия внутри кэшируемого выражения. Разделения «ключ vs residual» просто не существует. Плата: **не костируется вообще**, самоотключается в рантайме по hit rate (<0.2 — выкл, <0.7 — очистка). Худший опубликованный случай в их же таблице — 0.96× ([доки](https://mariadb.com/docs/server/ha-and-performance/optimization-and-tuning/query-optimizations/subquery-optimizations/subquery-cache.md)) |
| Oracle | scalar subquery caching | **нет** (оператора нет) | Чисто рантаймовый хэш на 255 слотов (10g/11g) / ~1024 бакета (19c), **без цепочек**: при коллизии вторая запись не кэшируется. Ключ фиксируется rewriter'ом. Костинг — эвристика «идеального кэша» (умножение на NDV). Льюис: одна строка-коллизия превращает 10 мс в ~21 с CPU ([Filter Subqueries](https://jonathanlewis.wordpress.com/2006/11/06/filter-subqueries/)) |
| CockroachDB | нет | **нет** | Cascades; lookup join порождается exploration-правилом целиком, `LookupExpr` (ограничивающая часть) отделён от `On` (residual) с рождения |
| DuckDB | не нужен | **нет** | Все подзапросы декоррелируются безусловно (Neumann & Kemper, BTW 2015); delim join строит DISTINCT по корреляционным колонкам заранее — структурная инверсия Memoize |

Вывод: гипотеза подтверждается — в memo-оптимизаторе required и residual известны в момент создания физического оператора, потому что они часть самого выражения, а не аннотация поверх готового плана.

---

## 2. Memoize: ключи кэша и назначение PARAM_EXEC

**Теория.** Корректность кэша требует, чтобы множество ключей покрывало все параметры, меняющиеся между итерациями.

**Hackers.**
- [Check lateral references within PHVs for memoize cache keys](https://www.postgresql.org/message-id/CAMbWs4_imG5C8rXt7xdU7zf6whUDc2rdDun+Vtrowcmxb41CzA@mail.gmail.com) — lateral-ссылки, спрятанные внутри PlaceHolderVar, не попадали в ключи: `Hits: 0 Misses: 10000 Evictions: 9999`, регрессия 130% против `enable_memoize=off`. Ричард Гуо перенёс вычисление в `get_memoize_path()` и тут же засомневался: *«doing this would make get_memoize_path too expensive»*.
- [A performance issue with Memoize](https://www.postgresql.org/message-id/CAMbWs48XHJEK1Q1CzAQ7L9sTANTs9W1cepXu8=Kc0quUL+tg4Q@mail.gmail.com) — `keyparamids` Memoize и `chgParam` внешнего плана расходятся, потому что слоты PARAM_EXEC раздаются в `create_plan()` (`create_subqueryscan_plan()` против `root->curOuterParams`) уже после создания MemoizePath. Два Var'а `t1.two` становятся разными параметрами, кэш чистится на каждом rescan: 124 с против 61 с без Memoize.
- [Don't Memoize lateral joins with volatile join conditions](https://www.postgresql.org/message-id/E1qSxGX-000r4k-I6@gemulon.postgresql.org) — Memoize опирался на побочный эффект: волатильные условия отсеивались в `match_opclause_to_indexcol()`, потому что *«ordinarily, the parameterization for the inner side of a nested loop will be an Index Scan»*. Для lateral это неверно (возможен параметризованный seqscan), и свойство безопасности, унаследованное от ещё не построенного узла, пришлось выводить заново явно.

**Как сейчас.** Ключи кэша выводятся из параметризации, видимой в момент создания пути. Идентичность параметров — из назначения PARAM_EXEC на этапе `create_plan()`. Между этими двумя моментами информация теряется, и оба бага — следствия.

**Как будет.** Второй проход читает `Memoize->param_exprs`/`keyparamids` из готового плана и сравнивает с `chgParam` родителя, а также собирает полный набор `Param`, реально доходящих до inner-поддерева. Если множества не совпадают — аннотация сообщает точный недостающий набор, и на втором планировании ключи строятся правильно (либо Memoize отвергается).

**Что собирает проход.** `kind = GAP_FINAL_QUALSET`, payload — `{memoize_keys}`; собирается объединение `chgParam` по пути от Memoize до листьев плюс все `PARAM_EXEC`, на которые ссылается inner-поддерево. Вердикт — покрытие множеств.

**Альтернативные СУБД.** Проблема отсутствует у всех по причинам из раздела 1. Ближайший аналог «ключ должен покрывать всё» — требование SQL Server, чтобы outer references образовывали ключ spool'а; у MariaDB ключ по построению есть весь список параметров.

---

## 3. Граница числа строк сквозь LEFT JOIN: bounded Sort и ранний останов скана

**Теория.** Top-k без сортировки всего входа. Формально ближе всего RankSQL (Li, Soliman, Chang, Ilyas, VLDB 2005) — там ранг поднят до логического свойства алгебры, и там же сформулирована ровно наша проблема:

> «In ranking query plans, however, an operator consumes only partial input, therefore the actual input size depends on the operator itself... This imposes a big challenge to System-R style optimizers that build subplans in bottom-up fashion, because **the input sizes consumed by operators depend on the location of that subplan in the complete plan, which is unavailable during enumeration.**»

RankSQL решает это сэмплированием, а не аналитической формулой. Прототип, к слову, на PostgreSQL 7.4.3.
Также: Ilyas, Aref, Elmagarmid, «Supporting Top-k Join Queries in Relational Databases», VLDB 2003 (операторы HRJN/NRJN).

**Hackers.**
- [Try a presorted outer path when referenced by an ORDER BY prefix](https://www.postgresql.org/message-id/f0dc7fcb-4034-4b5c-bfe6-1e7b8817cd36@gmail.com), 2026 — текущее состояние: *«production use has exposed that the "optimistic" strategy doesn't work safely: we can't suppose during planning that the outer of the LEFT JOIN returns no more than "limit_tuples" rows. Some pushed-down clause that lands as a join filter in the LEFT JOIN chain might cause the scan node to return (and sort) far more tuples than planned.»* Реализовано «оппортунистически»: костинг предполагает полную сортировку, а `ExecSetTupleBound` ставит границу на Sort, только если ни один LEFT JOIN в цепочке не несёт фильтров.
- [Push limit to sort through a subquery](https://www.postgresql.org/message-id/CADE5jYLQEwxDFHVYRqDnkZQJqCBSs+Hj9s4nMjijO=3L_AJXdg@mail.gmail.com), 2017 — весь `pass_down_bound`/`ExecSetTupleBound` существует как исполнительный костыль.
- [Wasteful nested loop join when there is limit](https://www.postgresql.org/message-id/CAAdwFAwm6HwXM_cuPWZBxrxX4E7pBdVg=KcVDSP6q9ume3hYpQ@mail.gmail.com) + [ответ Тома Лейна](https://www.postgresql.org/message-id/744079.1739775701@sss.pgh.pa.us): такой оптимизации нет, и даже будь она — *«could not push the LIMIT through a sort step»*.
- [Possible optimisation: push down SORT and LIMIT nodes](https://www.postgresql.org/message-id/E9FA92C2921F31408041863B74EE4C2001AEF33492@CCPMAILDAG03.cantab.local), 2018 — исходная постановка, с точными предусловиями (inner unique, колонки правой стороны не встречаются в WHERE и в порядке сортировки кроме хвоста). Ответили «используйте Incremental Sort».
- [Роберт Хаас про параллельные воркеры](https://www.postgresql.org/message-id/CA+TgmoYTgn97uzQ1zTwtnj0JZTaEZHrRQCNJUuyUFPsXjCqzzA@mail.gmail.com), 2017: *«even if it did, it would only affect the leader, not the workers, because each worker will of course have a separate copy of each executor state node»*. Так и не сделано.

**Пример.**

```sql
SELECT t.*, d.name FROM t LEFT JOIN d ON d.id = t.d_id   -- d.id уникален
ORDER BY t.created_at DESC LIMIT 100;
-- хочется: Index Scan по t.created_at, 100 строк, потом join
-- получаем: полный Sort всего t
```

**Как сейчас.** `root->tuple_fraction` — один на уровень запроса, влияет только на выбор fractional-optimal пути; гарантии не даёт. `limit_tuples` доезжает до `cost_sort()` только там, где Sort создаётся под самим Limit. Через join граница не проходит. Исполнительный `pass_down_bound()`/`ExecSetTupleBound()` умеет спускать границу через ограниченный набор узлов и не умеет через join, не доезжает до воркеров.

**Как будет.** Outer-путь строится с аннотацией `GAP_ROW_BOUND(n)` и двумя стоимостями: `optimistic` — bounded top-N sort на n строк, `pessimistic` — полная сортировка (то, что уходит в `add_path` сейчас). Второй проход проверяет по готовому плану: (1) ни один узел цепочки от Sort до Limit не несёт `qual`; (2) все join'ы в цепочке — LEFT/RIGHT с сохраняемой стороной там, где Sort, либо inner-unique INNER; (3) нет узлов, размножающих строки. Подтверждено — второе планирование строит bounded Sort и, где возможно, ранний останов индексного скана, и костит их честно.

**Что собирает проход.**

| поле | содержимое |
|---|---|
| `kind` | `GAP_ROW_BOUND` |
| `payload` | `{ bound = limit + offset, sort_pathkeys, preserved_side }` |
| собирается | для каждого узла на пути Sort → Limit: наличие `Plan->qual`, тип join'а, `inner_unique`, наличие SRF в tlist, наличие Gather |
| вердикт | цепочка чистая → граница твёрдая; иначе → мягкая (только костинг) |

**Альтернативные СУБД.** Здесь индустрия делится на два лагеря, и это важнее всего остального в документе.

**(A) Row goal как мягкая подсказка костингу — делится на селективность, ничего не гарантирует.**

- **SQL Server.** Канон. Пол Уайт: *«The optimizer changes required to enable the row goal feature are largely self-contained, sitting in a thin layer on top of the normal optimization activities»* — то есть row goal **не** required property в memo; exploration о нём не знает. Отличие только в обратном проходе по костингу: *«When a row goal is present, the optimizer subsequently works down the plan (from the row goal toward the plan leaves) modifying iterator costs and cardinality estimates»*. Остаточный фильтр обрабатывается **делением на селективность**, и это видно численно (TF 8607+8612): `TOP(28)` над фильтром `Quantity = 100`, дающим 29 строк из 113443, спускает скану `RowGoal 109531` = 28 × 113443 / 29. При `TOP(29)` row goal не ставится вовсе — цель не меньше обычной оценки. Отключение: TF 4138 / `USE HINT('DISABLE_OPTIMIZER_ROWGOAL')`, и Microsoft сама документирует это как workaround для неравномерных распределений. Патологии: [Row Goals Gone Rogue](https://learn.microsoft.com/en-us/archive/blogs/bartd/row-goals-gone-rogue) — `TOP 1` по непересекающимся таблицам, 9 секунд и 100 млн просканированных строк, из-за встроенного допущения о положительной корреляции; [anti-join anti-pattern](https://www.sql.kiwi/2018/03/row-goals-part-4-anti-join-anti-pattern/) — цепочка из шести корректных преобразований порождает row goal из ничего, 20 секунд, вердикт автора: *«entirely artificial, and has no basis in the original query specification»*.
- **Oracle.** `FIRST_ROWS_n` плюс First-K-Rows от предиката `ROWNUM` (`_optimizer_rownum_pred_based_fkr`). Параметр уровня query block с полным пересчётом костинга внутри блока — то есть та же грубость, что у `tuple_fraction`, но с пересчётом. Пропагация через NL вероятностная: для k=1 оценка outer = `(num_rows_inner + 1) / (cardinality_inner + 1)`. `SORT ORDER BY STOPKEY` — настоящий bounded top-N (trace 10032: 1000 входных, 10 выходных, 999 сравнений, 2048 байт). Ломается на нераспознанной обёртке: `where rownum <= nvl(:rn, rownum)` даёт `COUNT`+`FILTER` без STOPKEY, 2310 buffers вместо 4.
- **DB2.** `OPTIMIZE FOR n ROWS` — влияет только на оптимизацию, не ограничивает результат. IBM документирует эффект **пооперационно**: NL становится вероятнее, composite inner — реже, индекс под ORDER BY — вероятнее, list prefetch — реже, и прямо про join: *«the table with the columns in the ORDER BY clause is likely to be picked as the outer table»*. Формулировка LUW прямо про pipeline breakers: избегать *«inserting into a temporary table, sorting, or inserting into a hash join hash table»*. Явный список случаев, когда клауза **игнорируется**: DISTINCT, GROUP BY/ORDER BY без индекса, агрегат без GROUP BY, UNION.
- **CockroachDB — единственный, где это настоящее required property.** `LimitHint float64` в `physical.Required`: хешируется в `hasher.HashPhysProps`, сравнивается в `Equals`, входит в `groupStateKey{group, required}` — то есть группа переоптимизируется под другой hint. Enforcer'а при этом нет («All operators can provide the Presentation and LimitHint properties»). Деление на селективность в двух местах: `xform/physical_props.go` (`childProps.LimitHint = parentProps.LimitHint * inputRows / outputRows`) и `xform/coster.go` (`inputRowCount = min(inputRowCount, required.LimitHint/selectivity)`). Через hash/merge join hint **не передаётся** — эти операторы `required.LimitHint` не читают вовсе.

**(B) Жёсткая граница как переписывание дерева — и вот здесь главное наблюдение.**

Ни один движок не пытается поделить *жёсткую* границу на селективность остаточного фильтра. Все просто **отказываются проталкивать, если между Limit/Sort и Join стоит Filter**. Паттерн правила требует Join непосредственным (или через Project) ребёнком; Filter не матчится, правило молча не срабатывает.

- **Spark**, `LimitPushDown`: матчит ровно `LocalLimit(exp, join)` и `LocalLimit(exp, Project(_, join))`. Case для `Filter` отсутствует. Для LEFT/RIGHT OUTER требуется **непустое** условие join'а. Проталкивается только `LocalLimit`; глобальный остаётся сверху. Породивший гард баг: [SPARK-22211](https://issues.apache.org/jira/browse/SPARK-22211) «LimitPushDown optimization for FullOuterJoin generates wrong results».
- **Calcite**, `SortJoinTransposeRule`: только LEFT/RIGHT, ключи целиком с одной стороны, не срабатывает при динамических параметрах. Единственное место во всём обзоре, где вообще проверяется уникальность — `areColumnsDefinitelyUnique` — и то только ради корректности OFFSET, а не для усиления границы.
- **Trino**, `PushLimitThroughOuterJoin`/`PushTopNThroughOuterJoin`: вставляется `PARTIAL`-узел. Честный TODO авторов: *«this Rule violates the expectation that Rule transformations must preserve the semantics of the expression subtree. It works only because it's a PARTIAL TopN, so there will be a FINAL TopN that "fixes" it.»*
- **ClickHouse 26.5**, `topKThroughJoin` — самая проработанная реализация, с выписанным инвариантом: *«Consider Limit(n) <- Sort(K) <- Join(L, R) where K only references columns from L and the join is LEFT (so **every L row produces at least one output row**)... The outer Sort+Limit is preserved because LEFT JOIN may multiply each L row into several output rows. We do not apply this optimization to INNER joins: an L row with no R match produces zero output rows.»* Semi и Anti отвергаются явно — «they break the invariant». Между Sort и Join снимаются только `ExpressionStep` (≤4), `FilterStep` не предусмотрен. TPC-H sf100: 1.878 s / 1.88 GiB → 0.092 s / 10.98 MiB.
- **MariaDB** — единственный, кто попытался честно посчитать риск: `optimizer_join_limit_pref_ratio` (MDEV-34720). Постановка проблемы дословно: *«if the join has a condition with selectivity=0.5 that the optimizer is not aware of, the actual cost of producing #LIMIT rows will be 1/0.5=2 times higher. To account for this, we will add a multiplier, e.g. use QUERY_PLAN2-WITH-SHORTCUTTING only if promises a 100x speedup.»* Реализация — **двойная оптимизация**: обычная и принудительно с `sort_by_table` первой, затем сравнение. По умолчанию **выключено** (`0`), рекомендованное значение `100`. Полноценное решение вынесено в MDEV-8306, статус Stalled. Есть уже и регрессии от самого фикса: MDEV-40370 — модель применяет shortcut-стоимость к плану, который всё равно делает полный join и filesort.
- **DuckDB — принципиально другой ответ, и для нас он самый интересный.** Счётчик строк через join не толкается вовсе (`limit_pushdown.cpp` работает только через `LOGICAL_PROJECTION` и только при `limit_val < 8192`). Зато Top-N оператор **в рантайме публикует границу значения**: `TopN::PushdownDynamicFilters` держит N-ю по порядку границу и публикует её как `DynamicFilterData` (`C < boundary`), после чего фильтр вталкивается в `LogicalGet.table_filters`. И рекурсия `GetPushdownFilterTargets` идёт **сквозь `LOGICAL_COMPARISON_JOIN` и сквозь `LOGICAL_FILTER`**, останавливаясь только на `LOGICAL_LIMIT`/`LOGICAL_TOP_N`. Проблема остаточного фильтра просто не возникает: граница консервативна по построению и уточняется по мере наполнения кучи, поэтому фильтр сверху делает её не неверной, а лишь менее агрессивной.

**Что из этого следует для нас.** Инвариант, которым пользуется индустрия, — **не** уникальность inner-стороны, а «каждая строка сохраняемой стороны OUTER JOIN даёт хотя бы одну выходную строку». Верхний Sort+Limit при этом всегда сохраняется как страховка. Наш случай «inner unique ⇒ ровно одна строка ⇒ верхнюю границу можно сделать точной» в публичном коде не реализован нигде — это потенциально оригинальный вклад, но и повышенный риск. И отдельно стоит рассмотреть путь DuckDB: протаскивать вниз не счётчик строк, а границу значения ключа сортировки.

---

## 4. Ранняя остановка под SEMI/ANTI JOIN в костинге

**Теория.** Semi-join: достаточно первого совпадения. Вопрос не в исполнении (там останов уже есть), а в том, что **выбор плана** делается по стоимости полного скана.

**Hackers.** Отдельного треда нет — это следствие. Косвенно: [Memoize ANTI and SEMI](https://www.postgresql.org/message-id/60bf8d26-7c7e-4915-b544-afdb9020011d@gmail.com); [Cost estimates for parameterized paths](https://www.postgresql.org/message-id/14624.1283463072@sss.pgh.pa.us).

**Пример.**

```sql
SELECT * FROM big b WHERE EXISTS (SELECT 1 FROM huge h WHERE h.k = b.k);
-- inner костится как полный скан huge с параметризацией;
-- реально исполнитель берёт первую строку и уходит
```

**Как сейчас.** Ранний останов — свойство исполнителя (`ExecScan` под semi-join прекращает по первому совпадению). В костинге его нет: `cost_seqscan`/`cost_index` для inner-пути не знают, что окажутся под SEMI, и считают полный проход (с поправкой на `loop_count`, но не на «одна строка за итерацию»). Как следствие, NestLoop+SEMI недооценён по выгоде и проигрывает hash join там, где выиграл бы.

**Как будет.** Аннотация на inner-пути: «если надо мной окажется SEMI/ANTI и мой выход не фильтруется выше — считай стоимость как выборку одной строки». Второй проход подтверждает тип join'а и отсутствие фильтра.

**Что собирает проход.** `kind = GAP_FINAL_QUALSET` + `GAP_ROW_BOUND(1)`. Собирается: `JoinType` фактического родителя, `Join->joinqual ∖ (то, что ушло в параметризацию)`, `Plan->qual`.

**Альтернативные СУБД.** Здесь у SQL Server самый точный и самый поучительный ответ.

- **SQL Server.** Правило дословно: *«Only apply nested loops join has a row goal applied by the optimizer (remember though, a row goal for apply nested loops join is only added if the row goal is less than the estimate without it).»* Hash semi join и merge semi join row goal **не получают** — предикат проверяется на самом join'е, ранний выход по одному входу ничего не даёт. **Uncorrelated** nested loops semi join тоже не получает: предикат на join'е, *«the inner input has no way to determine which row(s) should be prioritized»* — рантайм всё равно останавливается, но в костинге это не отражено (TF 8607/8612 показывает `RowGoal 0`, оценка 4000 при фактических ~210). Виден как атрибут плана `EstimateRowsWithoutRowGoal` (2017 CU3+).
  **Anti-join — асимметрия, и она намеренная:** *«The optimizer assumes that people write a semi join... with the expectation that the row being searched for will be found... For anti join the optimizer's assumption is that a matching row will not be found. An apply anti join row goal is not set by the optimizer, because it expects to have to check all rows to confirm there is no match.»* Это прямо относится к нашему случаю: для ANTI ранний останов костить **нельзя**, и Microsoft пришла к этому эмпирически.
- **DB2.** Термин `EARLYOUT` подтверждён: `EXPLAIN_ARGUMENT.ARGUMENT_TYPE = 'EARLYOUT'` — входной аргумент оператора NLJOIN/HSJOIN, значения `LEFT`, `LEFT (REMOVE INNER DUPLICATES)`, `RIGHT`, `GROUPBY`, `NONE`. То есть это свойство *выбранного оптимизатором* оператора, записываемое на этапе компиляции. Конкретная формула скидки на inner в документации IBM не приводится.
- **Oracle.** Semi/anti — трансформации, *«the database stops processing the second data set at the first match»*. Костится ли inner как «одна строка» — формула не документирована; наблюдательно скидка огромная (NESTED LOOPS SEMI стоимостью 190 поверх TABLE ACCESS FULL стоимостью 186 при 10065 итерациях). Важная деталь: `NESTED LOOPS SEMI` в рантайме пользуется тем же scalar subquery cache, и при случайном порядке outer-строк inner стартует 4033 раза вместо 1000 — **план и cost при этом идентичны** ([12c Downgrade](https://jonathanlewis.wordpress.com/2015/07/20/12c-downgrade/)).
- **MariaDB** формулирует ограничение корректности явно, и оно ровно про нас: *«Note that the short-cutting has to take place **after** `Using where` has been applied.»* И размещение FirstMatch — плановое решение, параметризованное join-префиксом: *«the optimizer can make a choice between whether it should run the FirstMatch strategy as soon as all tables used in the subquery are in the join prefix, or at some later point in time»*.

---

## 5. Bloom-фильтр из hash join в скан probe-стороны

**Теория.** Semi-join reducer / bloomjoin. Bernstein & Chiu, JACM 28(1), 1981; термин «Bloomjoin» — Mackert & Lohman, «R* Optimizer Validation and Performance Evaluation for Distributed Queries», VLDB 1986, §6.3. Современная постановка ровно нашей проблемы: **Zeyl et al. (Huawei), «Including Bloom Filters in Bottom-up Optimization», SIGMOD-Companion 2025**, [arXiv 2505.02994](https://arxiv.org/pdf/2505.02994) — *«typically added during post-processing... after the optimal query plan structure has already been determined»*, *«To date, Bloom filter-aware query optimization has only been incorporated in a top-down query optimizer»*; **+32.8% сокращения latency на TPC-H 100GB** относительно post-optimization вставки. Это главный внешний аргумент за весь наш механизм.

**Hackers.** [hashjoins vs. Bloom filters (yet again)](https://www.postgresql.org/message-id/5cd8c20c-14b5-4b0d-bedc-69bf714e87eb@vondra.me), Томас Вондра, 2026. Постановка проблемы дословно:

> «Ideally, we'd know about the filters when constructing the scan nodes, so we'd have a chance to estimate how many tuples will be eliminated by probing the filters... But we can't do that, because our planner works bottom-up. When constructing the scan nodes we know which tables we'll join with, but we have no idea which of the join algorithms we'll pick. ...The only "correct" way I can think of dealing with this in the bottom-up world is having two sets of paths — one set for a hash join, one set for other joins. But that's not just for scans. We'd need that for all paths, and for different combinations of joins. For the query with 3 joins, we'd end up with 2^3 combinations. That seems not great.»

**Как сейчас.** Пуш-даун фильтра происходит в `create_hashjoin_plan()`, то есть после костинга. Скан костится так, как будто фильтра нет.

**Как будет.** Скан оставляет аннотацию `GAP_JOIN_METHOD` с двумя стоимостями. Второй проход читает готовый план и отвечает на вопрос, который в первом проходе не имел ответа: оказался ли этот скан под Hash Join, на probe-стороне, и по каким колонкам. Второе планирование костит скан с учётом фильтра — и, что важнее, **порядок join'ов может измениться**, потому что дешевеет именно то поддерево, которое фильтр защищает. Это ровно та дельта, которую Huawei измерили как 32.8%.

Важно: аннотация снимает возражение про 2^n. Мы не строим по паре путей на каждую комбинацию — мы строим один путь пессимистично и перепланируем один раз, уже зная, какие из 2^n комбинаций реализовались.

**Что собирает проход.** `kind = GAP_JOIN_METHOD`; payload — relids скана. Собирается: тип родительского join-узла, сторона (build/probe), список hash-клауз, оценка мощности build-стороны. Вердикт — расчётная селективность фильтра.

**Альтернативные СУБД.** Наша проблема здесь — **индустриальная норма**, а не патология PostgreSQL. Несколько движков признают это публично и прямым текстом.

| движок | механизм | костится? |
|---|---|---|
| **Oracle** | `JOIN FILTER CREATE/USE :BF0000`, `SYS_OP_BLOOM_FILTER` | Решение — да (по selectivity+volume, `_bloom_filter_ratio`). **Стоимость и rows скана — нет.** Четыре независимых плана у Льюиса и Пагано: `JOIN FILTER USE` показывает E-Rows и Cost, в точности равные нижележащему TABLE ACCESS FULL (10M / 8140 при фактических 15102). Побочный эффект: *размер* вектора берётся из оценки, поэтому недооценка калечит фильтр при байт-идентичном плане |
| **SQL Server** row-mode `Bitmap` | битовый фильтр от hash build | **Нет, и это документировано Microsoft дословно:** *«When bitmap filtering is introduced in the query plan after optimization, query compilation time is reduced; however, the query plans that the optimizer can consider are limited, and cardinality and cost estimates are not taken into account.»* Пол Уайт добавляет следствие, которое нам и нужно: оптимизатор может *отбросить* форму плана, которую bitmap спас бы — *«the optimizer has no say in the decision, so it rejects a sorting plan early on as being a silly idea»* |
| **SQL Server** `Opt_Bitmap` (star join) | оптимизированный bitmap | **Да** — *«uses cardinality and cost estimates to determine if optimized bitmap filtering is appropriate»*. Но финальный pushdown в скан — post-selection cleanup, из-за чего оценка скана протухает (Хуго Корнелис: скан 12.6M, Parallelism над ним 1.5M) |
| **SQL Server** batch-mode bitmap | | **Да для селективности** (порог 0.75, округление до степени 10), **нет для позиции**: *«the bitmap is only pushed down the probe side once a single final execution plan has been selected... This is a trade-off that might be improved in future»* |
| **Impala** | bloom / min-max | **Нет.** [IMPALA-3573](https://www.mail-archive.com/issues-all@impala.apache.org/msg09302.html) открыт с 2016: *«Applying selective runtime filters can drastically change the cardinality of scan nodes, the planner doesn't cost the runtime filters as filters as a result it misses out on a more selective plan.»* И IMPALA-12018: *«IMPALA-3573 is about considering runtime filters during join ordering which would be a major change»* |
| **Trino** | dynamic filtering | **Нет, намеренно.** Коммит в [PR #2793](https://github.com/trinodb/trino/pull/2793): *«reorder joins should operate on plan that doesn't have dynamic filters as it might cause stats and cost misestimates»* — фильтры проталкиваются после `ReorderJoins`, чтобы CBO их не видел |
| **Spark** | DPP + bloom join | **Нет** — чистые эвристики: `dynamicPartitionPruning.fallbackFilterRatio` по умолчанию **0.5**; bloom join — пороги 10MB / 10GB, литеральные константы размера фильтра |
| **ClickHouse 25.10+** | bloom → PREWHERE | **Нет** — `tryAddJoinRuntimeFilter` вызывается **после** `optimizeJoinLogical`, «because it can swap tables» |
| **DuckDB** | min/max + IN-список | **Нет, и в коде это написано прямым текстом:** `// perform join filter pushdown after the dust has settled` |
| **Greenplum 7 / Cloudberry** | `RuntimeFilter` узел | **Гибрид** — единственный открытый движок, где фильтр и решается при планировании, и попадает в стоимость. Но решение пороговое: в `try_runtime_filter()` — отказ при FP-rate > 0.5, «Useless filter» при разнице < 10000 строк, и зашитое *«RuntimeFilter should filter out at least 40% tuples»*. Дальше `create_runtime_filter_path()` и правка `hashjointuples` в `final_cost_hashjoin`. Оба GUC (`gp_enable_runtime_filter`, `gp_enable_runtime_filter_pushdown`) по умолчанию **off** |
| **HyPer / Umbra** | bloom в неиспользуемых 16 битах указателей | **Нет, сознательно.** Morsel-Driven Parallelism, SIGMOD 2014: *«hash tagging has very low overhead and can always be used, without relying on the query optimizer to estimate selectivities»* — они не решили задачу костинга, а устранили её, сделав фильтр почти бесплатным |
| **Vertica** | SIP filters | **Нет, сознательно, и с объяснением, которое стоит прочитать целиком.** [Shrinivas et al., ICDE 2013](https://15721.courses.cs.cmu.edu/spring2020/papers/13-execution/shrinivas-icde2013.pdf): *«One way of dealing with this situation is to not create SIP filters for join predicates that have low selectivity. However, query optimizers rely on estimates of join selectivity, which can be quite error prone. Another option is adaptive evaluation... In Vertica, we chose the latter approach»* — если `N_out/N_in > 0.9` на первых ~10 000 строк, движок перестаёт вычислять предикат. Плюс красивое наблюдение: *«SIP filters, by the time they are ready to be evaluated during a scan, look identical to ordinary pushed-down predicates»* |
| **Db2** | bit filter / range filter / star join | **Да.** `HOW_APPLIED = BIT_FLTR`, z/OS про star join: *«This is a cost-based decision that is made by optimizer»*. В BLU — наоборот, join filters строятся безусловно |
| **Microsoft, CIDR 2026** | | [I Can't Believe It's Not Yannakakis](https://www.vldb.org/cidrdb/papers/2026/p29-zhao.pdf) — сильнейшее опубликованное утверждение, что продакшн Cascades-оптимизатор костит runtime-фильтры |

Повторяющийся паттерн: **системы, сделавшие фильтр почти бесплатным, перестают его костить** (Umbra, Vertica, BLU); **системы, где фильтр — настоящий оператор плана, его костят** (Db2, SQL Server `Opt_Bitmap`, Orca partition selector). Нам придётся решить, в каком лагере мы.

---

## 6. Join filter, который мог бы стать index cond

**Теория.** Access path selection под полным набором предикатов (Selinger et al., SIGMOD 1979 — но там предикаты известны заранее).

**Hackers.** [Can JoinFilter condition be pushed down into IndexScan?](https://www.postgresql.org/message-id/a86814a4-8ca3-91d8-c8fc-63dc996cad83@enterprisedb.com), Вондра, 2023. Планировщик знает, что `t3_1` даёт не более одной строки, но row-comparison садится как `Join Filter: (ROW(t3_0.rank, t3_0.id) <= ROW(t4_0.rank, t4_0.id))` — 666667 отброшенных строк, 465 мс против 0.055 мс при переписывании через подзапрос. Диагноз автора важен: *«the problem is [not] in the planner not being able to do this transformation, but more likely in not being able to cost it correctly»* — план с join'ом костится в 2.15 против 9.15 у подзапроса, так что даже умеющий это планировщик выбрал бы неверно.

**Пример.** См. выше; обобщённо — любая клауза, которая при данной параметризации могла бы стать индексным условием, но при перечислении путей не рассматривалась, потому что параметризация ещё не была зафиксирована.

**Как сейчас.** Индексные пути строятся в `build_index_paths()` под `baserestrictinfo` плюс те join-клаузы, что попали в `rel->joininfo` и подошли по `match_restriction_clauses_to_index()`. Клауза, не подошедшая ни под один индекс на момент перебора, уходит в join filter и больше не рассматривается.

**Как будет.** Второй проход собирает окончательный `Join->joinqual` каждого join-узла и возвращает его вниз как «вот что реально будет вычисляться над этой релацией». Второе планирование пробует построить индексные пути и под эти клаузы тоже.

Осторожно: раздел Вондры про костинг никуда не девается. Механизм даёт возможность построить путь, но не гарантирует, что он выиграет. Этот раздел работает в паре с разделом 15.

**Что собирает проход.** `kind = GAP_FINAL_QUALSET`, payload — relids базовой релации. Собирается: все `joinqual` и `qual` всех узлов выше, ссылающиеся на эту релацию. Вердикт — множество клауз-кандидатов для `match_clause_to_index()`.

**Альтернативные СУБД.** Это прямое следствие разбиения required/residual, разобранного в разделе 1: в Starburst предикаты — параметры правила, порождающего inner-план, поэтому вопрос «а можно ли было эту клаузу сделать индексным условием» решается при порождении плана. В SQL Server разделение закодировано в типе оператора: `Apply` (Outer References, предикат протолкнут вниз, на join не вычисляется) против `Nested Loops Join` (Predicate, всегда вычисляется на join'е) — это два разных `PhyOp_`, конкурирующих в memo по цене.

---

## 7. Run-time partition pruning в костинге

**Теория.** Динамическое отсечение разделов по значению, приходящему из другой стороны join'а.

**Hackers.**
- [Cost model improvement for run-time partition prune](https://www.postgresql.org/message-id/CAKU4AWp=BwGA6rS4bEq=1pnz7bJ-eqzPD5gjvKZVc8NhH6M1+A@mail.gmail.com), Энди Фань, 2021 — **единственное сообщение в треде, ноль ответов**. *«Currently the cost model ignores the initial partition prune and run time partition prune totally... We can see the cost/rows of Append Path is highly overrated (the rows should be 1 rather than 100, cost should be 8.44 rather than 844).»* И причина, по которой он остановился: *«there are no way to guess the reasonable ratio»*.
- [Support run-time partition pruning for hash join](https://www.postgresql.org/message-id/CAMbWs49atE64_JjqrF2+BBZvG-h7afL89wCghg_GmvOHPB_LbQ@mail.gmail.com), Ричард Гуо, 2023–2024, stalled ровно на этом: *«All the join partition prunning decisions are made in createplan.c where the best path tree has been decided. This is not great. Maybe it's better to make it happen when we build up the path tree, so that we can take the partition prunning into consideration when estimating the costs.»* Ответ Роули: *«You'll need to then come up with some counter costs to subtract from the Append/MergeAppend. This is tricky, as discussed. Just come up with something crude for now.»*

**Как сейчас.** `PartitionPruneInfo` строится в `createplan.c` (`make_partition_pruneinfo()`), то есть после выбора плана. Append костится так, будто отсечения не произойдёт.

**Как будет.** Второй проход читает построенный `PartitionPruneInfo`: какие шаги отсечения реально сгенерированы, по каким ключам, от каких выражений. Второе планирование получает это как ожидаемую долю отсекаемых разделов и костит Append соответственно. Ответ на возражение Энди Фаня «нет способа угадать разумную долю» — **не угадывать, а посмотреть**: после первого прохода известно, какие именно pruning steps построены, и по статистике ключа можно оценить долю честно.

**Что собирает проход.** `kind = GAP_FINAL_QUALSET`, payload — relids партиционированной таблицы. Собирается: сгенерированные `PartitionPruneStep`, их `exprs`, источник значений (Param/join key). Вердикт — оценка числа переживающих отсечение разделов.

**Альтернативные СУБД.**

- **Oracle** — не отражается в стоимости, есть прямое подтверждение. Механизм: `PART JOIN FILTER CREATE :BF0000`, `PARTITION HASH JOIN-FILTER` с `:BF0000` в Pstart/Pstop (11gR1). [Hemant Chitale](https://hemantoracledba.blogspot.com/2011/03/cardinality-estimates-in-dynamic.html): *«in Dynamic Partition Pruning, Oracle cannot really present the expected Cardinality from the Partition search... the Optimizer computes expected Cardinality from Table level, not Partition level statistics.»* Демонстрация: четыре запроса с фактическими результатами 39, 0, 0, 0 дают **байт-идентичные планы**, plan hash 4059568812, и `PARTITION RANGE JOIN-FILTER | 1599K` — вся фактовая таблица. Нулевой кредит за отсечение. Показательна и ремарка Antognini о том, почему Oracle применяет это свободно: *«the overhead of using the bloom filter is so small, that even if no pruning occurs, the overhead associated with its use is negligible»*.
- **Greenplum / Orca — единственный, где селектор партиций реально в memo.** `CPhysicalPartitionSelector` — полноценный физический оператор, реализуемый `CXformImplementPartitionSelector`, с записью в `CCostModelGPDB::FUnary`. Оговорка прямо в том же файле: *«Note that the cost of the partition selector is ignored here. It may be higher than that of the complete tree»*. Документация подтверждает границу знания: *«the number of partitions that are scanned will be known only during query execution. The partitions selected are not shown in the EXPLAIN output»*.
- **Spark** — DPP с фиксированным `fallbackFilterRatio = 0.5`.
- **SQL Server** — join-driven pruning отсутствует; статический partition elimination в стоимости отражён, динамический — обычная догадка селективности. Работающий аналог — batch-mode segment elimination в columnstore.

---

# Группа B. Не хватает знания о потребителе сверху

---

## 8. Index-Only Scan: поздно приезжающие атрибуты

**Теория.** Covering index / late-arriving column requirements.

**Hackers.** Отдельного треда про «PlaceHolderVar ломает IOS» **нет** — поиск по архиву не даёт ни одного. Это открытая целина. Что есть:

- [Том Лейн о projection pushdown в index AM](https://www.postgresql.org/message-id/387035.1695145596@sss.pgh.pa.us), 2023, обсуждение умерло после трёх сообщений — лучшая цитата для нашего тезиса:
  > «The index has to also provide x ... or else the planner fails to detect that an IOS is applicable... This wouldn't be hard to fix exactly; the problem is to fix it without spending exponential amounts of planning time in check_index_only.»
  > «Costing doesn't account for the fact that we've avoided runtime computation of f(), thus the IOS plan may not be preferred over other plan shapes... Again, this is pretty closely tied to the fact that **we don't recognize until very late in the game** that we can get f(x) from the index.»
- [Дэвид Роули, 2024](https://www.postgresql.org/message-id/CAApHDvrULZwq1A+86hSJfX0h1X+qX9J+w-U=hOFmuVQMBd4pVA@mail.gmail.com): *«when creating the index paths, the Index Only Scan is always assumed to be better than Index Scan whenever it's possible to use IOS. There's no opportunity that if an IOS is possible that you'll get an Index Scan instead.»*
- [Extracting only the columns needed for a query](https://www.postgresql.org/message-id/CAAKRu_YxyYOCCO2e83UmHb51sky1hXgeRzQw-PoqT1iHj2ZKVg@mail.gmail.com), 2019–2020, stalled. Мелани Плагеман: *«attr_needed does not have all of the attributes needed set. Attributes are only added in add_vars_to_targetlist() and this is only called for certain query classes.»* Том в том же треде: *«that line of thought confirms that we want to do this at the end of planning when we know the shape of the plan tree»* — дословная формулировка нашей идеи, высказанная в 2019 году.
- Конкретная цена возражения Тома: в [профиле Дэвида Гайера](https://www.postgresql.org/message-id/21803d4b-d5e2-58a5-d920-97d285bf571b@gmail.com) `check_index_only` занимает 15.77% `make_one_rel`.

**Как сейчас.** `check_index_only()` вызывается при построении индексных путей и требует, чтобы индекс покрывал все Var'ы, которые `pull_varattnos()` находит в `baserestrictinfo` и `reltarget`. `attr_needed` неполон по построению. Атрибуты, приезжающие из PHV или lateral, могут не учитываться.

**Как будет.** Второй проход обходит готовый план и собирает для каждой базовой релации **фактический** набор атрибутов, потребляемых где угодно выше. Второе планирование вызывает `check_index_only()` один раз на точном множестве — что снимает и корректностную проблему, и возражение про экспоненциальное время планирования: мы не перебираем подмножества, мы знаем ответ.

**Что собирает проход.**

| поле | содержимое |
|---|---|
| `kind` | `GAP_ATTR_SET` |
| `rel` | relids базовой релации |
| собирается | объединение `pull_varattnos()` по всем `targetlist`, `qual`, `joinqual`, `hashclauses`, `mergeclauses`, `PartitionPruneInfo.exprs` всех узлов выше; плюс атрибуты, приходящие из развёрнутых PHV |
| вердикт | точный `Bitmapset` атрибутов вместо консервативной аппроксимации |

Побочный выигрыш: это же множество нужно разделу 9.

**Альтернативные СУБД.** В Orca требуемые выходные колонки — **required property**, передаваемое вниз вместе с optimization request наравне с sort order и distribution: *«Required properties also include output columns, rewindability, common table expressions and data partitioning»*. То есть в top-down оптимизаторе «какие колонки мне в итоге понадобятся» известно по построению — это часть запроса к группе. Проблема late-arriving column requirements специфична для bottom-up перебора. SQL Server решает выбор «seek + key lookup против clustered index scan» чисто по стоимости, и типичный режим отказа — переоценка стоимости lookup'а. DuckDB держит `COLUMN_LIFETIME`, `UNUSED_COLUMNS` и `LATE_MATERIALIZATION` **после** `JOIN_ORDER` в списке проходов, то есть решает это вторым проходом по готовому плану — ровно наша схема.

---

## 9. `use_physical_tlist` и ширина кортежа

**Теория.** Проекция как физическое решение: узкий tlist экономит deform/detoast и память сортировки, широкий экономит на проекции.

**Hackers.**
- [WIP: Upper planner pathification](https://www.postgresql.org/message-id/27296.1457114516@sss.pgh.pa.us), Том, PG9.6 — удалил `disuse_physical_tlist` и ввёл `CP_LABEL_TLIST`/`CP_SMALL_TLIST`/`CP_EXACT_TLIST`: *«use_physical_tlist now always makes the right decision to start with, and disuse_physical_tlist is gone entirely»*. Обратите внимание на посыл: лечение было в том, чтобы принять решение правильно сразу, а не откатывать позже.
- [Question about use_physical_tlist() which is applied on Scan path](https://www.postgresql.org/message-id/CAPt2h2YE2Cwp5aZG+uODu2y2ZJLZsWBVBm1WAo2+8xPhctJaxw@mail.gmail.com), 2023, stalled. Альваро: решение должен принимать table AM через `path->parent->amflags`, но *«Right now, we don't have any columnar stores, so there's no way to verify an implementation»*.

**Как сейчас.** `use_physical_tlist()` в `createplan.c` решает по трём категориям (`CP_*`), исходя из того, что известно про непосредственного потребителя. Насколько широкий кортеж доживёт до Sort/Hash на три уровня выше — неизвестно.

**Как будет.** Пользуемся множеством из раздела 8. Второй проход знает, где по дереву стоят материализующие узлы (Sort, Hash, Material, Memoize) и какой набор атрибутов до них доживает. Решение «физический tlist или узкий» принимается на этом знании, и, что важнее, **попадает в костинг** через ширину кортежа в `cost_sort`/`cost_agg`.

**Что собирает проход.** `kind = GAP_ATTR_SET` (тот же, что в разделе 8) + позиции материализующих узлов на пути от скана до корня.

**Альтернативные СУБД.** См. раздел 8. Отдельно отмечу измерение из того же треда: на TPC-H SF1 на REL_15 физический tlist не дал измеримого выигрыша — то есть перед тем, как тратить на это аннотацию, стоит измерить, есть ли что выигрывать.

---

## 10. Incremental Sort против полной сортировки при известной границе

**Теория.** Выбор между блокирующим и стримящим оператором зависит от того, сколько результата реально потребят.

**Hackers.**
- [cost_incremental_sort() and limit_tuples](https://www.postgresql.org/message-id/1619.1701675997@antos), Антонин Гоуска, 2023 — **ноль ответов**: *«I think that cost_incremental_sort() does not account for the limit_tuples argument properly.»*
- [Incremental Sort Cost Estimation Instability](https://www.postgresql.org/message-id/ba0edc53-4b1f-4c67-92d1-29aeddb36a18@gmail.com), 2024–2025, не решено: план переключается между Sort и Incremental Sort от перестановки сторон равенства в WHERE, потому что `estimate_num_groups()` берёт того члена EquivalenceClass, который оказался первым. Роули: *«that'll mean it'll just choose whichever expression was used when the PathKey was first created... both PathKey's are first created for the GROUP BY clause in standard_qp_callback()»* — учебниковый «заморожено в момент создания».
- Исходный тред Коротькова, 2017: уже там отмечена цена `MIN_GROUP_SIZE` при LIMIT и предложено то, чего до сих пор нет: *«If we see that there would be only few groups, we should choose plain sort instead of incremental sort.»*
- [Why don't we consider explicit Incremental Sort?](https://www.postgresql.org/message-id/40d81bb0-a7c2-4ab8-a109-52a4c9df4839@vondra.me) — Вондра: *«create_mergejoin_plan creates these Sort plans explicitly - it's not "pathified" so it doesn't go through the usual cost comparison etc.»*

**Как будет.** Аннотация `GAP_ROW_BOUND` от раздела 3 переиспользуется: узнав твёрдую границу, второй проход даёт `cost_incremental_sort()` честный `limit_tuples`, и выбор между Sort и Incremental Sort перестаёт быть лотереей. Отдельно `GAP_CONSUMER_ORDER` фиксирует, какой именно член EC реально используется потребителем — что лечит нестабильность.

**Что собирает проход.** `GAP_ROW_BOUND` (граница) + `GAP_CONSUMER_ORDER` (фактически используемое выражение сортировки из готового плана, а не первое попавшееся из EC).

**Альтернативные СУБД.** Прямого аналога Incremental Sort мало у кого; но выбор «bounded heap против полной сортировки» есть везде и везде решается **по факту**, а не по оценке. MySQL WL#1393: *«The current cost analysis in the optimizer does not calculate the cost of a filesort. Rather than extending the current cost model, we propose to let **filesort make a local decision** whether to use PQ or not»* — решение исполнителя. DuckDB `topn_optimizer.cpp` — эвристика с магическим числом: *«if the limit is > 0.7% of the child cardinality, sorting the whole table is faster»* плюс `constant_limit > 5000`.

---

## 11. LIMIT/ORDER BY в FDW после удаления одноузлового Append

**Hackers.** [FDW does not push down LIMIT & ORDER BY with sharding](https://www.postgresql.org/message-id/CAKJS1f9ZY_J1-Ouyi1STAzRUGf5Jo8tbhcD93jkGqanDVm7xfQ@mail.gmail.com), 2019. Append/MergeAppend ещё в плане, когда планируется LIMIT-upperrel, поэтому LIMIT никогда не предлагается единственной выжившей партиции; `setrefs.c` (коммит 8edd0e79) потом убирает одноузловой Append, но *«doesn't reassess whether the LIMIT on top (if any) should be applied to the partition directly»*. Предложенный Роули обходной путь — чтобы более ранний код спекулировал о том, что позже сделает `setrefs.c`.

Родственный тред: [Removing [Merge]Append nodes which contain a single subpath](https://www.postgresql.org/message-id/CA+Tgmoar4CFZ1x9Ozg5PafF9ZMhvs9EJmMoTe75TA+em8iP2Rg@mail.gmail.com) — одно-дочерний Append нужен **во время планирования** как буфер нумерации Var'ов, поэтому доживает до `setrefs.c`. Там же отвергнутая альтернатива Роули «ProxyPath», которая Хаасу понравилась.

**Как будет.** Классический случай для второго прохода: первый проход оставляет аннотацию «здесь Append, который может схлопнуться», второй проход смотрит, схлопнулся ли он в реальности, и если да — второе планирование предлагает LIMIT+ORDER BY прямо FDW-релации. Спекулировать не нужно — уже видно.

**Что собирает проход.** `kind = GAP_ROW_BOUND`; собирается список узлов, выброшенных `setrefs.c` (эта информация теперь записывается в `PlannedStmt` благодаря работе над pg_plan_advice — раздел 0.3).

**Альтернативные СУБД.** Прямых аналогов не искал; ближайшее по смыслу — DB2 LUW, который явно рекомендует комбинировать `OPTIMIZE FOR n` и `FETCH FIRST n`, потому что *«The Db2 data server does not automatically assume OPTIMIZE FOR n ROWS when FETCH FIRST n ROWS ONLY is specified»* — то есть там эту связь тоже не выводят автоматически, а перекладывают на пользователя.

---

## 12. Параметризованные пути: честное число loops

**Теория.** Стоимость параметризованного плана — функция от числа исполнений, то есть от контекста, а не от пути.

**Hackers.** [Cost estimates for parameterized paths](https://www.postgresql.org/message-id/14624.1283463072@sss.pgh.pa.us), Том Лейн, 2010 — прародитель всей темы:

> «a parameterized path can't really be assigned a fixed cost in the same way that a normal path can»

`cost_index()` нужно число loops, то есть мощность внешней релации, которой ещё не существует. Планировщик уже жульничал: костил inner indexscan один раз, по первой попавшейся внешней релации, и кэшировал. Предложение Тома — интервалы best/worst-case с перекостингом в момент join'а — он же сам и забраковал по времени планирования.

**Как будет.** Аннотация `GAP_LOOP_COUNT`: путь записывает, при каком `loop_count` он костился. Второй проход читает из готового плана фактическую оценку outer-мощности (`outerPlan->plan_rows` у NestLoop, с учётом фильтров на самом NestLoop) и возвращает её вниз. Второе планирование костит параметризованные пути на настоящем числе итераций.

Это, вероятно, самая простая из всех аннотаций и самая дешёвая в реализации.

**Что собирает проход.** `kind = GAP_LOOP_COUNT`, `rel` — relids inner'а, payload — `{assumed_loop_count}`. Собирается `outerPlan(nl)->plan_rows` умноженная на число rescan'ов выше. Вердикт — фактический `loop_count`.

**Альтернативные СУБД.** Прямой ответ на вопрос «есть ли движок, который костит inner **до** того, как узнал outer»: **нет ни одного из проверенных**. PostgreSQL здесь уникален — это следствие восходящего перебора путей без фиксированного префикса.

| движок | когда известна outer-мощность | механизм |
|---|---|---|
| Oracle | до | Перебор порядков join: *«the optimizer constructs a matrix of join orders and methods»*. Формула (Гайст, 11.2): `Cost(outer) + Cost(inner) × Card(outer)` |
| DB2 | до | Входные аргументы NLJOIN — сами функции outer-мощности: `MAXPAGES`/`ISCANMAX` — *«expected to be read from disk for all rows of the outer join»*; `GROUPS` = *«Nb of times the operator will repeat»* |
| MySQL/MariaDB | до | Жадное расширение префикса; префикс `1..N` зафиксирован при костинге таблицы `N+1` |
| SQL Server | до | Генерация spool-альтернатив явно зависит от *«the estimated number of rows on the outer input»* и *«the estimated number of duplicate join key values on the outer input»* |
| CockroachDB | до | Cascades: lookup join костится против оценённой мощности уже покостированной входной группы |

Цена, которую платят за «префикс сначала», — прунинг: хороший префикс может быть отсечён по стоимости до того, как стратегия вообще рассмотрена. MySQL Bug #42620 item 4: *«we never consider ("it","ot") because the partial plan "it" is considered already too costly (reaches prune_by_cost)»*. Bug #120793 (Verified, 9.7.1): при трёх таблицах прунинг даёт 13.3 мс против 0.33 мс при форсированном порядке.

У Oracle же есть реальный дефект недооценки ровно в этой формуле: fix-control **bug 3120429** «account for join key sparsity in computing NL index access cost» — если у inner меньше NDV в join-колонке, чем у outer, Oracle масштабирует per-iteration стоимость на отношение NDV; разобранный Гайстом случай — истинная стоимость ≈1 003 000, показано 52 609, потому что фильтр на outer сделал разреженный join плотным.

---

## 13. AlternativeSubplan и число исполнений подплана

**Теория.** Позднее связывание: отложить выбор до момента, когда известен контекст.

**Hackers.**
- [Get rid of runtime handling of AlternativeSubPlan?](https://www.postgresql.org/message-id/1992952.1592785225@sss.pgh.pa.us), Том, 2020 — обратная миграция, и она поучительна. AlternativeSubPlan был экспериментом позднего связывания в исполнителе (выбор hashed/non-hashed в `ExecInitNode`); двенадцать лет спустя Том называет его *«a failed experiment»* и переносит разрешение в `setrefs.c`. Обоснование — нам прямо в тему: `ExecInitAlternativeSubPlan` использовал универсальный `parent->plan->plan_rows` как оценку числа исполнений, верную только для tlist-подпланов, тогда как `setrefs.c` *«knows which subexpression it's working on at any point»*. Решено в PG14.
- [Планировщик делает плохой выбор в alternative subplan](https://www.postgresql.org/message-id/CAApHDvpbJHwMZ1U-nzU0kBxu0kwMpBvyL+AFWvFAmurypSo1SQ@mail.gmail.com), Роули, 2020 — отложенное решение всё равно ошибается: внутренний подзапрос планируется с неизвестным параметром, `var_eq_non_const()` видит одно значение и оценивает 10000 строк, `cost_subplan()` делит run cost на эту оценку, побеждает seqscan-на-каждую-строку: 7.4 с против 3.7 мс. Роули не может решить, *«which part of the planner to blame»*, и «no great ideas on how to fix without fudging the costs».

**Как будет.** `setrefs.c` уже знает, в каком выражении он находится. Пристрелочный проход добавляет к этому знание о **фактической** мощности узла, на котором выражение будет вычисляться (после всех фильтров), и о числе rescan'ов этого узла. Второе планирование костит подплан на этом числе.

Стоит отметить траекторию: AlternativeSubplan — это попытка решить нашу проблему исполнителем, признанная неудачной, с переносом решения на самый поздний момент планирования. Пристрелочный проход — следующий шаг по той же траектории: не «самый поздний момент», а «после того, как план построен».

**Что собирает проход.** `kind = GAP_LOOP_COUNT`; собирается `plan_rows` узла-носителя выражения после фильтров плюс число rescan'ов.

**Альтернативные СУБД.** Аналога позднего связывания подпланов в чистом виде нет; ближайшее по духу — SQL Server Interleaved Execution (раздел 20) и Batch Mode Adaptive Join, где решение откладывается до рантайма с заранее вычисленной точкой перегиба.

---

## 14. Поздняя материализация

**Теория.** Abadi, Myers, DeWitt, Madden, «Materialization Strategies in a Column-Oriented DBMS», ICDE 2007. Shrinivas et al., «Materialization Strategies in the Vertica Analytic Database: Lessons Learned», ICDE 2013 — вывод авторов: LM выигрывает у EM везде, кроме join со spill; **EM + SIP не хуже обоих**, до 72% на TPC-H.

**Hackers.** Прямого треда нет — у PostgreSQL нет оператора. Косвенно относится всё из раздела 8.

**Как будет (спекулятивно).** Если второй проход знает, что от широкой таблицы наверх доживают 10 строк из миллиона, открывается вариант «просканировать TID/ключи, применить фильтры, добрать широкие колонки только для выживших». Сейчас это невозможно хотя бы потому, что решение о том, какие колонки тащить, принимается в момент, когда неизвестно, сколько строк выживет.

Помечаю раздел как наименее зрелый: это не «включить существующую оптимизацию», а «построить новый оператор». Включаю для полноты.

**Альтернативные СУБД.** Vertica — не костится, решение структурное плюс рантайм-отключение SIP при `N_out/N_in > 0.9`. SQL Server — key lookup костится штатно (`EstimateRebinds`/`EstimateRewinds`). Oracle `TABLE ACCESS BY INDEX ROWID BATCHED` — это **не** поздняя материализация, а упорядочивание I/O; настоящий аналог у Oracle — bitmap star transformation (`BITMAP AND` над rowid-множествами до обращения к таблице). DuckDB — есть проход `OptimizerType::LATE_MATERIALIZATION` сразу после `TOP_N`. CockroachDB — index join костится штатно, с оплатой только ещё не выбранных колонок.

---

# Группа C. Не хватает глобального знания о выражениях

---

## 15. Совместная селективность поперёк границы join'а

**Теория.** Условная вероятность вместо перемножения независимых селективностей. Это, на мой взгляд, потенциально крупнее всего остального в документе вместе взятого — потому что все предыдущие разделы дают планировщику *возможность* построить лучший путь, а этот даёт *способность его выбрать*.

**Hackers.** [using extended statistics to improve join estimates](https://www.postgresql.org/message-id/c8c0ff31-3a8a-7562-bbd3-78b2ec65f16c@enterprisedb.com), Вондра, 2021 → последнее сообщение 2025-06. Ничего не закоммичено. Две идеи в корневом сообщении: (1) матчить MCV-списки обеих сторон по аналогии с `eqjoinsel_inner`; (2) использовать baserel-ограничения как **условия** на MCV-списки, чтобы коррелированные `t1.c < 25 AND t2.d > 75` оценивались как ~0, а не 60241.

Ограничение попарности, сформулированное Вондрой в 2021-10:
> «the estimates are calculated for pairs of relations... we'll estimate the first join (t1,t2) just fine, but then the second join actually combines (t1,t2,t3). What the patch currently does is it splits it into (t1,t2) and (t2,t3) and estimates those. I wonder if this should actually combine all three MCVs at once... But I haven't done that yet.»

Замечание Лепихова в том же треде (2024-09): *«the most harmful case I see most reports about is parameterised JOIN on multiple anded clauses... current patch doesn't resolve this issue»*. Последнее сообщение (Илья Евдокимов, 2025-06) — патч неверно применяет расширенную статистику к OR-клаузам.

Связанное: [Columns correlation and adaptive query optimization](https://www.postgresql.org/message-id/1220e592-d50d-c015-890c-67c2e8a4e001@postgrespro.ru), Книжник, stalled.

**Как будет.** Пристрелочный проход здесь работает иначе, чем во всех предыдущих разделах: он не подтверждает гипотезу, а **выясняет, какие клаузы в итоге оказались вместе на одном узле**. Зная это, второе планирование может (а) применить расширенную статистику к фактической группе клауз, а не к тому подмножеству, что было видно снизу; (б) при многотабличном join'е знать полный набор релаций, участвующих в оценке, и не разбивать на пары.

Связь с разделом 6 прямая: возражение Вондры «планировщик и не выбрал бы лучший путь, потому что не умеет его костить» снимается именно здесь.

**Что собирает проход.** `kind = GAP_SIBLING_STATS`; payload — relids. Собирается: фактическая группировка клауз по узлам плана; для каждого join-узла — полный набор релаций под ним и полный набор клауз, применённых к их комбинации.

**Альтернативные СУБД.** Тема статистики, а не архитектуры планировщика, поэтому детально не разбирал. Отмечу одно: Oracle делает транзитивное замыкание только для равенства с константой (раздел 16), и при этом добавление логически избыточного предиката вручную роняет оценку в 100 раз — Льюис называет это ошибкой дизайна: *«the predicate is redundant, and should not affect the selectivity»*. То есть даже в зрелых движках «какие предикаты оказались вместе» напрямую влияет на оценку и напрямую же её портит.

---

## 16. Predicate move-around: вывод предикатов через join за пределами равенства

**Теория.**
- Levy, Mumick, Sagiv, «Query Optimization by Predicate Move-Around», VLDB 1994, [PDF](https://www.vldb.org/conf/1994/P096.PDF).
- Bancilhon, Maier, Sagiv, Ullman, «Magic Sets and Other Strange Ways to Implement Logic Programs», PODS 1986.
- Beeri, Ramakrishnan, «On the Power of Magic», PODS 1987.
- Seshadri, Hellerstein, Pirahesh, Leung, Ramakrishnan, Srivastava, Stuckey, Sudarshan, «Cost-Based Optimization for Magic: Algebra and Implementation», SIGMOD 1996.
- Mumick, Pirahesh, «Implementation of magic-sets in a relational database system», SIGMOD 1994 — первая реализация в реляционной СУБД, и это **IBM Starburst/DB2**, а не Oracle.
- Современное обобщение: Yang, Zhao, Yu, Koutris, «Predicate Transfer: Efficient Pre-Filtering on Multi-Join Queries», CIDR 2024 — обобщение bloom-join на несколько хопов по схеме Яннакакиса. Авторы честны: *«we use a simple heuristic that points an edge from a smaller table to a bigger table»*, *«The predicate transfer graph is determined at planning time and remains fixed during runtime»*, *«These heuristics are largely intuition-based and a more thorough theoretical analysis is left for future work»*.

**Hackers.** Треда нет. Целина.

**Пример.**

```sql
SELECT * FROM a JOIN b ON a.d = b.d WHERE a.d BETWEEN '2026-01-01' AND '2026-01-31';
-- хочется вывести b.d BETWEEN ... — PostgreSQL умеет это только для равенства (EquivalenceClass)
```

**Как сейчас.** EquivalenceClass протаскивает равенства. Диапазонные и прочие предикаты через границу join'а не выводятся.

**Как будет.** Второй проход знает полный набор клауз, применённых к каждой релации в итоговом плане. Из этого можно вывести кандидатов: для каждого EC найти неравенственные предикаты на одном члене и предложить их другим членам. Второе планирование строит с ними индексные пути и уточняет селективности.

Важно: вывод должен быть логически корректным (предикат — следствие, а не догадка), и дублирование предиката не должно ломать селективность (см. дефект Oracle в разделе 15). В DB2 это решено так: *«if Db2 generates a redundant predicate for improved access path selection, Db2 can ignore that predicate at execution»*.

**Что собирает проход.** `kind = GAP_FINAL_QUALSET` + `GAP_SIBLING_STATS`; собирается полный набор клауз на каждую релацию и состав EC после всех трансформаций.

**Альтернативные СУБД.**

- **Oracle — гипотеза «только простая транзитивность по равенству» подтверждается.** Льюис: *«A person can see that the first pair of predicates allows us to infer that t1.col1 = t3.col3... The optimizer is coded only to recognize the second inference»*, и *«Transitive closure is relevant only if there are some constants in the mixture»*. То есть из `a=b AND b=c` (два join-предиката) вывод `a=c` **не делается** — только из `a=b AND b=const`. Демо на 12.2: отсутствие вывода схлопывает план в `MERGE JOIN CARTESIAN` на 4M строк (8.81 с) вместо hash join (0.81 с). «Константа» включает bind-переменные и детерминированные функции; работает и от check-констрейнтов.
- **Oracle MAGIC SET — гипотеза НЕ подтверждается.** Глава «Query Transformations» SQL Tuning Guide 21c прочитана целиком: слово «magic» встречается ноль раз. Полный документированный список: OR Expansion, View Merging, Predicate Pushing, Subquery Unnesting, Query Rewrite with MV, Star Transformation, In-Memory Aggregation, Cursor-Duration Temporary Tables, Table Expansion, Join Factorization. Magic sets в реляционных СУБД — это IBM.
- **DB2 — есть и документирован.** LUW: *«During the query rewrite stage, additional local predicates are derived on the basis of the transitivity that is implied by equality predicates.»* z/OS точнее: *«When a predicate meets the transitive closure conditions, Db2 generates a new predicate, whether or not it already exists in the WHERE clause.»* Генерация не гейтится стоимостью — она **кормит** cost-based оптимизатор.
- **SQL Server** — из фазы simplification документированы constant folding, **domain simplification** (*«enables the optimizer to reason about the range of valid values a column or expression can take»* — три перекрывающихся BETWEEN схлопываются в `ProductID = 400`), predicate push-down, join simplification, contradiction detection. Есть узкое правило move-around `SelOnSeqPrj` (протаскивание безопасных внешних предикатов через оконные функции), но только при сравнении с литералом. Общего транзитивного замыкания за пределами равенства подтвердить не удалось.
- **DuckDB** — `STATISTICS_PROPAGATION` (plan-time, после `JOIN_ORDER`) выводит фильтр на `t2` из min/max `t1` через equality-join. По сути транзитивное замыкание на интервалах, сделанное вторым проходом по готовому плану.

---

## 17. Размещение дорогих предикатов по стоимости

**Теория.** Hellerstein & Stonebraker, «Predicate Migration: Optimizing Queries with Expensive Predicates», SIGMOD 1993, [PDF](https://dsf.berkeley.edu/papers/sigmod93-predmig.pdf). Заявленный результат — *«orders of magnitude faster than plans generated by a traditional query optimizer»*. Реализовано, что иронично, в модифицированном оптимизаторе POSTGRES.

**Hackers.** Треда про перенос qual'ов между узлами нет. Что есть:
- [Improving RLS planning](https://www.postgresql.org/message-id/8185.1477432701@sss.pgh.pa.us), Том, PG10 — дал `order_qual_clauses()` его нынешнюю форму: *«In order_qual_clauses, sort first by security_level and second by cost.»*
- [Question about partial index WHERE clause predicate ordering](https://www.postgresql.org/message-id/1631331.1766808911@sss.pgh.pa.us), декабрь 2025 — самая свежая оценка Тома: *«order_qual_clauses is really quite crude when dealing with simple expressions. We don't have accurate costing data for most functions/operators --- they're all just labeled with procost 1 --- so that the "cost-based ordering" reduces to just counting the functions. ... order_qual_clauses exists mostly to ensure that subplans get pushed to the end.»*
- [BUG #19059](https://www.postgresql.org/message-id/2510592.1758403162@sss.pgh.pa.us), сентябрь 2025, won't fix: *«The whole exercise is pretty questionable really, considering how weak our cost model for expressions is. We could easily end up pessimizing a clause that the user had put into carefully-selected order.»*
- Живой тред 2026: «[RFC PATCH] Cost-based delayed projection for ORDER BY … LIMIT», ChenHui Mo. Ответ Тома с прецедентом, который нам стоит держать в голове: *«See for example the sad fate of commit db0d67db2, eventually reverted at f4c7c410e. ... this proposal seems completely dependent on expression costs, so I think it's likely to be mostly garbage-in-garbage-out.»*

**Как сейчас.** Размещение qual'а решается синтаксически (`distribute_qual_to_rels()` — протолкнуть как можно ниже, если законно). Cost-based только порядок **внутри** узла.

**Как будет.** Второй проход знает фактическую мощность каждого узла. Для дорогого предиката можно посчитать `cost × rows` в текущей позиции и в альтернативных законных позициях и выбрать минимум.

**Честная оценка: этот раздел — самый слабый в документе.** Возражение Тома («procost у всех 1, cost-based ordering вырождается в подсчёт функций») никуда не девается: механизм даст возможность переносить предикат, но качество решения упрётся в отсутствие данных о стоимости выражений. Реализовывать это раньше, чем появится что-то вроде реальных `procost`, бессмысленно. Включаю для полноты и чтобы зафиксировать, что это тупик по другой причине, а не по нашей.

**Альтернативные СУБД.** Переноса дорогого предиката **между** операторами не подтверждено ни для одного продакшн-движка. Всё, что есть, — упорядочивание внутри одного узла.
- Oracle: `ORDERED_PREDICATES` (deprecated). Поведение без хинта: сначала предикаты без user-defined функций в порядке WHERE; затем предикаты с UDF, **имеющими заданную пользователем стоимость, в порядке возрастания стоимости**; затем подзапросы. Почему хинт умер — объяснение Льюиса прямо про нашу тему: *«what would the hint mean if Oracle did some predicate transformation that introduced or eliminated some predicates, what would it mean if Oracle unnested a subquery, what would it mean if a rewrite turned what you thought was going to be an access predicate into a filter predicate?»*
- SQL Server: гарантий нет и это официальная позиция — *«A typical programmer may expect that the predicates are always evaluated in the order that they are specified, but this is not true»*, и *«Query Optimizer has no idea if the predicate evaluation would cause a runtime error»*. Аналога `ORDERED_PREDICATES` нет. Есть патент MS «Delaying evaluation of expensive expressions in a query» (US 7877379) — тема прорабатывалась, реализация не подтверждена.

---

## 18. Eager aggregation: выбор уровня проталкивания

**Теория.** Chaudhuri & Shim, «Including Group-By in Query Optimization», VLDB 1994; Yan & Larson, «Eager Aggregation and Lazy Aggregation», VLDB 1995.

**Hackers. Внимание: закоммичено.** [Eager aggregation, take 3](https://www.postgresql.org/message-id/CAMbWs48jzLrPt1J_00ZcPZXWUQKawQOFE8ROc-ADiYqsqrpBNw@mail.gmail.com), Ричард Гуо → коммит `8e1185910` (октябрь 2025, PG19), GUC `enable_eager_aggregate`. Предшественники: Антонин Гоуска, 2017 и 2022.

**И текст коммита — сильнейшая формулировка нашего тезиса во всём корпусе:**

> «In the current planner architecture, the separation between the scan/join planning phase and the post-scan/join phase means that aggregation steps are not visible when constructing the join tree, limiting the planner's ability to exploit aggregation-aware optimizations.»

Гуо называет комбинаторный взрыв причиной провала патча Гоуски: *«when we generate partially aggregated paths, each path of the input relation is considered as an input path for the grouped paths. As a result, the number of grouped paths we generate increases exponentially»*. Принятые ограничения: входом частичной агрегации служит только cheapest-total или подходяще отсортированный путь; join двух сгруппированных релаций **не поддерживается**; частичная агрегация проталкивается **только на самый нижний допустимый уровень**, где даёт значимое сокращение строк.

И [Роберт Хаас, сентябрь 2025](https://www.postgresql.org/message-id/CA+TgmoZh8aAadYx-j=Ahq1XRj67RDJ_5H0bUQx6rtB8=_wNkQg@mail.gmail.com) — предлагает ровно двухпроходную схему, ровно по нашей причине:

> «you could equally well finish planning everything up to the scan/join target first and then go back and add grouped_rels to relations where it seems worthwhile... I think it might provide a better structure for the future, **because you would then have a lot more information with which to judge where to do aggregation.** For instance, you could looked at the row counts of any number of those ungrouped-rels before deciding where to put the partial aggregation.»

Рекуррентное сомнение — качество оценок. Хаас, 2024, о регрессиях на TPC-DS: *«My fear is that we just don't have good enough estimates to make good decisions.»*

**Как будет.** Именно то, что описал Хаас. Первый проход планирует без частичной агрегации (или с текущей консервативной эвристикой «на самый нижний уровень») и оставляет аннотации на кандидатных уровнях. Второй проход даёт фактические `plan_rows` каждого уровня. Второе планирование ставит частичную агрегацию туда, где она реально сокращает строки, — вместо правила «всегда как можно ниже». Комбинаторный взрыв не возникает: мы не перебираем уровни, мы смотрим на числа.

**Что собирает проход.** `kind = GAP_ROW_BOUND` (в смысле фактической мощности, не границы); собирается `plan_rows` каждого join-узла кандидатной цепочки плюс оценка NDV по group-by ключам на каждом уровне.

**Альтернативные СУБД.** Здесь самый поучительный набор ответов во всём документе.

- **Snowflake — Aggregation Placement, и они решили НЕ знать предикаты сверху.** Критика классического подхода дословно: *«the optimizer's cost model is based on compiler statistics. Compiler statistics could be missing, stale, too coarse, expensive to maintain, and often deviate from the actual statistics in non-trivial cases.»* Правила применяются **в отдельной фазе трансформации плана после того, как определён порядок join'ов** — буквально второй проход по готовому плану. Агрегат **всегда** проталкивается на максимальную глубину: *«If an aggregation can be pushed below multiple joins, we always push to the deepest possible position in the join tree. This is different from the traditional approach... where the optimizer would consider alternatives and pick one, which execution is stuck with.»* Выбор делается **в рантайме, на уровне отдельного агрегата**: каждый child-aggregate смотрит на runtime-статистику своего pipeline, считает стоимость «с собой» против «без себя» и сам себя отключает. Применяется примерно к каждому пятому production-запросу; раскатка — 3 месяца, полный цикл ~полгода. И цифра цены некалиброванного решения: при первом прогоне TPC-DS 10 TB *«more than 10 queries had noticeable degradation»* при выигрышах до 3× на других.
- **Oracle — Group-By Placement, cost-based через грубую силу.** Хинты `PLACE_GROUP_BY`/`NO_PLACE_GROUP_BY`. Определение из [VLDB 2024](https://vldb.org/pvldb/vol17/p4200-pasupuleti.pdf): *«an array of early grouping query transformation strategies that involve pre-aggregating intermediate results by an eager group-by operation... A final group-by operation, after the join operation, computes the final aggregate values.»* GBP проходит через CBQT (cost-based query transformation): генерируется candidate query, он **полностью оптимизируется**, стоимости сравниваются. То есть Oracle не выводит недостающую информацию — он переоптимизирует каждое состояние целиком. Это прямой архитектурный прецедент «оптимизировать N раз внутри одной компиляции», и платят за него временем парса — но, в отличие от adaptive statistics, **CBQT включён по умолчанию и никогда не выключался** (см. 20.5).
- **SQL Server** — правило `LocalAggBelowJoin`. Выбор «partial или одноуровневая агрегация» зависит от числа уникальных групп и их размера: *«if the optimizer anticipates that a query will generate few large groups, it will use partial aggregation... many small groups — single level aggregation»*. Рантайм-подстраховка, важная для нашего дизайна: partial hash aggregate просит фиксированный минимальный грант и **никогда не спиллит** — если память кончилась, он перестаёт агрегировать и пропускает строки насквозь. Неудачная догадка деградирует до no-op, а не до спилла.
- **Presto** — `PushAggregationThroughOuterJoin`. **Doris** — eager aggregation с greedy join reorder.

Вывод для нас: **Snowflake и Oracle пришли к двум противоположным решениям одной и той же проблемы**, и обе работают. Oracle — полная переоптимизация на каждое состояние (дорого в парсе). Snowflake — второй проход по готовому плану плюс рантайм-самоотключение (дёшево, но не оптимально). Наш пристрелочный проход — между ними: второй проход по готовому плану плюс **одна** переоптимизация.

---

## 19. Join removal и self-join elimination на уровне пути

**Hackers.**
- [Removing unneeded self joins](https://www.postgresql.org/message-id/CAKU4AWrwZMAL=uaFUDMf4WGOVkEL3ONbatqju9nSXTUucpp_pw@mail.gmail.com) — история: коммит `d3d55ce5713` в цикле v17, **реверт** `d1d286d83c0` (Коротьков, май 2024), рекоммит `fc069a3a6` (февраль 2025), **вышло в PG18**. Причина реверта — [Том Лейн](https://www.postgresql.org/message-id/2422119.1714691974@sss.pgh.pa.us): *«you have already committed around twenty separate fixes for the original SJE patch, and now here you come with several more; so it doesn't seem like the defect rate has slowed materially»*.
- [UniqueKey](https://www.postgresql.org/message-id/CAKU4AWrwZMAL=uaFUDMf4WGOVkEL3ONbatqju9nSXTUucpp_pw@mail.gmail.com), Энди Фань, 2020–2021, stalled. Он сам формулирует недостающее: чтобы поймать больше join removal, надо проверять *«just before we join 2 relations»*, — и отказывается это делать.

**Почему это раздел-предупреждение.** Коммит Тома от августа 2026 пошёл в **противоположную** сторону: удаление join'ов теперь делается редактированием jointree с полным перевыводом, потому что редактирование выведенных структур на месте оказалось неподдерживаемым:

> «remove_leftjoinrel_from_query only bothered to update "parts of the planner's data structures that will actually be consulted later", with no good way to know what those are. Bug #19560 is one consequence.»

Вывод для нас двоякий. Плохая новость: удаление join'а «на уровне пути» — почти наверняка тот же класс ошибок, что двадцать фиксов SJE; не лезть туда. Хорошая новость: механика «выбросить выведенное и вывести заново» теперь есть, отлажена и бэкпортирована — и это именно то, на чём будет стоять наш второй проход (раздел 0.4).

**Альтернативные СУБД.** Oracle делит трансформации явно: *«Some query transformations must be costed to be chosen and some do not need to be costed. For example, if a table can be eliminated completely from the join, that transformation is applied and the cost to perform that transformation is minimal.»* То есть join elimination — эвристика на стадии переписывания, как у нас. Нюанс порядка, релевантный нашей теме: *«after a view has been merged, a table inside a view may permit the optimizer to use join elimination to remove a table outside the view»* — возможность появляется только **после** другой трансформации, типичный случай недостаточности однопроходного конвейера. SQL Server — правило упрощения на trusted FK. CockroachDB — правила нормализации над memo, с ремапингом колонок через функциональные зависимости ([PR #105214](https://github.com/cockroachdb/cockroach/pull/105214)). Настоящей cost-based альтернативы «с join'ом и без» в одном memo нет ни у кого — и это логично: удаление join'а никогда не хуже, костить нечего.

---

# Группа D. Механизм

---

## 20. Прецеденты двухпроходной оптимизации и их режимы отказа

Прямых прецедентов «спланировали → прошлись по готовому плану → собрали недостающие факты → перепланировали» в продуктовых движках **нет ни одного**. Есть четыре частичных.

### 20.1. POP — ближайший формальный аналог

**Markl, Raman, Simmen, Lohman, Pirahesh, Cilimdzic, «Robust Query Processing through Progressive Optimization», SIGMOD 2004.** Для каждого оператора вычисляются *validity ranges* — диапазоны кардинальностей, при которых текущий план ещё оптимален. План инструментируется **checkpoints**, которые при выходе за диапазон приостанавливают выполнение и запускают переоптимизацию.

Соответствие нашей схеме буквальное: «аннотация на узле» = validity range, «набралось достаточно аннотаций» = нарушение check condition. Разница в триггере: у POP — исполнение, у нас — проход по плану.

Предшественник: **Kabra & DeWitt, «Efficient Mid-Query Re-Optimization of Sub-Optimal Query Execution Plans», SIGMOD 1998** — в план компилируется statistic collector operator, который решает, продолжать или остановиться и переоптимизировать остаток.

### 20.2. LEO — DB2's Learning Optimizer

**Stillger, Lohman, Markl, Kandil, VLDB 2001**, [PDF](https://www.vldb.org/conf/2001/P019.pdf). Четыре компонента: Capture (code generator сбрасывает «скелет» QEP в отдельный файл — потому что reverse-engineering section → QEP «quite complicated»), Monitor (счётчики строк на оператор, оверхед **< 5%**, включается по запросам), Analyze (фоновый low-priority демон, post-order обход, анализ ветки останавливается при ошибке в ребёнке), Exploit.

**Три проектных решения, которые стоит скопировать:**

1. **LEO никогда не переписывает базовую статистику.** Строится второй слой корректировок в отдельных каталожных таблицах. Три причины прямым текстом: обучение можно отключить, просто проигнорировав слой; можно хранить применённую корректировку вместе с планом и не получать «deltas of deltas»; человек может править руками.
2. **Старая корректировка обязана храниться в скелете** — *«it is not sufficient to look up the adjustment factor in the system table, since LEO cannot know if it was actually used for that query»*.
3. **Два места, где факты недостоверны:** index start/stop key (не сканируем ни индекс, ни таблицу целиком, входная кардинальность неизвестна) и merge join с неявным early out (одна сторона кончилась, остаток другой не запрошен и не посчитан). Достоверность возвращается только при наличии материализующего узла.

И прямо признанное ограничение, раздел 6.1 «When to Re-Optimize»: *«It remains future work to investigate whether and when re-optimization of a query should take place. The trade-off between re-optimization and improved runtime must be weighed.»* Авторы LEO явно оставили наш вопрос открытым.

### 20.3. SQL Server Interleaved Execution

Дословно Microsoft: *«during optimization if the database engine encounters a candidate for interleaved execution that uses MSTVFs, **optimization pauses, execute the applicable subtree, capture accurate cardinality estimates, and then resume optimization for downstream operations**.»*

Детали, важные для дизайна:
- Триггер жёстко зашит в один синтаксический признак (MSTVF с фиксированной оценкой 100 строк). Запрос должен быть read-only.
- **Оверхед объявлен нулевым**, и это не маркетинг: MSTVF и раньше материализовался, новизна только в откладывании оптимизации.
- Пауза случается **один раз**: после кэширования плана последующие исполнения берут исправленный план.
- Честно названный failure mode: *«some plans could change such that with better cardinality for the subtree we get a worse plan for the query overall»*.
- **Есть XEvent `interleaved_exec_disabled_reason`** — «почему кандидат не получил interleaved execution». Для нашей схемы аннотаций это прямой прототип наблюдаемости: нужен эквивалент, показывающий, какие аннотации были поставлены и почему не сработали.

Родственное: **Batch mode on rowstore** — эвристика решает в два шага, причём второй формулируется как ревизия по ходу поиска: *«additional checkpoints, as the optimizer discovers new, cheaper plans for the query. If these alternative plans don't make significant use of batch mode, the optimizer stops exploring batch mode alternatives.»*

### 20.4. Orca Multi-Stage Optimization

*«An optimization stage in Orca is defined as a complete optimization workflow using a subset of transformation rules and (optional) time-out and cost threshold.»* Мотивация: *«the most expensive transformation rules are configured to run in later stages to avoid increasing the optimization time. This technique is also a foundation for obtaining a query plan as early as possible to cut-down search space for complex queries.»* Конфигурируется пользователем.

Это не «спланировали → собрали факты → перепланировали», а «полный workflow N раз с растущим набором правил и бюджетом». Но как прецедент многократной оптимизации внутри одной компиляции — валидный.

Отдельно в Orca есть **нисходящий проход вывода статистики**: сначала родительское group expression запрашивает у детей нужные гистограммы (`InnerJoin(T1,T2) on (a=b)` запрашивает гистограммы на `T1.a`, `T2.b`), затем восходящий проход их объединяет. То есть «какая информация мне понадобится» — отдельный нисходящий проход. Ровно наш «пристрелочный», только для статистики.

### 20.5. Oracle: история отката, и что в ней на самом деле стоило дорого

Этот раздел легко прочитать как аргумент против пристрелочного прохода. Это неверно, и разбираться стоит внимательно, потому что при беглом чтении вывод получается противоположным правильному.

**Ключевое различение: ни один из выключенных механизмов не является «вторым циклом планирования».**

**Что осталось включённым.**

- **Adaptive Plans** (`OPTIMIZER_ADAPTIVE_PLANS` = TRUE) — `STATISTICS COLLECTOR` в плане, точка перегиба посчитана при компиляции, выбор subplan в рантайме. Покрывает выбор NL/hash join, метод параллельного распределения и bitmap pruning в star transformation. Порядок join'ов **не меняется**. Ноль лишних парсов.
- **CBQT** (cost-based query transformation, с 10gR1) — и вот это самое важное для нас. Oracle *«provides a mechanism for the exploration of the state space generated by applying one or more transformations»*: генерируется candidate query, он **полностью оптимизируется**, стоимости сравниваются. То есть Oracle буквально запускает физический оптимизатор по разу на каждое состояние трансформации — и **этот механизм включён по умолчанию до сих пор**. Через него, в частности, работает Group-By Placement (раздел 18).

**Что выключили** (`OPTIMIZER_ADAPTIVE_STATISTICS` = FALSE с 12.2). По белой книге Oracle это ровно четыре вещи: SQL plan directives; statistics feedback (кардинальность join'ов); performance feedback (степень параллелизма при `PARALLEL_DEGREE_POLICY=ADAPTIVE`); adaptive dynamic sampling для параллельного исполнения.

**Почему это дорого — и дорого здесь не то, о чём думаешь.**

SQL Plan Directive — это **не** сохранённая кардинальность. Это инструкция «в следующий раз, когда будешь парсить что-то с этой группой колонок, сделай здесь dynamic sampling». То есть Oracle во время hard parse выпускает рекурсивный SQL, который **реально читает блоки таблицы**. Он опознаётся по комментарию `/* DS_SVC */`:

```sql
SELECT /* DS_SVC */ /*+ dynamic_sampling(0) no_sql_tune no_monitoring
  optimizer_features_enable(default) no_parallel result_cache(snapshot=3600) */
SELECT /*+ qb_name("innerQuery") NO_INDEX_FFS( "A") */ 1 AS C1
  ("A"."ACCOUNT"='40000001' OR "A"."ACCOUNT"='40000002' OR ...) AND
  ("A"."DEPTID"='001A' OR "A"."DEPTID"='002A' OR ...) innerQuery
```

Комментарий автора отчёта под этим листингом: *«It is easy to see that you wouldn't need too many additional queries like this to have a significant [impact] on system performance.»*

**Дорого не «оптимизировать второй раз». Дорого сходить за данными на диск посреди парса.**

Дальше три множителя, каждый из которых относится к персистентности, а не к повторной оптимизации:

1. **Директивы привязаны к выражению запроса, а не к statement'у.** Поэтому одна директива, рождённая одним запросом, начинает облагать налогом hard parse *всех остальных* запросов, трогающих те же колонки. Стоимость размазывается по всей нагрузке.
2. **Их число растёт комбинаторно** с числом рассматриваемых групп колонок — отсюда багфикс с говорящим названием Bug 20465582 «High parse time in 12c for multi-table join SQL with SQL plan directives enabled».
3. **Они тянут за собой автоматическое создание extended statistics**, что удорожает последующие `DBMS_STATS` и двигает планы в момент сбора статистики. Это тоже выключили (`AUTO_STAT_EXTENSIONS` = OFF, патч 21171382).

Плюс два самостоятельных дефекта:

- **Недетерминизм петли**: пока директива не сброшена из SGA в SYSAUX — работает statistics feedback, после сброса — директива. Результат второго исполнения зависит от того, сколько времени прошло между исполнениями.
- **Переоптимизация может дать план хуже.**

**Где это убило.** PeopleSoft: динамический SQL с литералами в тексте, каждый statement — уникальный hard parse, выполняется ровно один раз. Отчёт: *«This additional information should help the optimizer make better decisions, but it comes at the price of making the database do more work during SQL parse. Unfortunately, PeopleSoft makes extensive use of dynamically generated SQL, often with literal values leading to large amounts of parse. Even a small additional overhead during SQL parse can result in a significant overhead for the entire system.»* Официальная рекомендация Oracle для PeopleSoft — `optimizer_adaptive_features = FALSE` (Doc ID 1445965.1). Бэкпорт расщепления параметров в 12.1 — патч 22652097.

**Что из этого к нам не относится.** Пристрелочный проход не ходит за данными: он смотрит на дерево, которое уже построено. Чистый CPU, ограниченный размером плана, никакого I/O. И он не персистентен — аннотации живут внутри одного вызова планировщика и умирают вместе с ним. Ни один из трёх множителей выше не воспроизводится. А главное — Oracle **оставил включённым** механизм, который оптимизирует запрос N раз внутри одной компиляции; значит, сама по себе повторная оптимизация вендором признана допустимой по цене.

**Что относится.** Ровно одна вещь: стоимость падает на hard parse, и нагрузки, где hard parse доминирует, существуют. Второй проход — это примерно ×2 по времени планирования плюс цикл перевывода в `query_planner()` (Том: «does add some time» при многих итерациях). Для OLTP-запроса с планированием 0.2 мс и исполнением 0.3 мс это −40% к суммарной латентности.

Порядок величин у нас уже измерен, причём на куда более дешёвой операции: в треде про ORDER BY prefix повторные вызовы `relation_can_be_sorted_early()` дали **1329 мс → 3195 мс** на реальном большом запросе. Это ×2.4 от одной вспомогательной функции, а не от полного второго прохода.

Отсюда практический вывод: **порог входа считается от оценочной стоимости плана, а не от числа аннотаций.** Патологическая нагрузка — ровно та, где много дешёвых запросов, каждый из которых честно поставил по одной аннотации.

### 20.6. SQL Server: дисциплина обратной связи

В отличие от Oracle, отказы у Microsoft мягче, потому что петля верифицируемая:
- **Memory Grant Feedback** — классический failure mode **осцилляция**: когда потребность скачет, обратная связь качается между «мало» и «много»; в этом случае MGF **сама себя отключает**. Починено в 2022 переходом на высокий перцентиль истории из Query Store.
- **CE Feedback** (2022) — обратная связь не по числам, а **по модельным допущениям**: стартуем с base containment; если входные оценки join'а хорошие, а выходные плохие — пробуем alternate containment. Стало лучше — фиксируем как Query Store hint (персистентно и откатываемо). Стало хуже или пользователь отменил запрос — не применяем.
- **DOP Feedback** — при регрессии откат к последнему известному хорошему значению; отмена пользователем считается регрессией; планы при этом не рекомпилируются.

Общий паттерн: **каждая обратная связь верифицируется на следующем исполнении и откатывается при регрессии; персистится только подтверждённое.**

### 20.7. AQO и почему на hackers нет треда про аннотацию неопределённости

**Ни одного предложения записывать в Path/Plan во время планирования маркер «решение принято в условиях неопределённости» на hackers нет.** Идея многократно упоминается и многократно бросается по одной и той же причине: **нет представления неопределённости, которое можно протащить вверх через `add_path()`**.

- [Adaptive query optimization](https://www.postgresql.org/message-id/9f414c8d-21bb-39ba-6c11-5e18ff522b81@postgrespro.ru), Книжник, 2019, stalled через 4 дня. Главное возражение: *«using provided explain feedback we are able to adjust selectivities only for one particular plan. But there may be many other alternative plans, and once we adjust one plan, optimizer most likely choose some other plan which actually can be ever worser... number of possible plans can be very large for queries with many joins (factorial)... sixth iteration of Oleg's AQO on JOB queries set takes about two hours (instead of original 10 minutes!).»* Ответ Вондры — покомпонентные коэффициенты `AVG(actual/estimate)` по классам узлов, чтобы поправки переносились на другие планы, с версионированием «эпохой», чтобы не было самовозбуждения. Не реализовано.
- [disfavoring unparameterized nested loops](https://www.postgresql.org/message-id/CA+TgmoYtWXNpj6D92XxUfjT_YFmi2dWq1XXM9EY-CRcr2qmqbg@mail.gmail.com), Хаас, 2021, stalled. **Том Лейн:** *«So in the end this gets back to the planning risk factor that we keep circling around but nobody quite wants to tackle. I'd be a lot happier if this proposal were couched around some sort of estimate of the risk of the outer side producing more than the expected number of rows.»* **Вондра про то, почему не получается:** *«1) Now we're dealing with three cardinality estimates (the original "e" and the boundaries "a, "b"). So which one do we use to calculate cost and pass to upper parts of the plan? 2) The outer relation may be a complex join, so we'd need to combine the confidence intervals for the two input relations, somehow. 3) We'd need to know how to calculate the confidence intervals for most plan nodes, which I'm not sure we know how to do.»* Том соглашается: *«a truly complete approach using confidence intervals or the like seems frighteningly complicated.»*
- [Risk Estimation](https://www.postgresql.org/message-id/11603.1395100047@sss.pgh.pa.us), 2014 — источник фразы: *«I would like to see the planner's cost estimates extended to include some sort of uncertainty estimate... But it's a long way from wishing that to making it so. Right now it's not even clear (to me anyway) how we'd measure or model such uncertainty.»*
- Питер Гейгеган в том же треде: *«Some problems with planning just can't be solved at plan time -- no model can ever be smart enough. Better to focus on making query execution more robust, perhaps by totally changing the plan when it is clearly wrong.»*

**Почему наш подход обходит это возражение.** Все перечисленные попытки пытались протащить **неопределённость** вверх через костинг — и упирались в то, что доверительный интервал не композируется через `add_path()`. Пристрелочный проход не протаскивает неопределённость вверх: он записывает **факт, которого не хватает, и адрес, по которому его потом искать**. Композиция не нужна — аннотации просто накапливаются в списке. Это принципиально более слабое требование, и именно поэтому оно выполнимо.

---

## 21. Сводная таблица

| № | Оптимизация | Нужный факт | Статус в PG | Прецедент вовне |
|---|---|---|---|---|
| 1 | Memoize single_row для SEMI/ANTI | окончательный join filter | запрещено | SQL Server, DB2 — проблемы нет по конструкции |
| 2 | Memoize: ключи и PARAM_EXEC | окончательные параметры | два бага исправлены post-hoc | — |
| 3 | Граница строк сквозь LEFT JOIN | отсутствие фильтров в цепочке | оппортунистический патч | ClickHouse/Trino/Spark — структурный запрет; DuckDB — граница значения |
| 4 | Ранний останов SEMI/ANTI в костинге | тип родительского join'а | нет | SQL Server row goal (только apply NL; для ANTI намеренно не ставится) |
| 5 | Bloom-фильтр из hash join | метод join'а сверху | патч Вондры, застрял | **норма индустрии**; Huawei SIGMOD'25: +32.8% |
| 6 | Join filter → index cond | окончательный набор клауз | нет | DB2 Starburst — предикаты как параметры правила |
| 7 | Runtime pruning в костинге | построенные pruning steps | два стоящих треда | Orca — селектор в memo; Oracle — нулевой кредит |
| 8 | Index-Only Scan: атрибуты | фактический набор атрибутов | целина, нет треда | Orca — required property |
| 9 | use_physical_tlist | то же + позиции материализации | stalled | DuckDB — второй проход |
| 10 | Incremental Sort при границе | твёрдая граница + член EC | stalled, ноль ответов | MySQL — решение исполнителя |
| 11 | FDW LIMIT после схлопывания Append | схлопнулся ли Append | известно с 2019 | DB2 — перекладывают на пользователя |
| 12 | Параметризованные пути | число loops | известно с 2010 | **никто не костит inner до outer** |
| 13 | AlternativeSubplan | число исполнений | перенесено в setrefs (PG14) | SQL Server Interleaved Execution |
| 14 | Поздняя материализация | сколько строк выживет | оператора нет | Vertica, DuckDB |
| 15 | Селективность поперёк join'а | группировка клауз по узлам | патч Вондры, 4 года | — |
| 16 | Predicate move-around | полный набор клауз + EC | целина | DB2 — есть; Oracle — только равенство с константой |
| 17 | Дорогие предикаты | фактические мощности | **тупик по другой причине** (procost=1) | никто не переносит между операторами |
| 18 | Eager aggregation: уровень | plan_rows каждого уровня | закоммичено PG19, Хаас предлагает 2 прохода | **Snowflake — ровно наша схема**; Oracle — полная переоптимизация |
| 19 | Join removal на уровне пути | — | **не лезть** | никто не костит |

---

## 22. Что бы я делал первым

Порядок по отношению «выигрыш / риск»:

1. **№ 12 (число loops).** Самая простая аннотация, самый прямой эффект, тридцатилетняя проблема, ноль риска для корректности. Хороший полигон для механизма.
2. **№ 1 и № 3 вместе.** Ради них всё и затевалось; если контракт выдержит оба, он выдержит остальное. № 3 — с оглядкой на индустриальный инвариант («каждая строка сохраняемой стороны даёт ≥1 выходную»), а не на уникальность inner'а, и с сохранением верхнего Sort+Limit как страховки.
3. **№ 8 (атрибуты для IOS).** Целина, нет конкурирующих патчей, снимает возражение Тома про экспоненциальное время `check_index_only`, попутно даёт № 9.
4. **№ 5 (bloom-фильтры).** Только в координации с Вондрой; внешний аргумент (Huawei, +32.8%) сильный, но патч и так сложный.
5. **№ 15 (селективность поперёк join'а).** Отдельным треком — это не про bottom-up, а про отсутствие статистики нужной формы. Но без него разделы 6 и 16 останутся «можем построить, но не выберем».

Не делать: № 17 (упрётся в `procost`), № 19 (двадцать фиксов SJE).

---

## 23. Открытые вопросы

1. **Композиция аннотаций через Append/Gather.** Параллельный план: граница не доезжает до воркеров (раздел 3), и Хаас в 2017 расписал, что для этого надо (DSM + `pass_down_bound` в каждом воркере). Аннотация должна уметь сказать «подтверждено для лидера, не подтверждено для воркеров».
2. **Сколько итераций.** Одна? Или до сходимости? Опыт Книжника (шесть итераций AQO на JOB = два часа вместо десяти минут) говорит: одна, жёстко.
3. **Что делать, если второе планирование дало план хуже.** Microsoft: откат. У нас нет «следующего исполнения» для верификации — сравнивать придётся оценки, а они и есть источник проблемы. Возможный ответ: брать план с меньшей *пессимистичной* оценкой.
4. **Взаимодействие с `pg_plan_advice`.** Аннотации и advice — очень похожие сущности. Может ли пристрелочный проход выражать свои выводы на языке advice? Это дало бы бесплатную наблюдаемость (`EXPLAIN (PLAN_ADVICE)`) и путь к персистентности через `pg_stash_advice`.
5. **Порог входа.** Формула из 0.2 — заглушка. Нужно измерить на реальной нагрузке, какая доля запросов ставит аннотации и какая доля из них действительно даёт другой план.

---

## Приложение: источники

**Треды и коммиты PostgreSQL** — все ссылки в тексте разделов; ключевые:
- [Memoize ANTI and SEMI JOIN inner](https://www.postgresql.org/message-id/60bf8d26-7c7e-4915-b544-afdb9020011d@gmail.com) · [Try a presorted outer path](https://www.postgresql.org/message-id/f0dc7fcb-4034-4b5c-bfe6-1e7b8817cd36@gmail.com) · [hashjoins vs. Bloom filters](https://www.postgresql.org/message-id/5cd8c20c-14b5-4b0d-bedc-69bf714e87eb@vondra.me) · [Cost estimates for parameterized paths](https://www.postgresql.org/message-id/14624.1283463072@sss.pgh.pa.us) · [Join removal via jointree](https://www.postgresql.org/message-id/E1x020n-00000002XCr-0lpe@gemulon.postgresql.org) · [disfavoring unparameterized nested loops](https://www.postgresql.org/message-id/CA+TgmoYtWXNpj6D92XxUfjT_YFmi2dWq1XXM9EY-CRcr2qmqbg@mail.gmail.com)

**Академические работы**

Архитектура оптимизатора:
- Selinger et al., «Access Path Selection in a Relational Database Management System», SIGMOD 1979
- Lohman, «Grammar-like Functional Rules for Representing Query Optimization Alternatives», SIGMOD 1988
- Graefe & McKenna, «The Volcano Optimizer Generator», ICDE 1993
- Graefe, «The Cascades Framework for Query Optimization», IEEE Data Eng. Bull. 18(3), 1995
- Soliman et al., «Orca: A Modular Query Optimizer Architecture for Big Data», SIGMOD 2014

Переоптимизация и обратная связь:
- Kabra & DeWitt, «Efficient Mid-Query Re-Optimization of Sub-Optimal Query Execution Plans», SIGMOD 1998
- Stillger, Lohman, Markl, Kandil, «LEO — DB2's LEarning Optimizer», VLDB 2001
- Markl, Raman, Simmen, Lohman, Pirahesh, Cilimdzic, «Robust Query Processing through Progressive Optimization», SIGMOD 2004
- Babu, Bizarro, DeWitt, «Proactive Re-optimization», SIGMOD 2005
- Ahmed et al., «Cost-based query transformation in Oracle», VLDB 2006
- Deshpande, Ives, Raman, «Adaptive Query Processing», FnT Databases 1(1), 2007

Sideways information passing:
- Bancilhon, Maier, Sagiv, Ullman, «Magic Sets and Other Strange Ways to Implement Logic Programs», PODS 1986
- Mackert & Lohman, «R* Optimizer Validation and Performance Evaluation for Distributed Queries», VLDB 1986 (§6.3 — термин «Bloomjoin»)
- Beeri & Ramakrishnan, «On the Power of Magic», PODS 1987
- Levy, Mumick, Sagiv, «Query Optimization by Predicate Move-Around», VLDB 1994
- Mumick & Pirahesh, «Implementation of magic-sets in a relational database system», SIGMOD 1994
- Seshadri, Hellerstein, Pirahesh, Leung, Ramakrishnan, Srivastava, Stuckey, Sudarshan, «Cost-Based Optimization for Magic», SIGMOD 1996
- Ives & Taylor, «Sideways Information Passing for Push-Style Query Processing», ICDE 2008
- Yang, Zhao, Yu, Koutris, «Predicate Transfer: Efficient Pre-Filtering on Multi-Join Queries», CIDR 2024
- **Zeyl, Cheng, Pournaghi, Lam, Wang, Wong, Chen, Larson, «Including Bloom Filters in Bottom-up Optimization», SIGMOD-Companion 2025** — главный внешний аргумент
- Zhao et al. (Microsoft), «I Can't Believe It's Not Yannakakis: Pragmatic Bitmap Filters in Microsoft SQL Server», CIDR 2026

Top-k и row goals:
- Ilyas, Aref, Elmagarmid, «Supporting Top-k Join Queries in Relational Databases», VLDB 2003
- Li, Soliman, Chang, Ilyas, «RankSQL: Query Algebra and Optimization for Relational Top-k Queries», VLDB 2005

Агрегация и предикаты:
- Hellerstein & Stonebraker, «Predicate Migration: Optimizing Queries with Expensive Predicates», SIGMOD 1993
- Chaudhuri & Shim, «Including Group-By in Query Optimization», VLDB 1994
- Yan & Larson, «Eager Aggregation and Lazy Aggregation», VLDB 1995

Материализация и фильтры:
- Abadi, Myers, DeWitt, Madden, «Materialization Strategies in a Column-Oriented DBMS», ICDE 2007
- Leis, Boncz, Kemper, Neumann, «Morsel-Driven Parallelism», SIGMOD 2014
- Shrinivas et al., «Materialization Strategies in the Vertica Analytic Database», ICDE 2013
- Lang, Neumann, Kemper, Boncz, «Performance-Optimal Filtering: Bloom overtakes Cuckoo at High Throughput», PVLDB 12(5), 2019
