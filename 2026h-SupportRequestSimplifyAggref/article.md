# Оптимизация агрегатов PostgreSQL — расширяемый подход

Агрегаты в PostgreSQL не очень-то эффективны. Это особенно заметно в сравнении с SQL Server в сценарии, где частичная агрегация не помогает: когда агрегация только подготавливает данные для запроса, обрабатывая большой поток строк и на выходе получая ненамного меньший набор групп и посчитанных по ним агрегатов. Хуже всего приходится типам переменной длины. И здесь характерный пример — `SUM(numeric)`. Встроенные агрегаты обязаны обрабатывать значения в самом общем виде, тогда как на практике данные часто ограничены: например, в БД 1С все numeric имеют фиксированный масштаб.

Отсюда возникает идея оптимизировать агрегаты, подстроив их под конкретные условия эксплуатации. Раньше это было возможно только в форке PostgreSQL. Однако недавно David Rowley добавил в ядро любопытный инструмент расширения `SupportRequestSimplifyAggref` ([коммит 42473b3b31](https://github.com/postgres/postgres/commit/42473b3b31), PostgreSQL 19): теперь можно предоставить планнеру кастомную логику трансформации агрегата через механизм [функций поддержки планнера](https://www.postgresql.org/docs/19/xfunc-optimization.html) (prosupport). Сам механизм существует ещё с PostgreSQL 12, но до агрегатов добрался только сейчас. В ядре новый запрос применяется скромно: заменяет `COUNT(1)` и `COUNT(col)` по NOT NULL-колонке на `COUNT(*)`. А вот расширению он позволяет сделать с агрегатом во время планирования практически что угодно. Это открывает пространство для интересных технических решений.

Здесь я предлагаю посмотреть, как схема с преобразованием агрегата работает на живом и полезном примере — простом расширении с достаточно примитивной трансформацией.

## Лишняя сортировка

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

## Пишем функцию поддержки

Функция поддержки — это C-функция с SQL-сигнатурой `supportfn(internal) RETURNS internal`. Планировщик передаёт ей указатель на узел плана запроса, а она возвращает результат, тип которого зависит от типа запроса, либо NULL-указатель — «ничем помочь не могу». Типов запросов много: `SupportRequestSimplify`, `SupportRequestCost`, `SupportRequestRows` и другие — все описаны в [supportnodes.h](https://github.com/postgres/postgres/blob/master/src/include/nodes/supportnodes.h). Кстати, в документации `SupportRequestSimplifyAggref` пока не упомянут вовсе, так что заголовочный файл — единственный источник.

Нас интересует именно `SupportRequestSimplifyAggref`: в нём планировщик приносит узел агрегата `Aggref` и готов заменить его на то, что мы вернём. Правила игры простые: возвращать нужно новый узел, модифицировать исходный нельзя, а если трансформация неприменима — вернуть `PG_RETURN_POINTER(NULL)`, но ни в коем случае не ошибку. Набор типов запросов расширяется от версии к версии, и получить незнакомый запрос — штатная ситуация для функции поддержки.

Схематически код функции будет выглядеть весьма просто:

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

	 	foreach(lc, aggref->args)
		{
			if (((TargetEntry *) lfirst(lc))->resjunk)
				PG_RETURN_POINTER(NULL);
		}

	    switch (linitial_oid(aggref->aggargtypes))
		{
			case INT2OID:
			case INT4OID:
			case INT8OID:
			case NUMERICOID:
		 		newagg = copyObject(aggref);
		 		newagg->aggorder = NIL;
		 
		 		foreach(lc, newagg->args)
					((TargetEntry *) lfirst(lc))->ressortgroupref = 0;
		 
		 		PG_RETURN_POINTER(newagg);
			default:
				PG_RETURN_POINTER(NULL);
		}
	}

	PG_RETURN_POINTER(NULL);
}
```

В минимальном варианте нам достаточно определить, что агрегат суммирует значения подходящего типа — целые или [точные десятичные типы](https://habr.com/ru/companies/tantor/articles/1070300/). В таком случае копируем ноду, реализующую этот агрегат, и возвращаем её без клаузы `ORDER BY`. Старый агрегат мы оставляем без изменения — для других расширений или если оптимизатор станет использовать дерево запроса в каком-нибудь альтернативном планировании.

Проверка на `resjunk` — это своеобразный способ отделить выражения вида `SUM(x ORDER BY y)`. Если колонка сортировки не попадает в выражение суммирования, то такая колонка появится в списке аргументов как `resjunk` — под текущую оптимизацию не подходит.

Строка с обнулением `ressortgroupref` требуется для того, чтобы удалить метку «отсортировано», которая устанавливалась на колонку `x`: сортировки нет, значит, признак должен быть снят, чтобы последующие проверки дерева плана запроса не обнаружили неконсистентность.

Однако это не всё. Промышленный код, как обычно, будет сложнее, ибо должен учитывать разнообразные варианты применения и отрабатывать в том числе и попытки некорректного использования функции. Также приходится писать код так, чтобы отрицательные проверки выполнялись как можно раньше и «fast path» — «ничем помочь не могу» — происходил как можно раньше. Поэтому полный код будет выглядеть, конечно, [чуть сложнее](https://github.com/danolivo/conf/blob/1fbdd0d8aeb8a8a427c40877aa65d565f5471aec/2026h-SupportRequestSimplifyAggref/aggsupport/agg_support.c#L33).

// Spoiler:

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

		Assert(aggref->aggkind == AGGKIND_NORMAL);

		if (aggref->aggorder == NIL || aggref->aggdistinct != NIL)
			PG_RETURN_POINTER(NULL);

		Assert(list_length(aggref->aggargtypes) == 1);
		if (list_length(aggref->aggargtypes) != 1)
			PG_RETURN_POINTER(NULL);

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

		foreach(lc, aggref->args)
		{
			if (((TargetEntry *) lfirst(lc))->resjunk)
				PG_RETURN_POINTER(NULL);
		}

		newagg = copyObject(aggref);
		newagg->aggorder = NIL;

		foreach(lc, newagg->args)
			((TargetEntry *) lfirst(lc))->ressortgroupref = 0;

		PG_RETURN_POINTER(newagg);
	}

	PG_RETURN_POINTER(NULL);
}
```

Давайте разберём эти проверки.

Проверка наличия условия DISTINCT. DISTINCT означает, что агрегату в любом случае требуется сортировка, а значит, оптимизация не повлияет ни на что — по крайней мере, пока DISTINCT внутри агрегата не научится дедупликации методом хеширования. Желающих, впрочем, пока не видно: комментарий `We don't implement DISTINCT or ORDER BY aggs in the HASHED case (yet)` живёт в [`nodeAgg.c`](https://github.com/postgres/postgres/blob/master/src/backend/executor/nodeAgg.c) со времён [коммита 34d26872ed8](https://github.com/postgres/postgres/commit/34d26872ed816b299eef2fa4240d55316697f42d), которым Том Лейн в 2009 году и добавил `ORDER BY` внутрь агрегатов.

Далее проверяем, что support-функция вызвана для «обычного» агрегата. У [ordered-set и hypothetical-set агрегатов](https://www.postgresql.org/docs/19/xaggr.html#XAGGR-ORDERED-SET-AGGREGATES) (`percentile_disc(0.5) WITHIN GROUP (ORDER BY x)`) поле `aggorder` убрать нельзя без риска поменять семантику. Конечно, агрегат `SUM()` не может быть использован с `WITHIN GROUP` по определению — здесь мы страхуемся от того, чтобы пользователь не приаттачил prosupport к несовместимому агрегату. То же самое относится и к следующей проверке на то, что входных аргументов ровно одна штука.

## Подключаем её к sum()

Расширение, которое хочет добавить кастомный prosupport-хелпер, в обычном случае просто выполняет DDL: [`CREATE FUNCTION ... SUPPORT`](https://www.postgresql.org/docs/19/sql-createfunction.html) или [`ALTER FUNCTION ... SUPPORT`](https://www.postgresql.org/docs/19/sql-alterfunction.html). С агрегатами нас ждёт сюрприз:

```sql
=# ALTER FUNCTION pg_catalog.sum(numeric) SUPPORT sum_agg_support;
ERROR:  "pg_catalog.sum" is an aggregate function
```

DDL, позволяющего навесить функцию поддержки на агрегат, в ванильном PostgreSQL просто нет: фича в ядре формально есть, но снаружи ядра недостижима. Патч, добавляющий опцию `SUPPORT` в `CREATE AGGREGATE` и форму `ALTER AGGREGATE ... SUPPORT`, [предложен в pgsql-hackers](https://www.postgresql.org/message-id/flat/8f58c96d-d3c7-4c0f-9898-116f00eeaff6@gmail.com). Пока он не закоммичен, и здесь мы выполним работу DDL вручную. Кроме C-функции, скрипт расширения объявляет пару plpgsql-хелперов — `agg_support_attach()` и `agg_support_detach()`. Суть attach — две записи в системный каталог, ровно те, что сделал бы DDL:

```sql
UPDATE pg_catalog.pg_proc
   SET prosupport = 'sum_agg_support'::regproc
 WHERE oid = 'pg_catalog.sum(numeric)'::regprocedure;

-- обычная (NORMAL) зависимость: теперь sum(numeric) будет зависеть от sum_agg_support
INSERT INTO pg_catalog.pg_depend
       (classid, objid, objsubid, refclassid, refobjid, refobjsubid, deptype)
VALUES ('pg_catalog.pg_proc'::regclass, 'pg_catalog.sum(numeric)'::regprocedure, 0,
        'pg_catalog.pg_proc'::regclass, 'sum_agg_support'::regproc, 0, 'n');
```

Зависимость `deptype = 'n'` (NORMAL) в [`pg_depend`](https://www.postgresql.org/docs/19/catalog-pg-depend.html) означает «объект нельзя удалить, пока на него ссылаются».

Без второй записи можно было бы и обойтись — но недолго, и сейчас увидим почему.

Подключаемся — прямо к встроенному `sum(numeric)`, планировщику всё равно, чей агрегат перед ним:

```sql
SELECT agg_support_attach('pg_catalog.sum(numeric)'::regprocedure);
EXPLAIN (VERBOSE, COSTS OFF) SELECT sum(x ORDER BY x) FROM t;
 Aggregate
   Output: sum(x)
   ->  Seq Scan on public.t
```

Вот здесь ручная запись в `pg_depend` и перестаёт быть формальностью. Если удалить расширение, то `prosupport` у `sum(numeric)` станет указывать в пустоту, после чего каждый запрос с `sum(numeric)` будет падать на планировании с `cache lookup failed for function NNNNN`, пока кто-нибудь не обнулит поле обратно. С зависимостью же система сама не даст выстрелить себе в ногу:

```sql
=# DROP EXTENSION agg_support;
ERROR:  cannot drop function sum(numeric) because it is required by the database system
```

Сообщение не самое говорящее — механизм зависимостей дошёл по нашей записи до pinned-объекта `sum(numeric)` и отказался его трогать, — но провал безопасный: не поможет даже `CASCADE`. Порядок наводится штатно: сначала `agg_support_detach('pg_catalog.sum(numeric)')` — симметричный хелпер, обнуляющий `prosupport` и удаляющий запись из `pg_depend`, — затем `DROP EXTENSION`.

Заметим, что кастомные prosupport-функции намеренно не переживают pg_dump/restore и pg_upgrade. Если на новом кластере есть необходимость использовать ту же оптимизацию, то attach придётся повторить.

## Смотрим на результат

Итак, проверим, работает ли наше расширение. Сборка стандартная для расширений (нужен PostgreSQL 19+). Создаём расширение в базе и прошиваем наш агрегат в системном каталоге:

```bash
psql -c "CREATE EXTENSION agg_support"
psql -c "SELECT agg_support_attach('pg_catalog.sum(numeric)'::regprocedure)"
```

Возьмём табличку с numeric и сравним планы. До подключения встроенный `sum` честно сортирует:

```sql
EXPLAIN (VERBOSE, COSTS OFF) SELECT sum(x ORDER BY x) FROM t;
 Aggregate
   Output: sum(x ORDER BY x)
   ->  Sort
         Output: x
         Sort Key: t.x
         ->  Seq Scan on public.t
               Output: x
```

После attach планировщик вызвал нашу функцию поддержки — и от `ORDER BY` не осталось следа, узел Sort исчез вместе с ним:

```sql
EXPLAIN (VERBOSE, COSTS OFF) SELECT sum(x ORDER BY x) FROM t;
 Aggregate
   Output: sum(x)
   ->  Seq Scan on public.t
         Output: x

=# SELECT sum(x ORDER BY x) = sum(x) AS same FROM t;
 same
------
 t
```

## Заключение

Профит ровно тот, что мы прикидывали в начале: запрос из вступления, тот самый на 10 миллионах строк, после подключения функции поддержки укладывается в 3,5 секунды вместо 5,7 — минус треть времени. И это не «почти как без сортировки», а буквально столько же, сколько занимает `sum(x)`, написанный без `ORDER BY`: сортировка исчезла не только из плана, но и из профиля выполнения. Запрос при этом не тронут, ядро не пропатчено, приложение ничего не знает.

Разрешив трансформацию агрегатной функции, PostgreSQL открыл путь фантазии разработчиков — сделать с агрегатом можно всё, что угодно. Это позволит «подчищать» плохо или избыточно сгенерированные запросы и подстраивать агрегаты под конкретные условия эксплуатации СУБД. Здесь мы разобрали простой пример, который всего лишь устраняет неаккуратность генератора запросов. Более серьёзным примером может служить подстановка оптимизированной версии `SUM()`, когда на входе numeric заведомо известного и небольшого масштаба, — см. прототип расширения [pg_numeric_agg_support](https://github.com/danolivo/pg_numeric_agg_support) на GitHub: на группирующих запросах он снимает 40–50% времени и до 70% памяти хеш-таблицы.

Не хватает малого — DDL, чтобы расширения могли пользоваться этим механизмом, не залезая в системный каталог руками. Если тема вам близка, поучаствуйте в [обсуждении патча](https://www.postgresql.org/message-id/flat/8f58c96d-d3c7-4c0f-9898-116f00eeaff6@gmail.com) в pgsql-hackers.
