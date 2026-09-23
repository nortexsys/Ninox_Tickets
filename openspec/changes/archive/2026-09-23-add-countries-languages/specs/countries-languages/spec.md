# Countries and Languages Specification

## Purpose

The product's distinguishing claim is a deterministic layer above reading: check
digits, arithmetic over independently read values, legal-rate checks and
negative-context suppression. That layer is only as good as the **data it judges
against**, and the data is country-specific and easy to get subtly wrong.

Three Spanish identifier formats that look alike are three different algorithms. A
German `Steuernummer` has no reliable check digit at all, so the honest answer is
to validate nothing. A Swiss cash rounding adjustment must be captured from the
print and never recomputed. And the core checks have to work for a document from a
country the table has never heard of.

This capability is where that data is written down once, at reference precision,
with one owner. It owns the **data**; the capability that decides to consult it
owns the decision. `validation-confidence` owns that a legal-rate check runs and
that a check-digit validator exists and is accepted against test vectors; this
capability owns *which* rates are legal and *how* each algorithm is computed. That
split is fixed in `openspec/project.md` §3.3 and is the reason the prototype's
error — the NIF algorithm applied to a valid CIF — cannot recur by accident.

---

## ADDED Requirements

---

### Requirement: deterministic-country-detection

The app SHALL detect the document's country from the document's own evidence —
tax identifier format, currency, address, language — and SHALL apply that
country's row of the country table. There SHALL be no user-facing country setting
and nothing for the user to activate.
[Origen: Funcional §4.11 FR-CTR-001; PDR §10; ADR-005]

#### Scenario: a German invoice needs no user action

- GIVEN an invoice printing a `DE` VAT identifier
- WHEN it is read
- THEN the German row of the table applies
- AND the user has taken no action to select a country

#### Scenario: a Spanish ticket is detected from its identifier

- GIVEN a ticket printing an `ES_CIF`
- WHEN it is read
- THEN the Spanish row of the table applies

---

### Requirement: universal-core

A universal core SHALL apply in every country, including one with no row in the
table: amount arithmetic, date coherence, date and decimal format inference, the
EAN-13 check digit, and IBAN modulo 97. The universal core SHALL NOT depend on the
country table.
[Origen: Funcional §4.11 FR-CTR-002; Funcional Annex B (B.2, the two universal rows); PDR §10]

#### Scenario: a country with no row still gets the core checks

- GIVEN a document from a country that has no row in the country table
- WHEN it is validated
- THEN amount arithmetic and date coherence still run
- AND its EAN-13 and IBAN are validated where the document carries them

#### Scenario: the EAN-13 check digit

- GIVEN a thirteen-digit barcode
- WHEN its check digit is computed
- THEN the twelve leading digits are weighted alternately 1 and 3 beginning with 1
- AND the check digit is the one that makes the weighted total a multiple of 10

#### Scenario: the IBAN check

- GIVEN an IBAN whose length matches its country's fixed length
- WHEN its check digits are validated
- THEN the first four characters are moved to the end
- AND letters are converted to 10 through 35
- AND the value is valid only if the remainder modulo 97 is 1

---

### Requirement: country-table-contract

The country table SHALL declare, per country: the tax identifier format and its
check-digit algorithm; the legal set of tax rates and the number of tax slots; the
date format; the decimal separator; and any cash-rounding rule. Adding a country
SHALL be a table row plus at most one small check-digit function, and SHALL touch
no code outside the table and its identifier validator.
[Origen: Funcional §4.11 FR-CTR-003; Funcional Annex B (B.1 slot-count rule); ADR-005]

#### Scenario: adding a country touches almost nothing

- GIVEN the four launch rows in place
- WHEN a fifth country is added
- THEN the change is one table row plus at most one check-digit function
- AND no code outside the table and that function is modified

#### Scenario: the slot count follows the rate set

- GIVEN a country whose legal rate set has four members, the zero rate included
- WHEN its row is written
- THEN it declares four slots
- AND the slot count is not maintained separately from the rate set

---

