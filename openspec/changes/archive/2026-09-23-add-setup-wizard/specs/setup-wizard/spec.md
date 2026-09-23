# Setup Wizard Specification

## Purpose

Configuration is the only part the user cannot skip and the part they will do once, so
everything about it is judged against one risk: the user confirming a proposal they did
not read. A field mapped to the wrong column does not fail loudly — it writes a plausible
value into the wrong place, and the read-back shows the app succeeded.

That risk decides the mapping step. Proposals are **pre-filled** so the user corrects
rather than constructs, and the matching threshold is deliberately **strict**, so that
below it a field is left visibly unmapped rather than offered a mediocre suggestion. The
functional names the failure mode exactly: a mediocre suggestion a user confirms without
reading. Leaving `doc_date` unmapped looks worse and behaves better.

Two requirements keep the wizard honest about what it is doing. It never renders Ninox's
login inside a WebView it controls — the token is obtained through the platform's own
browser, which is a contract line rather than a convenience. And nothing is mandatory: a
user may map nothing at all, which the closing summary states in plain language instead of
leaving it to be discovered.

---

## ADDED Requirements

---

### Requirement: five-screens-at-most

The wizard SHALL have at most five screens: token, team, database, table and mapping.
[Origen: Funcional §4.6 FR-WIZ-001; PDR §8]

#### Scenario: no sixth screen exists

- GIVEN a full first run
- WHEN the flow is walked through
- THEN it presents at most the five named steps
- AND no sixth step is introduced

---

### Requirement: steps-auto-omit-when-there-is-nothing-to-choose

The team, database and table steps SHALL each be skipped automatically when their list contains exactly one option.
[Origen: Funcional §4.6 FR-WIZ-002; PDR §8]

#### Scenario: a single-option subscription sees two screens

- GIVEN a subscription with one team and one database
- WHEN the wizard runs
- THEN the team and database steps are skipped
- AND the user sees the token and mapping steps only

#### Scenario: omission rather than a hidden step

- GIVEN a one-option list
- WHEN its step would have appeared
- THEN it does not appear at all
- AND the user is not asked to confirm a single choice

---

### Requirement: token-step-via-the-system-browser

The token step SHALL offer instructions for obtaining a Ninox API token, a paste-from-clipboard action, and an option to open Ninox's settings page in the platform's own system browser — Custom Tabs on Android, SFSafariViewController on iOS — and the app SHALL never render Ninox's login inside a WebView it controls. The token SHALL be validated immediately, and a successful call SHALL also return the list the next step needs.
[Origen: Funcional §4.6 FR-WIZ-003; PDR §8; ADR-018; Finding 7; Funcional §2.4 contract line 3; Funcional §8 NFR-SEC-002]

#### Scenario: the login is presented outside the app's process

- GIVEN the user chooses to open Ninox's settings page
- WHEN the login form is displayed
- THEN it is rendered by the platform's system browser
- AND no WebView the app controls renders it

#### Scenario: an invalid token keeps the user on the step

- GIVEN the user pastes an invalid token
- WHEN it is validated
- THEN the step is not passed
- AND an error is shown

#### Scenario: a valid token also delivers the next list

- GIVEN a valid token
- WHEN it is validated
- THEN the next step's list is populated by the same call
- AND no additional round trip is needed for it

---

### Requirement: table-listing-returns-the-schema

The table listing SHALL also return the table's schema so that the mapping step needs no additional round trip, and formula and read-only fields SHALL be annotated in what is returned so that the mapping step can exclude them.
[Origen: Funcional §4.6 FR-WIZ-004; PDR §8; ADR-004]

#### Scenario: one round trip per list

- GIVEN the listing call for a table
- WHEN it returns
- THEN it carries the table's schema with it
- AND reaching the mapping step requires no further network call

#### Scenario: the picker cannot offer an unwritable field

- GIVEN a table containing a formula field and a read-only field
- WHEN the mapping step builds its picker
- THEN neither appears among the candidates
- AND the annotation in the listing is what the mapping step used to exclude them

---

### Requirement: pre-filled-proposals

The mapping step SHALL show each of the six core fields as a pre-filled proposal over the table's real fields, so that the user corrects only what is wrong, and where nothing plausible exists the field SHALL be visibly unmapped rather than shown as an empty selector.
[Origen: Funcional §4.6 FR-WIZ-005; PDR §8]

#### Scenario: a proposal is ready to correct

- GIVEN a table with a plausible candidate for a core field
- WHEN the mapping step opens
- THEN that field is pre-filled with the proposal
- AND it is not presented as an empty dropdown

#### Scenario: nothing plausible is shown as unmapped

- GIVEN a table with no plausible candidate for a core field
- WHEN the mapping step opens
- THEN that field reads as unmapped
- AND it is visibly so rather than silently empty

---

### Requirement: two-stage-matching-with-a-strict-threshold

Field matching SHALL run in two stages — a hard type filter first, then string similarity against a multilingual synonym dictionary — and SHALL use a threshold strict enough that below it a field is left unmapped rather than proposed.
[Origen: Funcional §4.6 FR-WIZ-006; PDR §8.1; Annex C]

#### Scenario: the type filter runs before similarity

