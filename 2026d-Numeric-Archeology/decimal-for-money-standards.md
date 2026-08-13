# Почему в БД на PostgreSQL популярен тип `numeric`?

Документация PostgreSQL по `numeric` содержит два плохо согласующихся [утверждения](https://www.postgresql.org/docs/current/datatype-numeric.html):

«especially recommended for storing monetary amounts and other quantities where exactness is required» — и сразу же: «calculations on `numeric` values are **very slow** compared to the integer types, or to the floating-point types». То есть рекомендуют для хранения денежных величин и тут же признают, что это весьма дорого.

Для меня, как разработчика СУБД это сигнал к действию. Если операции с типом заметно медленнее `bigint`, возникает соблазн: а нельзя ли хранить денежные величины целым числом копеек и округлять по стандартному правилу? Это бы прилично сэкономило вычислительные ресурсы наших серверов баз данных, разве нет? А что, если вообще использовать `double precision`?

Но прежде чем оптимизировать тип или менять его на целое, стоит понять, что от него на самом деле требуют: закон, форматы обмена данными, прикладные платформы. Правда ли, что точный десятичный тип — стандарт для финансовых приложений, пусть даже и де-факто? Или это инженерный фольклор, который можно спокойно обойти?

Дальше — попытка ответить по первоисточникам, а не по общему знанию. Задача копания в первоисточниках никогда не была простой. Однако с AI-агентами стало сильно легче. Так что засучим рукава и приступим.

## Содержание

- [1. Что говорит стандарт SQL](#1-что-говорит-стандарт-sql)
- [2. Чего требуют закон и регуляторы](#2-чего-требуют-закон-и-регуляторы)
- [3. Форматы обмена финансовыми данными](#3-форматы-обмена-финансовыми-данными)
- [4. Платежные системы: масштаб как атрибут валюты](#4-платежные-системы-масштаб-как-атрибут-валюты)
- [5. Чего требуют TPC-бенчмарки](#5-чего-требуют-tpc-бенчмарки)
- [6. Что говорят вендоры, авторитеты и практики](#6-что-говорят-вендоры-авторитеты-и-практики)
- [7. Что происходит в ERP](#7-что-происходит-в-erp)
- [8. Куда движется точный десятичный тип](#8-куда-движется-точный-десятичный-тип)
- [9. Выводы](#9-выводы)

## 1. Что говорит стандарт SQL

В ISO SQL нет типа MONEY. Нет не только типа — в стандарте языка SQL вообще отсутствует понятие валюты. Тип `money` в PostgreSQL и `money`/`smallmoney` в SQL Server — вендорские расширения, а не реализация стандарта.

Имеется три категории числовых типов:

- Exact numeric types: `NUMERIC`, `DECIMAL`, `SMALLINT`, `INTEGER`, `BIGINT`.
- Approximate numeric types: `FLOAT`, `REAL`, `DOUBLE PRECISION`.
- The decimal floating-point type: `DECFLOAT`.

У типов `Numeric` и `Decimal` есть небольшая семантическая разница.

Подраздел 6.1 «data type», Syntax Rules 28 и 29:
> 28) NUMERIC specifies the data type exact numeric, with the decimal precision and scale specified by the precision and scale.
> 29) DECIMAL specifies the data type exact numeric, with the decimal scale specified by the scale and the implementation-defined (ID063) decimal precision equal to or greater than the value of the specified precision.

Для понимания различия: NUMERIC(15,2) — это жёсткое ограничение ровно на 15 цифр, DECIMAL(15,2) — на «не меньше 15». По этому определению оба типа можно скомбинировать в один, чем и пользуется `numeric` в PostgreSQL.

Стандарт не запрещает реализацию точного десятичного типа поверх двоичного целого. Это даёт возможность существовать вариантам реализации в Arrow, SQL Server, DuckDB и пр. Фиксированная ширина на int64/int128 — это предусмотренный им вариант.

Подраздел 4.5.2 «Characteristics of numbers»:
«An exact numeric type has a precision P and a scale S. P is a positive integer that determines the number of significant digits in a particular radix R, where R is either 2 or 10. S is a non-negative integer. Every value of an exact numeric type of scale S is of the form n × 10⁻ˢ, where n is an integer such that −Rᴾ ≤ n < Rᴾ.»

Итого: точный десятичный тип `DECIMAL`/`NUMERIC` входит в обязательное ядро SQL (фича E011-03), а `DECFLOAT` — опциональная (T076), наравне с `BIGINT`.

Также для анализа требований к типу `numeric` важно, что стандарт SQL ничего не говорит про минимальную и максимальную точность, но накладывает ограничения на арифметику: масштаб сложения, вычитания и умножения задан жёстко. Масштаб деления отдан на откуп реализации.

---

## 2. Чего требуют закон и регуляторы

Регламент Совета ЕС № 1103/97 [о введении евро](https://eur-lex.europa.eu/legal-content/EN/TXT/HTML/?uri=CELEX:31997R1103) хорошо проработан и достаточно однозначно требует шесть значащих десятичных цифр без округления и усечения, и фиксирует детерминированное поведение при округлении за пределами точности. Тип `float` под такие требования не подходит.

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

### Итог по требованиям регуляторов

Прямого предписания «используйте точный десятичный тип» ни в одной из проверенных норм нет. Но из их совокупности складывается функционально эквивалентное требование, и оно состоит из четырёх частей:

1. **Хранение обязано быть точным до минимальной денежной единицы.** Двоичный `float` не представляет 0,01 точно, значит система на `double precision` нарушает это по построению, независимо от того, насколько аккуратно написан прикладной код.
2. **Округление — нормируемая операция в единственной точке**, а не побочный эффект арифметики. Регламент ЕС формулирует это предельно жёстко: курсы «shall not be rounded or truncated», а округление до цента происходит ровно один раз, после пересчёта.
3. **Поведение ровно на половине задано явно.** И ЕС, и HMRC отдельно оговаривают случай `0,5`: округлять вверх. Тип, у которого правило ничьей зависит от реализации, такую норму сам по себе не обеспечивает.
4. **Разрядность зависит от валюты**, а не от типа: три знака у ЕС на промежуточном пересчёте, доли пенни у HMRC. Значит масштаб должен быть параметром модели, а не константой, зашитой в схему.

Закон не называет тип, но описывает поведение. В PostgreSQL этому набору требований удовлетворяет `numeric`: точное десятичное хранение, отсутствие неявного округления, явно управляемый масштаб.

**И тут же вылезает то, чего ни один регулятор не предусмотрел.** Правило округления, которое закон задаёт однозначно, в СУБД не зафиксировано — оно различается и между системами, и между типами внутри одной системы. Bill Schneider [разбирает](https://wrschneider.github.io/2022/03/08/spark-rounding.html) расхождение Spark и SQL Server на одних и тех же десятичных данных: одна система округляет, другая усекает. IBM в Db2 пошла дальше всех и просто [вынесла правило в настройку](https://www.ibm.com/docs/en/db2-for-zos/12.0.0?topic=registers-current-decfloat-rounding-mode) — семь режимов на выбор, значение по умолчанию задаётся при установке. То есть требование «округляй вверх на ровно половине» тип данных вам не гарантирует ни в одной СУБД: округление придётся делать явно и в одном месте, как того и требует пункт 2.

## 3. Форматы обмена финансовыми данными

Здесь пришлось изрядно повозиться с первоисточниками — часть спецификаций платная, часть отдаётся только скриптом.

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

А в бинарной кодировке SBE — двоичном формате, на котором биржи гоняют потоки котировок, — явно указано использовать десятичные кодировки для цен и всего денежного, а двоичная плавающая точка — только для тех числовых полей, которые не являются ценами или денежными суммами.
([FIX SBE v1.0 RC4, Field Encoding](https://github.com/FIXTradingCommunity/fix-simple-binary-encoding/blob/master/v1-0-RC4/doc/02FieldEncoding.md)):
> «Decimal encodings should be used for prices and related monetary data types like
> PriceOffset and Amt.»
>
> «Binary floating point encodings are compatible with IEEE Standard for Floating-Point
> Arithmetic (IEEE 754-2008). They should be used for floating point numeric fields **that
> do not represent prices or monetary amounts**.»

## 4. Платежные системы: масштаб как атрибут валюты

Платёжная индустрия деньги дробным числом не передаёт вообще. А причина здесь скорее всего в возрасте системы, стандартах и тех возможностях ИТ, которые определили эти стандарты в 60–70-х гг.

**ISO 8583**, протокол карточных сетей, задаёт элемент данных DE 4 «Amount, transaction» форматом **`n 12`** — двенадцать цифр, и всё. В чисто числовом поле фиксированной длины десятичному разделителю просто негде разместиться, поэтому масштаб берётся снаружи — из поля «Currency code». Сумма на проводе — целое, а сколько у него знаков после запятой, определяет валюта. Количество знаков после запятой у валют разное: у JPY, KRW и VND — ноль, у USD, EUR и GBP — два, а у BHD, KWD, OMR, TND и JOD — три.

Таким образом в платежах масштаб — это атрибут валюты, а не свойство числа. Он не хранится вместе со значением и не передаётся вместе с ним; он лежит в отдельном поле, а число остаётся целым.

Платёжные HTTP-API сохраняют карточное наследие, а те, кто пришёл позже и не из карточного мира, часто выбирают способ представления десятичной строкой:

| Система / формат | Величина | Формат сообщения |
|---|---|---|
| ISO 8583 | целое | binary |
| [FIX SBE](https://github.com/FIXTradingCommunity/fix-simple-binary-encoding/blob/master/v1-0-RC4/doc/02FieldEncoding.md) | целое | binary |
| [Stripe](https://docs.stripe.com/api/charges/object) | целое | JSON |
| [Adyen](https://docs.adyen.com/development-resources/currency-codes/) | целое | JSON |
| [Square](https://developer.squareup.com/reference/square/objects/Money) | целое | JSON |
| [T-Bank](https://developer.tbank.ru/eacq/api/init) | целое, копейки | JSON |
| [Google `Money`](https://raw.githubusercontent.com/googleapis/googleapis/master/google/type/money.proto) | целое | protobuf (binary), JSON в REST |
| [PayPal](https://raw.githubusercontent.com/paypal/paypal-rest-api-specifications/main/openapi/checkout_orders_v2.json) | десятичное | JSON |
| [Shopify](https://shopify.dev/docs/api/admin-graphql/latest/scalars/Decimal) | десятичное | JSON (GraphQL) |
| [ЮKassa](https://yookassa.ru/developers/using-api/response-handling/response-format) | десятичное | JSON |
| [Braintree](https://developer.paypal.com/braintree/docs/reference/request/transaction/sale) | десятичное | JSON |
| [Wise](https://github.com/transferwise/api-docs/blob/master/source/includes/reference/_quotes.md) (legacy v1) | десятичное | JSON |
| [Plaid](https://raw.githubusercontent.com/plaid/plaid-openapi/master/2020-09-14.yml) | десятичное (`double`) | JSON |
| [ISO 20022](https://github.com/kedder/ofxstatement-iso20022/blob/master/doc/camt.053.001.05.xsd) | десятичное (`decimal`) | XML |
| [FIX 4.x / Latest](https://fiximate.fixtrading.org/en/FIX.Latest/fix_datatypes.html) | десятичное, текст | текст (tag=value) |

Из этой таблицы вылезает третий слой требований, о котором обычно не думают. Спорят про **хранение** — представима ли копейка. Иногда доходят до **вычислений** — детерминированность, точка округления, правило на ровно половине. Но есть ещё **сериализация**: значение должно пережить переход через границу, где его разбирает парсер, который вы не писали и не контролируете.

Требование на этом слое устроено иначе, чем на первых двух. Здесь нужна не точность внутри вашей системы, а согласие: две независимые реализации на разных языках обязаны сойтись на одном и том же значении, до последней цифры. И этому удовлетворяет ровно одна конструкция — **точное целое плюс масштаб, заданный вне значения**. Не потому, что целые «точнее», а потому что это единственный числовой тип, о котором договорились все языки и все парсеры без исключения. Масштаб при этом едет отдельной дорогой: в схеме потока (Arrow, Parquet, FIX SBE), в соседнем поле (`units` + `nanos` у Google) или в коде валюты (ISO 8583, Stripe, Adyen).

Так что платёжная практика точный десятичный тип не отвергает — она добавляет к нему третье, независимое требование, которого нет ни в законе, ни в стандарте SQL.

## 5. Чего требуют TPC-бенчмарки

Бенчмарк TPC-C требует точных вычислений и следования стандарту SQL.

[Standard Specification Rev. 5.11, клауза 1.3.1](https://www.tpc.org/tpc_documents_current_versions/pdf/tpc-c_v5.11.0.pdf) —
> Numeric fields that contain monetary values (W_YTD, D_YTD, C_CREDIT_LIM, C_BALANCE, C_YTD_PAYMENT, H_AMOUNT, OL_AMOUNT, I_PRICE) **must use data types that are defined by the DBMS as being an exact numeric data type** or that satisfy the ANSI SQL Standard definition of being an exact numeric representation.

То же самое имеется в требованиях TPC-E.

[v1.14.0, клауза 2.2.1](https://www.tpc.org/tpc_documents_current_versions/pdf/tpc-e_v1.14.0.pdf):
> «ENUM and SENUM… must be implemented using a Native Data Type which provides **exact representation** of at least n Digits of precision after the decimal place.»
>
> «BALANCE_T is defined as SENUM(12,2)… FIN_AGG_T is defined as SENUM(15,2)…»

Бенчмарки, ориентированные на аналитику, — TPC-H и TPC-DS — снижают требования к точности. Для `Integer` требование точности сформулировано жёстко, а для `Decimal` нет: в агрегатах допуск составляет 1% (AVG и отношения) и «within $100» (SUM). Точное соответствие требуется только в COUNT.

[TPC-H v3.0.1, клауза 1.3.1](https://www.tpc.org/tpc_documents_current_versions/pdf/tpc-h_v3.0.1.pdf):
> «Decimal means that the column must be able to represent values in the range −9,999,999,999.99 to +9,999,999,999.99 in increments of 0.01; the values can be **either represented exactly or interpreted to be in this range**»

Интересный вывод: транзакционные бенчмарки требуют точного типа дословно, аналитические — явно разрешают приближение. Такое послабление потенциально позволяет включать различные оптимизации для запроса, объявленного как "аналитический".

## 6. Что говорят вендоры, авторитеты и практики

Если проанализировать документацию и публикации представителей разработки известных СУБД (см. разделы документации [PostgreSQL](https://www.postgresql.org/docs/current/datatype-numeric.html), [SQL Server](https://learn.microsoft.com/en-us/sql/t-sql/data-types/float-and-real-transact-sql), [MySQL](https://dev.mysql.com/doc/refman/8.4/en/fixed-point-types.html), и [IBM](https://speleotrove.com/decimal/decifaq1.html)), то видно, что для точных вычислений (финансовые часто упоминаются прямо) они не рекомендуют использовать типы с двойной плавающей точкой. Прямой рекомендации обычно не даётся, что оставляет пространство для использования как `numeric`, так и целочисленного представления.

Теперь — те, на кого в таких спорах принято ссылаться.

Джошуа Блох, «[Effective Java](https://github.com/clxering/Effective-Java-3rd-edition-Chinese-English-bilingual/blob/dev/Chapter-9/Chapter-9-Item-60-Avoid-float-and-double-if-exact-answers-are-required.md)» не рекомендует использовать `float` или `double` в любых вычислениях, где предполагается точный ответ. А `BigDecimal` и `int`/`long` предлагает как равноправные варианты.

> In summary, don't use float or double for any calculations that require an exact answer. Use BigDecimal if you want the system to keep track of the decimal point and you don't mind the inconvenience and cost of not using a primitive type… **If performance is of the essence… use int or long.** If the quantities don't exceed nine decimal digits, you can use int; if they don't exceed eighteen digits, you can use long.

Мартин Фаулер в книге [Patterns of Enterprise Application Architecture](https://stackoverflow.com/questions/7574745/common-sense-when-storing-currencies) выступает строго против любых `float`-типов для операций над денежными величинами и агностичен между целым и десятичным.


[Cybertec, Ханс-Юрген Шёниг](https://www.cybertec-postgresql.com/en/postgresql-int4-vs-float4-vs-numeric/):
> In the case of money, different rounding rules are needed, which is why numeric is the data type you have to use to handle financial data.

[Crunchy Data, Элизабет Кристенсен](https://www.crunchydata.com/blog/working-with-money-in-postgres)
> «Use `int` or `bigint` if you can work with whole numbers of cents and you don't need fractional cents.»
> «Use `decimal` / `numeric` for storing money in fractional cents and even out to many many decimal points.»
> «Store currency separately from the actual monetary values…»


В этом контексте можно привести достаточно подробно аргументированное мнение Otar Chekurishvili [Storing money as integer cents is often over-engineering](https://world.hey.com/otar/storing-money-as-integer-cents-is-often-over-engineering-7238a485):

> When you store 1999 instead of 19.99, you don't actually solve a problem. You move it out of the database and into every other layer of the app.


Спецификация Java для работы с денежными величинами (JSR 354) (Java Money) намеренно отказывается фиксировать представление.**
[`javax.money.MonetaryAmount`](https://javamoney.github.io/apidocs/javax/money/MonetaryAmount.html):

> JSR 354 explicitly supports different types of monetary amounts to be implemented and used. Reason behind is that the requirements to an implementation heavily vary for different usage scenarios.

А референсная реализация содержит два варианта: [`Money`](https://raw.githubusercontent.com/JavaMoney/jsr354-ri/master/moneta-core/src/main/java/org/javamoney/moneta/Money.java) на `BigDecimal` и [`FastMoney`](https://raw.githubusercontent.com/JavaMoney/jsr354-ri/master/moneta-core/src/main/java/org/javamoney/moneta/FastMoney.java) на `long`. Про второй в javadoc утверждается, что он даёт ускорение в 10–15 раз, что может быть использовано, если большая точность не нужна.

## 7. Что происходит в ERP

- **SAP** — `packed decimal` плюс обязательное поле валюты [ABAP docs, currency field](https://eduardocopat.github.io/abap-docs/7.31/abencurrency_field/).
- **Oracle E-Business Suite / Fusion** — `NUMBER` вообще без точности и масштаба. [GL_JE_LINES](https://docs.oracle.com/en/cloud/saas/financials/26a/oedmf/gljelines-24789.html).
- **Odoo** — самый интересный случай, к нему вернёмся отдельно. Колонка в базе имеет тип `numeric` ([odoo/fields.py 17.0](https://raw.githubusercontent.com/odoo/odoo/17.0/odoo/fields.py)), а значение в ORM — Python `float`; отсюда и целый модуль хелперов [odoo/tools/float_utils.py](https://raw.githubusercontent.com/odoo/odoo/17.0/odoo/tools/float_utils.py).
- **1С**. Тип «Число» в платформе — [ИТС, «Разрядность результатов выражений и агрегатных функций»](https://its.1c.ru/db/content/metod8dev/src/developers/platform/metod/query/i8102665.htm). Максимальная разрядность 38 знаков, нотация вида `Число(17,4)`, правила вывода разрядности результата для сложения, умножения и деления.

**Про Odoo стоит сказать отдельно, потому что это неожиданный результат.** Получается production-ERP, у которой колонки объявлены как `numeric`, а вся арифметика ведётся в двоичном `double` — со всеми вытекающими, из-за которых и пришлось написать `float_utils.py` с функциями сравнения и округления. Вывод из этого шире, чем один вендор: **тип колонки в схеме сам по себе не означает, что вычисления идут в десятичной арифметике.** Схема гарантирует только хранение. Если приложение вытащило значение в `double`, посчитало и записало обратно, точность потерялась в прикладном слое, а база при этом выглядит безупречно.

**И общий вывод по разделу, который важен для ответа на вопрос статьи.** В платежах, как мы видели, масштаб — атрибут валюты: он один и приходит извне. В учётных системах всё иначе. У 1С разрядность задаётся **на каждый реквизит** отдельно, нотацией `Число(N,M)`: суммы обычно с двумя знаками, количества с тремя, коэффициенты и курсы — с большим числом. У SAP денежное поле обязано идти в паре с полем валюты, но масштаб при этом определяется видом величины, а не только валютой. Иными словами, **здесь масштаб принадлежит предметной области, а не денежной единице**, и в одной базе их одновременно несколько. Именно поэтому целое число минимальных единиц ERP не спасает: одной константы масштаба на всю схему не хватит, а SQL задаёт масштаб типом колонки, а не значением.

## 8. Куда движется точный десятичный тип

- Международные платежи с конца 2025 года живут на ISO 20022 — и разрядность денежной величины там `totalDigits="18"`, то есть **меньше, чем даёт `int64`**. Формат, через который идут межбанковские расчёты всего мира, в произвольной точности не нуждается.
- C23 внёс `_Decimal32/64/128` в стандарт языка C ([cppreference, C23](https://en.cppreference.com/c/23)) — правда, опционально, через макрос `__STDC_IEC_60559_DFP__`. GCC поддерживает его частично, Clang и MSVC — пока нет.
  ([RFC в LLVM всё ещё открыт](https://discourse.llvm.org/t/rfc-decimal-floating-point-support-iso-iec-ts-18661-2-and-c23/62152)).
- `DECFLOAT` из SQL:2016 реализован не только в Db2, но и в Firebird 4.0 ([README.floating_point_types.md](https://raw.githubusercontent.com/FirebirdSQL/firebird/master/doc/sql.extensions/README.floating_point_types.md)).
- Точный десятичный тип есть во множестве СУБД и во всех колоночных форматах.

А вот в аналитических движках картина разнородная, и она хорошо показывает, где точность считают обязательной, а где договорной. Apache Druid точного числового типа не имеет вовсе и [отклонил](https://github.com/apache/druid/issues/10190) предложение его добавить. ClickHouse спокойно живёт с `Float64` и лишь [рекомендует](https://clickhouse.com/docs/sql-reference/data-types/float) `Decimal` там, где нужна точность. А Elasticsearch и Power BI выбрали третий путь — точную арифметику на фиксированном масштабе поверх целого. То есть аналитика сошлась не на «точном типе», а на «точном сложении на фиксированном масштабе», и это ровно то послабление, которое разрешают TPC-H и TPC-DS.

### Сколько стоит произвольная точность

Вопрос из начала статьи — «а насколько, собственно, дорого» — до сих пор оставался без цифр. Вот замер.

Стенд: PostgreSQL 18.4, собранный из исходников с `-O2`, 10 млн строк денежных величин с двумя знаками, данные целиком в кэше, JIT и параллелизм выключены, минимум из трёх прогонов. В роли «целого со scale» — расширение `fixeddecimal` (int64 с масштабом 2), собранное на том же сервере.

| Запрос | `bigint` | `numeric` | целое со scale |
|---|---|---|---|
| `sum(v)` | 533 мс | 882 мс | 543 мс |
| `count(*) where v > c` | 628 мс | 1078 мс | 652 мс |
| `sum(v*v + v)` | — | 2515 мс | 695 мс |
| `order by v`, полная сортировка | 1987 мс | 4815 мс | 2512 мс |
| `group by v` | 2583 мс | 4087 мс | 2312 мс |

Если вычесть общий пол сканирования (≈533 мс), стоимость самой арифметики на строку выглядит так: накопление суммы — **1 нс против 35 нс**, выражение `v*v + v` — **16 нс против 198 нс**. То есть на уровне операции разница больше порядка, и подозрение из введения полностью подтверждается.

Но у этой картины есть две поправки, без которых вывод получится неверным.

**Первая: как только в выражении появляется `numeric`-литерал, целочисленный тип проигрывает.** `sum(v * 1.1)` на типе со scale — 2659 мс против 1526 мс у `numeric`, то есть **в 1,7 раза медленнее**: приведение к `numeric` происходит на каждой строке. Целое быстрее ровно до первого умножения на что-то, кроме целого, — а в учётной системе ставки, проценты и доли есть всегда.

**Вторая: место на диске целое не экономит.** Средний `pg_column_size` у денежных величин: `numeric` — **6,98 байта**, `int64` — 8. Короткий формат `numeric` для сумм с двумя знаками оказывается компактнее, чем восьмибайтовое целое, а выравнивание у него мягче.

Так что выигрыш у фиксированной ширины есть, он большой и он ровно один — процессорное время на арифметике. Именно за него и борются все, кто ограничивает точность.

### Потолок в 38 цифр

А вот что не актуально, так это произвольная точность переменной длины. Потолок в 38 цифр (int128) выглядит де-факто универсальной константой:

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
| [YDB](https://ydb.tech/docs/en/yql/reference/types/primitive) | 35 | int128, 16 байт, precision и scale в типе |

### Чем платят за фиксированную ширину

Каждое техническое решение подразумевает какие-то компромиссы. Не обходится без этого и с СУБД, которые ограничивают точный десятичный тип. Например, Redshift [прямо предупреждает](https://docs.aws.amazon.com/redshift/latest/dg/r_Numeric_types201.html):

> Do not arbitrarily assign maximum precision to DECIMAL columns unless you are certain that your application requires that precision. 128-bit values use twice as much disk space as 64-bit values and can slow down query execution time.

Apache Arrow фиксирует ровно четыре ширины ([Schema.fbs](https://raw.githubusercontent.com/apache/arrow/main/format/Schema.fbs)):

> Exact decimal value represented as an integer value in two's complement. Currently 32-bit (4-byte), 64-bit (8-byte), 128-bit (16-byte) and 256-bit (32-byte) integers are used.» / «The accepted widths are 32, 64, 128 and 256.

Причём эволюция идёт в сторону сужения: Arrow 18.0.0 (октябрь 2024) [добавил Decimal32 и Decimal64](https://arrow.apache.org/blog/2024/10/28/18.0.0-release/), а не более широкие типы. Легко можно понять, что суть здесь в повышении производительности: 32-битные и 64-битные операции сильно легче 128-битных в текущих аппаратных системах.

Самый показательный источник — CedarDB, коммерческий наследник Umbra, движок, спроектированный в 2020-х. Он явно и письменно противопоставляет себя PostgreSQL ([документация по numeric](https://cedardb.com/docs/references/datatypes/numeric/)):

> «PostgreSQL offers a maximum precision of 131072 and scale of 16383, where **CedarDB restricts precision and scale to a maximum of 38, for performance reasons.**»
>
> «Operations on 16 Byte types are expensive to compute. We recommend using a precision of 18 or less when possible for your application.»
>
> «PostgreSQL allows NaN, +Infinity, and -Infinity as special numeric values» — «CedarDB forbids entering these values as numeric data types.»

Команда, которая целенаправленно делает быстрый PostgreSQL-совместимый движок, отказалась ровно от того, что делает `numeric` медленным: от произвольной точности, от varlena и от специальных значений.

Понятно, что у всего есть своя цена. Например ClickHouse [честно документирует](https://clickhouse.com/docs/sql-reference/data-types/decimal), что у широких фиксированных типов проверки переполнения нет вовсе. То есть у `Decimal32`/`Decimal64` переполнение целой части даёт исключение, а у `Decimal128`/`Decimal256` — молча неверный результат.

Поскольку у типа фиксированной ширины бюджет разрядов конечен, то разработке приходится балансировать. В данном случае, приходится искать баланс между шириной диапазона, проверками переполнения и специальными значениями. В таблице ниже компромиссы, которые удалось идентифицировать:

| Движок | Чем заплатил |
|---|---|
| ClickHouse | проверками переполнения — у `Decimal128`/`Decimal256` их нет |
| CedarDB | специальными значениями — `NaN` и `±Infinity` запрещены |
| YDB | диапазоном — три десятичных разряда из 38 отданы под служебные значения |
| PostgreSQL `numeric` | ничем |

Показательно и то, что YDB спроектирован независимо и в те же 2010–2020-е, что CedarDB и
DuckDB, — и пришёл к той же конструкции: целое фиксированной ширины, масштаб в типе, потолок
в районе 35–38. Произвольную точность переменной длины не выбрал никто.

## 9. Выводы

Собственно, что даёт нам это небольшое исследование?

Область применения `real` и `double precision` для величин, над которыми выполняется арифметика, стремится к нулю.

А вот между целым и точным десятичным выбор действительно есть, и он не про точность. Оба типа точны. Различает их то, чем задан масштаб. Если масштаб приходит извне и одинаков для всех строк — из кода валюты, из константы протокола, — целое работает идеально. Если же масштаб задан предметной областью, разный у разных полей и настраивается в работающей системе — целое не подходит в принципе, потому что одной константы масштаба на всю базу не хватит. Отсюда и наблюдаемая картина: в финансовых системах, выросших из старых форматов, живут целые типы, а в учётных и в более современных — вариации `DECIMAL`. Аргумент в пользу десятичного при прочих равных хорошо сформулировал Otar Chekurishvili в тексте [Storing money as integer cents is often over-engineering](https://world.hey.com/otar/storing-money-as-integer-cents-is-often-over-engineering-7238a485): целое не решает проблему, а перекладывает её на приложение.

Третий вывод оказался достаточно неожиданным. Обычно дискутируют вопросы хранения — как представлять копейки. Иногда доходят до вычислений — детерминированность, точка округления, правило на ровно половине. Но есть и третий аспект — сериализация: значение должно пережить переход через границу, где его разбирает парсер, который вы не писали и не контролируете.

Цена произвольной точности измерима, и она велика: больше порядка на уровне операции — 35 нс против 1 нс на накоплении суммы. Но выигрыш при переходе на целое ровно один, процессорное время: места на диске оно не экономит, а в смешанной арифметике со ставками и процентами даже проигрывает. Поэтому производительность точного десятичного типа явно стоит на повестке у разработчиков движков, и общий ответ выглядит одинаково — ограничить ширину. Типовым потолком стали 38 цифр. Однако и это не всегда влезает в int128, поэтому приходится искать компромисс: кто-то ослабляет проверки переполнения, кто-то выкидывает специальные значения вроде `NaN` или `Infinity`, кто-то часть диапазона. Никто не выбрал произвольную точность переменной длины — кроме PostgreSQL.

И главный постгресовый инсайт для меня состоит в том, что системе встроенных типов PostgreSQL не хватает `numeric` ограниченной ширины и точности. Именно эту конструкцию выбрали Arrow, SQL Server, DuckDB, ClickHouse, YDB и Power BI, и именно её у нас нет. Да, история знает уже как минимум три (заброшенные) попытки реализовать "быстрый" `decimal` тип, но кажется мне, что скоро разработчикам станет трудно игнорировать давление со стороны пользователей ... .

А вы что думаете? Поделитесь своим мнением в комментариях!