### Requirement: launch-rows

Germany, Austria, Switzerland and Spain SHALL be the four launch rows, with the
content below. None of the four SHALL be treated as the reference case, and
Switzerland SHALL be included from the start because DACH is the primary market,
not as a later extension.
[Origen: Funcional §4.11 FR-CTR-004; Funcional Annex B (B.1 rows)]

| Country | Currency | Tax ID formats | Legal rates (basis points) | Slots | Date format | Cash rounding |
| --- | --- | --- | --- | --- | --- | --- |
| DE Germany | EUR | `DE_USTID`, `DE_STNR` | 1900, 700, 0 | 3 | `DD.MM.YYYY` | none |
| AT Austria | EUR | `AT_UID` | 2000, 1300, 1000, 0 | 4 | `DD.MM.YYYY` | none |
| CH Switzerland | CHF | `CH_UID` | 810, 380, 260, 0 | 4 | `DD.MM.YYYY` | 5 Rappen |
| ES Spain | EUR | `ES_NIF`, `ES_NIE`, `ES_CIF` | 2100, 1000, 400, 0 | 4 | `DD/MM/YYYY` | none |

#### Scenario: the German row applies its own rates

- GIVEN a German document printing a 19 % rate
- WHEN its tax rate is gated
- THEN 1900 basis points is admitted as legal
- AND a rate outside the German set is refused

#### Scenario: the Spanish row uses a different date format

- GIVEN a Spanish document printing a date
- WHEN it is parsed
- THEN the `DD/MM/YYYY` format of the Spanish row applies
- AND the German `DD.MM.YYYY` format is not assumed

#### Scenario: reverse charge is not an error

- GIVEN an intra-EU business invoice in Germany whose tax lines are printed at 0
  with a reverse-charge notice
- WHEN it is validated
- THEN the zero lines are accepted
- AND the document is not reported as incoherent

---

### Requirement: three-spanish-formats-are-three-algorithms

`ES_NIF`, `ES_NIE` and `ES_CIF` SHALL be implemented as three distinct algorithms
that never share code. A value of one type SHALL never be validated by another
type's algorithm.
[Origen: Funcional §4.11 FR-CTR-004; Funcional Annex B (B.2); 16-document test]

#### Scenario: a valid CIF is not judged by the NIF algorithm

- GIVEN a valid `ES_CIF` such as `A28017895`
- WHEN it is validated
- THEN it passes its own algorithm
- AND it is never checked against the `ES_NIF` algorithm
- AND no doubtful state is raised on it

#### Scenario: a foreign natural person's identifier is its own type

- GIVEN an `ES_NIE` beginning with `X`, `Y` or `Z`
- WHEN it is validated
- THEN the leading letter is replaced by 0, 1 or 2 respectively
- AND the mod-23 letter of `ES_NIF` is then applied by the `ES_NIE` implementation, not the `ES_NIF` one

---

### Requirement: format-inference

Because the universal core cannot assume a format, the app SHALL infer it from the
document's own evidence: a day greater than twelve disambiguates the date order,
and the thousands grouping pattern distinguishes `1.234,56` from `1,234.56`.
[Origen: Funcional §4.11 FR-CTR-005; PDR §10]

#### Scenario: a day greater than twelve resolves the order

- GIVEN a document printing `13.08.2026`
- WHEN the date is parsed
- THEN it is read as 13 August 2026
- AND the day-first order is inferred from the value itself

#### Scenario: grouping separates the two decimal conventions

- GIVEN the printed amount `1.234,56`
- WHEN it is parsed
- THEN it is one thousand two hundred thirty-four and 56 hundredths
- AND the same digits printed as `1,234.56` are read differently and correctly

---

### Requirement: interface-languages

The user interface SHALL ship in English and German.
[Origen: Funcional §4.11 FR-CTR-006; Funcional §8 NFR-I18N-001]

#### Scenario: both interface languages are usable

- GIVEN the app installed
- WHEN the user changes the interface language
- THEN English and German are both available
- AND every user-facing surface is present in both

---

