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
  `MoneyRangeError` outside it, so `minor × basis points` (§ below) stays inside a 64-bit `int`.

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

**`ValueSource`** — `document`, `memory`, `user`. Separate from provenance on purpose: the four tags
of Funcional §6.2.1 describe how a value was obtained *from the document*, and §6.1.1's "memory" for
`supplier_name` is recorded here, so both statements of the functional hold without changing either
(GAP-028 closed 2026-09-28: the functional is the source of truth, no document is changed). Supplier
memory is R1 (UC-15); in the MVP no value is built with `ValueSource.memory`.

**`ConfidenceState`** — `green`, `amber`, `red` (Funcional §6.2.2). The model holds the state; the
rules that assign it are T1.7.

**`FieldValue<T>`** — a sealed class with three cases:
* `Present<T>(T value, Provenance provenance, ConfidenceState confidence, {ValueSource source =
  document, bool edited = false})`. `provenance` is required and non-nullable: an untagged value
  cannot be built. `edited` is the review screen's marker (DEC-007, `review-screen` ·
  `user-edits-are-authoritative`); `copyWithEdit(T value)` returns a `Present` with
  `source: user`, `edited: true`, and **the confidence state unchanged** (editing never re-imposes a
  colour) — note: *which* provenance an edited value carries is not specified anywhere; keep the
  original provenance and flag it in the lane report rather than choose.
* `Absent()` — nothing was read. Distinct from zero: there is no `Present(0)` shortcut and no
  getter that turns `Absent` into `0` (BR-13, `validation-confidence` · `absent-is-not-zero`).
* `NotInXml()` — the structured e-invoice route's status for a field its profile does not carry
  (FR-EXT-003). Never equal to `Absent`, never zero.

**`CanonicalDocument`** — immutable, one `FieldValue` per field; list fields as unmodifiable lists.
* Core fields, §6.1.1, in this order: `docDate` (`FieldValue<CalendarDate>`), `supplierName`,
  `supplierTaxId`, `docNumber` (text), `grossTotal` (`FieldValue<Money>`), `currency`
  (`FieldValue<CurrencyCode>`).
* Extended groups, §6.1.2: `docType`, `docTime` (`HH:MM` as a small value type, not a `DateTime`),
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
* **The attachment is not part of the model** (BR-22).
* Currency invariant: when `currency` is `Present`, every `Present` amount in the document must be in
  that currency; the constructor throws otherwise. When `currency` is not `Present`, amounts keep the
  currency they were interpreted in, and what that means (BR-12, amounts suppressed) is T1.6/T1.7.

**`CalendarDate`** — a `YYYY-MM-DD` value type (year, month, day as `int`, validated including leap
years), not `DateTime`: a document date has no time zone, and `DateTime` invites one.

**JSON.** `toJson`/`fromJson` for every type, so Mobile's store and QA's fixtures share one shape:
money as `{"minor": 1999, "currency": "EUR"}`, rates as integers, provenance by wire name, `Absent`
and `NotInXml` as `{"state": "absent"}` / `{"state": "not_in_xml"}`. A round-trip test over a fully
populated document proves no value changes type (**no amount ever becomes a JSON number with a
fraction or a string**). This is the core's side of BR-09; the store and the payload are proven by
their own lanes.

## 4. T1.3 — Country table ES + DE and check digits

To be detailed before dispatch: Annex B rows for ES and DE, `countries-languages` ·
`country-table-contract`, `launch-rows`, `three-spanish-formats-are-three-algorithms`,
`country-identifier-check-digits`, `tax-identifier-normalisation`; `validation-confidence` ·
`check-digit-validators` with the standard vectors (EAN-13, IBAN, `ES_NIF`, `ES_NIE`, `ES_CIF`,
`DE_USTID`). The synthetic `12345679S` / `123456795` of DEC-001 is the only Spanish personal
identifier a test may use.

## 5. T1.4 — Format inference and dictionaries

To be detailed before dispatch: `countries-languages` · `format-inference`,
`document-dictionaries-are-separate-from-interface-language`; `extraction-pipeline` ·
`multilingual-label-dictionaries`, `negative-context-suppresses-non-tax-figures` (the list only).

## 6. What this change does not do

No I/O, no Flutter, no network. No confidence rule, no solver, no layout reasoning (T1.5–T1.7). No
serialisation format decision for the store beyond the JSON shape of §3.

## 7. Risks

* **The ISO 4217 table is transcribed by a model.** A wrong exponent is a silent ×10 error on every
  amount in that currency. Mitigation: the vectors of §2 and a QA check of the table against the
  published list before the change is merged.
* **Shape churn.** Ninox and Mobile start against these types on Wed 30 Sep; a rename after that
  costs three lanes. The orchestrator reviews §3's public API with the product owner before those
  lanes are dispatched.
