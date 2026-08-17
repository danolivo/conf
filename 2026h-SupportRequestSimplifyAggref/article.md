# Оптимизация агрегатов PostgreSQL — расширяемый подход

Агрегаты в PostgreSQL не очень-то эффективны. Это особенно заметно в сравнении с SQL Server в сценарии, где частичная агрегация не помогает: когда агрегация только подготавливает данные для запроса, обрабатывая большой поток строк и на выходе получая ненамного меньший набор групп и посчитанных по ним агрегатов. Хуже всего приходится типам переменной длины. И здесь характерный пример — `SUM(numeric)`. Встроенные агрегаты обязаны обрабатывать значения в самом общем виде, тогда как на практике данные часто ограничены: например, в БД 1С все numeric имеют фиксированный масштаб.

Отсюда возникает идея оптимизировать агрегаты, подстроив их под конкретные условия эксплуатации. Раньше это было возможно только в форке PostgreSQL. Однако недавно David Rowley добавил в ядро любопытный инструмент расширения `SupportRequestSimplifyAggref` ([коммит 42473b3b31](https://github.com/postgres/postgres/commit/42473b3b31), PostgreSQL 19): теперь можно предоставить планнеру кастомную логику трансформации агрегата через механизм [функций поддержки планнера](https://www.postgresql.org/docs/19/xfunc-optimization.html) (prosupport). Сам механизм существует ещё с PostgreSQL 12, но до агрегатов добрался только сейчас. В ядре новый запрос применяется скромно: заменяет `COUNT(1)` и `COUNT(col)` по NOT NULL-колонке на `COUNT(*)`. А вот расширению он позволяет сделать с агрегатом во время планирования практически что угодно. Это открывает пространство для интересных технических решений.

Здесь я предлагаю посмотреть, как схема с преобразованием агрегата работает на живом и полезном примере — простом расширении с достаточно примитивной трансформацией.

## Введение

В реальных условиях, где запросы генерируются приложением динамически, время от времени встречаются избыточные конструкции вроде следующей:

```sql
SUM(x ORDER BY x)
```

Действительно, порядок следования значений на сумму не влияет. Так зачем выполнять лишнюю сортировку?

Для начала проверим, действительно ли PostgreSQL сохраняет ненужную операцию сортировки, и прикинем, что может дать избавление от неё. Ниже — два запроса с суммированием, при наличии сортировки и без неё:

```sql
SELECT sum(x ORDER BY x) FROM
  (SELECT (random()*1E6)::numeric(16,2) AS x FROM generate_series(1,1E7))
OFFSET 1E7;
Time: 5716.916 ms (00:05.717)

SELECT sum(x) FROM
  (SELECT (random()*1E6)::numeric(16,2) AS x FROM generate_series(1,1E7))
OFFSET 1E7;
Time: 3664.739 ms (00:03.665)
```

Треть времени запроса уходит впустую — значительное ускорение в идеальном случае. Имеет смысл реализовать замену: она отработает один раз на этапе планирования и не должна стоить дорого. А в случае [generic-планов](https://www.postgresql.org/docs/19/sql-prepare.html) результат трансформации будет ещё и переиспользоваться от выполнения к выполнению.

## Этап первый. Тело функции

Функция поддержки — это C-функция с SQL-сигнатурой `supportfn(internal) RETURNS internal`. Планировщик передаёт ей указатель на узел плана запроса, а она возвращает результат, тип которого зависит от типа запроса, либо NULL-указатель — «ничем помочь не могу». Типов запросов много: `SupportRequestSimplify`, `SupportRequestCost`, `SupportRequestRows` и другие — все описаны в [supportnodes.h](https://github.com/postgres/postgres/blob/master/src/include/nodes/supportnodes.h). Кстати, в документации `SupportRequestSimplifyAggref` пока не упомянут вовсе, так что заголовочный файл — единственный источник.

Нас интересует именно `SupportRequestSimplifyAggref`: в нём планировщик приносит узел агрегата `Aggref` и готов заменить его на то, что мы вернём. Правила игры простые: возвращать нужно новый узел, модифицировать исходный нельзя, а если трансформация неприменима — вернуть `PG_RETURN_POINTER(NULL)`, но ни в коем случае не ошибку. Набор типов запросов расширяется от версии к версии, и получить незнакомый запрос — штатная ситуация для функции поддержки.

Схематически, код функции будет выглядеть весьма просто:

```c
Datum
sum_agg_support(PG_FUNCTION_ARGS)
{
	Node	   *rawreq = (Node *) PG_GETARG_POINTER(0);

	if (IsA(rawreq, SupportRequestSimplifyAggref))
	{
		SupportRequestSimplifyAggref *req;
		Aggref	   *aggref;
		Aggref	   *newagg;
		ListCell   *lc;

		req = (SupportRequestSimplifyAggref *) rawreq;
		aggref = req->aggref;

		if (aggref->aggdistinct != NIL)
			PG_RETURN_POINTER(NULL);

	    switch (linitial_oid(aggref->aggargtypes))
		{
			case INT2OID:
			case INT4OID:
			case INT8OID:
			case NUMERICOID:
		 		newagg = copyObject(aggref);
		 		newagg->aggorder = NIL;
		 		PG_RETURN_POINTER(newagg);
			default:
				PG_RETURN_POINTER(NULL);
		}
	}

	PG_RETURN_POINTER(NULL);
}
```

Однако, как и всегда в промышленном коде, требуется множество проверок на корректность и всяких "fast path". Поэтому полный код будет выглядеть как-то так:

```c
Datum
sum_agg_support(PG_FUNCTION_ARGS)
{
	Node	   *rawreq = (Node *) PG_GETARG_POINTER(0);

	if (IsA(rawreq, SupportRequestSimplifyAggref))
	{
		SupportRequestSimplifyAggref *req;
		Aggref	   *aggref;
		Aggref	   *newagg;
		ListCell   *lc;

		req = (SupportRequestSimplifyAggref *) rawreq;
		aggref = req->aggref;

		/*
		 * Plain aggregates only.  For an ordered-set or hypothetical-set
		 * aggregate the sort clause is what WITHIN GROUP means, and
		 * ordered_set_startup() reads aggorder at execution time, so removing
		 * it would break the aggregate rather than optimize it.
		 */
		if (aggref->aggkind != AGGKIND_NORMAL)
			PG_RETURN_POINTER(NULL);

		/* Nothing to remove, and DISTINCT needs the sort anyway */
		if (aggref->aggorder == NIL || aggref->aggdistinct != NIL)
			PG_RETURN_POINTER(NULL);

		/*
		 * Be paranoid about what we are attached to: sum() takes exactly one
		 * argument.  This also makes linitial_oid() below safe, since
		 * aggargtypes is NIL for a star aggregate such as count(*).
		 */
		if (list_length(aggref->aggargtypes) != 1)
			PG_RETURN_POINTER(NULL);

		/*
		 * Reject inexact types, where the summation order is observable.
		 * aggtranstype is not filled in until preprocess_aggrefs(), which
		 * runs after us, so consult the declared argument type instead.
		 */
		switch (linitial_oid(aggref->aggargtypes))
		{
			case INT2OID:
			case INT4OID:
			case INT8OID:
			case NUMERICOID:
				break;
			default:
				PG_RETURN_POINTER(NULL);
		}

		/*
		 * Punt if any argument is resjunk, ie. it is present only to feed the
		 * ORDER BY, as in sum(x ORDER BY y).  Removing the sort would leave
		 * it unused, and rebuilding the argument list is more than this
		 * example needs.
		 */
		foreach(lc, aggref->args)
		{
			if (((TargetEntry *) lfirst(lc))->resjunk)
				PG_RETURN_POINTER(NULL);
		}

		/*
		 * Note: no check of agglevelsup is needed.  supportnodes.h warns
		 * about Aggrefs with agglevelsup > 0, but dropping a semantically
		 * inert ORDER BY is valid at any aggregation level.
		 */

		/*
		 * The API requires a new node; the original must not be modified.  A
		 * deep copy is wanted here, rather than the makeNode/memcpy shortcut
		 * some in-core support functions use, because we go on to modify the
		 * argument list.
		 */
		newagg = copyObject(aggref);
		newagg->aggorder = NIL;

		/*
		 * The sort-group references on the arguments existed only to be
		 * targets of that ORDER BY.  Left behind, they would make this call
		 * unequal to an identical one written without ORDER BY, and
		 * find_compatible_agg() would then evaluate the same aggregate twice.
		 * Clearing them is safe precisely because aggorder and aggdistinct
		 * are both gone.
		 */
		foreach(lc, newagg->args)
			((TargetEntry *) lfirst(lc))->ressortgroupref = 0;

		PG_RETURN_POINTER(newagg);
	}

	PG_RETURN_POINTER(NULL);
}
```

Почти весь код — проверки применимости, и в них вся суть.

**Только обычные агрегаты.** У ordered-set и hypothetical-set агрегатов (`percentile_disc(0.5) WITHIN GROUP (ORDER BY x)`) поле `aggorder` — это семантика WITHIN GROUP, и читается оно на этапе исполнения. Убрать его — значит сломать агрегат, а не ускорить.

**Никакого DISTINCT.** В `sum(DISTINCT x ORDER BY x)` дедупликация выполняется через ту же сортировку — убирать её нельзя.

**Один аргумент и точный тип.** float4/float8 отвергаем: для них порядок суммирования наблюдаем, сумма в другом порядке — другое число. Здесь есть тонкость: тип аргумента приходится брать из `aggargtypes`, а не из `aggtranstype` — последний заполняется в `preprocess_aggrefs()`, которая выполняется позже, и на момент нашего вызова там ещё `InvalidOid`.

**Никаких resjunk-аргументов.** В `sum(x ORDER BY y)` столбец `y` попадает в список аргументов агрегата с пометкой resjunk — он нужен только сортировке. Выкинув `ORDER BY`, мы оставили бы бесхозный аргумент; перестройка списка аргументов для демонстрации избыточна — проще отказаться от трансформации.

Отдельной проверки заслуживал бы `agglevelsup`: supportnodes.h прямо предупреждает, что функция поддержки может получить Aggref с `agglevelsup > 0` — агрегат, ссылающийся из подзапроса на внешний уровень. Нам, впрочем, беспокоиться не о чем: выбрасывание семантически инертного `ORDER BY` корректно на любом уровне агрегации.

Сама трансформация после всех проверок — три действия: `copyObject()`, `aggorder = NIL` и обнуление `ressortgroupref` у аргументов. Последнее неочевидно, но важно: ссылки sort-group существовали только ради `ORDER BY`, однако функция `equal()` их учитывает. Не обнули мы их — и `find_compatible_agg()` посчитала бы `sum(x ORDER BY x)` после трансформации и написанный рядом `sum(x)` разными агрегатами, вычислив одно и то же дважды.

## Этап второй. Подключение функции как prosupport к агрегату

Для обычной функции всё просто: `CREATE FUNCTION ... SUPPORT` или `ALTER FUNCTION ... SUPPORT`. С агрегатами ждёт сюрприз:

```sql
=# ALTER FUNCTION pg_catalog.sum(numeric) SUPPORT sum_agg_support;
ERROR:  "pg_catalog.sum" is an aggregate function

=# ALTER AGGREGATE pg_catalog.sum(numeric) SUPPORT sum_agg_support;
ERROR:  syntax error at or near "SUPPORT"
```

DDL, позволяющего навесить функцию поддержки на агрегат, в ванильном PostgreSQL просто нет: фича в ядре формально есть, но снаружи ядра недостижима. Патч, добавляющий опцию `SUPPORT` в `CREATE AGGREGATE` и форму `ALTER AGGREGATE ... SUPPORT`, [предложен в pgsql-hackers](https://www.postgresql.org/message-id/flat/8f58c96d-d3c7-4c0f-9898-116f00eeaff6@gmail.com). Пока он не закоммичен, придётся делать работу DDL руками. Кроме C-функции, скрипт расширения объявляет пару plpgsql-хелперов — `agg_support_attach()` и `agg_support_detach()`. Суть attach — две записи в системный каталог, ровно те, что сделал бы DDL:

```sql
-- планировщик начинает советоваться с функцией поддержки
UPDATE pg_catalog.pg_proc SET prosupport = supfn WHERE oid = agg;

-- обычная (NORMAL) зависимость: агрегат зависит от функции поддержки
INSERT INTO pg_catalog.pg_depend
       (classid, objid, objsubid, refclassid, refobjid, refobjsubid, deptype)
VALUES ('pg_catalog.pg_proc'::regclass, agg, 0,
        'pg_catalog.pg_proc'::regclass, supfn, 0, 'n');
```

Без второй записи можно было бы и обойтись — но недолго, и сейчас увидим почему.

Подключаемся — прямо к встроенному `sum(numeric)`, планировщику всё равно, чей агрегат перед ним:

```sql
=# SELECT agg_support_attach('pg_catalog.sum(numeric)'::regprocedure);
=# EXPLAIN (VERBOSE, COSTS OFF) SELECT sum(x ORDER BY x) FROM t;
 Aggregate
   Output: sum(x)
   ->  Seq Scan on public.t
```

Вот здесь ручная запись в `pg_depend` и перестаёт быть формальностью. Голый `UPDATE pg_proc` без неё — игра с огнём: удалили расширение — и `prosupport` у `sum(numeric)` указывает в пустоту, после чего каждый запрос с `sum(numeric)` падает на планировании с `cache lookup failed for function NNNNN`, пока кто-нибудь не обнулит поле обратно. С зависимостью же система сама не даст выстрелить себе в ногу:

```sql
=# DROP EXTENSION agg_support;
ERROR:  cannot drop function sum(numeric) because it is required by the database system
```

Сообщение не самое говорящее — механизм зависимостей дошёл по нашей записи до pinned-объекта `sum(numeric)` и отказался его трогать, — но провал безопасный: не поможет даже `CASCADE`. Порядок наводится штатно: сначала `agg_support_detach('pg_catalog.sum(numeric)')` — симметричный хелпер, обнуляющий `prosupport` и удаляющий запись из `pg_depend`, — затем `DROP EXTENSION`.

Две оговорки честности ради. Attach к встроенному агрегату действует на всю базу и всех её пользователей — это решение администратора, а не библиотеки. И связка не переживает pg_dump/restore и pg_upgrade: на новом кластере исчезают обе записи разом, `sum` продолжает работать как стоковый, просто attach придётся повторить. Предложенный патч делает всё то же самое штатно — `ALTER AGGREGATE ... SUPPORT` пишет и `prosupport`, и зависимость, — но без похода в системный каталог руками и с человеческими сообщениями об ошибках.

Заодно отметим: и `CREATE EXTENSION` (C-функция), и сам attach требуют суперпользователя — запись в системный каталог дешевле не продаётся.

## Смотрим на результат

Сборка стандартная для расширений (нужны PostgreSQL 19+ и заголовки сервера):

```bash
make PG_CONFIG=/path/to/pg_config install
psql -c "CREATE EXTENSION agg_support"
psql -c "SELECT agg_support_attach('pg_catalog.sum(numeric)'::regprocedure)"
```

Возьмём табличку с numeric и сравним планы. До подключения встроенный `sum` честно сортирует:

```sql
=# EXPLAIN (VERBOSE, COSTS OFF) SELECT sum(x ORDER BY x) FROM t;
 Aggregate
   Output: sum(x ORDER BY x)
   ->  Sort
         Output: x
         Sort Key: t.x
         ->  Seq Scan on public.t
               Output: x
```

После attach планировщик вызвал нашу функцию поддержки — и от `ORDER BY` не осталось следа, узел Sort исчез вместе с ним, а результат, разумеется, не изменился:

```sql
=# EXPLAIN (VERBOSE, COSTS OFF) SELECT sum(x ORDER BY x) FROM t;
 Aggregate
   Output: sum(x)
   ->  Seq Scan on public.t
         Output: x

=# SELECT sum(x ORDER BY x) = sum(x) AS same FROM t;
 same
------
 t
```

Работает и дедупликация, ради которой мы обнуляли `ressortgroupref`: оба вызова ниже сведены к одному агрегату и вычисляются один раз.

```sql
=# EXPLAIN (VERBOSE, COSTS OFF) SELECT sum(x ORDER BY x), sum(x) FROM t;
 Aggregate
   Output: sum(x), sum(x)
   ->  Seq Scan on public.t
```

Все «отказные» ветки тоже на месте: для `sum(f ORDER BY f)` по float8, `sum(DISTINCT x ORDER BY x)` и `sum(x ORDER BY g)` план остаётся с сортировкой, а `FILTER` трансформации не мешает и честно сохраняется.

Теперь время. Тот же запрос на 10 миллионах строк, что и в начале статьи (лучшее из двух прогонов на ноутбуке, сборка без ассертов, конфигурация по умолчанию):

| Запрос | Sort в плане | Время |
|---|---|---|
| `sum(x ORDER BY x)`, сток | есть | 5717 мс |
| `sum(x)` | нет | 3665 мс |
| `sum(x ORDER BY x)` после attach | убран функцией поддержки | 3527 мс |

После подключения `sum(x ORDER BY x)` сравнялся с `sum(x)` в пределах шума (разница двух нижних строк — случайные данные между прогонами): сортировка исчезла не только из плана, но и из профиля выполнения. Минус 38% времени, не тронув ни запрос, ни ядро.

Бонус: та самая внутриядерная трансформация из коммита 42473b3b31, с которой всё началось, — рядом. `count` по NOT NULL-колонке больше не таскает значение в агрегат:

```sql
=# EXPLAIN (VERBOSE, COSTS OFF) SELECT count(a) FROM tc;   -- a объявлена NOT NULL
 Aggregate
   Output: count(*)
   ->  Seq Scan on public.tc
```

## Заключение

Разрешив трансформацию агрегатной функции, PostgreSQL открыл путь фантазии разработчиков — сделать с агрегатом можно всё что угодно. Это позволит «подчищать» плохо или избыточно сгенерированные запросы и подстраивать агрегаты под конкретные условия эксплуатации СУБД. Здесь мы разобрали простой пример, который всего лишь устраняет неаккуратность генератора запросов. Более серьёзным примером может служить подстановка оптимизированной версии `SUM()`, когда на входе numeric заведомо известного и небольшого масштаба, — см. прототип расширения [pg_numeric_agg_support](https://github.com/danolivo/pg_numeric_agg_support) на GitHub: на группирующих запросах он снимает 40–50% времени и до 70% памяти хеш-таблицы.

Не хватает малого — DDL, чтобы расширения могли пользоваться этим механизмом, не залезая в системный каталог руками. Если тема вам близка, поучаствуйте в [обсуждении патча](https://www.postgresql.org/message-id/flat/8f58c96d-d3c7-4c0f-9898-116f00eeaff6@gmail.com) в pgsql-hackers.
