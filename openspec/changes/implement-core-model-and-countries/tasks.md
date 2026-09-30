# Tasks: implement-core-model-and-countries

Plan v0.2 M1, Core lane. A task is done when its check passes, not when its files exist. Every check
is run from the repository root on Flutter 3.47.5 / Dart 3.13.4:
`dart analyze --fatal-infos packages/paperdrop_core`, `dart format --set-exit-if-changed packages/paperdrop_core`,
`dart test packages/paperdrop_core`, `python .github/scripts/core_purity.py`.

## 1. Core — first dispatch: the shared contract (T1.1–T1.2)

- [x] 1.1 **`CurrencyCode` and the ISO 4217 table** (design §2). *Done when* the vectors of design
      §2 pass, an unknown code returns `null`, and no code path yields a default exponent.
- [x] 1.2 **`Money`** (design §2): exact parse of the canonical decimal form, arithmetic, currency
      mismatch error, range bound, canonical `toDecimalString`. *Done when* the examples of design §2
      pass, including every rejection.
- [x] 1.3 **`RateBp` and the exact product** (design §2). *Done when* `21`, `5.5`, `2.75` parse to
      2100, 550, 275, `5.555` and `100.01` are rejected, and `timesRate` compares exactly with no
      rounding function in the public API.
- [x] 1.4 **Canonical model** (design §3): `Provenance`, `ValueSource`, `ConfidenceState`,
      `FieldValue` (`Present`, `Absent`, `NotInXml`), `CalendarDate`, `CanonicalDocument` with
      `TaxSlot` and `Surcharge`, JSON round-trip. The three fields deferred to R1 (design §3, GAP-027) are **not** present.
      *Done when*:
      * a test named `[extraction-pipeline/provenance-on-every-value] every value is tagged` builds a
        fully populated document and proves every `Present` value carries one of the four tags;
      * `Absent`, `NotInXml` and `Present(0)` are three unequal values, and none converts to another;
      * `cardMasked` refuses five or more digits;
      * a document with `currency: EUR` and a USD amount cannot be constructed;
      * the JSON round-trip of a fully populated document is lossless and every amount is a JSON
        integer.
- [x] 1.5 **No float in `lib/`** (design §1): a test scans `packages/paperdrop_core/lib/` and fails on
      `double`, `num `, `toDouble` or `double.parse`. *Done when* it passes, and fails on a planted
      `double` (proved inside the test with a temporary file under the system temp directory, not
      under `lib/`).
- [x] 1.6 **Public API** exported from `lib/paperdrop_core.dart`, dartdoc on every public member.
      *Done when* the four checks at the top of this file are green, and the lane report lists the
      public API (type names and constructors) for the orchestrator's review.

- [x] 1.7 **The `Edited` case** (design §3, PO decision 2026-09-28), replacing `copyWithEdit` and the
      `user` source and `edited` flag on `Present`. *Done when* `FieldValue.edit` turns each of
      `Present`, `Absent` and `NotInXml` into an `Edited` holding only the value; `Present` refuses
      `source: user`; an `Edited` has no provenance and no confidence and its JSON has neither key;
      and the round-trip test covers it.

- [x] 1.8 **Remove `docType`** from `CanonicalDocument`, its JSON and its tests (design §3, GAP-029,
      PO decision 2026-09-28). *Done when* no `docType` / `doc_type` remains in
      `packages/paperdrop_core/` and the checks at the top of this file are green.

## 2. Core — second dispatch (T1.3–T1.4)

Detailed in design §4–§5 on 2026-09-30. Dispatched on a fresh lane thread: the first dispatch's
thread is not extended (plan status 2026-09-28, lane cost).

- [ ] 2.1 **Universal checks** (design §4): `isValidEan13` and IBAN with its length table, returning
      `CheckResult`. *Done when* every vector of design §4 for EAN-13 and IBAN passes, a grouped IBAN
      normalises and passes, and neither function takes a country row. Tag
      `[countries-languages/universal-core] the EAN-13 check digit` and `… the IBAN check`.
- [ ] 2.2 **Tax identifiers** (design §4): `TaxIdType`, `TaxId.parse` (raw + normalised),
      classification by shape, and `ES_NIF`, `ES_NIE`, `ES_CIF` in three files that share no code.
      `DE_USTID` shape and normalisation only, validator `notChecked` citing GAP-030; `DE_STNR`
      `notChecked`. *Done when* every vector of design §4 passes; a test proves no import between the
      three Spanish files; the scenarios of `three-spanish-formats-are-three-algorithms`,
      `tax-identifier-normalisation` and *the German Steuernummer is deliberately left unchecked* are
      tagged; the privacy job's findings on the NIE vectors are listed in the report, not dodged.
- [ ] 2.3 **Country table** (design §4): `CountryRow`, `CountryTable` with ES and DE, `slotCount` as
      a getter, `isLegalRate`, `rowFor`, `rowForTaxIdType`. *Done when* *the German row applies its own
      rates*, *the slot count follows the rate set*, *a Spanish ticket is detected from its identifier*
      and *adding a country touches almost nothing* (design §4's structural test) pass and are tagged.
- [ ] 2.4 **Format inference** (design §5): `inferDecimalConvention`, `parsePrintedAmount`,
      `inferDateOrder`, `parsePrintedDate`. *Done when* every vector of design §5 passes, no function
      returns a default convention or order, and *a day greater than twelve resolves the order*,
      *grouping separates the two decimal conventions* and *the Spanish row uses a different date
      format* are tagged.
- [ ] 2.5 **Dictionaries** (design §5): Annex C's seeds exactly, with languages and surcharge hints,
      and `findTerms`. *Done when* a test compares the seeds with Annex C term by term; whole-word and
      longest-match cases pass (`tipo`, `HTTP`, `Tomorrow`, `TOTAL A PAGAR`); no file in `lib/`
      reads a locale; *the negative-context list spans the languages of the market* and *labels bind
      regardless of interface language* (lookup half: `Total à payer` and `Zu zahlen` are both found
      as `total` with the interface language irrelevant — untagged if binding is not proved, with
      the scenario named in a comment).
- [x] 2.6 **`DE_USTID` validator** — not in the MVP: the product owner decided on 2026-09-30 to leave
      it unvalidated (`notChecked`, like `DE_STNR`) until R1 (GAP-030). Nothing to implement.

## 3. QA

- [x] 3.1 Review the ISO 4217 table against the published list (design §7) and report any
      difference as a finding; QA does not edit `lib/`. *Done 2026-09-30:* 165 codes, zero
      differences (`validation/reviews/iso4217-2026-09-30.md`), re-checked by the orchestrator.
- [ ] 3.2 Review the IBAN length table (design §4) against the SWIFT IBAN Registry, the same way;
      and allowlist the three NIE documentation vectors of design §4 in the privacy job, with that
      reason, once the lane's tests exist. *Length table checked by the orchestrator on 2026-09-30*
      against registry release 101 (python-stdnum 2.2): 82 entries equal, 7 countries missing — sent
      back to Core. Allowlisting after the merge.

## 4. Orchestrator

- [x] 4.1 Review the lane's report and diff; run the checks at the top of this file and
      `python .github/scripts/scenario_coverage.py`; present the public API of §1 to the product
      owner before Ninox and Mobile are dispatched against it.
- [ ] 4.2 Merge `change/implement-core-model-and-countries` with `--no-ff` after the product owner
      approves; archive the change when §1–§3 are done.
