# Почему в БД на PostgreSQL популярен тип `numeric`?

Тип `numeric` является важным числовым типом используемым в схеме БД многих приложений . Учитывая, что операции с этим типом значительно медленнее стандартных `int`/`bigint`/`real` или `double precision`, то я хочу прояснить вопрос: а действительно ли есть необходимость в такой точности? Можно же хранить денежные величины с точностью до копеек и округлять по стандартному правилу. - это бы могло прилично сэкономить вычислительные ресурсы наших серверов баз данных, разве нет?

Так что здесь я буду искать ответ на вопрос: правда ли, что `numeric` (или *точные десятичные типы*) — стандарт, пусть даже и де-факто, для финансовых приложений. Оправдано ли его применение, или это инженерный фольклор?

Короткий ответ: формального требования «используйте numeric для денег» не существует нигде — ни в ISO SQL, ни в законодательстве. Но существуют несколько независимых слоя требований, которым двоичная плавающая точка не удовлетворяет по построению.

---

## Что имеется в стандарте SQL SO/IEC 9075-2:2023

В ISO SQL нет ни типа MONEY. Нет не только типа — в стандарте языка SQL вообще отсутствует понятие валюты. Тип `money` в PostgreSQL и `money`/`smallmoney` в SQL Server — вендорские расширения, а не реализация стандарта.

Имеется три категории числовых типов:

- Exact numeric types: `NUMERIC`, `DECIMAL`, `SMALLINT`, `INTEGER`, `BIGINT`.
- Approximate numeric types: `FLOAT`, `REAL`, `DOUBLE PRECISION`.
- The decimal floating-point type: `DECFLOAT`.

У типов `Numeric` и `Decimal` есть небольшая семантическая разница.

Подраздел 6.1 «data type», Syntax Rules 28 и 29:
> 28) NUMERIC specifies the data type exact numeric, with the decimal precision and scale specified by the precision and scale.
> 29) DECIMAL specifies the data type exact numeric, with the decimal scale specified by the scale and the implementation-defined (ID063) decimal precision equal to or greater than the value of the specified precision.

Для понимания различия: NUMERIC(15,2) — это жёсткое ограничение ровно на 15 цифр, DECIMAL(15,2) — на «не меньше 15». По этому определению оба типа можно скомбинировать в один, чем и пользуется постгрессовый `numeric`.

Cтандарт не запрещает реализацию точного десятичного типа поверх двоичного целого. Это даёт возможность существовать вариантам реализации в Arrow, SQL Server, DuckDB и пр. Фиксированная ширина на int64/int128 — это предусмотренный им вариант.

Подраздел 4.5.2 «Characteristics of numbers»:
«An exact numeric type has a precision P and a scale S. P is a positive integer that determines the number of significant digits in a particular radix R, where R is either 2 or 10. S is a non-negative integer. Every value of an exact numeric type of scale S is of the form n × 10⁻ˢ, where n is an integer such that −Rᴾ ≤ n < Rᴾ.»

Итого. Точный десятичный тип входит в обязательное ядро SQL, равно как и `DECIMAL`/`NUMERIC`. А `DECFLOAT` — опциональная фича, наравне с `BIGINT`.

Также, для анализа требований к типу `numeric` важно, что стандарт SQL ничего не говорит про минимальную и максимальную точность, но накладывает ограничения на арифметику: масштаб сложения, вычитания и умножения задан жестко. Масштаб деления отдан на откуп реализации.

---

## Технические требования к финансовым операциям