### Requirement: document-dictionaries-are-separate-from-interface-language

Document keyword dictionaries SHALL be independent of the interface language and
SHALL cover several languages from the start. They SHALL include positive labels
for each field the app reads, and the negative-context terms of Annex C.
[Origen: Funcional §4.11 FR-CTR-006; Funcional Annex C]

#### Scenario: a foreign document is parsed regardless of the interface language

- GIVEN the interface set to English
- WHEN a German document and a French document are read
- THEN each is parsed with its own language's label dictionary
- AND the interface language does not restrict which dictionaries are consulted

#### Scenario: the negative-context list spans the languages of the market

- GIVEN the negative-context dictionary
- WHEN its contents are inspected
- THEN it holds terms in Spanish, German, French and English
- AND it includes at least `DCC`, `Skonto`, `Registro Mercantil`, `Tomo`, `Folio`, `HRB`, `Amtsgericht`, `commission` and `tip`

---

### Requirement: swiss-rounding-is-captured-not-recomputed

For Switzerland, the printed cash-rounding adjustment SHALL be captured into
`rounding_minor` to the nearest 5 Rappen, and SHALL be used in the exact identity
`net + tax + rounding = gross`. The app SHALL never compute a rounding adjustment
of its own.
[Origen: Funcional §4.11 FR-CTR-007; Funcional Annex B (B.1 Swiss rounding); ADR-016]

#### Scenario: the printed rounding line reaches the record

- GIVEN a Swiss cash receipt printing a rounding adjustment
- WHEN it is read
- THEN that printed value is stored in `rounding_minor`
- AND `net + tax + rounding = gross` holds exactly

#### Scenario: the app never substitutes its own rounding

- GIVEN a Swiss document printing no rounding adjustment
- WHEN the amounts are assembled
- THEN `rounding_minor` is left empty or zero as the document supports
- AND the app does not invent an adjustment to make the identity hold

---

### Requirement: country-identifier-check-digits

Each country identifier type SHALL have the check-digit algorithm stated here,
implemented at reference precision.

| Type | Format | Algorithm |
| --- | --- | --- |
| `DE_USTID` | `DE` + 9 digits | ISO 7064 mod-97-10, as implemented for German VAT identifiers |
| `DE_STNR` | Varies by issuing tax office; no stable national format | **Explicitly not validated** — no reliable check digit exists |
| `AT_UID` | `ATU` + 8 digits | ISO 7064 mod-97-10, as published by the Austrian Ministry of Finance |
| `CH_UID` | `CHE` + 9 digits, printed `CHE-nnn.nnn.nnn` | Weighted modulo 11 over the nine digits, as published by the Swiss federal register |
| `ES_NIF` | 8 digits + letter | Letter index = numeric part mod 23 over `TRWAGMYFPDXBNJZSQVHLCKE` |
| `ES_NIE` | `X`/`Y`/`Z` + 7 digits + letter | Replace `X`→0, `Y`→1, `Z`→2, then the mod-23 letter as for `ES_NIF` |
| `ES_CIF` | letter + 7 digits + control | Weighted sum over the seven digits with doubling of alternating positions and the digits of each product summed; control = `(10 - sum mod 10) mod 10`. For issuing letters in `{N, P, Q, R, S, W}`, the control is the corresponding letter of `JABCDEFGHI` |

[Origen: Funcional Annex B (B.2 identifier formats and check digits); Funcional §4.11 FR-CTR-003]

#### Scenario: the German Steuernummer is deliberately left unchecked

- GIVEN a document printing a `DE_STNR`
- WHEN the app validates it
- THEN no check-digit validation is applied
- AND the value is carried as read, with no doubtful state raised on the sole ground that it was not validated

#### Scenario: the Swiss UID is validated by its own published weight

- GIVEN a `CH_UID` printed as `CHE-nnn.nnn.nnn`
- WHEN it is validated
- THEN the nine digits are checked with the published weighted modulo-11 algorithm
- AND the punctuation of the printed form does not affect the result

#### Scenario: an Austrian UID

