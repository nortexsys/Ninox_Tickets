## MODIFIED Requirements

### Requirement: amounts-block-collapse-rule

The amounts block SHALL collapse to a single confirming line when a redundancy check passes, SHALL be expanded whenever it does not, including whenever an amount has no breakdown to check against at all, and an edit made after a passing check SHALL leave the block as the check left it.
[Origen: Funcional §4.4 FR-REV-005, FR-REV-010; PDR §7.2, §5.3; DEC-007]

#### Scenario: a confirmed document shows one line

- GIVEN a fully confirmed document
- WHEN the review screen is shown
- THEN the amounts block shows a single confirming line

#### Scenario: no breakdown to check means expanded

- GIVEN a card-terminal slip printing only a total
- WHEN the review screen is shown
- THEN the amounts block is expanded

#### Scenario: several slots are all visible when the check does not pass

- GIVEN a multi-rate receipt whose check does not pass
- WHEN the review screen is shown
- THEN every occupied slot is visible
- AND the block is not collapsed merely because no error was raised

#### Scenario: an edit after a passing check does not re-expand the block

- GIVEN an amounts block collapsed because its redundancy check passed
- WHEN the user unlocks and edits one of its amounts
- THEN the block stays as the check left it
- AND the edited amount is marked as edited

---

### Requirement: user-edits-are-authoritative

A value the user edits SHALL be the value sent and SHALL be marked as edited, editing SHALL NOT re-impose a confidence colour, and an edited value SHALL NOT be recomputed by the pipeline.
[Origen: Funcional §4.4 FR-REV-010; PDR §4, §7.2; DEC-007]

#### Scenario: the correction is what reaches Ninox

- GIVEN a total the user corrects
- WHEN the document is saved
- THEN the corrected total is written
- AND the read-back shows it

#### Scenario: no validation overrides the user

- GIVEN an edited value that fails a check the pipeline would have applied
- WHEN the document is saved
- THEN the edited value is written
- AND no validation replaces it

#### Scenario: editing does not restore a colour

- GIVEN an amber value the user edits
- WHEN the edit is committed
- THEN no confidence colour is re-imposed on it
- AND it is not recomputed

#### Scenario: an edited value says so

- GIVEN any value the user edits
- WHEN the edit is committed
- THEN the field shows that it was edited
- AND the mark stays until the document is saved or discarded
