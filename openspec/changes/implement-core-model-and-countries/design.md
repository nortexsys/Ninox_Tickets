# Design: implement-core-model-and-countries

Owner: Core lane. Written by the orchestrator on 2026-09-28. §2–§3 (T1.1–T1.2, the shared contract)
are detailed for dispatch now; §4–§5 (T1.3–T1.4) are detailed before their own dispatch, after the
product owner has reviewed the contract.

## 1. Rules that bind every file of this change

* `packages/paperdrop_core/lib/` imports only `dart:core`, `dart:collection`, `dart:math`,
  `dart:convert`, `dart:typed_data` and its own files (`core-purity` CI job). No new dependency in
  `pubspec.yaml` without the orchestrator; `dev_dependencies` stays `test`.
* **No `double` anywhere in `lib/`** that holds or computes money or a rate — not as a parameter, a
  field, a return type or an intermediate. `num` is also refused. Enforced by a test that scans
  `lib/` for `double`, `num `, `toDouble` and `parse(`-to-double (task 1.5).
* Every public type is immutable (`final` fields, `const` constructors where possible), has value
  equality and `hashCode`, and a `toString` that never prints more than the value itself.
* `lib/paperdrop_core.dart` exports the public API; implementation lives under `lib/src/`.
* Tests follow the scenario tag convention of plan §11.1: a test that proves a whole scenario is
  named `[<capability>/<requirement>] <scenario name verbatim>`. A test that proves only part of a
  scenario is **not** tagged; it names the scenario in a comment instead. A wrong tag is worse than
  a missing one.
* English everywhere; dartdoc on every public member, citing the requirement identifier it serves.

## 2. T1.1 — Money and rates (BR-09)

```
lib/src/money/currency.dart     CurrencyCode, Iso4217 table
lib/src/money/money.dart        Money
lib/src/money/rate.dart         RateBp
```

**`CurrencyCode`** — a validated three-letter upper-case ISO 4217 alphabetic code with its minor-unit
exponent. Constructed only through `CurrencyCode.parse(String)`, which returns `null` for a code not
in the table. **There is no default exponent**: an unknown code is not a currency (a missing
exponent must never silently become 2). The table holds every *active* ISO 4217 code with its
exponent, transcribed from the ISO 4217 list maintained by SIX (the maintenance agency); the file
header cites the source and its publication date. Tests use the standard vectors: EUR 2, USD 2,
GBP 2, CHF 2, MAD 2, SEK 2, JPY 0, KRW 0, KWD 3, BHD 3, TND 3, CLF 4; `XXX` and `ABC` are rejected.

**`Money`** — `(int minor, CurrencyCode currency)`.
* `Money.parseDecimal(String text, CurrencyCode c)` accepts only the canonical form
  `-?[0-9]+(\.[0-9]+)?` with a dot, and **rejects** more fractional digits than the exponent (never
  rounds). `'19.99'` EUR → `1999`; `'19.9'` → `1990`; `'19.999'` EUR → error; `'100'` JPY → `100`;
  `'1.5'` JPY → error. Locale formats (`19,99`, `1.234,56`) are **not** this function's job: format
  inference is T1.4 (FR-CTR-005).
* `+`, `-`, unary `-`, `compareTo`, `isZero`, `isNegative`. Operands of different currencies throw
  `CurrencyMismatchError`; there is no implicit conversion anywhere.
* `toDecimalString()` → canonical text (`1999` EUR → `'19.99'`, `-5` EUR → `'-0.05'`,
  `100` JPY → `'100'`). For logs and tests only; never used to compute.
* Overflow: amounts are bounded to `|minor| ≤ 10^15`; construction and every operation throw
  `MoneyRangeError` outside it. `minor × basis points` can reach 10^19, beyond a signed 64-bit
  `int`, so the exact product below is computed with `BigInt` (`dart:core`). Corrected after the
  first dispatch, where the Core lane found the overflow in this design.

**`RateBp`** — an integer number of basis points, `0 ≤ bp ≤ 10000` (a tax rate above 100 % is
rejected). `RateBp.parsePercent('21')` → 2100, `'5.5'` → 550, `'2.75'` → 275, `'5.555'` → error
(more than two fractional digits is not a basis-point value).

