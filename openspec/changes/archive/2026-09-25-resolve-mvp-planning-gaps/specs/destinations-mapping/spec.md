## MODIFIED Requirements

### Requirement: formula-and-read-only-fields-are-not-mapping-candidates

Formula fields SHALL never be offered as mapping candidates nor shown in any screen where the user builds or edits a mapping, and a field the API rejects as unwritable SHALL be reported as a mapping error rather than discovered by writing to the user's database.
The Ninox API exposes no read-only marker, so the app SHALL NOT claim to exclude read-only fields in advance: a mapped field that makes a send fail with HTTP 500 after the single retry of the retry matrix is reported as a mapping error naming the mapped fields, and the user is taken to the mapping.
[Origen: Funcional §4.5 FR-DST-004; PDR §7.4, §8.1; ADR-004; Annex A (formula and read-only fields); DEC-005]

#### Scenario: a formula field is not offered

- GIVEN a table whose total is a formula field
- WHEN the mapping picker is shown
- THEN that field does not appear among the candidates
- AND it does not appear in any other screen where the mapping is built or edited

#### Scenario: exclusion does not depend on the field's name or type

- GIVEN a formula field whose name and result type match a core field, such as a number field called `Total`
- WHEN the candidates are built
- THEN it is still excluded
- AND no writable field is excluded in its place

#### Scenario: the app never provokes a 500 on a formula write

- GIVEN any destination the user can configure
- WHEN a record is written
- THEN no request targets a formula field
- AND the HTTP 500 the API returns for such a write is never produced by a formula field

#### Scenario: an unwritable field without a marker is reported, not probed

- GIVEN a mapped field that the API rejects although nothing in the schema marked it
- WHEN a send fails with HTTP 500 after the schema refresh and the single retry
- THEN the failure is reported as a mapping error naming the mapped fields
- AND the user is taken to the mapping
- AND the app issues no additional write to find out which field was rejected