- GIVEN a candidate field of the wrong type for a value
- WHEN matching runs
- THEN it is removed before similarity is computed
- AND a date is never proposed against a non-date field, nor an amount against a non-number field

#### Scenario: formula and read-only fields never reach matching

- GIVEN a table containing a formula field and a read-only field
- WHEN matching runs
- THEN neither was a candidate at any stage

#### Scenario: a German table receives its proposals

- GIVEN a table with `Belegdatum`, `Betrag` and `Lieferant`
- WHEN matching runs
- THEN date, total and supplier receive proposals

#### Scenario: below the threshold the field stays unmapped

- GIVEN a table with no date-like field
- WHEN matching runs for `doc_date`
- THEN `doc_date` is left unmapped
- AND no weak suggestion is offered in its place

#### Scenario: the failure mode is a confirmed non-suggestion

- GIVEN a mediocre suggestion that the user would confirm without reading it
- WHEN the threshold applies
- THEN the suggestion is not made
- AND the field is left for the user to map deliberately or not at all

---

### Requirement: no-mapping-is-mandatory

No mapping SHALL be mandatory, and a user SHALL be able to finish the wizard having mapped everything, one field, or nothing at all.
[Origen: Funcional §4.6 FR-WIZ-007; PDR §8.2]

#### Scenario: finishing with nothing mapped is possible

- GIVEN a user who maps no field
- WHEN the wizard is completed
- THEN it completes
- AND the closing summary describes that case

#### Scenario: the consequence is stated, not implied

- GIVEN a wizard finished with nothing mapped
- WHEN the outcome is described
- THEN it says the document will be attached to an otherwise empty record

---

### Requirement: plain-language-summary-and-first-document-offer

The wizard SHALL close with a plain-language summary of the consequence — naming exactly which core fields will be saved and which will not — and its final screen SHALL offer to capture a document of any kind rather than returning the user to an empty application.
[Origen: Funcional §4.6 FR-WIZ-008; PDR §8.2, §2]

#### Scenario: the summary names the mapped and the unmapped fields

- GIVEN a wizard that mapped date and total but not supplier, tax identifier or VAT
- WHEN the summary is shown
- THEN it names those fields as saved and those as not saved
- AND it does so in plain language rather than as a list of keys

#### Scenario: the empty-record case is described

- GIVEN a wizard that mapped nothing
- WHEN the summary is shown
- THEN it says that only the document will be attached, with no data

#### Scenario: the flow ends by offering a first document

- GIVEN the wizard's final screen
- WHEN the user accepts its offer
- THEN capture opens for a document of any kind
- AND no receipt-specific flow is assumed

---

## Out of Scope

- **What a destination is and what its fields obey.** `destinations-mapping` owns the
  tuple, identifier storage, choice fields, formula and read-only fields, the per-field
  absent setting and `never-write-an-unmapped-field`. This wizard applies those rules and
  redefines none of them.
- **Storage of the token and the rest of local data.** `local-config-privacy` owns the
  keystore storage (FR-CFG-004, NFR-SEC-001), the export that carries a destination to
  another device and the clearing action.
- **The credential invariants themselves.** `product-invariants` owns
  `token-is-the-only-credential`; the token step implements it and this capability does not
  restate it.
- **The review screen's field presentation.** `review-screen` owns the six fields' order,
  type and colour. The closing summary names the same six fields but defines nothing about
  how review presents them.
- **The first capture.** `capture-intake` owns it; the wizard's last screen offers it.
- **The matching threshold's numeric value.** The functional gives no number, and this
  spec states the outcome the threshold must produce rather than inventing one — the same
  reason `extraction-pipeline` states no accuracy figure for the photo route.

---

## Cross-Capability References

- `destinations-mapping` — owns everything about what a destination is and what may be
  written; this wizard's mapping step applies `formula-and-read-only-fields-are-not-mapping-candidates`
  and `choice-fields-offer-the-existing-options` rather than restating them.
- `product-invariants` — owns `token-is-the-only-credential`, which the token step
  implements, and `no-backend-and-no-account`, which is why configuration is local.
- `local-config-privacy` — owns the token's storage in the platform keystore, the
  configuration export this wizard's output is carried by, and the clearing action.
- `countries-languages` — owns the multilingual dictionaries the synonym matching
  consults, and the interface languages.
- `capture-intake` — owns the capture the wizard's final screen offers.
- `review-screen` — owns the presentation of the six fields the closing summary names.

---

## Open Questions

- **GAP-005** — a choice field written with text outside its options. It concerns
  `destinations-mapping` but reaches this capability through the mapping step's picker: if
  the case behaves unexpectedly, the picker is where the user would meet it.
- **GAP-006** — the private-cloud host has not been re-verified. The destination's advanced
  setup, which this wizard leads the user to, is where that host is entered.
- **Deliberately left to implementation.** The similarity threshold's value, the synonym
  dictionary's full contents beyond Annex C, and what counts as a "plausible" candidate are
  all unspecified in the functional. `two-stage-matching-with-a-strict-threshold` requires
  the outcome — below the threshold the field stays unmapped, and a mediocre suggestion is
  never made — because that outcome is what the acceptance test can check, while a number
  would be asserted by this spec and tested by nobody.
