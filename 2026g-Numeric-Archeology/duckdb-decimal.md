# DECIMAL в DuckDB: устройство, история, компромисс

> Рабочая заметка к разделу «Что имеется в стандарте SQL ISO/IEC 9075-2:2023»
> (см. [decimal-for-money-standards.md](decimal-for-money-standards.md), абзац про Arrow,
> SQL Server и DuckDB).
>
> **Статус проверки.** Всё, что ниже, сверено по исходникам DuckDB
> ([duckdb/duckdb](https://github.com/duckdb/duckdb), тег `v1.5.5` и `main`), по
> официальной документации и по истории git. Числа в разделе «Измерения» получены на этой
> машине; методика описана там же. Непроверенных утверждений в тексте не осталось.

---

## 1. Устройство

`DECIMAL(width, scale)`, значение хранится как масштабированное целое
`n = value × 10^scale`. Физический носитель выбирается по объявленной ширине.

Из [`src/include/duckdb/common/types/decimal.hpp`](https://github.com/duckdb/duckdb/blob/main/src/include/duckdb/common/types/decimal.hpp):

```cpp
template <> struct DecimalWidth<int16_t>   { static constexpr uint8_t max = 4;  };
template <> struct DecimalWidth<int32_t>   { static constexpr uint8_t max = 9;  };
template <> struct DecimalWidth<int64_t>   { static constexpr uint8_t max = 18; };
template <> struct DecimalWidth<hugeint_t> { static constexpr uint8_t max = 38; };
```

То же в [документации](https://duckdb.org/docs/stable/sql/data_types/numeric):

> «Internally, decimals are represented as integers depending on their specified `WIDTH`.»

| Width | Internal | Size (bytes) |
|---|---|---|
| 1–4 | INT16 | 2 |
| 5–9 | INT32 | 4 |
| 10–18 | INT64 | 8 |
| 19–38 | INT128 | 16 |

> «The `WIDTH` must be between 1 and 38»
>
> «The default `WIDTH` and `SCALE` is `DECIMAL(18, 3)`, if none are specified.»

Проверено на месте (DuckDB 1.5.5):

```
SELECT typeof(CAST(1 AS DECIMAL))   -> DECIMAL(18,3)
CAST(1 AS DECIMAL(39,2))            -> Binder Error: DECIMAL type width must be between 1 and 38
CAST(1 AS DECIMAL(20,25))           -> Binder Error: DECIMAL type scale cannot be greater than width
```

Это в точности форма из подраздела 4.5.2 стандарта — `n × 10⁻ˢ`, где `n` — целое в
диапазоне `−R^P ≤ n < R^P`. Только `P` здесь не «сколько угодно», а «сколько влезло в
выбранный int».

---

## 2. Главное: DuckDB отказывается расширять тип ради скорости

Это самый интересный факт, и он не в документации, а в коде — в комментарии.

[`src/function/scalar/operator/arithmetic.cpp`](https://github.com/duckdb/duckdb/blob/v1.5.5/src/function/scalar/operator/arithmetic.cpp#L213-L227),
вывод типа результата сложения и вычитания:

```cpp
uint8_t required_width = MaxValue<uint8_t>(max_scale + max_width_over_scale, max_width);
if (!IS_MODULO) {
    // for addition/subtraction, we add 1 to the width to ensure we don't overflow
    required_width = NumericCast<uint8_t>(required_width + 1);
    if (required_width > Decimal::MAX_WIDTH_INT64 && max_width <= Decimal::MAX_WIDTH_INT64) {
        // we don't automatically promote past the hugeint boundary to avoid the large
        // hugeint performance penalty
        bind_data->check_overflow = true;
        required_width = Decimal::MAX_WIDTH_INT64;
    }
}
```

Дословно: **«мы не расширяем автоматически за границу hugeint, чтобы избежать большого
штрафа за производительность hugeint»**. Точно такой же блок стоит в выводе типа умножения
(там же, ветка `BindDecimalMultiply`).

Практический результат — измерено на колонках таблицы, не на константах:

| выражение | результат | комментарий |
|---|---|---|
| `DECIMAL(4,2) + DECIMAL(4,2)` | `DECIMAL(5,2)` | честное `+1` |
| `DECIMAL(9,2) + DECIMAL(9,2)` | `DECIMAL(10,2)` | честное `+1` |
| `DECIMAL(18,2) + DECIMAL(18,2)` | **`DECIMAL(18,2)`** | должно быть 19 — упёрлось в int64 |
| `DECIMAL(38,2) + DECIMAL(38,2)` | `DECIMAL(38,2)` | упёрлось в int128 |
| `DECIMAL(4,2) * DECIMAL(4,2)` | `DECIMAL(8,4)` | `w1+w2` |
| `DECIMAL(10,2) * DECIMAL(10,2)` | **`DECIMAL(18,4)`** | должно быть 20 — прижато к int64 |
| `DECIMAL(18,2) * DECIMAL(18,2)` | **`DECIMAL(18,4)`** | должно быть 36 — прижато к int64 |
| `DECIMAL(20,2) * DECIMAL(20,2)` | `DECIMAL(38,4)` | вход уже int128 |

То есть DuckDB **сохраняет масштаб** (`s1+s2` для умножения — как требует стандарт), но
**не сохраняет точность**: ширина результата прижимается к границе физического контейнера
входных операндов. Риск переполнения не устраняется, а переносится в рантайм:

```
SELECT CAST(999999999999999999 AS DECIMAL(18,0)) * CAST(999999999999999999 AS DECIMAL(18,0));
-- Out of Range Error: Overflow in multiplication of DECIMAL(18)
--   (999999999999999999 * 999999999999999999).
--   You might want to add an explicit cast to a bigger decimal.
```

Формально это стандарту не противоречит: для умножения ISO SQL фиксирует масштаб, а
точность оставляет implementation-defined. Но по духу — это ровно противоположное
PostgreSQL решение.

### Как убирается стоимость проверки

Проверка переполнения — это ветка на каждый элемент
([`add.cpp`](https://github.com/duckdb/duckdb/blob/main/src/function/scalar/operator/add.cpp#L235-L247)):

```cpp
static bool TryDecimalAddTemplated(T left, T right, T &result) {
    if (right < 0) { if (min - right > left) return false; }
    else           { if (max - right < left) return false; }
    result = left + right;
    return true;
}
```

Обратите внимание на границы: для int64 это `±999999999999999999`, то есть `10^18−1` —
десятичная граница ширины, а не граница int64. Запас между `10^18` и `9.22×10^18` не
используется, он и есть место для «одной лишней цифры» до срабатывания проверки.

Но эта ветка не всегда исполняется. `PropagateNumericStats` в
[`arithmetic.cpp`](https://github.com/duckdb/duckdb/blob/main/src/function/scalar/operator/arithmetic.cpp#L234-L246)
на этапе оптимизации по min/max-статистике колонки доказывает, что переполнение
невозможно, и подменяет функцию на версию без проверки:

```cpp
} else {
    // no potential overflow: replace with non-overflowing operator
    if (input.bind_data) {
        auto &bind_data = input.bind_data->Cast<DecimalArithmeticBindData>();
        bind_data.check_overflow = false;
    }
    expr.FunctionMutable().SetFunctionCallback(
        GetScalarIntegerFunction<BASEOP>(expr.GetReturnType().InternalType()));
}
```

Вот это и есть механизм, который делает точную десятичную арифметику бесплатной: цикл
превращается в безусловное целочисленное сложение, которое компилятор автовекторизует.
(Проверено по коду; ассемблер я не смотрел.)

---

## 3. Деление: официально уходит в double

Здесь была самая сильная гипотеза в первой версии заметки — подтвердилась дословно.

[Документация](https://duckdb.org/docs/stable/sql/data_types/numeric):

> «Division of fixed-point decimals does not typically produce numbers with finite decimal
> expansion. Therefore, DuckDB uses approximate floating-point arithmetic for all divisions
> that involve fixed-point decimals and accordingly returns floating-point data types.»

Измерено:

```
typeof(DECIMAL(10,2) / DECIMAL(10,2))   -> DOUBLE     (1/3 = 0.3333333333333333)
typeof(DECIMAL(38,10) / DECIMAL(38,10)) -> DOUBLE
typeof(DECIMAL(10,2) // DECIMAL(10,2))  -> DOUBLE
typeof(DECIMAL(10,2) % DECIMAL(10,2))   -> DECIMAL(10,2)   -- остаток остаётся точным
typeof(AVG(DECIMAL(10,2)))              -> DOUBLE
typeof(PRODUCT(DECIMAL(10,2)))          -> DOUBLE
typeof(SUM(DECIMAL(10,2)))              -> DECIMAL(38,2)   -- аккумулятор int128
```

Для темы статьи это существенно: **`AVG` по денежной колонке в DuckDB — это IEEE-754
double.** Регламент ЕС 1103/97 с его «shall not be rounded or truncated» и требованием
детерминированного результата на таком типе не выполняется. Ровно та граница, по которой
в тексте проходит различие между транзакционными и аналитическими бенчмарками TPC.

Обратная сторона: точное десятичное сложение и умножение в DuckDB есть, а вот
восстановить точное деление в рамках этого дизайна нельзя в принципе — расширять `P`
некуда.

---

## 4. Измерения

> Своя методика, не чужой бенчмарк. Опубликованного анализа именно этой оптимизации найти
> не удалось: ни в блоге DuckDB, ни в статьях — только фраза в документации «decimal
> values with a width above 19 are slow». Числа ниже мои.
>
> Apple M4 Pro (14 ядер), 24 ГБ. DuckDB 1.5.5, `SET threads=1`, персистентная БД,
> 20 000 000 строк, значения `(hash(i)%1000)/100.0` — диапазон 0.00…9.99, 1000 различных
> значений (данные подобраны так, чтобы не вырождались в RLE). Лучшее из 5 прогонов.
> `scan` — это `SELECT count(*) FROM d WHERE v IS NOT NULL`, то есть стоимость чтения
> колонки без арифметики.

| тип | физический | scan, мс | `SUM(v)`, мс | арифметика (sum−scan) | `SUM(v*v)`, мс |
|---|---|---|---|---|---|
| `DECIMAL(9,2)` | int32 | 6.6 | 9.1 | 2.5 | 40.0 |
| `DECIMAL(18,2)` | int64 | 5.2 | **8.7** | 3.5 | 13.9 |
| `DECIMAL(19,2)` | int128 | 804.4 | **886.5** | 82.0 | 914.2 |
| `DECIMAL(38,2)` | int128 | 817.9 | 893.3 | 75.4 | 986.0 |
| `BIGINT` | int64 | 5.4 | 8.5 | 3.1 | 14.4 |
| `HUGEINT` | int128 | 820.3 | 904.3 | 84.0 | 953.2 |
| `DOUBLE` | double | 9.0 | **19.2** | 10.2 | 21.0 |

Четыре вывода из таблицы.

**1. Точность здесь бесплатна — и даже прибыльна.** `DECIMAL(18,2)` считает сумму в
**2.2 раза быстрее**, чем `DOUBLE` (8.7 против 19.2 мс). Целочисленное сложение дешевле
плавающего, а колонка целых сжимается BitPacking'ом, тогда как для `DOUBLE` включается
ALP — более дорогой кодек. Тезис «точный тип медленнее приближённого» в этой архитектуре
просто неверен.

**2. `DECIMAL(18,2)` неотличим от `BIGINT`** (8.7 против 8.5 мс). Никакой «надбавки за
десятичность» нет: масштаб живёт в каталоге, в рантайме это обычное целое.

**3. Обрыв на границе 19 — стократный.** 8.7 → 886.5 мс, это ×102. И `HUGEINT` ведёт себя
идентично `DECIMAL(19,2)` и `DECIMAL(38,2)`, значит платится не за десятичную логику, а
именно за 128-битный носитель. Причём основная часть штрафа приходится на **чтение**
колонки (804 мс из 886), а не на арифметику (82 мс) — распаковка int128 дороже самого
сложения.

**4. Узкие типы могут быть медленнее на умножении.** `DECIMAL(9,2)` даёт 40.0 мс против
13.9 мс у `DECIMAL(18,2)`, потому что `DECIMAL(9,2) * DECIMAL(9,2) → DECIMAL(18,4)`
пересекает границу int32→int64 и требует приведения обоих операндов; у `DECIMAL(18,2)`
результат остаётся в int64 и приведения не нужно. Практический совет из этого:
`DECIMAL(18,2)` — оптимальная точка для денег, а не «возьмём поуже, будет быстрее».

### Для сравнения — PostgreSQL на тех же данных

PostgreSQL 20devel, та же машина, те же 20 млн значений, `jit=off`, куча 996 МБ.

| запрос | 1 поток | 2 параллельных воркера |
|---|---|---|
| `count(*) WHERE n IS NOT NULL` | 574 мс | — |
| `sum(n)`, `numeric(18,2)` | 581 мс | 271 мс |
| `sum(n*n)` | 1253 мс | 462 мс |
| `sum(f)`, `float8` | 451 мс | 177 мс |
| `sum(b)`, `bigint` | 476 мс | 185 мс |

Кросс-сравнение движков (581 против 8.7 мс, ×67) читать буквально нельзя: там строчное
хранение и заголовки кортежей, тут колоночное со сжатием. Честно сравнивать надо
**внутри** движка:

- PostgreSQL: `numeric` / `float8` = 581 / 451 = **×1.29**. Точность стоит денег.
- DuckDB: `DECIMAL(18,2)` / `DOUBLE` = 8.7 / 19.2 = **×0.45**. Точность не стоит ничего.

Ещё одна деталь не в пользу расхожего мнения: по `pg_column_size` колонка
`numeric(18,2)` на этих данных занимает 129 МиБ против 153 МиБ у `float8`. Короткий
`numeric` в PostgreSQL **компактнее** double — весь его оверхед сидит в арифметике и в
аллокациях, а не в размере.

---

## 5. История: когда и откуда

**До августа 2020 года точного десятичного типа в DuckDB не было вообще.**

Из тела [PR #858 «Fixed-precision DECIMAL types»](https://github.com/duckdb/duckdb/pull/858),
Mark Raasveldt:

> «This PR implements correct fixed-precision decimal types. **Before this, DECIMAL was an
> alias for DOUBLE.** Now decimals are implemented. The maximum width supported by DECIMAL
> is 38. The default decimal is DECIMAL(18,3)…»

Хронология по git:

| дата | что |
|---|---|
| 2019-04-02 | коммит `4b79d862f7` «Map decimal type to double in C API» — фиксирует, чем `DECIMAL` был раньше |
| 2020-08-04 | `bb0396e9fa` — появляется `HUGEINT` (int128), [PR #819](https://github.com/duckdb/duckdb/pull/819) |
| 2020-08-11 | `8cec822ce7` «Initial support for DECIMAL type: parsing to and from strings now working» |
| 2020-08-14 | [PR #835](https://github.com/duckdb/duckdb/pull/835) «Types Rework» — разделение `LogicalType` / `PhysicalType` |
| 2020-08-18 | `014c830c2d` — арифметика над decimal; ради неё переработан порядок биндинга функций |
| 2020-08-29 | PR #858 влит Ханнесом Мюлайзеном, вышло в **v0.2.1** (29.08.2020) |

Порядок здесь неслучаен и хорошо читается.

**Сначала построили носитель.** [PR #819](https://github.com/duckdb/duckdb/pull/819),
за неделю до начала работы над decimal:

> «The primary purpose of the HUGEINT type is overflow prevention (**and in the future,
> larger decimal support**).»

**Потом переделали систему типов.** [PR #835](https://github.com/duckdb/duckdb/pull/835)
ввёл разделение логического и физического типа именно потому, что несколько логических
типов ложатся на один физический — и `DECIMAL` в этом списке фигурирует четырежды:

> ```
> {SMALLINT(, DECIMAL)}          -> INT16
> {INTEGER, DATE, TIME(, DECIMAL)} -> INT32
> {BIGINT, TIMESTAMP(, DECIMAL)} -> INT64
> {HUGEINT, DECIMAL)}            -> INT128
> ```

То есть архитектурная предпосылка — «масштаб живёт в каталоге, в рантайме это целое» —
была вынесена в отдельный рефакторинг ядра ещё до самого типа.

**И только потом — арифметика.** Коммит `014c830c2d` описывает, почему пришлось менять
порядок биндинга: биндинг функции должен происходить *до* приведения аргументов, «чтобы
функция `+(DECIMAL, DECIMAL)` могла сама решить, к какому именно decimal-типу
(width/scale) приводить входы». Это и есть тот код из раздела 2.

---

## 6. Откуда идея

Ниоткуда специально — это наследство MonetDB, и линия прямая.

DuckDB сделан в CWI (Амстердам), в группе Database Architectures — той же, что делает
MonetDB. Репозиторий до переезда назывался **`cwida/duckdb`** (видно по merge-коммитам
августа 2020: `Merge branch 'decimal' of github.com:cwida/duckdb`). Оба автора —
Марк Раасвельдт и Ханнес Мюлайзен — оттуда же.

[Документация MonetDB, Base Types](https://www.monetdb.org/documentation/user-guide/sql-manual/data-types/base-types/):

> «The decimal types are represented as **fixed length integers, whose decimal point is
> produced during result rendering**.»

И раскладка по ширине там же:

| Prec | байт |
|---|---|
| 1–2 | 1 |
| 3–4 | 2 |
| 5–9 | 4 |
| 10–18 | 8 |
| 19–38 | 16 (когда поддержан HUGEINT) |

Совпадение полное, включая ту же зависимость от наличия 128-битного целого и ту же пару
границ 18/38. DuckDB лишь выкинул однобайтовый ярус (начинает с int16). Это не
заимствование идеи — это перенос конкретной реализации из предыдущей системы той же
лаборатории.

Дальняя предыстория той же линии — MonetDB/X100 (позже Vectorwise/Actian Vector),
CIDR 2005, где вся идея векторизованного исполнения строится на том, что колонка должна
быть плоским массивом значений фиксированной ширины. Тип переменной длины с указателем в
эту модель не помещается по построению. Так что «decimal поверх целого» здесь не выбор из
двух вариантов, а единственный способ вообще иметь точный десятичный тип в векторном
движке.

Косвенное подтверждение того же — Arrow и Parquet, которые определяют decimal ровно так
же и по тем же причинам.

---

## 7. Что даёт и чего стоит

### Плюсы

**Фиксированная ширина.** Значение не имеет заголовка, не лежит по указателю и не требует
аллокации. Колонка `DECIMAL(18,2)` — плоский массив int64. Постгрессовый `numeric` —
varlena с переменным числом base-10000 «цифр», dscale и весом; каждая операция — разбор
структуры, `palloc` под результат и цикл по цифрам.

**Сложение при равном масштабе — целочисленное сложение**, и при доказуемом отсутствии
переполнения даже без проверки (раздел 2).

**Сравнение = сравнение целых** при равном масштабе. Сортировка, хеш-джойны, группировка
идут по тем же кодовым путям, что и для `bigint`.

**Сжатие.** Измерено: на decimal-колонках включается BitPacking, на `DOUBLE` — ALP.
Целочисленное представление доступно всему арсеналу integer-кодеков.

**Структурное совпадение с Parquet.** Проверено round-trip'ом: `DECIMAL(18,2)` пишется в
Parquet как физический `INT64` с логической аннотацией `Decimal(precision=18, scale=2)`,
`DECIMAL(38,2)` — как `FIXED_LEN_BYTE_ARRAY`. Никакой конвертации представления.

### Минусы

**Потолок 38 цифр, и это ошибка рантайма.** У `numeric` в PostgreSQL этой ситуации не
существует (до 131072 цифр слева от точки).

**Отказ от расширения ширины** (раздел 2) — переполнение возможно там, где по стандартным
правилам вывода точности его не было бы.

**Стократный обрыв на ширине 19** (раздел 4), и большая часть штрафа — в чтении колонки,
а не в арифметике.

**Деление и `AVG` — это `DOUBLE`** (раздел 3).

**Точность — свойство типа, а не значения.** Аргумент Python-документации про хвостовой
ноль (`1.30 + 1.20 = 2.50`) здесь работает, но значимость хранится в объявлении колонки.
Неограниченного варианта, где каждое значение несёт свой `dscale`, в DuckDB нет вовсе.

### Поправка к первой версии заметки

Утверждение «zero-copy с Arrow» было неверным. Проверено: DuckDB отдаёт в Arrow **всегда**
`decimal128`, независимо от ширины —

```
DECIMAL(4,2)  -> arrow decimal128(4, 2)   byte_width=16
DECIMAL(9,2)  -> arrow decimal128(9, 2)   byte_width=16
DECIMAL(18,2) -> arrow decimal128(18, 2)  byte_width=16
DECIMAL(38,2) -> arrow decimal128(38, 2)  byte_width=16
```

То есть для узких decimal при экспорте в Arrow происходит расширение с 2/4/8 байт до 16 —
это копия, а не zero-copy. Структурно 1:1 совпадение есть только с **Parquet**, который
для точности ≤ 18 использует физический `INT64`.

---

## 8. Компромисс

Одной фразой: **DuckDB обменял неограниченность точности на векторизуемость, а тихую
деградацию — на явную ошибку переполнения.**

Четыре следствия:

1. **Ответственность за диапазон переехала к пользователю.** В PostgreSQL «влезет ли» —
   не вопрос. В DuckDB это решение при проектировании схемы, и цена ошибки — упавший
   запрос. Причём, как показал раздел 2, упасть может и там, где по стандартным правилам
   вывода точности результат обязан был поместиться.
2. **Точность перестала быть платной.** Это неочевидный и, пожалуй, главный результат:
   при ширине ≤ 18 точный десятичный тип быстрее `DOUBLE`. Аргумент «numeric медленный,
   возьмём float» — свойство конкретной реализации PostgreSQL, а не свойство точной
   десятичной арифметики.
3. **Дальний хвост точности признан не нужным аналитике.** Согласуется с находкой по TPC:
   транзакционные бенчмарки требуют точного типа дословно, аналитические (TPC-H, TPC-DS)
   явно разрешают приближение. `AVG → DOUBLE` — это ровно вход в разрешённую TPC-H
   погрешность 1%.
4. **Формат обмена продиктовал внутреннее представление.** Parquet первичен, тип данных
   подстроен под него. У PostgreSQL история обратная: `numeric` спроектирован под свои
   требования, и любой экспорт — конвертация.
