# Proposal — countries-languages

## Why

Every validator in the product consumes country-specific data: which tax
identifier formats exist and how each one's check digit is computed, which tax
rates are legal, how dates and decimal separators are written, how many tax slots
a document may declare, and whether cash rounding applies.

That data has to live in exactly one place. FR-CTR-003 already says so — adding a
country shall be a table row plus at most one small check-digit function — and
Annex B is its launch content. If the data is instead scattered across the
capabilities that consume it, adding a fifth country touches five specs, and the
same algorithm gets written twice. That is not a hypothetical: the prototype
applied the **NIF** algorithm to a valid **CIF** and reported a correct supplier
identifier as doubtful. Two implementations of "the Spanish tax identifier" is
precisely the condition that produced that error, and the functional records it as
the failure FR-CTR-004 exists to prevent.

## What Changes

- Add one capability spec, `countries-languages`, with approximately **11
  requirements**: FR-CTR-001…007, the row content and check-digit algorithms of
  Annex B, and the dictionary content of Annex C.
- It owns the **data**; the capability that *decides to consult it* stays where it
  is. `validation-confidence` owns that a legal-rate check happens and that a
  check-digit validator runs; this capability owns which rates are legal and how
  each algorithm is computed (`project.md` §3.3).
- **No behaviour changes.** Every requirement traces to FR-CTR, Annex B or Annex C.

## Capabilities

### New Capabilities

- `countries-languages`: the universal validation core that applies everywhere, the
  country table and its four launch rows, the check-digit algorithms for every
  identifier type the table declares, format inference, interface languages, and
  the document keyword and negative-context dictionaries that are separate from
  interface language.

### Modified Capabilities

- None. No approved specification's requirements change.

## Impact

- `openspec/specs/countries-languages/spec.md` — new.
- No application code, dependency, schema or API is touched by this proposal.
- Two capabilities consume this one and must reference it rather than restate it:
  `validation-confidence` (which algorithm, which legal rates) and
  `extraction-pipeline` (dictionaries and formats). Both boundaries are already
  fixed in `project.md` §3.3.

---

## Spec type

Lite. The content is large but it is data and stated algorithms, not a contract
with expensive ambiguity: a wrong rate or a wrong check digit fails loudly against
a test vector, which is the opposite of the silent failures that justify a Full
spec.

## Problem statement

The product's distinguishing claim is a deterministic layer above reading. That
layer is only as good as the data it judges against, and the data is
country-specific and easy to get subtly wrong: three Spanish identifier formats
that look alike and are three different algorithms; a German `Steuernummer` that
has no reliable check digit at all and must therefore be *explicitly not*
validated; a Swiss cash-rounding adjustment that must be captured from the print
and never recomputed; and a universal core that must work for a country with no
table row at all.

Each of those is a place where the honest answer and the convenient answer differ,
and where the convenient one fails silently. This capability is where the honest
data is written down once, with its algorithms at reference precision.

## Scope

### In scope

| Group | What it covers |
| --- | --- |
| Universal core (FR-CTR-002) | Amount arithmetic, date coherence, date and decimal format inference, EAN-13 check digit, IBAN modulo 97 — applies in every country, including one with no table row |
| Country detection (FR-CTR-001) | Determined from the document's own evidence — identifier format, currency, address, language. No user-facing country setting and nothing to activate |
| Table contract (FR-CTR-003) | Per country: tax identifier format and its check-digit algorithm, the legal rate set and slot count, date format, decimal separator, cash-rounding rule |
| Launch rows (FR-CTR-004, Annex B.1) | DE, AT, CH, ES, with their currencies, identifier types, legal rates in basis points, slot counts, date formats and rounding. None of the four is the reference case; Switzerland is in from the start because DACH is the primary market |
| Spanish identifiers (FR-CTR-004) | `ES_NIF`, `ES_NIE` and `ES_CIF` as three distinct algorithms that never share code |
| Check digits (Annex B.2) | EAN-13 and IBAN (universal), `DE_USTID`, `AT_UID`, `CH_UID`, `ES_NIF`, `ES_NIE`, `ES_CIF` — and `DE_STNR` **explicitly not validated**, because no reliable check digit exists |
| Normalisation (Annex B.2) | `supplier_tax_id_raw` exactly as printed; `supplier_tax_id` normalised, with the country prefix where the number is an intra-EU VAT identifier |
| Format inference (FR-CTR-005) | A day greater than twelve disambiguates date order; the thousands grouping pattern separates `1.234,56` from `1,234.56`. Named in the functional as the one genuinely new piece of work the universal layer introduces |
| Languages (FR-CTR-006) | Interface ships in English and German; document keyword dictionaries are a **separate** matter and cover several languages from the start |
| Dictionaries (Annex C) | Positive labels by field (totals, tax, base, supplier, date, document number) and the negative-context terms (`DCC`, `Skonto`, `Registro Mercantil`, `Tomo`, `HRB`, `Amtsgericht`, …) |
| Swiss rounding (FR-CTR-007) | The printed 5-Rappen adjustment is captured into `rounding_minor` and used in `net + tax + rounding = gross`; never recomputed |