**Exact product.** `Money.timesRate(RateBp r)` returns an `ExactAmount`: the numerator
`minor × bp` over the fixed denominator 10000, in that currency. It exposes `compareToMoney(Money)`
and `distanceInMinorUnits(Money)` as exact integer arithmetic (the latter returns the distance as a
rational `(numerator, 10000)` or equivalent integers — never a float). **No rounding function
exists in this change**: which rounding and which tolerance apply is FR-VAL-006, task T1.7.

## 3. T1.2 — Canonical model (FR-EXT-011, Funcional §6.1–§6.2)

```
lib/src/model/provenance.dart       Provenance, ValueSource
lib/src/model/confidence.dart       ConfidenceState
lib/src/model/field_value.dart      FieldValue<T>
lib/src/model/canonical_document.dart  CanonicalDocument, TaxSlot, Surcharge, SurchargeLabel, enums
```

**`Provenance`** — exactly four values: `read`, `fromXml`, `derived`, `repaired` (Funcional §6.2.1).
`bool get mayConfirm` is `true` for `read` and `fromXml` only — this is the fact FR-VAL-002 consumes.
Wire names for serialisation: `read`, `from_xml`, `derived`, `repaired`.

**`ValueSource`** — `document`, `memory` (a user value is the `Edited` case below, not a source). Separate from provenance on purpose: the four tags
of Funcional §6.2.1 describe how a value was obtained *from the document*, and §6.1.1's "memory" for
`supplier_name` is recorded here, so both statements of the functional hold without changing either
(GAP-028 closed 2026-09-28: the functional is the source of truth, no document is changed). Supplier
memory is R1 (UC-15); in the MVP no value is built with `ValueSource.memory`.

**`ConfidenceState`** — `green`, `amber`, `red` (Funcional §6.2.2). The model holds the state; the
rules that assign it are T1.7.

**`FieldValue<T>`** — a sealed class with four cases:
* `Present<T>(T value, Provenance provenance, ConfidenceState confidence, {ValueSource source =
  document})` — an **extracted** value. `provenance` is required and non-nullable: an untagged
  extracted value cannot be built (FR-EXT-011). `source` is `document` or `memory`; `user` is not
  accepted here.
* `Edited<T>(T value)` — a value the user typed or corrected on the review screen, **whatever the
  field held before** (`Present`, `Absent` or `NotInXml`). It carries **no provenance tag and no
  confidence state**: it is not an extracted value, so FR-EXT-011's tag does not apply, and DEC-007
  makes the "edited" marker replace the confidence colour (`review-screen` ·
  `user-edits-are-authoritative`). It is always the value sent, and **it can never confirm
  anything**: no check may treat it as `read` (BR-02). `FieldValue.edit(T value)` returns an
  `Edited` from any case. Decided by the product owner on 2026-09-28; it replaces the first
  dispatch's `copyWithEdit`, which kept the original tag and colour and could not represent a field
  the user filled from empty.
* `Absent()` — nothing was read. Distinct from zero: there is no `Present(0)` shortcut and no
  getter that turns `Absent` into `0` (BR-13, `validation-confidence` · `absent-is-not-zero`).
* `NotInXml()` — the structured e-invoice route's status for a field its profile does not carry
  (FR-EXT-003). Never equal to `Absent`, never zero.

**`CanonicalDocument`** — immutable, one `FieldValue` per field; list fields as unmodifiable lists.
* Core fields, §6.1.1, in this order: `docDate` (`FieldValue<CalendarDate>`), `supplierName`,
  `supplierTaxId`, `docNumber` (text), `grossTotal` (`FieldValue<Money>`), `currency`
  (`FieldValue<CurrencyCode>`).
* Extended groups, §6.1.2: `docTime` (`HH:MM` as a small value type, not a `DateTime`),
  `docSeries`, `controlCode`; `supplierAddress`, `supplierCity`, `supplierCountry` (ISO 3166-1
  alpha-2, validated shape); `netTotal`, `taxTotal`, `discountTotal` (`Money`); `taxSlots` — a list
  of `TaxSlot { FieldValue<RateBp> rate, FieldValue<Money> base, FieldValue<Money> amount }`, one per
  printed rate (slot count per country is T1.3); `exchangeRate` — **kept as the printed text**
  (`FieldValue<String>`): §6.1.2 says "decimal, as printed" and no computation in the MVP uses it;
  `paymentMethod` (enum: card, cash, transfer, direct_debit, other); `cardBrand`; `cardMasked` —
  its constructor **refuses** anything but at most four digits (optionally preceded by mask
  characters), whatever the ticket shows (§6.1.2, `AGENTS.md` §1.2); `authCode`; `iban`
  (normalised text; the modulo-97 check is T1.3); `surcharges` — a list of
  `Surcharge { SurchargeLabel label, FieldValue<Money> amount }`, labels exactly `dccMarkup`,
  `serviceCharge`, `tip`, `roundingAdjustment`, `other` (wire names `dcc_markup`, `service_charge`,
  `tip`, `rounding_adjustment`, `other`); travel: `licenceNumber`, `vehiclePlate`, `tripFrom`,
  `tripTo`, `distanceKm`, `durationMin` (`int`).
