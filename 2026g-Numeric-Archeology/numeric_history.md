
## Откуда вообще взялся numeric

Прежде чем менять код, полезно знать, при каких обстоятельствах он родился. Хронология восстанавливается по git и по архивам pgsql-hackers довольно точно.

**До 6.5 никакого точного десятичного типа не было вовсе.** В Postgres95 из вещественных типов только `float4` и `float8` — ни `numeric`, ни `decimal`. В 6.4 слова `NUMERIC` и `DECIMAL` в грамматике уже были, но это была имитация: парсер [подменял их на `integer`](https://github.com/postgres/postgres/blob/REL6_4_2/src/backend/parser/gram.y#L2951-L2963) и [ругался на всё, что туда не влезало](https://github.com/postgres/postgres/blob/REL6_4_2/src/backend/parser/gram.y#L2992-L3026):

```c
opt_numeric:  '(' Iconst ',' Iconst ')'
                {
                    if ($2 != 9)
                        elog(ERROR,"NUMERIC precision %d must be 9",$2);
                    if ($4 != 0)
                        elog(ERROR,"NUMERIC scale %d must be zero",$4);
                }
```

То есть попытка объявить `NUMERIC(10,5)` вызвала бы ошибку, а `NUMERIC(9,0)` — молча стал бы целым числом. Сами разработчики [называли](https://www.postgresql.org/message-id/3679FF70.FBDCB083%40alumni.caltech.edu) это в переписке «brain-damaged».

**Настоящий тип появился 30 декабря 1998 года**, коммит [`0e9d75c6ac`](https://github.com/postgres/postgres/commit/0e9d75c6ac97cfb370313b0aff803f9f464d0758), Jan Wieck. Мотив зафиксирован в [письме](https://www.postgresql.org/message-id/m0zr4z8-000EBPC%40orion.SAPserv.Hamburg.dsh.de), за двенадцать дней до коммита. Это ответ на пункт TODO-листа «Add full ANSI SQL capabilities»:

> And NUMERIC (NUMBER in Oracle :-) is defined as a datatype that uses exact representation of arbitrary precise numbers. But everyone has different legal value ranges and defaults for it. The ranges for the precision (number of total digits) varies from 38 (Oracle) to over 1000 sometimes.
>
> I'll hack around a little on it to see what's possible for us.

То есть причина переменной длины была не в том, чтобы сделать быстрый десятичный тип, а «выполнить требование стандарта про произвольную точность, и не хуже, чем у соседей». Цена был понятна [сразу](https://www.postgresql.org/message-id/367B1658.6B3BD9%40alumni.caltech.edu):

> This is probably the worst part, since you would hate to take the hit representing everything as extended precision even if the actual range is int4/float8.

А сам Jan в день коммита [написал](https://www.postgresql.org/message-id/m0zvBJ1-000EBPC%40orion.SAPserv.Hamburg.dsh.de) фразу, которая хорошо описывает его приоритеты: «Postgres shouldn't become a substitute for arbitrary precision calculators».

**Ключевой момент — 2001 год.** Марк Батлер предложил сделать `numeric` фиксированной длины ради скорости. [Ответ](https://www.postgresql.org/message-id/3077.987145046%40sss.pgh.pa.us) Тома Лейна — это, по сути, окончательное архитектурное решение, действующее до сих пор:

> If we were willing to restrict `numeric` values to a much tighter range, perhaps so. I rather like a `numeric` type that can handle ranges wider than double precision, however.
>
> I don't have any objection in principle to an additional datatype "small numeric", or some such name, with a different representation. I do object to emasculating the type we have.
>
> (I think it'd be far more helpful to reimplement `numeric` using base-10000 representation --- four decimal digits per int16 --- and then eliminate the distinction between storage format and computation format.)

Замеры Батлера в том же треде — миллион сложений: PL/pgSQL `numeric` 14,8 с, float8 10,7 с, Oracle PL/SQL number 2,0 с. То есть жалоба была обоснованной, но решение приняли в пользу универсальности типа, а не скорости.

Дальше — чистая история оптимизации представления. Перечислим ключевые моменты:

- **7.4 (2003).** Том Лейн переписывает `numeric` на base-10000, коммит [`d72f6c7503`](https://github.com/postgres/postgres/commit/d72f6c75038d8d37e64a29a04b911f728044d83b): «I see about a factor of ten speedup on the 'numeric' regression test». До этого арифметика шла по одной десятичной цифре на байт, а на диске лежало BCD — по две цифры в байте, то есть каждая операция начиналась с распаковки. Заодно из заголовка выкинули `n_rscale`: 10 байт → 8. Сама идея base-10000, кстати, [не Лейна, а Вика](https://www.postgresql.org/message-id/m10ctKO-000EBPC%40orion.SAPserv.Hamburg.dsh.de), он её предложил ещё в апреле 1999-го.
- **8.3 (2007).** Однобайтовый varlena-заголовок Грега Старка плюс перестановка полей `numeric` (коммит `f828f878e9`) — специально, чтобы потом можно было ужать заголовок без слома совместимости.
- **9.1 (2011).** Роберт Хаас добавляет двухбайтовый `NumericShort`-заголовок, коммит [`145343534c`](https://github.com/postgres/postgres/commit/145343534c153d1e6c3cff1fa1855787684d9a38). Итог: типичное значение несёт 3 байта служебных данных вместо исходных 10.
- **14 (2021).** Том Лейн добавляет `Infinity`/`-Infinity`, коммит `a57d312a77`. `NaN` был с самого первого коммита 1998 года.

Итого: `numeric` — это тип, спроектированный под требование стандарта о произвольной точности, который потом дорабатывался. Всё, что дальше в статье, — следствия того решения 1998 года и его подтверждения в 2001-м.

---

## Америку я не открываю

Медлительность numeric — старая тема в pgsql-hackers, работа идёт больше десяти лет подряд. Хронология с конкретикой, потому что в популярных пересказах эти пункты обычно перепутаны:

- **2012.** Коммит [`5cb0e33597`](https://github.com/postgres/postgres/commit/5cb0e335976befdcedd069c59dd3858fb3e649b3) «Speed up operations on numeric, mostly by avoiding palloc() overhead». Автор патча — Kyotaro Horiguchi, коммитил Heikki Linnakangas, вышло в 9.3. Появился `init_var_from_num()`: `NumericVar` кладётся на стек, а его `digits` указывают прямо внутрь исходного значения, без `palloc` + `memcpy`. Важная деталь, которую обычно упускают: это касается **арифметики, вывода и приведений** — `numeric_add/sub/mul/div`, `numeric_out`, `numeric_int8`. Функций сравнения и хэширования патч не трогает вообще, `cmp_numerics()` никогда и не пользовался `NumericVar`. В [исходном письме Хоригучи](https://www.postgresql.org/message-id/20120914.172508.259995810.horiguchi.kyotaro@lab.ntt.co.jp) есть базовая линия, которая нам ещё пригодится: `sum()` по 10 млн строк — int 1570 мс, numeric 3930 мс, то есть 2,5×; его патч давал 11 %.
- **2013.** Крейг Рингер предлагает [добавить десятичную плавающую точку IEEE 754:2008 вместе с аппаратной поддержкой](https://www.postgresql.org/message-id/flat/51B7B932.3000407%402ndquadrant.com). Тред закрыл Том Лейн в тот же день: «As near as I can tell, there is no such hardware support… On the whole, I think the effort would be a lot more usefully spent on trying to make the existing NUMERIC support go faster». Патча так и не появилось. К этой ветке мы ещё вернёмся в разделе про decimal128.
- **2013, отдельно.** [Ускорение avg(numeric)](https://www.postgresql.org/message-id/51DAF8E4.20402%40agliodbs.com) — тред закончился коммитом `69c8fbac20` (патч Hadi Moshayedi, коммитил Том Лейн, PostgreSQL 9.4): `sum`/`avg`/`stddev`/`variance` переехали на `INTERNAL`-состояние вместо массива numeric. Заявленные в треде «+25 % на sum и +50 % на avg» — это цифры Павла Стехуле, процитированные Джошем Беркусом, а не результат финального коммита.
- **2015.** [«Using 128-bit integers for sum, avg and statistics aggregates»](https://commitfest.postgresql.org/3/26/), коммиты `8122e1437e` и `959277a4f5`, PostgreSQL **9.5**. Автор — Andreas Karlsson, коммитил Andres Freund (их часто путают). Самые говорящие числа во всей хронологии — из [письма Карлссона](https://www.postgresql.org/message-id/544BB5F1.50709@proxel.se), 10 млн строк, меняется только аккумулятор:

  | запрос | накопитель numeric | накопитель int128 |
  |---|---|---|
  | `sum(int8)` | 2521 мс | 1023 мс |
  | `var_samp(int4)` | 3809 мс | 1033 мс |

  Заметьте: колонки тут целочисленные, numeric вылезает как *внутренний* тип агрегата. Это одна из самых частых ситуаций, когда пользователь упирается в numeric, ни разу его не объявив.
- **2024.** Joel Jacobson и Dean Rasheed разогнали [умножение](https://www.postgresql.org/message-id/CAEZATCV2qPTGo2Fd8xDs06Q7iU5aorgSa9+Fw9zkuQv1y15rcw@mail.gmail.com) и [деление](https://www.postgresql.org/message-id/CAEZATCVHR10BPDJSANh0u2+Sg6atO3mD0G+CjKDNRMD-C8hKzQ@mail.gmail.com). Всё это в PostgreSQL 18, в release notes одна строка: «Improve the speed of numeric multiplication and division (Joel Jacobson, Dean Rasheed)», четыре коммита — `ca481d3c9a`, `c4e44224c`, `8dc28d7eb8`, `9428c001f6`.

  Здесь надо быть аккуратным с цифрами, которые кочуют по пересказам. Знаменитое «от 25 до 81 %» — это [реплика Джоэла Джейкобсона от 5 июля 2024](https://www.postgresql.org/message-id/ce08a807-b3ca-4316-8fcf-98be5dec10a2%40app.fastmail.com), дословно «Impressive speed-up, between 25% - 81%», и относится она к **промежуточной версии v7** патча `mul_var_small`, замеренной **микробенчмарком самой функции `numeric_mul()`**, на операндах в 1–4 базовые цифры (то есть до 16 десятичных), на трёх процессорах. Разброс 1,25× (Core i9-14900K, 1×1 цифра) — 1,81× (Apple M3 Max, 3×3). На уровне запроса `SELECT SUM(var1*var2)` тот же автор получил 11–13 %. Финальные же коммиты меряются иначе: `8dc28d7eb8` (арифметика по основанию NBASE²) обещает «between around 3 and 6 times» на длинных числах — и честно предупреждает о замедлении на 32-битных машинах; `9428c001f6` — «up to around 20 times as fast as the old Knuth algorithm when 'exact' is true».
- **2025.** Ветка [«Improving and extending int128.h to more of numeric.c»](https://www.postgresql.org/message-id/CAEZATCWgBMc9ZwKMYqQpaQz2X6gaamYRB+RnMsUNcdMcL2Mj_w@mail.gmail.com) закоммичена — пять коммитов Дина Рашида в августе 2025, ключевой `d699687b32`, всё это в PostgreSQL **19**. Только это не про ускорение арифметики numeric: речь про то, чтобы `SUM(int8)`, `AVG(int8)`, `stddev`/`var` от int2/int4 считались в 128 битах **на всех платформах**, а не только там, где у компилятора есть родной `__int128`. Дин мерил ~1,3–1,5× на 32-битной системе, Джон Нейлор — 3015 → 2206 мс на s390x. В release notes PostgreSQL 19 отдельной строки про это нет; главным мотивом сам автор называл упрощение кода: «Even if this had zero performance benefit… it's worth doing».

Обратите внимание на закономерность. Почти всё перечисленное — про **арифметику**: умножение, деление, агрегаты. А самая дорогая статья в моём замере, как выяснится дальше, лежит совсем не там.

---