### Out of scope

- **Deciding to consult this data.** That a legal-rate check gates a tax candidate
  is `validation-confidence`; the negative-context *application rule* — what
  happens to a number found within the influence radius of a suppressed term — is
  FR-EXT-010 in `extraction-pipeline`. This capability owns the dictionary's
  **content** and the rate sets; it does not own what a consumer does with them.
- **The confidence consequence of a validator's outcome.** FR-VAL-005 owns that a
  check-digit result moves a value's state; this capability owns the algorithm
  that produces the result.
- **Where a slot's value is written.** FR-VAL-011 owns the slot model used by the
  canonical data; this capability declares only how many slots a country's rate
  set implies.
- **User-facing language selection and UI strings.** `local-config-privacy` owns
  NFR-I18N-001. What is here is that the dictionaries are not bound to it.
- **Detecting the country of a document whose evidence is contradictory.** The
  requirement is deterministic detection from the document's evidence; a document
  that cannot sustain a country is handled by the confidence model, not by a
  fallback row.

## Source documents

- `docs/Fase 2. Define/Paperdrop_Funcional_v1.0_EN.md` §4.11 (FR-CTR-001…007),
  **Annex B** (B.1 rows, B.2 identifier formats and check digits, the slot-count
  rule, Swiss rounding, reverse charge) and **Annex C** (the dictionaries and how
  negative context applies).
- `docs/Fase 1. Discover/Paperdrop_PDR_v0.2_EN.md` §10 (countries and detection).
- `docs/Fase 1. Discover/Paperdrop_ADR_v0.2_EN.md` — ADR-005 (the country table),
  ADR-016 (integer minor units and basis points, which the rate sets are expressed
  in).
- `corpus_test/REPORT_after_review.md` — the product owner's verdicts, including
  the records where a currency was mis-detected.

## Key design constraints

1. **The algorithms are stated at reference precision and accepted against test
   vectors.** Annex B.2 already fixes the acceptance condition: each validator is
   accepted only when it reproduces the standard valid and invalid vectors for its
   identifier type. A spec that describes the algorithm but not the vectors is not
   finished.
2. **The universal core must not depend on the table.** FR-CTR-002 is explicit: a
   document from a country with no row still gets arithmetic, date checks, EAN-13
   and IBAN. Where a requirement would introduce a table lookup into the universal
   path, it is wrong.
3. **`DE_STNR` is a requirement about absence.** "Explicitly not validated" is a
   deliverable, not an omission, and it needs its own scenario — otherwise someone
   later adds a check digit that does not exist.
4. **The three Spanish algorithms never share code.** This is the one place where
   the functional names the exact bug it is preventing, so the requirement is
   written as three separate algorithms rather than as one parameterised family.
5. **Rate sets are data, and their cardinality drives the slot count.** The
   functional's rule — slots equal the cardinality of the legal rate set including
   the zero rate — means the two must not be maintained separately.
6. **No invented content.** Annex B and Annex C are labelled as seeds and launch
   content. Where a value is genuinely open it is recorded as an `Open Question`
   and in the gaps register rather than filled in.

## Open questions at proposal stage

- **None blocking.** Two entries in `openspec/gaps-register.md` bear on this
  capability:
  - **GAP-002** (ADR-011, PDF text extraction) does not touch this capability.
  - **GAP-006** (private-cloud Ninox host) does not touch this capability.
  Neither blocks it.
- **To confirm while reviewing:** whether the negative-context dictionary's
  *influence radius* — how close a term must be to suppress a numeric candidate —
  belongs here or in `extraction-pipeline`. Annex C states the rule and attributes
  it to FR-EXT-010, which is `extraction-pipeline`. This proposal reads it as
  `extraction-pipeline`'s, and this capability as owning the term list only. If the
  product owner prefers the radius parameter to live with the terms, the boundary
  in `project.md` §3.3 is amended rather than the spec being written ambiguously.