Регламент Совета EC No. 1103/97 [о введении евро](https://eur-lex.europa.eu/legal-content/EN/TXT/HTML/?uri=CELEX:31997R1103) хорошо проработан и достаточно однозначно требует шесть значащих десятичных цифр без округления и усечения, и фиксирует детерминированное поведение при округлении за пределами точности. Тип `float` под такие требования не подходит.

Статья 4:
> «The conversion rates shall be adopted with six significant figures.»
>
> «The conversion rates **shall not be rounded or truncated** when making conversions.»
>
> «Inverse rates derived from the conversion rates shall not be used.»
>
> «Monetary amounts to be converted from one national currency unit into another shall
> first be converted into a monetary amount expressed in the euro unit, which amount may
> be rounded to not less than three decimals… **No alternative method of calculation may
> be used unless it produces the same results.**»

Статья 5:
> «Monetary amounts to be paid or accounted for when a rounding takes place after a
> conversion into the euro unit pursuant to Article 4 shall be rounded up or down to the
> nearest cent. … **If the application of the conversion rate gives a result which is
> exactly half-way, the sum shall be rounded up.**»

Великобритания, [HMRC VAT Trader Records, VATREC12030](https://www.gov.uk/hmrc-internal-manuals/vat-trader-records/vatrec12030). Требования к масштабу формулируются в долях пенни и точность в три знака после запятой.

> «If the VAT on any transaction comes to less than 0.5 of one penny, it should be rounded
> down. If the VAT comes to 0.5 of one penny or more, it should be rounded up.»

Чтобы проанализировать форматы обмена финансовыми данными, пришлось прибегнуть к помощи Claude.

ISO 20022. [Пример](https://raw.githubusercontent.com/yudhik/example-iso-20022/master/src/main/java/id/brainmaster/iso20022/model/pacs.008.001.07.xsd) (SWIFT, SEPA, платёжные системы) позволяет сделать вывод, что межбанковский стандарт — это структурно `NUMERIC(18,5)` плюс обязательный код валюты. Прямого запрета на плавающую точку в тексте нет, но суть понятна: в официальном JSON-биндинге суммы передаются строками, а значит фиксированный размер предпочтителен.
([ISO 20022 JSON Schema draft, 10.06.2025](https://www.iso20022.org/sites/default/files/media/file/ISO_20022_Generation_of_JSON_Schema_Draft_2020_12_for_ISO_20022_2013_10June2025.pdf)):
> «Number type are represented as strings because there was a preference for validating
> the total digits and fraction digits in the schema.»

**FIX** (биржевая торговля). В tag-value FIX 4.4 тип `float` определён как символьная
строка ([FIX 4.4 dictionary, Onix](https://www.onixs.biz/fix-dictionary/4.4/index.html)):

> «Sequence of digits with optional decimal point and sign character… All float fields must
> accommodate up to fifteen significant digits.»

В FIXML привязка [явная](https://fiximate.fixtrading.org/en/FIX.Latest/fixml_datatypes.html):
`float`, `Qty`, `Price`, `Amt`, `Percentage` → `xs:decimal`.

А в бинарной кодировке SBE - двоичный формат передачи данных на котором биржи гоняют потоки котировок - явно указано использовать десятичные кодировки для цен и всего денежного, а двоичная плавающая точка — только для тех числовых полей, которые не являются ценами или денежными суммами.
([FIX SBE v1.0 RC4, Field Encoding](https://github.com/FIXTradingCommunity/fix-simple-binary-encoding/blob/master/v1-0-RC4/doc/02FieldEncoding.md)):
> «Decimal encodings should be used for prices and related monetary data types like
> PriceOffset and Amt.»
>
> «Binary floating point encodings are compatible with IEEE Standard for Floating-Point
> Arithmetic (IEEE 754-2008). They should be used for floating point numeric fields **that
> do not represent prices or monetary amounts**.»

### А какие требования у стандартных TPC-бенчмарков?

Бенчмарк TPC-C требует точных вычислений и следования стандарту SQL.

[Standard Specification Rev. 5.11, клауза 1.3.1](https://www.tpc.org/tpc_documents_current_versions/pdf/tpc-c_v5.11.0.pdf) —
> Numeric fields that contain monetary values (W_YTD, D_YTD, C_CREDIT_LIM, C_BALANCE, C_YTD_PAYMENT, H_AMOUNT, OL_AMOUNT, I_PRICE) **must use data types that are defined by the DBMS as being an exact numeric data type** or that satisfy the ANSI SQL Standard definition of being an exact numeric representation.

То же самое имеется в требованиях TPC-E.

[v1.14.0, клауза 2.2.1](https://www.tpc.org/tpc_documents_current_versions/pdf/tpc-e_v1.14.0.pdf):
> «ENUM and SENUM… must be implemented using a Native Data Type which provides **exact representation** of at least n Digits of precision after the decimal place.»
>
> «BALANCE_T is defined as SENUM(12,2)… FIN_AGG_T is defined as SENUM(15,2)…»

Бенчмарки, ориентированные на аналитику - TPC-H и TPC-DS — снижают требования к точности. Для `Integer` требование точности сформулировано жёстко, а для `Decimal` нет - в агрегатах требования к точности требуют обеспечения 1% (AVG, ratios), "within $100" (SUM). Точное соответствие требуется только в COUNT.

[TPC-H v3.0.1, клауза 1.3.1](https://www.tpc.org/tpc_documents_current_versions/pdf/tpc-h_v3.0.1.pdf):
> «Decimal means that the column must be able to represent values in the range −9,999,999,999.99 to +9,999,999,999.99 in increments of 0.01; the values can be **either represented exactly or interpreted to be in this range**»

Интересный вывод: транзакционные бенчмарки требуют точного типа дословно, аналитические — явно разрешают приближение. Такое послабление потенциально позволяет включать различные оптимизации для запроса, объявленного как "аналитический".

Заглядывая в существующие СУБД, можно заметить, что Apache Druid не имеет точного числового типа и [отклонил](https://github.com/apache/druid/issues/10190) PR на эту тему. ClickHouse содержит Float64 для чисел и только [рекомендует](https://clickhouse.com/docs/sql-reference/data-types/float) использовать Decimal для операций, требующих повышенной точности. ElasticSearch и Power BI пошли по пути арифметических операций без потерь, но с фиксированной точностью.

При этом правила округления не зафиксированы и сильно различаются как между СУБД, так и между типами внутри одной СУБД. На эту тему есть [пост](https://wrschneider.github.io/2022/03/08/spark-rounding.html) Bill Schneider, который подметил заметную разницы в вычислениях на Spark и SQL Server. Поэтому, чтобы избежать неопределённостей, IBM  DB2 просто вынесла это в [настройки](https://www.ibm.com/docs/en/db2-for-zos/12.0.0?topic=registers-current-decfloat-rounding-mode).

### Что говорят вендоры СУБД

Если проанализировать документацию и публикации представителей разработки известных СУБД (см. ссылки yf на разделы документации [PostgreSQL](https://www.postgresql.org/docs/current/datatype-numeric.html), [SQL Server](https://learn.microsoft.com/en-us/sql/t-sql/data-types/float-and-real-transact-sql), [MySQL](https://dev.mysql.com/doc/refman/8.4/en/fixed-point-types.html), и [IBM](https://speleotrove.com/decimal/decifaq1.html)), то видно, что для точных вычислений (финансовые часто упоминаются прямо) они не рекомендуют использовать типы с двойной плавающей точкой. Прямой рекомендации обычно не даётся, что оставляет пространство для использования как `numeric`, так и целочисленного представления.

### 1С

**Тип «Число» в платформе** —
[ИТС, «Разрядность результатов выражений и агрегатных функций»](https://its.1c.ru/db/content/metod8dev/src/developers/platform/metod/query/i8102665.htm):
максимальная разрядность 38 знаков, нотация вида `Число(17,4)`, правила вывода разрядности
результата для сложения, умножения и деления. Там же оговорка: **«В DB2 максимум составляет
31, а не 38 знаков»** — косвенное, но сильное свидетельство, что «Число(N,M)» ложится прямо
в `DECIMAL/NUMERIC(N,M)` СУБД, раз ограничение платформы наследуется от ограничения СУБД.

### Итог по РФ

Прямого предписания «используйте точный десятичный тип» в российском законодательстве нет. Но из совокупности норм следует функционально эквивалентное требование:

1. **Хранение обязано быть точным до копейки** — ПП № 1137 требует рубли и копейки в счёте-фактуре, письма Минфина и ФНС запрещают там округление. Двоичный float не представляет 0,01 точно, значит система на `double precision` нарушает это по построению.
2. **Округление — нормируемая операция в единственной точке**, а не побочный эффект арифметики.
3. **Незаконное округление меняет налоговую обязанность** — это установлено судом, а не только логикой.
4. **Разрядность зависит от валюты, и российские классификаторы её не дают** — значит масштаб может быть параметром модели, а не константой.

Закон не называет тип, но описывает поведение, которому в PostgreSQL удовлетворяет ровно `numeric`: точное десятичное хранение, отсутствие неявного округления, явно управляемый масштаб.

---

## 4. Языки и фреймворки: где кончается документация и начинается фольклор

### 4.3. Два самых цитируемых авторитета говорят не то, что им приписывают

**Джошуа Блох, Effective Java, Item 60** — «Avoid float and double if exact answers are required» ([английский текст](https://github.com/clxering/Effective-Java-3rd-edition-Chinese-English-bilingual/blob/dev/Chapter-9/Chapter-9-Item-60-Avoid-float-and-double-if-exact-answers-are-required.md)):

> In summary, don't use float or double for any calculations that require an exact answer. Use BigDecimal if you want the system to keep track of the decimal point and you don't mind the inconvenience and cost of not using a primitive type… **If performance is of the essence… use int or long.** If the quantities don't exceed nine decimal digits, you can use int; if they don't exceed eighteen digits, you can use long.

Запрет у него один — на двоичный float. `BigDecimal` и `int`/`long` предлагаются как равноправные варианты.

**Мартин Фаулер, PoEAA, гл. 18, паттерн Money.**

> You can store the amount as either an integral type or a fixed decimal type. The decimal type is easier for some manipulations, the integral for others. **You should absolutely avoid any kind of floating point type**, as that will introduce the kind of rounding problems that Money is intended to avoid.

Фаулер тоже агностичен между целым и десятичным. Его нерушимое требование — **валюта в типе**, а не десятичность представления.

**JSR 354 (Java Money) намеренно отказывается фиксировать представление.**
[`javax.money.MonetaryAmount`](https://javamoney.github.io/apidocs/javax/money/MonetaryAmount.html):

> JSR 354 explicitly supports different types of monetary amounts to be implemented and used. Reason behind is that the requirements to an implementation heavily vary for different usage scenarios.

И референсная реализация везёт обе:
[`Money`](https://raw.githubusercontent.com/JavaMoney/jsr354-ri/master/moneta-core/src/main/java/org/javamoney/moneta/Money.java) на `BigDecimal` и [`FastMoney`](https://raw.githubusercontent.com/JavaMoney/jsr354-ri/master/moneta-core/src/main/java/org/javamoney/moneta/FastMoney.java) на `long` в minor units, про который в javadoc написано:

> It suggested to have a performance advantage of a 10-15 times faster compared to `Money`, which internally uses `BigDecimal`. Nevertheless this comes with a price of less precision.

### Практика в платёжных API

| Провайдер | Представление | Тип в JSON |
|---|---|---|
| [Stripe](https://docs.stripe.com/api/charges/object) | целое, minor units | `integer` |
| [Adyen](https://docs.adyen.com/development-resources/currency-codes/) | minor units | integer |
| [Square](https://developer.squareup.com/reference/square/objects/Money) | smallest denomination | `int64` |
| [Google `Money`](https://developers.google.com/android-publisher/api-ref/rest/v3/Money) | `units` (int64) + `nanos` (int32) | строка + integer |
| [PayPal](https://raw.githubusercontent.com/paypal/paypal-rest-api-specifications/main/openapi/checkout_orders_v2.json) | десятичное | **строка** с regex |
| [Braintree](https://developer.paypal.com/braintree/docs/reference/request/transaction/sale) | `BigDecimal` | десятичное/строка |
| [Shopify](https://shopify.dev/docs/api/admin-graphql/latest/scalars/Decimal) | скаляр `Decimal` | **строка** |
| [Wise](https://github.com/transferwise/api-docs/blob/master/source/includes/reference/_quotes.md) | `Decimal` | число |
| [Plaid](https://raw.githubusercontent.com/plaid/plaid-openapi/master/2020-09-14.yml) | **`number` / `format: double`** | float64 |
| [T-Bank](https://developer.tbank.ru/eacq/api/init) | целое, копейки | `Integer<int64>` |
| [ЮKassa](https://yookassa.ru/developers/using-api/response-handling/response-format) | десятичное | строка |
| [ISO 20022](https://github.com/kedder/ofxstatement-iso20022/blob/master/doc/camt.053.001.05.xsd) | `xs:decimal(18,5)` + `Ccy` | XML decimal |

Их основная проблема - в использовании JSON. В нём нет типа, способного переносить десятичную семантику. Как следствие, обычно используется строковое представление

### 5.2. Почему в API целые: причина в JSON

[RFC 8259, §6 «Numbers»](https://www.rfc-editor.org/rfc/rfc8259):

> «Since software that implements IEEE 754 binary64 (double precision) numbers is generally
> available and widely used, good interoperability can be achieved by implementations that
> expect no more precision or range than these provide…»
>
> «…numbers that are integers and are in the range [−(2**53)+1, (2**53)−1] are
> **interoperable** in the sense that implementations will agree exactly on their numeric
> values.»

В JSON нет десятичного типа, и гарантированно переживают round-trip только целые в
пределах ±2⁵³. Отсюда две стратегии: либо целые в minor units (Stripe, Adyen, T-Bank),
либо десятичное **строкой** (PayPal, Shopify, ЮKassa). Голое дробное JSON-число — это
третий, наименее надёжный путь.

Явная формулировка проблемы —
[тред api-craft «Encoding of money amounts in JSON representations»](https://groups.google.com/g/api-craft/c/jwnVh9TJyVw)
и [разбор про JS](https://cardinalby.github.io/blog/post/best-practices/storing-currency-values-data-types/):

> «JavaScript uses signed *Float64* as an internal representation for the *number* data
> type… by default a JavaScript application will overflow its number type trying to
> deserialize JSON containing this value.»

### 5.3. Ledger-системы

[Modern Treasury, «Floats don't work for storing cents»](https://www.moderntreasury.com/journal/floats-dont-work-for-storing-cents):

> «We primarily use 64-bit Integers to represent money in our system.»

Суммы хранятся в дробных единицах на **PostgreSQL `bigint`**.

Дословно противоположная позиция, для баланса —
[Otar Chekurishvili, «Storing money as integer cents is often over-engineering»](https://world.hey.com/otar/storing-money-as-integer-cents-is-often-over-engineering-7238a485):

> «When you store 1999 instead of 19.99, you don't actually solve a problem. You move it out
> of the database and into every other layer of the app.»

---

## 6. ERP и системы учёта: тут decimal побеждает

**SAP** — packed decimal плюс обязательное поле валюты
([ABAP docs, currency field](https://eduardocopat.github.io/abap-docs/7.31/abencurrency_field/);
оригинал `help.sap.com` закрыт robots.txt):

> «A data element of data type CURR is treated as a field of data type DEC and is stored in
> database tables in the BCD format.»
>
> «For every structure component of data type CURR, a component of the same structure or of
> a different structure or database table must be specified… as a reference field, which has
> the data type CUKY.»

Это чистейшая реализация паттерна Фаулера: сумма + обязательная ссылка на валюту.

**Oracle E-Business Suite / Fusion** — `NUMBER` вообще без точности и масштаба.
[GL_JE_LINES](https://docs.oracle.com/en/cloud/saas/financials/26a/oedmf/gljelines-24789.html):
`ENTERED_DR`, `ENTERED_CR`, `ACCOUNTED_DR`, `ACCOUNTED_CR` — все `NUMBER`.

**ERPNext / Frappe** — `decimal(21,9)` на обоих бэкендах
([mariadb/database.py](https://raw.githubusercontent.com/frappe/frappe/develop/frappe/database/mariadb/database.py),
postgres-версия идентична):

```python
"Currency": ("decimal", "21,9"),
"Float":    ("decimal", "21,9"),
"Percent":  ("decimal", "21,9"),
```

Девять знаков дробной части, и бинарных float-колонок нет вовсе.

**Odoo — лучший контрпример из всех, и не тот, которого ждёшь.** Колонка в базе —
`numeric`, [odoo/fields.py 17.0](https://raw.githubusercontent.com/odoo/odoo/17.0/odoo/fields.py):

```python
class Monetary(Field):
    """ Encapsulates a :class:`float` expressed in a given currency. """
    type = 'monetary'
    column_type = ('numeric', 'numeric')
```

Но значение в ORM — Python `float`. Оттуда и хелперы
([odoo/tools/float_utils.py](https://raw.githubusercontent.com/odoo/odoo/17.0/odoo/tools/float_utils.py)):

> `float_round`: «Return `value` rounded to `precision_digits` decimal digits, **minimizing
> IEEE-754 floating point representation errors**, and applying the tie-breaking rule
> selected with `rounding_method`, by default HALF-UP (away from zero).»
>
> `float_compare`: «**Warning: `float_is_zero(value1-value2)` is not equivalent to
> `float_compare(value1,value2) == 0`**, as the former will round after computing the
> difference, while the latter will round before…»

То есть production-ERP с `numeric`-колонками, которая всю арифметику ведёт в двоичном
double. **Колонка типа `numeric` сама по себе не означает десятичной арифметики** — это,
пожалуй, главный практический вывод всего раздела.

Версии Odoo ≤ 15.0 несут `column_cast_from = ('float8',)` — свидетельство, что колонка
исторически была `float8` и её мигрировали.

---

## 7. Что говорят практики PostgreSQL

[Wiki «Don't Do This»](https://wiki.postgresql.org/wiki/Don%27t_Do_This):

> «The money data type isn't actually very good for storing monetary values. **Numeric, or
> (rarely) integer may be better.**»
>
> «it doesn't handle fractions of a cent…, it's rounding behaviour is probably not what you
> want.»
>
> «if you insert '$10.00' while lc_monetary is set to 'en_US.UTF-8' the value you retrieve
> may be '10,00 Lei' or '¥1,000' if lc_monetary is changed.»
>
> «Storing a value as a numeric, possibly with the currency being used in an adjacent
> column, might be better.»

[Cybertec, Ханс-Юрген Шёниг](https://www.cybertec-postgresql.com/en/postgresql-int4-vs-float4-vs-numeric/):

> «In the case of money, different rounding rules are needed, which is why numeric is the
> data type you have to use to handle financial data.»

[Crunchy Data, Элизабет Кристенсен](https://www.crunchydata.com/blog/working-with-money-in-postgres) —
и обратите внимание на порядок:

> «Use `int` or `bigint` if you can work with whole numbers of cents and you don't need
> fractional cents.»
>
> «Use `decimal` / `numeric` for storing money in fractional cents and even out to many many
> decimal points.»
>
> «Store currency separately from the actual monetary values…»

---

## 8. Судьба numeric: что умирает, а что нет

### 8.1. Точный десятичный тип не умирает — он расширяется

- Период сосуществования MT и MX в SWIFT **закончился 22 ноября 2025 года**
  ([Swift, ISO 20022 FAQ](https://www.swift.com/standards/iso-20022/iso-20022-faqs/implementation)):
  «The coexistence period ended on 22 November 2025». Банк России идёт следом, полный
  переход платёжной системы — 2029 год (см. §3.3).
- **C23 внёс `_Decimal32/64/128` в стандарт языка C**
  ([cppreference, C23](https://en.cppreference.com/c/23)) — правда, опционально, через
  макрос `__STDC_IEC_60559_DFP__`; GCC поддерживает частично, Clang и MSVC — нет
  ([RFC в LLVM всё ещё открыт](https://discourse.llvm.org/t/rfc-decimal-floating-point-support-iso-iec-ts-18661-2-and-c23/62152)).
- `DECFLOAT` из SQL:2016 реализован не только в Db2, но и в **Firebird 4.0**
  ([README.floating_point_types.md](https://raw.githubusercontent.com/FirebirdSQL/firebird/master/doc/sql.extensions/README.floating_point_types.md)):
  «DECFLOAT(16) - 64 bit Decimal64», «DECFLOAT(34) - 128 bit Decimal128».
- Точный десятичный тип есть во всех проверенных аналитических движках и во всех
  колоночных форматах. Ни один не отказался от него.

### 8.2. Умирает конкретная конструкция: произвольная точность переменной длины

Потолок **38 цифр (int128)** стал де-факто универсальной константой:

| Система | Потолок | Представление |
|---|---|---|
| [Snowflake](https://docs.snowflake.com/en/sql-reference/data-types-numeric) | 38 | адаптивная ширина по фактическому диапазону |
| [Redshift](https://docs.aws.amazon.com/redshift/latest/dg/r_Numeric_types201.html) | 38 | int64 до 19 цифр, int128 до 38 |
| [SQL Server / Synapse](https://learn.microsoft.com/en-us/sql/t-sql/data-types/decimal-and-numeric-transact-sql) | 38 | 5/9/13/17 байт |
| [Databricks / Spark](https://docs.databricks.com/aws/en/sql/language-manual/data-types/decimal-type) | 38 | long fast-path ≤18 цифр, BigDecimal дальше |
| [DuckDB](https://duckdb.org/docs/current/sql/data_types/numeric.html) | 38 | INT16/32/64/128 |
| [Iceberg](https://raw.githubusercontent.com/apache/iceberg/main/format/spec.md) | 38 | «precision must be 38 or less» |
| [ClickHouse](https://clickhouse.com/docs/sql-reference/data-types/decimal) | 76 | int32/64/128/256 |
| [BigQuery](https://raw.githubusercontent.com/google/zetasql/master/docs/data-types.md) | 38 / ~76.8 | int128 с разным scale |

[Redshift прямо предупреждает](https://docs.aws.amazon.com/redshift/latest/dg/r_Numeric_types201.html):

> «Do not arbitrarily assign maximum precision to DECIMAL columns unless you are certain
> that your application requires that precision. 128-bit values use twice as much disk
> space as 64-bit values and can slow down query execution time.»

**Apache Arrow** фиксирует ровно четыре ширины
([Schema.fbs](https://raw.githubusercontent.com/apache/arrow/main/format/Schema.fbs)):

> «Exact decimal value represented as an integer value in two's complement. Currently
> 32-bit (4-byte), 64-bit (8-byte), 128-bit (16-byte) and 256-bit (32-byte) integers are
> used.» / «The accepted widths are 32, 64, 128 and 256.»

Причём эволюция идёт **в сторону сужения**: Arrow 18.0.0 (октябрь 2024)
[добавил Decimal32 и Decimal64](https://arrow.apache.org/blog/2024/10/28/18.0.0-release/),
а не более широкие типы.

**Самый показательный источник — CedarDB**, коммерческий наследник Umbra, движок,
спроектированный в 2020-х. Он явно и письменно противопоставляет себя PostgreSQL
([документация по numeric](https://cedardb.com/docs/references/datatypes/numeric/)):

> «PostgreSQL offers a maximum precision of 131072 and scale of 16383, where **CedarDB
> restricts precision and scale to a maximum of 38, for performance reasons.**»
>
> «Operations on 16 Byte types are expensive to compute. We recommend using a precision of
> 18 or less when possible for your application.»
>
> «PostgreSQL allows NaN, +Infinity, and -Infinity as special numeric values» — «CedarDB
> forbids entering these values as numeric data types.»

Команда, которая целенаправленно делает быстрый PostgreSQL-совместимый движок, отказалась
ровно от того, что делает `numeric` медленным: от произвольной точности, от varlena и от
специальных значений.

**И чем за это платят.** [ClickHouse честно документирует](https://clickhouse.com/docs/sql-reference/data-types/decimal),
что у широких фиксированных типов проверки переполнения нет вовсе:

> «During calculations on Decimal, integer overflows might happen. Excessive digits in a
> fraction are discarded (not rounded). Excessive digits in integer part will lead to an
> exception.»
>
> «**Overflow check is not implemented for Decimal128 and Decimal256. In case of overflow
> incorrect result is returned, no exception is thrown.**»

То есть у `Decimal32`/`Decimal64` переполнение целой части даёт исключение, а у
`Decimal128`/`Decimal256` — молча неверный результат. Для сравнения: у PostgreSQL `numeric`
выход за формат — всегда ошибка (`value overflows numeric format`). Это ровно та часть
цены фиксированной ширины, о которой в спорах «decimal против копеек» обычно не вспоминают.

**Колоночные форматы — то же самое.** [Parquet](https://raw.githubusercontent.com/apache/parquet-format/master/LogicalTypes.md)
допускает `BYTE_ARRAY` с неограниченной точностью, но даже там значение — это
`unscaledValue` в дополнительном коде, а `precision is required` всегда. Семантики
«произвольная точность как контракт типа» нет нигде.

### 8.3. Честные контрпримеры

Чтобы вывод не выглядел натянутым, вот что играет против него:

- **`shopspring/decimal`** — самая популярная Go-библиотека для денег — это `big.Int` +
  `int32` экспонента ([pkg.go.dev](https://pkg.go.dev/github.com/shopspring/decimal)), то
  есть буквально модель PostgreSQL `numeric`. И предложение внести decimal128 в stdlib Go
  [было отклонено](https://github.com/golang/go/issues/12332).
- **H2** реализовал стандартный `DECFLOAT` поверх `BigDecimal`, а не поверх IEEE
  decimal128 ([issue #2254](https://github.com/h2database/h2database/issues/2254)).
- **Snowflake** хранит `NUMBER` с адаптивной шириной, а не строго фиксированной.

Общий знаменатель: **произвольная длина как деталь физического кодирования встречается;
произвольная точность как контракт типа — нет.**

## 10. Отдельно: 1С

Вопрос практический — раз 1С один из крупнейших потребителей PostgreSQL, стоит проверить,
не собирается ли она уходить от `numeric`. **Признаков нет; данные указывают в
противоположную сторону.**

### 10.1. `numeric` зафиксирован в документации 1С как контракт

Официальная таблица соответствия типов — ИТС, [«Особенности хранения составных типов
данных»](https://its.1c.ru/db/metod8dev/content/1828/hdoc):

| Колонка | MS SQL | PostgreSQL | DB2 | Oracle |
|---|---|---|---|---|
| `_N` (число) | `NUMERIC(n,k)` | **`numeric(n,k)`** | `dec(n,k)` | `NUMBER(n,k)` |
| `_S` (строка) | `NCHAR(n)` | **`mchar(n)`** | `graphic(n)` | `CHAR(n+1)` |

Обратите внимание на асимметрию во второй строке. **Для строк стоковый `varchar` 1С не
устроил — они написали собственный тип `mchar`/`mvarchar`. Для чисел взяли стоковый
`numeric` как есть.** Аналога «mnumeric» не существует.

Ограничение платформы — 38 знаков, «в DB2 максимум 31»
([ИТС](https://its.1c.ru/db/metod8dev/content/2665/hdoc); чистые цитаты воспроизведены в
[документации SonarQube BSL Plugin](https://docs.checkbsl.org/checks/query/CastToNumber/)).
То есть платформа сама живёт внутри той же границы 38, что и весь остальной мир.

### 10.4. Платформа движется в сторону большей точности, а не меньшей

[Новое в платформе 8.5.4](https://v8.1c.ru/platforma/news/novoe-v-platforme-8-5-4/):

> «Мы **повысили точность** простых арифметических операций при выполнении запросов к СУБД.
> Это изменение реализовано для СУБД Microsoft SQL Server и PostgreSQL и ее производных.»

Там же — нагрузочное тестирование «1С:ERP» на **30 000 одновременных пользователей** в
единой базе на PostgreSQL с патчем от 1С.

От типа, от которого собираются уходить, не требуют большей точности.

### 10.6. Что это значит для задачи «numeric фиксированной длины для 1С»

Данные складываются в довольно определённую картину:

- **Замены `numeric` не будет** — ни от 1С, ни от вендоров СУБД. Значит работать надо с
  тем `numeric`, который есть, а не проектировать ему смену.
- **Ускорение `numeric` — единственное живое направление** и в upstream (Дин Рашид), и,
  судя по всему, единственное реалистичное здесь.
- **Аргумент «pass-by-value вместо varlena» уже был озвучен в сообществе** — Робертом
  Хаасом в 2017 году, и по существу не оспорен. Но три написанных расширения умерли, а
  тема в hackers мертва с ноября 2018-го. Это надо учитывать, оценивая шансы нового захода.
- **Граница 38 цифр, на которую ориентируется весь остальной мир, совпадает с
  ограничением самой платформы 1С.** Это аргумент в пользу того, что фиксированная ширина
  для 1С-профиля данных вообще возможна — но и напоминание, что за пределами 1С
  у `numeric` есть потребители, которым нужны 78 и 156 цифр (см. §9.2).

---

## 11. Выводы

1. **Формального стандарта «для денег используйте NUMERIC» не существует.** В ISO SQL нет
   даже типа MONEY. Утверждать обратное — ошибка.
2. **Зато есть требования к поведению**, которым двоичная плавающая точка не удовлетворяет:
   точное представление копейки, детерминированное поведение на ровно половине, округление
   строго в предписанных точках и нигде больше, масштаб как параметр валюты. Это следует из
   права (регламент ЕС 1103/97, HMRC, п. 6 ст. 52 НК РФ + ПП № 1137), форматов обмена
   (ISO 20022, XBRL, FIX/SBE, ФФД, форматы ФНС) и транзакционных бенчмарков (TPC-C, TPC-E).
3. **Реальный консенсус звучит не «используйте decimal», а «никогда не двоичный float, и
   всегда валюта рядом с суммой».** Именно так формулируют его Фаулер, Блох, JSR 354 и
   PostgreSQL wiki.
4. **Внутри этого консенсуса две легитимные кодировки, и индустрия делится предсказуемо.**
   Системы учёта (SAP, Oracle EBS, ERPNext, ISO 20022, ЭДО-форматы ФНС, DirectBank) берут
   точное десятичное, потому что им нужен переменный и большой масштаб. Транспорт и
   высоконагруженные ledger'ы (Stripe, Adyen, T-Bank, ФФД, Modern Treasury) берут целые в
   minor units, потому что так удобнее JSON и процессору.
5. **Для PostgreSQL это значит:** `numeric` — правильный дефолт для системы учёта, и
   документация говорит это прямо. Но там же, в соседнем предложении, сказано «very slow
   compared to the integer types» — и `bigint` в копейках не ересь, а вторая половина того
   же индустриального консенсуса. Выбор между ними — про масштаб и про то, где проходит
   граница системы, а не про «правильно/неправильно».
6. **Отдельно и важно:** тип колонки не определяет тип арифметики. Odoo хранит в `numeric`
   и считает в `double`. Проверять надо оба слоя.
7. **Точный десятичный тип не умирает — умирает конкретно варианта «произвольная точность
   переменной длины».** 38 цифр (int128) стали универсальным потолком, а CedarDB, движок
   2020-х, письменно объясняет отказ от модели PostgreSQL «for performance reasons».
   В самом PostgreSQL развилка была пройдена в 2001 году и с 2018-го не обсуждалась.
8. **Сфера применения `numeric` не «финансы», а «всё, где нужна точность за пределами
   int128 или заранее неизвестный масштаб».** Финансам хватает 15–18 цифр на хранение и
   25–32 на промежуточные результаты; биржам — 15 по спецификации FIX. Реальный массовый
   потребитель произвольной точности — EVM-блокчейны (78 цифр на `uint256`, до 156 в
   промежуточных вычислениях) и сама арифметика агрегатов, где сумма и произведение
   выводят разрядность за 38 без всякого домена.
9. **1С от `numeric` не уходит и не собирается.** За ~18 лет патча к PostgreSQL — ноль
   строк про numeric, при том что для строк 1С написала собственный тип. Платформа 8.5.4
   наоборот повысила точность арифметики в запросах к СУБД.
