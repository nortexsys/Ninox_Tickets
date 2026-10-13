# Design: implement-country-detection

Owner: Core lane (function), Mobile lane (wiring). Written by the orchestrator, 2026-10-13.

## 1. Who decides the country

Three candidates were on the table; the spec picks one.

| Candidate | Verdict |
| --- | --- |
| **The document's issuer**, deduced from the document | **Yes** (`deterministic-country-detection`) |
| The destination (the Ninox table) | No: a destination carries no country and receives documents from any issuer |
| The user (a setting, or the device language) | No: "no user-facing country setting"; `document-dictionaries-are-separate-from-interface-language` |

The function never reads a locale, a destination or any preference. Its only inputs are the pages
and the table.

## 2. The circularity, and how it is avoided

Reading dates and amounts needs the country (date order, decimal convention); detecting the country
from what is read would need them. The way out is that detection uses **only evidence that needs
neither**. All of it is shape-level, found on words:

| Evidence | Source in Core | Strength | Notes |
| --- | --- | --- | --- |
| Tax identifier of a table country | `normaliseTaxId` + `classifyTaxId` over the page's words (`ES` prefix, `DE` + 9 digits, NIF/NIE/CIF shapes) | strong | A document prints the **customer's** id too. Ids of two different countries on one document are a conflict, never a vote (§3) |
| Country name | a small closed list per table row, in the languages of the dictionaries (`España`/`Spain`/`Spanien`, `Deutschland`/`Germany`/`Alemania`…) | medium | Next to an address or a postal code it is the issuer's; elsewhere it is only mentioned |
| Language of the label dictionaries | `TermMatch.language` over the page | weak | Between ES and DE it separates; it will not separate DE from AT in R1, so it is a tiebreaker only, never alone |
| Currency | `readCurrencyEvidence` ISO codes and symbols | exclusion only | `EUR` fits both launch rows. A currency that no row declares (e.g. `CHF`) is evidence that **no launch row applies** |

Date order and decimal convention are *not* evidence here: they are read afterwards under the chosen
row, or inferred from the document itself when there is no row (`format-inference`).

## 3. The answer

```dart
sealed class CountryDetection {}
final class Detected extends CountryDetection {
  final CountryRow row;
  final List<CountryEvidenceKind> evidence;   // kinds only, never text from the document
}
final class Undetected extends CountryDetection {
  final UndetectedReason reason;              // noEvidence | conflictingEvidence | countryWithoutRow
}

CountryDetection detectCountry({required Iterable<TextPage> pages, required CountryTable table});
```

Rules, in this order, no weighting and no score:

1. Collect the countries named by **strong** evidence. Exactly one country and it has a row →
   `Detected`.
2. Two or more different countries from tax identifiers → look for a **medium** evidence that
   picks one of them (the country name adjacent to the issuer's address block); exactly one
   survives → `Detected`; otherwise `Undetected(conflictingEvidence)`. The function never picks
   "the first id" or "the most frequent".
3. No strong evidence: medium evidence naming exactly one row → `Detected`; weak evidence alone is
   never enough → `Undetected(noEvidence)`.
4. Evidence points only at a country with no row (or a currency no row declares) →
   `Undetected(countryWithoutRow)`.

It is deterministic and order-independent: the same words in any arrival order give the same answer
(pages' word order is already declared arbitrary by `TextPage`). It is also consensus-friendly: the
extraction runs it on each pass and the passes must agree; the service uses the page set of the
**first pass with words**, and a disagreement between passes is `conflictingEvidence`.

## 4. What an `Undetected` document does — an open point for the PO

The spec already says what is possible: `universal-core` applies "in every country, including one
with no row": amount arithmetic, date coherence, date/decimal format inference, EAN-13, IBAN.
What a country row adds is the legal-rate gate and the tax-id check digit. So the proposal, **not a
decision**:

* `Undetected` does not stop extraction. `extractDocument` runs with the universal core only
  (no rate gate, no id check), every value that depended on a row is `unverified`, and the document
  has `needsReview`.
* `ExtractionService` stores the reason (`noEvidence` etc.) as part of the engine metadata, never
  as a failure.

This changes `extractDocument`'s `country` parameter to nullable, which is a Core change in this
same change. If the PO prefers that an undetected document fail extraction (and be shown as
"country not recognised"), tasks 1.4 and 2.2 change; nothing else does.

## 5. Privacy and tests

The result carries evidence **kinds**, never the identifier, name or address text. Tests use only
synthetic pages: valid-shaped invented ids (`AGENTS.md` §1.2: no real identifier, the project's
documented synthetic `12345679S` is allowed), invented names. Cases: a Spanish ticket (CIF) → ES;
a German invoice (`DE`+9 digits) → DE; an invoice with the customer's foreign id plus the issuer's
(medium evidence breaks the tie); two ids with no tiebreak → conflict; no evidence → noEvidence;
`CHF` and a Swiss id → countryWithoutRow; word order shuffled → same answer; the circularity case: a
`13.08.2026` date and `1.234,56` amount do not change the answer.

## 6. Dispatches

| Step | Lane | Needs |
| --- | --- | --- |
| A. `detectCountry`, `CountryDetection`, tests; nullable `country` in `extractDocument` per §4 | Core | PO answer to §4 only for task 1.4 |
| B. `ExtractionService` asks `detectCountry` | Mobile | A merged |
