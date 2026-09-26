## MODIFIED Requirements

### Requirement: table-listing-returns-the-schema

The table listing SHALL also return each table's writable fields so that the mapping step needs no additional round trip, and formula fields SHALL NOT reach the mapping step.
[Origen: Funcional §4.6 FR-WIZ-004; PDR §8; ADR-004; DEC-005]

#### Scenario: one round trip per list

- GIVEN the listing call for a table
- WHEN it returns
- THEN it carries the table's fields with it
- AND reaching the mapping step requires no further network call

#### Scenario: the picker cannot offer a formula field

- GIVEN a table containing a formula field
- WHEN the mapping step builds its picker
- THEN that field does not appear among the candidates
- AND its exclusion does not depend on its name or type

---

### Requirement: two-stage-matching-with-a-strict-threshold

Field matching SHALL run in two stages — a hard type filter first, then string similarity against a multilingual synonym dictionary — and SHALL use a threshold strict enough that below it a field is left unmapped rather than proposed.
[Origen: Funcional §4.6 FR-WIZ-006; PDR §8.1; Annex C; DEC-005]

#### Scenario: the type filter runs before similarity

- GIVEN a candidate field of the wrong type for a value
- WHEN matching runs
- THEN it is removed before similarity is computed
- AND a date is never proposed against a non-date field, nor an amount against a non-number field

#### Scenario: formula fields never reach matching

- GIVEN a table containing a formula field
- WHEN matching runs
- THEN it was not a candidate at any stage

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
