## MODIFIED Requirements

### Requirement: deterministic-country-detection

The app SHALL detect a document's country from that document's own evidence — tax
identifier format, currency, address, language — and SHALL apply that country's row
of the country table, on every route except the photo route. A photographed document
SHALL NOT take its country from detection: its country is the input in force for the
ticket, and no evidence found on the image SHALL override it
(`country-is-an-input`). There SHALL be no user-facing selection of a country row,
and nothing to activate beyond that input.
[Origen: Funcional §4.11 FR-CTR-001; PDR §10; ADR-005; DEC-022]

#### Scenario: a German invoice needs no user action

- GIVEN an invoice printing a `DE` VAT identifier
- WHEN it is read
- THEN the German row of the table applies
- AND the user has taken no action to select a country

#### Scenario: a Spanish ticket is detected from its identifier

- GIVEN a PDF receipt with a text layer printing an `ES_CIF`
- WHEN it is read
- THEN the Spanish row of the table applies

#### Scenario: a photographed ticket does not take its country from its identifier

- GIVEN a photographed ticket printing an `ES_CIF`
- AND the country in force for that ticket is Germany
- WHEN it is read
- THEN the German row applies
- AND the identifier printed on the image has not changed the country

---

## ADDED Requirements

### Requirement: country-is-an-input

The country of a photographed document SHALL be an input rather than a detection
result: the app SHALL keep a default country in its settings, initialised on first
run from the phone's region and not re-read from the device afterwards, SHALL use
that default for every ticket until the country of a ticket is changed, and SHALL
take the country of a ticket from that default or from the change the user makes for
that ticket (`review-screen` · `country-shown-and-editable-per-ticket`) — from
nothing else.
The country row the country resolves to SHALL supply that ticket's decimal
convention, date order and date separator, legal rate set, currency and label
vocabulary; where a row is in force its declared date order and decimal convention
SHALL decide the parse, and the inference of `format-inference` SHALL apply only to a
value the row's declaration leaves unsettled.
[Origen: Funcional §4.11 FR-CTR-001; Funcional §4.11 FR-CTR-005; PDR §10; ADR-005; DEC-022]

#### Scenario: the first run takes the phone's region

- GIVEN a phone whose region is Spain
- WHEN the app is started for the first time
- THEN the default country is Spain
- AND the first ticket shows Spain as its country without the user having chosen one

#### Scenario: the default applies to every ticket until it is changed

- GIVEN a default country of Germany
- WHEN two documents are captured and the country of neither ticket is changed
- THEN both are read with the German row

#### Scenario: the row's declaration is applied before format inference

- GIVEN a photographed ticket with Spain in force printing a date as `05/06/2026`
- WHEN the date is parsed
- THEN the day-first order the Spanish row declares is the reading applied
- AND the month-first order of another row is not used

---

## Out of Scope

- **What the confidence state of a value read under a country row is.** The three
  strengths, and that a currency sourced from the row is presented in whatever state
  `validation-confidence` allows, are FR-VAL-001, FR-VAL-009 and BR-04/BR-05. This
  capability states which row is in force and what it supplies.
- **The presentation and the editing of the country on the review screen.** That the
  ticket shows the country and lets the user change it there is `review-screen`'s
  `country-shown-and-editable-per-ticket`; this capability owns the setting and the
  row that follows from it.
- **The reader the photo route uses.** `extraction-pipeline` owns
  `photo-route-readers-take-their-formats-from-the-country-row`; this capability owns
  the row those readers are given.

---

## Cross-Capability References

- `extraction-pipeline` — receives the country in force and owns the readers that
  consume the row's parameters (`photo-route-readers-take-their-formats-from-the-country-row`)
  and the photo route's currency (`currency-is-read-from-the-document`).
- `review-screen` — shows the country in force for the ticket and lets the user
  change it there (`country-shown-and-editable-per-ticket`).
- `validation-confidence` — owns what may be presented as confirmed, unchanged by
  this decision: a currency that comes from a row rather than from the document is
  still that capability's to state.
- `local-config-privacy` — owns the configuration file and the clearing action; if
  the default country travels in either, that is a change to its requirements and is
  not made here (GAP-039).
- `setup-wizard` — owns the first run. Whether the country is offered there is not
  decided (GAP-039).

---

## Open Questions

- **GAP-036** — what the app does, and what the user sees, when the country in force
  has no row in the country table (a phone whose region is France, for instance). A
  photographed document read with a row in force is specified above; the no-row case
  is not, and it is blocking for that case only.
- **GAP-038** — whether a country changed for one ticket also becomes the new
  default, or whether the default stays as it was and each further ticket goes back
  to it.
- **GAP-039** — whether the default country travels in the configuration export,
  whether the clearing action resets it to the phone's region, and whether it is
  offered as a step of the first-run wizard.