- GIVEN an `AT_UID` printed as `ATU` followed by eight digits
- WHEN it is validated
- THEN ISO 7064 mod-97-10 is applied as published by the Austrian Ministry of Finance

---

### Requirement: tax-identifier-normalisation

`supplier_tax_id_raw` SHALL hold the tax identifier exactly as the document prints
it. `supplier_tax_id` SHALL hold the normalised form: uppercase, with no spaces,
dots or hyphens, and with the country prefix where the number is an intra-EU VAT
identifier.
[Origen: Funcional Annex B (B.2 normalisation); Funcional §6.1.1]

#### Scenario: a printed form and its normalised form are both kept

- GIVEN a document printing `DE 123 456 789`
- WHEN the supplier identifier is stored
- THEN `supplier_tax_id_raw` is `DE 123 456 789` exactly as printed
- AND `supplier_tax_id` is `DE123456789`

#### Scenario: punctuation is removed from a Spanish identifier

- GIVEN a document printing `A-28.017.895`
- WHEN it is normalised
- THEN the result is `A28017895`
- AND the identifier type remains `ES_CIF`

---

## Out of Scope

- **Deciding to consult this data.** That a legal-rate check gates a tax candidate,
  and that the outcome of a check-digit validation moves a value's confidence
  state, are `validation-confidence`'s (FR-VAL-005, FR-VAL-007). This capability
  states the algorithms and the legal rate sets and stops there.
- **The application rule for negative context.** This capability owns the **list**
  of terms. What happens to a number found within a suppressed term's influence
  radius — and the radius itself — is FR-EXT-010 and BR-08, owned by
  `extraction-pipeline`.
- **Where a tax slot's value is written.** FR-VAL-011 owns the slot model used by
  the canonical data. This capability declares only how many slots a country's rate
  set implies.
- **User-facing language selection and interface strings.** NFR-I18N-001 belongs to
  `local-config-privacy`. What is required here is only that the document
  dictionaries are not bound to it.
- **The country of a document whose evidence is contradictory.** Detection is
  deterministic from the document's evidence. A document that cannot sustain a
  country is handled by the confidence model, not by a fallback row.
- **Table content beyond the four launch rows.** Annex B is explicitly the launch
  content; further countries are added by the mechanism FR-CTR-003 requires, and
  are not specified here.

---

## Cross-Capability References

- `validation-confidence` — owns that a check-digit validator exists and is
  accepted only against the standard valid and invalid test vectors for its
  identifier type (FR-VAL-005), that a legal-rate check gates a candidate
  (FR-VAL-007), and that an absent value is not a zero (FR-VAL-012). This
  capability supplies the algorithm and the rate set those requirements consume.
- `extraction-pipeline` — owns the application of the negative-context dictionary
  (FR-EXT-010, BR-08) and the use of the label dictionaries when binding a label to
  a value (FR-EXT-014). This capability owns the dictionaries' content.
- `local-config-privacy` — owns the interface languages' strings and the language
  selection (NFR-I18N-001).
- `destinations-mapping` — owns the per-field "if absent, write 0" setting
  (FR-DST-006), which is what makes the `DE_STNR` and `rounding_minor` cases
  resolvable at the destination rather than here.

---

## Open Questions

- **None blocking.** None of the open entries in `openspec/gaps-register.md` touches
  this capability: GAP-001 and GAP-002 concern the recognition engine and the PDF
  extraction library, GAP-004 to GAP-009 concern the send pipeline, the mapping and
  the photo route.
- **Settled before writing.** Where the negative-context dictionary's
  influence-radius parameter lives: with the application rule in
  `extraction-pipeline`, not with the term list here. Confirmed by the product owner
  and recorded in `openspec/project.md` §3.3, so that neither spec has to be read as
  ambiguous about it.
- **Annex B and Annex C are seeds.** The functional labels them as launch content
  and as content "to be extended as real documents demand". Extension is expected
  and is not a gap: the mechanism is FR-CTR-003's, and a new term or a new country
  is a data change, not a specification change.