* Metadata: `needsReview` (bool), `recognitionEngine` (text, includes the route), `sourceHash`
  (text). The per-field `confidence` metadatum of §6.1.2 is read from the `FieldValue`s, not stored
  twice.
* **Deferred to R1:** `docSubtype`, `grossTotalDocumentCurrency`, `grossTotalCardCurrency`. They
  belong to the canonical model — the product owner ruled on 2026-09-28 that Funcional §6.1.2
  governs over PRE-006 (GAP-027 closed, DEC-013) — but no MVP surface uses them: the MVP maps the six
  core fields plus `net_total` and `tax_total`, and no `choice` field (plan v0.2 §2, §4, FR-DST-007).
  They are added after the MVP, in R1. Do not add them now, and do not add placeholders.
* **Deferred to R1: `docType`.** Funcional §6.1.2 types it as an enum and lists no values (GAP-029).
  Nothing in the MVP fills, shows or maps it, and a free-text field would invite invented values.
  The product owner decided on 2026-09-28 to leave it out until its values are defined in R1.
* **The attachment is not part of the model** (BR-22).
* Currency invariant: when `currency` is `Present`, every `Present` amount in the document must be in
  that currency; the constructor throws otherwise. When `currency` is not `Present`, amounts keep the
  currency they were interpreted in, and what that means (BR-12, amounts suppressed) is T1.6/T1.7.

**`CalendarDate`** — a `YYYY-MM-DD` value type (year, month, day as `int`, validated including leap
years), not `DateTime`: a document date has no time zone, and `DateTime` invites one.

**JSON.** `toJson`/`fromJson` for every type, so Mobile's store and QA's fixtures share one shape:
money as `{"minor": 1999, "currency": "EUR"}`, rates as integers, provenance by wire name, `Absent`
and `NotInXml` as `{"state": "absent"}` / `{"state": "not_in_xml"}`, `Edited` as
`{"state": "edited", "value": …}` with no provenance or confidence key. A round-trip test over a fully
populated document proves no value changes type (**no amount ever becomes a JSON number with a
fraction or a string**). This is the core's side of BR-09; the store and the payload are proven by
their own lanes.

## 4. T1.3 — Country table ES + DE and check digits

Detailed on 2026-09-30. Requirements: `countries-languages` · `universal-core` (the EAN-13 and IBAN
half), `country-table-contract`, `launch-rows` (ES and DE rows only — AT and CH are R1, plan §4.8),
`three-spanish-formats-are-three-algorithms`, `country-identifier-check-digits`,
`tax-identifier-normalisation`; `validation-confidence` · `check-digit-validators` (FR-VAL-005).
Detection from the identifier is included because it is the table's natural lookup; detection from
currency, address and language (the rest of FR-CTR-001) is integration work, T2.1.

```
lib/src/checks/ean13.dart           isValidEan13
lib/src/checks/iban.dart            Iban (normalise, isValid), the IBAN length table
lib/src/countries/tax_id.dart       TaxIdType, TaxId (raw + normalised), normaliseTaxId
lib/src/countries/es_nif.dart       one file per algorithm: es_nif, es_nie, es_cif
lib/src/countries/es_nie.dart
lib/src/countries/es_cif.dart
lib/src/countries/country_table.dart  CountryRow, CountryTable (ES, DE)
```

**Validators return a verdict, not a bool,** so the confidence rules of T1.7 can tell "checked and
valid" from "not checkable": `enum CheckResult { valid, invalid, notChecked }`. `notChecked` is what
`DE_STNR` always returns; it carries no doubt by itself (`country-identifier-check-digits`, *the German
Steuernummer is deliberately left unchecked*). A malformed input (wrong length, wrong alphabet) is
`invalid`, never an exception.

**Universal core** — depends on nothing in the country table (`universal-core`):
* `isValidEan13(String)` → `CheckResult`: 13 ASCII digits; weights 1, 3, 1, … over the twelve leading
  digits beginning with 1; the check digit makes the total a multiple of 10.
