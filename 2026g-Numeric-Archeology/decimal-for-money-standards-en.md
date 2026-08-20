# Why is `numeric` so popular in PostgreSQL databases?

The PostgreSQL documentation on `numeric` contains two [statements](https://www.postgresql.org/docs/current/datatype-numeric.html) that don't sit well together:

"especially recommended for storing monetary amounts and other quantities where exactness is required" — and right away: "calculations on `numeric` values are **very slow** compared to the integer types, or to the floating-point types". So the type is recommended for storing monetary amounts, and in the same breath admitted to be rather expensive.

For me, as a DBMS developer, that reads as a call to action. If operations on a type are noticeably slower than on `bigint`, a temptation arises: couldn't we store monetary amounts as an integer number of cents and round by the standard rule? That would save a fair amount of computing resources on our database servers, wouldn't it? And what if we went all the way and used `double precision`?

But before optimizing the type or swapping it for an integer, it's worth understanding what is actually demanded of it: by law, by data interchange formats, by application platforms. Is the exact decimal type really the standard for financial applications, if only a de-facto one? Or is it engineering folklore that can safely be worked around?

Rather than rely on survey literature, let's dig into the primary sources. This task has never been a simple one, but AI agents have made it much easier. So let's roll up our sleeves and get started. If the text feels overly dry or boring — well, that's because it is. Which is why there's a table of contents, so you can quickly jump to whatever you need.

## Table of contents

- [1. What the SQL standard says](#1-what-the-sql-standard-says)
- [2. What law and regulators require](#2-what-law-and-regulators-require)
- [3. Financial data interchange formats](#3-financial-data-interchange-formats)
- [4. Payment systems: scale as an attribute of the currency](#4-payment-systems-scale-as-an-attribute-of-the-currency)
- [5. What the TPC benchmarks require](#5-what-the-tpc-benchmarks-require)
- [6. What vendors, authorities, and practitioners say](#6-what-vendors-authorities-and-practitioners-say)
- [7. What's going on in ERP systems](#7-whats-going-on-in-erp-systems)
- [8. Where the exact decimal type is heading](#8-where-the-exact-decimal-type-is-heading)
- [9. Conclusions](#9-conclusions)

## 1. What the SQL standard says

ISO SQL has no MONEY type. And it's not just the type that's missing — the SQL standard has no notion of currency at all. The `money` type in PostgreSQL and `money`/`smallmoney` in SQL Server are vendor extensions, not implementations of the standard.

What the standard does have is three categories of numeric types:

- Exact numeric types: `NUMERIC`, `DECIMAL`, `SMALLINT`, `INTEGER`, `BIGINT`.
- Approximate numeric types: `FLOAT`, `REAL`, `DOUBLE PRECISION`.
- The decimal floating-point type: `DECFLOAT`.

There is a subtle semantic difference between `NUMERIC` and `DECIMAL`.

Subclause 6.1 "data type", Syntax Rules 28 and 29:
> 28) NUMERIC specifies the data type exact numeric, with the decimal precision and scale specified by the precision and scale. 29) DECIMAL specifies the data type exact numeric, with the decimal scale specified by the scale and the implementation-defined (ID063) decimal precision equal to or greater than the value of the specified precision.

To make the difference concrete: NUMERIC(15,2) is a hard limit of exactly 15 digits, while DECIMAL(15,2) means "no fewer than 15". Under this definition the two types can be merged into one — which is exactly what PostgreSQL's `numeric` does.

The standard does not forbid implementing an exact decimal type on top of a binary integer. Fixed width based on int64/int128 is an option the standard explicitly allows for. This is what makes the implementation variants in Arrow, SQL Server, DuckDB and others possible.

Subclause 4.5.2 "Characteristics of numbers":
"An exact numeric type has a precision P and a scale S. P is a positive integer that determines the number of significant digits in a particular radix R, where R is either 2 or 10. S is a non-negative integer. Every value of an exact numeric type of scale S is of the form n × 10⁻ˢ, where n is an integer such that −Rᴾ ≤ n < Rᴾ."

Bottom line: the exact decimal type `DECIMAL`/`NUMERIC` belongs to the mandatory core of SQL (feature E011-03), while `DECFLOAT` is optional (T076) — as is `BIGINT`, by the way.

One more point matters for analyzing the requirements on `numeric`: the SQL standard says nothing about minimum or maximum precision, but it does constrain the arithmetic — the scale rules for addition, subtraction, and multiplication are pinned down rigidly. The scale of division is left up to the implementation.

---

## 2. What law and regulators require

Council Regulation (EC) No 1103/97 [on the introduction of the euro](https://eur-lex.europa.eu/legal-content/EN/TXT/HTML/?uri=CELEX:31997R1103) is well thought through: it quite unambiguously requires six significant decimal digits with no rounding or truncation, and pins down deterministic behavior when rounding beyond that precision. A `float` type simply doesn't fit these requirements.

Article 4 of the regulation defines the very mechanics of conversion: the rate is taken with six significant figures, rounding or truncating it is forbidden, and converting one national currency into another goes only through the euro. Plus the final proviso: any other method of calculation is admissible only if it produces the same result.

> «The conversion rates shall be adopted with six significant figures.»
>
> «The conversion rates **shall not be rounded or truncated** when making conversions.»
>
> «Inverse rates derived from the conversion rates shall not be used.»
>
> «Monetary amounts to be converted from one national currency unit into another shall first be converted into a monetary amount expressed in the euro unit, which amount may be rounded to not less than three decimals… **No alternative method of calculation may be used unless it produces the same results.**»

Article 5 adds something you won't find in any standard: **the rule for behavior at exactly one half.** Amounts to be paid are rounded to the nearest cent, and if the conversion lands exactly half-way — round up.

> «Monetary amounts to be paid or accounted for when a rounding takes place after a conversion into the euro unit pursuant to Article 4 shall be rounded up or down to the nearest cent. … **If the application of the conversion rate gives a result which is exactly half-way, the sum shall be rounded up.**»

The British tax authority phrases the same thing in fractions of a penny. HMRC requires VAT to be calculated to three decimal places and rounded by the same rule: less than half a penny — down, half a penny or more — up ([HMRC VAT Trader Records, VATREC12030](https://www.gov.uk/hmrc-internal-manuals/vat-trader-records/vatrec12030)).

> «If the VAT on any transaction comes to less than 0.5 of one penny, it should be rounded down. If the VAT comes to 0.5 of one penny or more, it should be rounded up.»

So no direct prescription to "use an exact decimal type" can be found anywhere in the regulations. But taken together, they add up to a functionally equivalent requirement, and it consists of four parts:

1. **Storage must be exact down to the minor currency unit.** Binary `float` cannot represent 0.01 exactly, so a system built on `double precision` violates this by construction, no matter how carefully the application code is written.
2. **Rounding is a regulated operation performed at a single point**, not a side effect of arithmetic. The EU regulation puts it as bluntly as possible: the rates "shall not be rounded or truncated", and rounding to the cent happens exactly once, after the conversion.
3. **The behavior at exactly one half is spelled out explicitly.** Both the EU and HMRC single out the `0.5` case: round up. A type whose tie-breaking rule is implementation-defined does not, by itself, deliver on this norm.
4. **The number of decimal places depends on the currency**, not on the type: three decimals in the EU's intermediate conversion, fractions of a penny at HMRC. So the scale must be a parameter of the model, not a constant baked into the schema.

The law never names a type — it describes behavior. In PostgreSQL, the type that satisfies this set of requirements is `numeric`: exact decimal storage, no implicit rounding, explicitly controlled scale.

**And right here, something surfaces that no regulator has provided for.** The rounding rule the law defines unambiguously is not pinned down in DBMSs — it differs both between systems and between types within a single system. Bill Schneider [dissects](https://wrschneider.github.io/2022/03/08/spark-rounding.html) how Spark and SQL Server diverge on the very same decimal data: one system rounds, the other truncates. IBM went further than anyone in Db2 and simply [turned the rule into a setting](https://www.ibm.com/docs/en/db2-for-zos/12.0.0?topic=registers-current-decfloat-rounding-mode) — seven modes to choose from, with the default picked at installation time. In other words, no DBMS's data type will guarantee you "round up at exactly one half": the rounding will have to be done explicitly and in one place, exactly as point 2 demands.

## 3. Financial data interchange formats

The law speaks of behavior, not representation. Interchange formats, though, have no such luxury: they must commit to a concrete encoding, or two systems simply won't understand each other.

**ISO 20022** is what SWIFT, SEPA, and national payment systems run on. The message schemas live in the [official catalogue](https://www.iso20022.org/iso-20022-message-definitions), and a monetary amount is defined there like this ([camt.053](https://github.com/kedder/ofxstatement-iso20022/blob/master/doc/camt.053.001.05.xsd)):

```xml
<xs:simpleType name="ActiveCurrencyAndAmount_SimpleType">
    <xs:restriction base="xs:decimal">
        <xs:totalDigits value="18"/>
        <xs:fractionDigits value="5"/>
    </xs:restriction>
</xs:simpleType>
<xs:complexType name="ActiveCurrencyAndAmount">
    <xs:extension base="ActiveCurrencyAndAmount_SimpleType">
        <xs:attribute name="Ccy" type="ActiveCurrencyCode" use="required"/>
    </xs:extension>
</xs:complexType>
```

Structurally, that is a `NUMERIC(18,5)` plus a **mandatory** currency code attached to the value itself: a message without `Ccy` fails validation. There is no explicit ban on floating point in the text, but the intent is clear: in the official JSON binding, amounts travel as strings, which means a fixed size is the preferred option.
([ISO 20022 JSON Schema draft, 10.06.2025](https://www.iso20022.org/sites/default/files/media/file/ISO_20022_Generation_of_JSON_Schema_Draft_2020_12_for_ISO_20022_2013_10June2025.pdf)):
> «Number type are represented as strings because there was a preference for validating the total digits and fraction digits in the schema.»

**FIX** (exchange trading) is set up in a curious way: the type there is called `float`, yet there is no binary floating point behind the name. In text-based FIX 4.4, `float` is a sequence of digits with an optional decimal point and sign character — a decimal number spelled out in characters — and the specification requires it to accommodate at least fifteen significant digits ([FIX 4.4 dictionary, Onix](https://www.onixs.biz/fix-dictionary/4.4/index.html)):

> «Sequence of digits with optional decimal point and sign character… All float fields must accommodate up to fifteen significant digits.»

In FIXML the binding is [explicit](https://fiximate.fixtrading.org/en/FIX.Latest/fixml_datatypes.html):
`float`, `Qty`, `Price`, `Amt`, `Percentage` → `xs:decimal`.

And in the SBE binary encoding — the wire format exchanges use to pump their quote streams — the instruction is explicit: use decimal encodings for prices and everything monetary, and binary floating point only for those numeric fields that are not prices or monetary amounts.
([FIX SBE v1.0 RC4, Field Encoding](https://github.com/FIXTradingCommunity/fix-simple-binary-encoding/blob/master/v1-0-RC4/doc/02FieldEncoding.md)):
> «Decimal encodings should be used for prices and related monetary data types like PriceOffset and Amt.»
>
> «Binary floating point encodings are compatible with IEEE Standard for Floating-Point Arithmetic (IEEE 754-2008). They should be used for floating point numeric fields **that do not represent prices or monetary amounts**.»

## 4. Payment systems: scale as an attribute of the currency

Payments deserve a separate look, because the solution that took hold there exists neither in the standard nor in the law. The payment industry does not transmit money as fractional numbers at all. The reason most likely lies in the age of the system — in the standards, and in the IT capabilities of the 1960s–70s that shaped those standards.

**ISO 8583**, the protocol of the card networks, defines data element DE 4, "Amount, transaction", with the format **`n 12`** — twelve digits, and that's it. In a purely numeric fixed-length field there is simply no room for a decimal separator, so the scale is taken from outside — from the "Currency code" field. The amount on the wire is an integer, and how many decimal places it carries is determined by the currency. Currencies differ in that respect: JPY, KRW, and VND have zero, USD, EUR, and GBP have two, while BHD, KWD, OMR, TND, and JOD have three.

So in payments, the scale is an attribute of the currency, not a property of the number. It is not stored with the value and does not travel with it; it sits in a separate field, and the number stays an integer.

Payment HTTP APIs carry the card-network legacy forward, while those who arrived later — and from outside the card world — often choose to represent amounts as decimal strings:

| System / format | Amount | Message format |
|---|---|---|
| ISO 8583 | integer | binary |
| [FIX SBE](https://github.com/FIXTradingCommunity/fix-simple-binary-encoding/blob/master/v1-0-RC4/doc/02FieldEncoding.md) | integer | binary |
| [Stripe](https://docs.stripe.com/api/charges/object) | integer | JSON |
| [Adyen](https://docs.adyen.com/development-resources/currency-codes/) | integer | JSON |
| [Square](https://developer.squareup.com/reference/square/objects/Money) | integer | JSON |
| [Klarna](https://docs.klarna.com/api/payments/) | integer, minor units | JSON |
| [Google `Money`](https://raw.githubusercontent.com/googleapis/googleapis/master/google/type/money.proto) | integer | protobuf (binary), JSON in REST |
| [PayPal](https://raw.githubusercontent.com/paypal/paypal-rest-api-specifications/main/openapi/checkout_orders_v2.json) | decimal | JSON |
| [Shopify](https://shopify.dev/docs/api/admin-graphql/latest/scalars/Decimal) | decimal | JSON (GraphQL) |
| [Mollie](https://docs.mollie.com/reference/create-payment) | decimal | JSON |
| [Braintree](https://developer.paypal.com/braintree/docs/reference/request/transaction/sale) | decimal | JSON |
| [Wise](https://github.com/transferwise/api-docs/blob/master/source/includes/reference/_quotes.md) (legacy v1) | decimal | JSON |
| [Plaid](https://raw.githubusercontent.com/plaid/plaid-openapi/master/2020-09-14.yml) | decimal (`double`) | JSON |
| [ISO 20022](https://github.com/kedder/ofxstatement-iso20022/blob/master/doc/camt.053.001.05.xsd) | decimal (`decimal`) | XML |
| [FIX 4.x / Latest](https://fiximate.fixtrading.org/en/FIX.Latest/fix_datatypes.html) | decimal, text | text (tag=value) |

Out of this table climbs a third layer of requirements, one people rarely think about. The debate is usually about **storage** — whether a cent is representable. Sometimes it reaches **computation** — determinism, the rounding point, the rule at exactly one half. But there is also **serialization**: the value must survive crossing a boundary where it gets picked apart by a parser you didn't write and don't control.

The requirement at this layer is shaped differently from the first two. What's needed here is not exactness inside your system but agreement: two independent implementations in different languages must arrive at one and the same value, down to the last digit. And exactly one construction satisfies that — **an exact integer plus a scale defined outside the value**. Not because integers are somehow "more exact", but because the integer is the only numeric type that every language and every parser, without exception, has agreed upon. The scale, meanwhile, travels by its own road: in the stream schema (Arrow, Parquet, FIX SBE), in a neighboring field (Google's `units` + `nanos`), or in the currency code (ISO 8583, Stripe, Adyen).

So payment practice does not reject the exact decimal type — it adds a third, independent requirement on top of it, one found neither in the law nor in the SQL standard.

## 5. What the TPC benchmarks require

Benchmarks are a source of a special kind: they don't describe how things ought to be done — they record what the vendors have agreed to compete on. And here a split shows up. The TPC-C benchmark demands exact computation and adherence to the SQL standard.

[Standard Specification Rev. 5.11, clause 1.3.1](https://www.tpc.org/tpc_documents_current_versions/pdf/tpc-c_v5.11.0.pdf) —
> Numeric fields that contain monetary values (W_YTD, D_YTD, C_CREDIT_LIM, C_BALANCE, C_YTD_PAYMENT, H_AMOUNT, OL_AMOUNT, I_PRICE) **must use data types that are defined by the DBMS as being an exact numeric data type** or that satisfy the ANSI SQL Standard definition of being an exact numeric representation.

The same goes for TPC-E, only stricter: monetary types there are declared with concrete precision — the balance as `SENUM(12,2)`, aggregates as `SENUM(15,2)` — and the implementation is obliged to provide an **exact** representation of the declared decimal places.

[v1.14.0, clause 2.2.1](https://www.tpc.org/tpc_documents_current_versions/pdf/tpc-e_v1.14.0.pdf):
> «ENUM and SENUM… must be implemented using a Native Data Type which provides **exact representation** of at least n Digits of precision after the decimal place.»
>
> «BALANCE_T is defined as SENUM(12,2)… FIN_AGG_T is defined as SENUM(15,2)…»

The analytics-oriented benchmarks — TPC-H and TPC-DS — lower the bar on exactness. For `Integer` the exactness requirement is stated rigidly; for `Decimal` it is not: aggregates get a tolerance of 1% (AVG and ratios) and "within $100" (SUM). An exact match is required only for COUNT.

[TPC-H v3.0.1, clause 1.3.1](https://www.tpc.org/tpc_documents_current_versions/pdf/tpc-h_v3.0.1.pdf):
> «Decimal means that the column must be able to represent values in the range −9,999,999,999.99 to +9,999,999,999.99 in increments of 0.01; the values can be **either represented exactly or interpreted to be in this range**»

An interesting takeaway: the transactional benchmarks require an exact type verbatim, while the analytical ones explicitly permit approximation. A relaxation like that potentially opens the door to all sorts of optimizations for a query declared "analytical".

## 6. What vendors, authorities, and practitioners say

Next, it's worth looking at what the people who ought to know write about this: the developers of the DBMSs themselves, and the authors customarily cited in such debates.

With the vendors, the picture is uniform. The documentation of [PostgreSQL](https://www.postgresql.org/docs/current/datatype-numeric.html), [SQL Server](https://learn.microsoft.com/en-us/sql/t-sql/data-types/float-and-real-transact-sql), [MySQL](https://dev.mysql.com/doc/refman/8.4/en/fixed-point-types.html), and [IBM's materials](https://speleotrove.com/decimal/decifaq1.html) converge on one point: where an exact answer is needed, binary floating point should not be used — and financial calculations are named as the example in so many words. But notice what these texts do *not* contain. Not a single vendor says "use `numeric`" — they all state the requirement from the negative side, leaving the choice between an exact decimal type and an integer count of minor units open.

It's exactly the same with the authorities, and this was perhaps the biggest surprise for me: they are usually quoted in support of `decimal`, while what they actually say is something else.

**Joshua Bloch** in "[Effective Java](https://www.informit.com/store/effective-java-9780134685991)" (3rd edition, Addison-Wesley; Item 60, "Avoid float and double if exact answers are required") does indeed ban `float` and `double` wherever an exact answer is needed. But then he puts `BigDecimal` and the integer types **on equal footing**: `BigDecimal` — if you want the system to keep track of the decimal point and are willing to pay for that in inconvenience and performance; an integer — if performance is critical. And he draws a concrete boundary: up to nine digits, `int` will do; up to eighteen — `long`.

> In summary, don't use float or double for any calculations that require an exact answer. Use BigDecimal if you want the system to keep track of the decimal point and you don't mind the inconvenience and cost of not using a primitive type… **If performance is of the essence… use int or long.** If the quantities don't exceed nine decimal digits, you can use int; if they don't exceed eighteen digits, you can use long.

**Martin Fowler** in [Patterns of Enterprise Application Architecture](https://www.informit.com/store/patterns-of-enterprise-application-architecture-9780321127426) sets the monetary value apart as its own pattern, [Money](https://martinfowler.com/eaaCatalog/money.html) — and its essence is not the choice of type, but that the amount and the currency must travel together, and that rounding to the minor unit must be an explicit operation. On representation, Fowler is categorical about one thing only: no binary floating point. Between integer and decimal he does not choose. The book is available for purchase.

In the Postgres community, though, the positions diverge, and both are worth quoting. [Hans-Jürgen Schönig of Cybertec](https://www.cybertec-postgresql.com/en/postgresql-int4-vs-float4-vs-numeric/) is unequivocal: money demands special rounding rules, which is why financial data belongs in `numeric`.

> In the case of money, different rounding rules are needed, which is why numeric is the data type you have to use to handle financial data.

[Elizabeth Christensen of Crunchy Data](https://www.crunchydata.com/blog/working-with-money-in-postgres) gives a recommendation with a fork in it, closer to what we saw in Bloch: an integer — if whole cents suit you and you don't need fractional ones; `numeric` — if you need fractions of a cent and lots of digits in general. And as a separate point: store the currency nearby, but in its own field.

> «Use `int` or `bigint` if you can work with whole numbers of cents and you don't need fractional cents.» «Use `decimal` / `numeric` for storing money in fractional cents and even out to many many decimal points.» «Store currency separately from the actual monetary values…»

The most fleshed-out argument against integer cents comes from [Otar Chekurishvili](https://world.hey.com/otar/storing-money-as-integer-cents-is-often-over-engineering-7238a485), and it's not about exactness but about where the error lives. By storing `1999` instead of `19.99`, you don't solve the problem — you move it out of the database and into every other layer of the application: everyone who reads that column is now obliged to know about the implicit scale.

> When you store 1999 instead of 19.99, you don't actually solve a problem. You move it out of the database and into every other layer of the app.

Telling, too, is what the **Java money specification** (JSR 354) did: it deliberately does **not** fix the representation, because the requirements on it vary too much across usage scenarios.

> JSR 354 explicitly supports different types of monetary amounts to be implemented and used. Reason behind is that the requirements to an implementation heavily vary for different usage scenarios.

And this is no abstract caution: the reference implementation ships two classes at once — [`Money`](https://raw.githubusercontent.com/JavaMoney/jsr354-ri/master/moneta-core/src/main/java/org/javamoney/moneta/Money.java) on top of `BigDecimal` and [`FastMoney`](https://raw.githubusercontent.com/JavaMoney/jsr354-ri/master/moneta-core/src/main/java/org/javamoney/moneta/FastMoney.java) on top of `long`. The javadoc of the latter states outright that it is 10–15 times faster, with limited precision as the price.

## 7. What's going on in ERP systems

What remains is to look at the application systems that handle money every day — and, while we're at it, to check whether the declared type matches what actually happens to the number.

- **SAP** — `packed decimal` plus a mandatory currency field. [ABAP docs, currency field](https://eduardocopat.github.io/abap-docs/7.31/abencurrency_field/).
- **Oracle E-Business Suite / Fusion** — `NUMBER` with no precision or scale at all. [GL_JE_LINES](https://docs.oracle.com/en/cloud/saas/financials/26a/oedmf/gljelines-24789.html).
- **Odoo** — the most interesting case; we'll come back to it separately. The database column has type `numeric` ([odoo/fields.py 17.0](https://raw.githubusercontent.com/odoo/odoo/17.0/odoo/fields.py)), while the value in the ORM is a Python `float`; hence a whole module of helpers, [odoo/tools/float_utils.py](https://raw.githubusercontent.com/odoo/odoo/17.0/odoo/tools/float_utils.py).
- **1C:Enterprise** (the ERP platform dominant across Russia and the CIS). The platform's "Number" type — [ITS, "Precision of expression results and aggregate functions"](https://its.1c.ru/db/content/metod8dev/src/developers/platform/metod/query/i8102665.htm). Maximum precision of 38 digits, notation of the form `Число(17,4)` — i.e. Number(17,4) — and rules for deriving the result precision for addition, multiplication, and division.

**Odoo deserves a separate note, because the result is unexpected.** What we get is a production ERP whose columns are declared `numeric` while all the arithmetic runs in binary `double` — with all that this entails, which is exactly why `float_utils.py`, with its comparison and rounding helpers, had to be written. The lesson is broader than any single vendor: **a column type in the schema does not, by itself, mean the computation runs in decimal arithmetic.** The schema guarantees storage only. If the application pulled the value into a `double`, did the math, and wrote it back, the precision was lost in the application layer — while the database looks immaculate.

**And the section's overall takeaway, the one that matters for the question this article asks.** In payments, as we saw, the scale is an attribute of the currency: there is one, and it comes from outside. In accounting systems everything is different. In 1C the precision is set **per attribute**, with the `Число(N,M)` notation: amounts usually carry two decimal places, quantities three, coefficients and exchange rates more. In SAP a monetary field must be paired with a currency field, yet the scale is determined by the kind of quantity, not by the currency alone. In other words, **here the scale belongs to the domain, not to the currency unit** — and a single database holds several of them at once. That is precisely why an integer count of minor units does not save an ERP: one scale constant per schema is not enough, and SQL fixes the scale in the column type, not in the value.

## 8. Where the exact decimal type is heading

Now for the trend. The exact decimal type is not going anywhere — quite the opposite, it keeps spreading.

- Since late 2025, international payments run on ISO 20022 — and the precision of the monetary amount there is `totalDigits="18"`, i.e. **less than what `int64` provides**. The format carrying the entire world's interbank settlements has no need for arbitrary precision.
- C23 brought `_Decimal32/64/128` into the C language standard ([cppreference, C23](https://en.cppreference.com/c/23)) — optionally, though, behind the `__STDC_IEC_60559_DFP__` macro. GCC supports it partially; Clang and MSVC don't yet.
  ([The RFC in LLVM is still open](https://discourse.llvm.org/t/rfc-decimal-floating-point-support-iso-iec-ts-18661-2-and-c23/62152)).
- `DECFLOAT` from SQL:2016 is implemented not only in Db2, but also in Firebird 4.0 ([README:floating_point_types](https://raw.githubusercontent.com/FirebirdSQL/firebird/master/doc/sql.extensions/README.floating_point_types.md)).
- The exact decimal type exists in a multitude of DBMSs and in every columnar format.

In analytical engines, however, the picture is mixed — and it shows nicely where exactness is considered mandatory and where negotiable. Apache Druid has no exact numeric type at all and [rejected](https://github.com/apache/druid/issues/10190) a proposal to add one. ClickHouse lives comfortably with `Float64` and merely [recommends](https://clickhouse.com/docs/sql-reference/data-types/float) `Decimal` where exactness is needed. And Elasticsearch and Power BI took a third path — exact arithmetic at a fixed scale on top of an integer. That is, analytics converged not on "an exact type" but on "exact addition at a fixed scale" — which is precisely the relaxation TPC-H and TPC-DS allow.

The same split reaches outside DBMSs. Bloomberg's market-data API — from a company whose entire business is financial data — ships prices as `FLOAT64`, binary floating point, while its `DECIMAL` data type is to this day marked ["Currently Unsupported"](https://bloomberg.github.io/blpapi-docs/python/3.13/_autosummary/blpapi.DataType.html). A quote, after all, is not a ledger entry: for streaming market data the loose, within-1% world is enough — the very line the analytical engines drew.

### The 38-digit ceiling

What is *not* in fashion is variable-length arbitrary precision. The ceiling of 38 digits (int128) looks like a de-facto universal constant:

| System | Ceiling | Representation |
|---|---|---|
| [Snowflake](https://docs.snowflake.com/en/sql-reference/data-types-numeric) | 38 | adaptive width based on the actual range |
| [Redshift](https://docs.aws.amazon.com/redshift/latest/dg/r_Numeric_types201.html) | 38 | int64 up to 19 digits, int128 up to 38 |
| [SQL Server / Synapse](https://learn.microsoft.com/en-us/sql/t-sql/data-types/decimal-and-numeric-transact-sql) | 38 | 5/9/13/17 bytes |
| [Databricks / Spark](https://docs.databricks.com/aws/en/sql/language-manual/data-types/decimal-type) | 38 | long fast path up to 18 digits, BigDecimal beyond |
| [DuckDB](https://duckdb.org/docs/current/sql/data_types/numeric.html) | 38 | INT16/32/64/128 |
| [Iceberg](https://raw.githubusercontent.com/apache/iceberg/main/format/spec.md) | 38 | «precision must be 38 or less» |
| [ClickHouse](https://clickhouse.com/docs/sql-reference/data-types/decimal) | 76 | int32/64/128/256 |
| [BigQuery](https://raw.githubusercontent.com/google/zetasql/master/docs/data-types.md) | 38 / ~76.8 | int128 with different scales |
| [YDB](https://ydb.tech/docs/en/yql/reference/types/primitive) | 35 | int128, 16 bytes, precision and scale in the type |

### What fixed width costs

Every engineering decision implies some trade-offs, and the DBMSs that cap their exact decimal type are no exception. Redshift, for instance, explicitly talks users out of grabbing the maximum precision "just in case": 128-bit values take twice as much space as 64-bit ones and slow query execution down ([documentation](https://docs.aws.amazon.com/redshift/latest/dg/r_Numeric_types201.html)):

> Do not arbitrarily assign maximum precision to DECIMAL columns unless you are certain that your application requires that precision. 128-bit values use twice as much disk space as 64-bit values and can slow down query execution time.

Apache Arrow fixes exactly four widths and describes the representation outright: the exact decimal value is stored as a **two's-complement integer** — 32, 64, 128, or 256 bits — while the scale lives in the stream schema ([Schema.fbs](https://raw.githubusercontent.com/apache/arrow/main/format/Schema.fbs)):

> Exact decimal value represented as an integer value in two's complement. Currently 32-bit (4-byte), 64-bit (8-byte), 128-bit (16-byte) and 256-bit (32-byte) integers are used.» / «The accepted widths are 32, 64, 128 and 256.

Moreover, the evolution runs toward narrower, not wider: Arrow 18.0.0 (October 2024) [added Decimal32 and Decimal64](https://arrow.apache.org/blog/2024/10/28/18.0.0-release/), not wider types. The point is easy to see — performance: 32-bit and 64-bit operations are far cheaper than 128-bit ones on today's hardware.

The most telling source is CedarDB — the commercial heir of Umbra, an engine designed in the 2020s. It sets itself against PostgreSQL explicitly and in writing: where PostgreSQL offers precision up to 131072 digits, CedarDB caps it at 38 — and states in plain text that this was done for performance. Along the way, it recommends staying within 18 digits, because operations on 16-byte values are expensive, and it forbids the `NaN` and infinities that PostgreSQL allows ([numeric documentation](https://cedardb.com/docs/references/datatypes/numeric/)):

> «PostgreSQL offers a maximum precision of 131072 and scale of 16383, where **CedarDB restricts precision and scale to a maximum of 38, for performance reasons.**»
>
> «Operations on 16 Byte types are expensive to compute. We recommend using a precision of 18 or less when possible for your application.»
>
> «PostgreSQL allows NaN, +Infinity, and -Infinity as special numeric values» — «CedarDB forbids entering these values as numeric data types.»

A team purpose-building a fast PostgreSQL-compatible engine dropped exactly the things that make `numeric` slow: arbitrary precision, varlena, and the special values.

Naturally, everything comes at a price. ClickHouse, for one, [honestly documents](https://clickhouse.com/docs/sql-reference/data-types/decimal) that its wide fixed types have no overflow checks at all. That is, with `Decimal32`/`Decimal64` an overflow of the integral part raises an exception, while with `Decimal128`/`Decimal256` you silently get a wrong result.

Since a fixed-width type has a finite budget of digits, the designers have to strike a balance — here, between the width of the range, overflow checks, and special values. The table below lists the trade-offs I managed to identify:

| Engine | What it paid with |
|---|---|
| ClickHouse | overflow checks — `Decimal128`/`Decimal256` have none |
| CedarDB | special values — `NaN` and `±Infinity` are forbidden |
| YDB | range — three decimal digits out of 38 are reserved for sentinel values |
| PostgreSQL `numeric` | nothing |

It is telling, too, that YDB was designed independently — and in the same 2010s–2020s as CedarDB and DuckDB — and arrived at the same construction: a fixed-width integer, the scale in the type, a ceiling around 35–38. Variable-length arbitrary precision was chosen by no one.

## 9. Conclusions

So, what does this little investigation give us?

First, the range of uses for `real` and `double precision` — for quantities that arithmetic is actually performed on — is shrinking toward zero.

Between the integer and the exact decimal, though, there is a real choice. What separates them is where the scale is defined and how the rounding is performed. If the scale comes from outside and is the same for every row — from the currency code, from a protocol constant — and the rounding rules don't matter, the integer works perfectly. But if the scale is set by the domain, differs from field to field, and gets reconfigured in a live system, the integer is unsuitable in principle, because one scale constant for the whole database won't be enough. Otar Chekurishvili put it very precisely in [Storing money as integer cents is often over-engineering](https://world.hey.com/otar/storing-money-as-integer-cents-is-often-over-engineering-7238a485): the integer doesn't solve the problem — it shifts it onto the application.

The third conclusion turned out to be rather unexpected. The usual debate is about storage — how to represent cents. Sometimes it reaches computation — determinism, the rounding point, the rule at exactly one half. But there is a third aspect — serialization: the value must survive crossing a boundary where it gets picked apart by a parser you didn't write and don't control.

Meanwhile, the performance of the exact decimal type is plainly on the engine developers' agenda, and the common answer looks the same everywhere — cap the width. The typical ceiling settled at 38 digits. That, however, doesn't always fit into an int128, so a compromise has to be found: some relax the overflow checks, some throw out special values like `NaN` or `Infinity`, some give up part of the range. Nobody chose variable-length arbitrary precision — except PostgreSQL.

And the main Postgres insight, for me, is that PostgreSQL's built-in type system is probably missing a `numeric` of bounded width and precision. That is exactly the construction chosen by Arrow, SQL Server, DuckDB, ClickHouse, YDB, and Power BI — and exactly the one we don't have. Yes, history knows at least three abandoned attempts to build a "fast" `decimal` as an extension. But judging by where everyone else is heading, this demand will only get harder to ignore.

What do you think? Share your opinion in the comments!
