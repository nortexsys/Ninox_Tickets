## MODIFIED Requirements

### Requirement: currency-is-read-from-the-document

The currency of a document read by the **photo route** SHALL be the currency the
country row in force for the ticket declares, and the photo route SHALL NOT run a
currency-reading stage that can fail. That currency SHALL be recorded with the
country setting as its origin and SHALL NOT be given the provenance of a reading, and
the state it is presented in is `validation-confidence`'s
(`currency-carries-its-own-confidence-state`, green for this source by DEC-023).
The currency of a document read by any other route SHALL still be extracted from the
document's own evidence — the printed ISO code, the symbol, the issuer country — and
SHALL never be defaulted to the table's currency. Which state a currency may be
presented in, and whether an unsustained one suppresses the amounts, remain
`validation-confidence`'s (FR-VAL-009) and are not changed here.
Where the country in force has no row in the table, the photo route SHALL NOT take a
currency from any other source in its place — no table, no mapping, no evidence on the
image — and the field SHALL be left for the user to fill, like the ticket's other
fields (`countries-languages` · `country-is-an-input`).
[Origen: Funcional §4.2 FR-EXT-013; PDR §6 (v0.2); Finding 3; DEC-022; DEC-023]

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
- AND its origin is the country setting, not a reading of the image

#### Scenario: a country without a row gets no currency from anywhere else

- GIVEN a photographed ticket whose country in force has no row in the country table
- WHEN the record is assembled
- THEN no currency is taken from a table, a mapping or the image in the row's place
- AND the currency field is left for the user to fill

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
ported test cases. Where the country in force has no row in the table, neither reader
SHALL run: the photo route SHALL produce no read for that ticket rather than a read
under assumed conventions, and the ticket's fields SHALL be left for the user to fill
by hand (`countries-languages` · `country-is-an-input`).
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

#### Scenario: a country without a row gets no read at all

- GIVEN a photographed ticket whose country in force is Portugal, which has no row in
  the country table
- WHEN the ticket is read
- THEN neither the labelled reader nor the arithmetic reader runs
- AND no decimal convention, date order, date separator, rate set, currency or label
  vocabulary is assumed in their place
- AND the ticket's fields are left for the user to fill by hand

---

### Requirement: second-read-on-the-users-request

The photo route SHALL read a document once automatically and SHALL run a second read of that same document only when the user asks for it — never on its own, and never in place of the first read. The second read SHALL work on the document already captured, without a new capture, and SHALL produce its candidate readings by running the reader that did not lead the first read and/or further recognition passes — no third reader is introduced, and the two readers and their precedence stay `photo-route-readers-take-their-formats-from-the-country-row`'s; those candidates SHALL enter the same consensus as the first read's, whose majority rule (`consensus-by-majority`, BR-06) SHALL decide, and this requirement SHALL add no cap, no exception and no new confidence state to it. Provenance SHALL NOT change: a value the second read produces carries the provenance the reading gives it, and a value derived by identity still confirms nothing (BR-05). The second read SHALL NOT overwrite a value the user has edited or typed: it SHALL only fill a field that is empty and refine a value the user has not touched, and a field the user touched SHALL keep the user's value and its edited mark whatever the second read returns (`review-screen` · `user-edits-are-authoritative`). A second read SHALL be a request the user may make and need not: no value SHALL be withheld or marked merely because no second read was asked for.
[Origen: Funcional §4.2 FR-EXT-006; Funcional §4.4 FR-REV-010; Funcional §5 BR-05, BR-06; DEC-017; DEC-024]

#### Scenario: the first read runs automatically and no second one without a request

- GIVEN a captured photograph
- WHEN the document is read
- THEN the photo route reads it once, without the user asking
- AND no second read runs on it until the user asks for one

#### Scenario: a requested second read feeds the same consensus

- GIVEN a photographed document whose first read left a value unresolved
- WHEN the user asks for a second read
- THEN the other reader and further recognition passes run on the same captured
  document
- AND the value used is the one the majority of the candidate readings agree on
- AND no second capture was needed to produce them

#### Scenario: the second read changes nothing about what a value is worth

- GIVEN a second read that agrees with the first on an amount
- WHEN that amount's confidence state is determined
- THEN no new cap, exception or strength applies to it because of the second read
- AND a value the second read derived by identity confirms nothing

#### Scenario: an edited value survives the second read

- GIVEN a total the user edited before asking for a second read
- WHEN the second read returns a different total
- THEN the user's total is the value kept
- AND it keeps its edited mark

#### Scenario: a value the user did not touch is filled or refined

- GIVEN an empty field, and a date the first read produced that the user has not
  touched
- WHEN the second read returns a value for each
- THEN the empty field is filled
- AND the untouched date may be refined
- AND neither is presented as confirmed by the second read alone

---

## Out of Scope

- **Which country is in force for a ticket, and how it is chosen.** That is
  `countries-languages` · `country-is-an-input`; this capability only consumes the
  row it resolves to.
- **The currency's confidence state.** Unchanged in ownership: `validation-confidence`
  (FR-VAL-009, BR-12) owns it, and `openspec/project.md` §3.3 keeps reading and
  trusting apart. Its value for the photo route is stated above; the green that
  DEC-023 gives the country-sourced currency is that capability's exception to BR-04,
  made there and not here.
- **Which rates are legal and which dictionary words exist.** `countries-languages`
  owns the data. This capability owns that the readers take it from the row.
- **The PDF text route and the XML route.** They are not touched by this change: the
  currency rule above keeps its original form for them, and their detection of the
  country is unchanged.
- **Provenance and what a check may confirm.** `validation-confidence` owns both; the
  ported arithmetic reader's output stays `derived` and confirms nothing, as before,
  and the second read adds nothing to that.
- **The request, the running indicator and the edit that survives.** `review-screen`
  owns them (`second-read-is-requested-and-shown-running`,
  `user-edits-are-authoritative`); this capability owns only what the second read is
  and what it may write.
- **Which country the second read reads under.** It reads the document under the
  country in force for the ticket, like the first read: `countries-languages` owns the
  input and `review-screen` the change.

---

## Cross-Capability References

- `countries-languages` — owns the country table, the country input and the label and
  negative-context dictionaries whose content the readers consume
  (`country-is-an-input`, `document-dictionaries-are-separate-from-interface-language`).
- `validation-confidence` — owns the three strengths, the confirmatory rule that
  consumes this capability's provenance (FR-VAL-002, BR-02, BR-05), and currency's
  confidence state (FR-VAL-009, and DEC-023's green for the country-sourced currency).
- `review-screen` — shows the country in force and lets the user change it
  (`country-shown-and-editable-per-ticket`), and owns the edit that the second read
  never overwrites together with the request and the running indicator
  (`user-edits-are-authoritative`, `second-read-is-requested-and-shown-running`).

---

## Open Questions

- **GAP-034** — what a history entry records about the country in force now that the
  photo route no longer detects one. The suffix convention the PO accepted is
  unchanged; its subject is not decided.
- **Settled on 2026-10-20 (GAP-040, DEC-024).** The second read on the user's request
  is `second-read-on-the-users-request`, above. It has an origin of its own because
  no source document of `openspec/project.md` §2 names it: DEC-024 supplies that
  origin. It diverges from nothing — BR-06 and its majority rule are unchanged, and
  `review-screen` · `user-edits-are-authoritative` is applied as it stands — and to
  it are added the two rules the PO fixed with it: the second read never overwrites a
  value the user edited or typed, and the app shows that it is running
  (`review-screen` · `second-read-is-requested-and-shown-running`).