* IBAN: normalise (uppercase, remove spaces), then the length must equal the fixed length of its
  country code in an **IBAN length table** transcribed from the SWIFT IBAN Registry (every country of
  the registry; the file header cites the registry release). An unknown country code is `invalid`.
  Then move the first four characters to the end, letters → 10…35, remainder modulo 97 must be 1.
  Compute the remainder piecewise on `int` (no `BigInt` needed): feed the digit string in chunks.
  The length table is transcribed by a model like the ISO 4217 table: QA checks it (task 3.2).

**`TaxIdType`** — `esNif`, `esNie`, `esCif`, `deUstid`, `deStnr`. Wire names `ES_NIF`, `ES_NIE`,
`ES_CIF`, `DE_USTID`, `DE_STNR` (the functional's spelling).

**Normalisation** (`tax-identifier-normalisation`): `TaxId.parse(String raw)` keeps `raw` exactly as
printed and computes `normalised`: uppercase, spaces, dots and hyphens removed, and the country prefix
where the number is an intra-EU VAT identifier (`DE 123 456 789` → `DE123456789`). A Spanish
identifier printed with an `ES` prefix keeps it in the normalised form (`ESA28017895`); its type is
decided on the part after the prefix. `A-28.017.895` → `A28017895`, type `ES_CIF`.

**Type classification is by shape, then the type's own algorithm** — never "try every algorithm until
one passes". `classify(normalised)` returns the one type whose *shape* matches:
* `ES_NIF`: 8 digits + letter; `ES_NIE`: `X`/`Y`/`Z` + 7 digits + letter; `ES_CIF`: one of the CIF
  issuing letters `ABCDEFGHJNPQRSUVW` + 7 digits + a digit or a letter of `JABCDEFGHI`. The three
  shapes are disjoint, so a value is never validated by another type's algorithm
  (`three-spanish-formats-are-three-algorithms`).
* `DE_USTID`: `DE` + 9 digits. `DE_STNR` is **not** classified from shape — it has no stable national
  format; it is a type a later step assigns from a label (`Steuernummer`, `St.-Nr.`), and its
  validator returns `notChecked` unconditionally.
* Anything else → `null` (unclassified). No guessing.

**The three Spanish algorithms live in three files that share no code** — not a helper, not the
mod-23 letter table. `ES_NIE` has its own copy of `TRWAGMYFPDXBNJZSQVHLCKE`: the duplication is the
requirement (Annex B.2: "separate code from NIF").
* `ES_NIF`: letter index = the eight digits mod 23 over `TRWAGMYFPDXBNJZSQVHLCKE`.
* `ES_NIE`: `X`→0, `Y`→1, `Z`→2 prepended to the seven digits, then the mod-23 letter.
* `ES_CIF`, exactly as the spec states it: over the seven digits, digits in odd positions (1st, 3rd,
  5th, 7th) are doubled and the digits of each product summed; digits in even positions are added;
  control = `(10 − sum mod 10) mod 10`. For issuing letters `N P Q R S W` the control must be the
  letter at that index of `JABCDEFGHI`; for every other issuing letter it must be the digit. (Real
  registries accept either form for some letters; the spec does not, and it governs — see §7.)

**`DE_USTID` is blocked (GAP-030, opened 2026-09-30).** The functional and the spec say ISO 7064
mod-97-10; the published algorithm is ISO 7064 MOD 11,10, and two published valid identifiers fail
mod-97-10. Until the product owner decides, T1.3 implements the `DE_USTID` shape, the classification
and the normalisation, and its validator returns `notChecked`, with a dartdoc and a test that cite
GAP-030. Do not implement either algorithm for it.

**Standard vectors** (verified by the orchestrator with python-stdnum on 2026-09-30; a test that
disagrees with one of these is reported, not "fixed"):

| Type | Valid | Invalid |
| --- | --- | --- |
| EAN-13 | `8435430627640` (Annex D.1), `4006381333931` | `8435430627840` (D.1's competitor), `4006381333932`, 12 or 14 digits, a letter |
| IBAN | `DE89370400440532013000`, `ES9121000418450200051332`, `GB82WEST12345698765432`, `FR1420041010050500013M02606`, `NO9386011117947`, and the first one printed in groups of four | `GB82TEST12345698765432`, `DE89370400440532013001`, a DE IBAN one character short, unknown country `QQ` |
| `ES_NIF` | `12345679S` (DEC-001 — the only NIF a test may use) | `12345679T`, `123456795` (D.2's misreading), 7 or 9 digits |
| `ES_NIE` | `X1234567L`, `Y1234567X`, `Z1234567R` | `X1234567T`, `W1234567L` (not a NIE shape → unclassified) |
| `ES_CIF` | `A28017895` (the spec's), `B12345674`, `Q2826000H` | `A28017894`, `A2801789J` (A takes a digit), `Q28260005` (Q takes a letter) |

The three NIE vectors are the public documentation examples of the format, not persons' data, but
the privacy job flags any valid NIE: the lane does not work around it (no string splitting to dodge
the regex). It reports the findings, and QA allowlists exactly those three lines with that reason.

**`CountryRow`** (`country-table-contract`): `countryCode` (ISO 3166-1 alpha-2), `currency`
(`CurrencyCode`), `taxIdTypes` (list), `legalRates` (`Set<RateBp>`), `slotCount` — **a getter equal
to `legalRates.length`**, never a stored field (*the slot count follows the rate set*), `dateOrder`
(§5's `DateOrder`) and `dateSeparator`, `decimalConvention` (§5), `cashRounding` (`none` for both
rows; the CH 5-Rappen rule is R1). `isLegalRate(RateBp)`.

**`CountryTable`**: `const` rows for **ES** (EUR; `ES_NIF`, `ES_NIE`, `ES_CIF`; 2100, 1000, 400, 0;
4 slots; `DD/MM/YYYY`; decimal comma) and **DE** (EUR; `DE_USTID`, `DE_STNR`; 1900, 700, 0; 3 slots;
`DD.MM.YYYY`; decimal comma). `rowFor(String countryCode)` → `CountryRow?`; `rowForTaxIdType(TaxIdType)`
→ `CountryRow` (the row of an identifier's type — the identifier half of FR-CTR-001: *a Spanish ticket
is detected from its identifier*, *a German invoice needs no user action*). A country with no row
returns `null` and the universal core still applies (*a country with no row still gets the core
checks*: the EAN-13 and IBAN functions take no row).

Adding a country is one row plus at most one validator file: the test *adding a country touches almost
nothing* is proved structurally — a test that builds a third `CountryRow` in the test file (not in
`lib/`) and runs the table lookups on it, with no change in `lib/`.

## 5. T1.4 — Format inference and dictionaries

Detailed on 2026-09-30. Requirements: `countries-languages` · `format-inference`,
`document-dictionaries-are-separate-from-interface-language`; `extraction-pipeline` ·
`multilingual-label-dictionaries` (the dictionaries and their lookup), `negative-context-suppresses-non-tax-figures`
(**the list only** — the influence radius and what happens to a candidate inside it are FR-EXT-010's
application rule, T1.6); `validation-confidence` · `date-coherence-and-ambiguity` (FR-VAL-013) on the format side only: an
undecided date order is returned as `null` so the caller can flag it; the flag is T1.7.

```
lib/src/format/decimal.dart        DecimalConvention, inferDecimalConvention, parsePrintedAmount
lib/src/format/date.dart           DateOrder, inferDateOrder, parsePrintedDate
lib/src/dictionaries/labels.dart   LabelKind, the positive label seeds of Annex C
lib/src/dictionaries/negative.dart the negative-context seeds of Annex C
lib/src/dictionaries/lookup.dart   the matcher
```

**Decimal convention** (*grouping separates the two decimal conventions*): `enum DecimalConvention {
commaDecimal, dotDecimal }`. `inferDecimalConvention(Iterable<String> printedAmounts)` →
`DecimalConvention?` from the document's own evidence: a separator followed by exactly three digits
and then the other separator (`1.234,56`, `1,234.56`) decides; a single separator followed by exactly
two digits at the end decides in favour of that separator being the decimal one; a lone separator
followed by exactly three digits (`1.234`) decides nothing. Contradictory evidence within one
document → `null`. **No evidence → `null`, never a default**; the caller may then use the country
row's convention (both MVP rows are comma-decimal), and that fallback is the caller's, not hidden here.

`parsePrintedAmount(String printed, DecimalConvention c, CurrencyCode currency)` → `Money?`: strips
the grouping separator of `c` (and spaces used as grouping, `1 234,56`), turns the decimal separator
into `.`, and hands the result to `Money.parseDecimal`, whose rejections stand (more fractional digits
than the exponent → `null`, never rounding). A leading `-` or a trailing `-` is a negative amount.
Currency symbols are not this function's job: the input is the number only. Vectors: `1.234,56`
comma → 123456; `1,234.56` dot → 123456; `1.234,56` dot → `null`; `0,5` comma EUR → 50;
`12,345` comma EUR → `null` (three decimals); `100` JPY either convention → 100.

**Date order** (*a day greater than twelve resolves the order*): `enum DateOrder { dmy, mdy, ymd }`.
`inferDateOrder(Iterable<String> printedDates)` → `DateOrder?`: four leading digits → `ymd`; otherwise
a first component greater than 12 → `dmy`, a second component greater than 12 → `mdy`; contradiction →
`null`; nothing decisive → `null`. `parsePrintedDate(String printed, DateOrder order)` →
`CalendarDate?` over the separators `.`, `/`, `-`; two-digit years are **rejected** (`null`) — the
spec gives no pivot rule, and inventing one is a decision. Invalid calendar dates → `null`.
Vectors: `13.08.2026` → inferred `dmy`, 2026-08-13; `08/13/2026` → `mdy`; `2026-08-13` → `ymd`;
`05.06.2026` alone → `null` order; `31.02.2026` dmy → `null`; `13.08.26` → `null`.
*The Spanish row uses a different date format*: when inference returns `null`, the caller uses the
detected row's `dateOrder` and separator — proved by a test that parses `05/06/2026` with the ES row
as 5 June and does not accept `05.06.2026` as the ES row's format.

**Dictionaries** — data, `const`, independent of any interface language (nothing in `lib/` may read
a locale). Seeds exactly as Funcional Annex C prints them, each term with its language code:
* `enum LabelKind { total, tax, base, supplier, date, docNumber }` and the positive seeds for each;
* the negative-context seeds, all 22 of Annex C, each with its language and a `SurchargeLabel` hint
  where the term names one (`DCC`, `mark-up`, `markup`, `currency conversion`, `conversión de divisa`
  → `dccMarkup`; `propina`, `tip` → `tip`; `service charge` → `serviceCharge`; the rest → none).
  The negative list must contain at least the nine terms of the spec's scenario *the negative-context
  list spans the languages of the market*, in Spanish, German, French and English. A term carries a
  **set** of languages: `commission` is spelled the same in English and French and is tagged with
  both; it is Annex C's only French negative term, and the lane adds no other (a new term is a data
  change the product owner makes as real documents demand).
* Terms are stored as printed (`Total à payer`, `MwSt.`); do not strip accents.

**Lookup:** `findTerms(String line)` → the matches (term, kind or negative, language, start, end) in
that line: case-insensitive (Unicode-aware lower-casing), whitespace runs collapsed, **whole-word
only** — `tip` must not match inside `tipo`, `HT` not inside `HTTP`, `Tomo` not inside `Tomorrow`. A
longer term wins over a shorter one at the same position (`TOTAL A PAGAR` over `TOTAL`). The matcher
consults every language's seeds whatever the interface language (*a foreign document is parsed
regardless of the interface language*). Which label then binds which value is FR-EXT-014's
application, T1.5–T1.6.

## 6. What this change does not do

No I/O, no Flutter, no network. No confidence rule, no solver, no layout reasoning (T1.5–T1.7). No
serialisation format decision for the store beyond the JSON shape of §3.

## 7. Risks

* **The ISO 4217 table is transcribed by a model.** A wrong exponent is a silent ×10 error on every
  amount in that currency. Mitigation: the vectors of §2 and a QA check of the table against the
  published list before the change is merged.
* **The IBAN length table** has the same risk (a wrong length rejects every IBAN of a country).
  Mitigation: QA checks it against the SWIFT IBAN Registry (task 3.2).
* **`ES_CIF` control form.** The spec requires a letter for `N P Q R S W` and a digit otherwise. Real
  registries accept either form for some issuing letters (`C D F G J U V`); a genuine CIF printed with
  a letter control for one of those would be rejected. The spec governs; if the corpus shows such a
  CIF, it becomes a gap, not a local fix.
* **`DE_USTID` (GAP-030).** Blocked on the product owner: the spec's algorithm is not the published
  one (§4).
* **Shape churn.** Ninox and Mobile start against these types on Wed 30 Sep; a rename after that
  costs three lanes. The orchestrator reviews §3's public API with the product owner before those
  lanes are dispatched.
