## MODIFIED Requirements

### Requirement: currency-is-read-from-the-document

The currency of a document read by the **photo route** SHALL be the currency the
country row in force for the ticket declares, and the photo route SHALL NOT run a
currency-reading stage that can fail. The currency of a document read by any other
route SHALL still be extracted from the document's own evidence — the printed ISO
code, the symbol, the issuer country — and SHALL never be defaulted to the table's
currency. Which state a currency may be presented in, and whether an unsustained one
suppresses the amounts, remain `validation-confidence`'s (FR-VAL-009) and are not
changed here.
[Origen: Funcional §4.2 FR-EXT-013; PDR §6 (v0.2); Finding 3; DEC-022]

#### Scenario: a euro receipt is tagged EUR

- GIVEN a receipt paid in euros in Madrid
- WHEN the currency is read
- THEN it is EUR

#### Scenario: a dollar invoice is not turned into euros

- GIVEN an invoice issued in the United States and printed in dollars
- WHEN the currency is read
- THEN it is USD
- AND the table's currency is not substituted for it

#### Scenario: an unreadable currency is not defaulted

- GIVEN an invoice read by the text route whose currency cannot be read from any of
  its evidence
- WHEN extraction completes
- THEN the currency is left unsustained rather than defaulted
- AND the consequence for the amounts is the validation layer's, not invented here

#### Scenario: a photographed ticket takes the currency of its country row

- GIVEN a photographed ticket whose country in force is Spain
- WHEN the record is assembled
- THEN its currency is EUR, the currency the Spanish row declares
- AND no currency evidence printed on the image was needed to reach it

---

## ADDED Requirements

### Requirement: photo-route-readers-take-their-formats-from-the-country-row

The photo route SHALL read a photograph through two readers and no others: a
**labelled reader**, which runs a table pass and then binds each label of the
document's dictionary to the value printed with it, and a **vocabulary-free
arithmetic reader**, which binds no label and keeps a number only where an
arithmetic relation printed on the page holds it. The labelled result SHALL take
precedence, the arithmetic reader SHALL only fill gaps the labelled pass left empty,
and a value it produces SHALL carry provenance `derived` and SHALL NOT confirm
anything on the strength of that identity. Every convention and vocabulary the two
readers consume — decimal convention, date order and date separator, legal rate set,
currency and label vocabulary — SHALL come from the country row in force for the
ticket, and SHALL NOT be fixed for any country in the reading logic; for Spain the
ported readers SHALL give the same result as the prototype they come from on the
ported test cases.
[Origen: Funcional §4.2 FR-EXT-014, FR-EXT-015; Funcional §4.2 FR-EXT-008; Funcional §5 BR-07; Funcional Annex C; PDR §6.1; DEC-022]

#### Scenario: a printed label binds its value

- GIVEN a photograph printing a labelled total that the Spanish row's dictionary
  contains
- WHEN it is read
- THEN the total is bound from that label with provenance `read`

#### Scenario: the arithmetic reader fills a gap and stays derived

- GIVEN a photograph printing a base and a tax but no labelled total
- WHEN it is read
- THEN the arithmetic reader produces the gross total with provenance `derived`
- AND that total is not presented as confirmed on the strength of that identity

#### Scenario: a labelled value is not displaced by an arithmetic one

- GIVEN a labelled total and an arithmetic total that differ
- WHEN the values are chosen
- THEN the labelled total is the value used
- AND the arithmetic reader has only filled a gap

#### Scenario: two countries read one image with their own conventions

- GIVEN one photograph of a receipt printing a date and an amount
- WHEN it is read with Germany in force and then with Spain in force
- THEN each read applies the date order and the decimal convention its own country
  row declares
- AND no convention was fixed for a country in the readers themselves

#### Scenario: Spain keeps the prototype's results

- GIVEN the test cases ported from the prototype
- WHEN they are run against the ported readers with Spain in force
- THEN every expectation of the prototype holds unchanged

---

## Out of Scope

- **Which country is in force for a ticket, and how it is chosen.** That is
  `countries-languages` · `country-is-an-input`; this capability only consumes the
  row it resolves to.
- **The currency's confidence state.** Unchanged: `validation-confidence` (FR-VAL-009,
  BR-12) owns it, and `openspec/project.md` §3.3 keeps reading and trusting apart.
- **Which rates are legal and which dictionary words exist.** `countries-languages`
  owns the data. This capability owns that the readers take it from the row.
- **The PDF text route and the XML route.** They are not touched by this change: the
  currency rule above keeps its original form for them, and their detection of the
  country is unchanged.
- **Provenance and what a check may confirm.** `validation-confidence` owns both; the
  ported arithmetic reader's output stays `derived` and confirms nothing, as before.

---

## Cross-Capability References

- `countries-languages` — owns the country table, the country input and the label and
  negative-context dictionaries whose content the readers consume
  (`country-is-an-input`, `document-dictionaries-are-separate-from-interface-language`).
- `validation-confidence` — owns the three strengths, the confirmatory rule that
  consumes this capability's provenance (FR-VAL-002, BR-02, BR-05), and currency's
  confidence state (FR-VAL-009).
- `review-screen` — shows the country in force and lets the user change it
  (`country-shown-and-editable-per-ticket`).

---

## Open Questions

- **GAP-036** — a ticket whose country has no country row: what the readers do, and
  whether the country can be selected at all. Blocking for that case only; the
  requirements above are written for a ticket whose country has a row.
- **GAP-037** — which state a currency that comes from the country row carries when
  it is displayed. It is not a reading, so `validation-confidence`'s
  `currency-carries-its-own-confidence-state` has nothing to sustain it from, and no
  requirement here decides its colour.
- **GAP-034** — what a history entry records about the country in force now that the
  photo route no longer detects one. The suffix convention the PO accepted is
  unchanged; its subject is not decided.
- **GAP-040** — the second read on the user's request (proposal, PO decision of
  2026-10-19, item 4; design §4) has no requirement here: it has no origin to cite in
  a source document of `openspec/project.md` §2. It is not specified in this change
  and the requirements above describe the first read.
