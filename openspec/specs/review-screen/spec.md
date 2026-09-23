# review-screen Specification

## Purpose
Review is the screen the user sees on every document, so it decides whether the
application feels light or heavy. The functional fixes an expectation for it honestly â€”
three taps on a clean document, five or six on a typical one â€” and every requirement here
exists to protect that number without hiding what the user needs in order to trust the
result.

Two items are doing more than layout. The **daily destination confirmation** is the one
deliberate exception to the three-tap principle: once a day rather than once per document,
because sending a document to the wrong table is a mistake the user cannot see afterwards.
And the **thumbnail with the read region** is how the screen shows *why* the app reached a
number: tapping a confirmed total highlights the regions of every operand that fed the
check, which is the only way to audit a confirmation instead of taking it on faith.

The capability also owns the two requirements that stop it fighting the product's own
principles: a save is never blocked, and a user's edit is final.

---
## Requirements
### Requirement: destination-bar

The review screen SHALL carry a full-width, persistent destination bar showing team, database and table, tappable to change the destination without leaving the document.
[Origen: Funcional Â§4.4 FR-REV-001; PDR Â§7.2]

#### Scenario: the bar is always visible

- GIVEN the review screen at any point in the flow
- WHEN the screen is displayed
- THEN the destination bar is visible with team, database and table

#### Scenario: the destination changes without losing the document

- GIVEN a document under review
- WHEN the user taps the destination bar
- THEN destination selection opens
- AND the document is still there when the selection closes

---

### Requirement: daily-destination-confirmation

The destination bar SHALL be pre-loaded with the destination used last, and on the first capture of each calendar day it SHALL be highlighted with the save button disabled until the user has acknowledged the destination once.
[Origen: Funcional Â§4.4 FR-REV-002; PDR Â§7.2, Â§7.3; Finding 4]

#### Scenario: the first capture of a day requires acknowledgement

- GIVEN the first capture of a calendar day
- WHEN the review screen opens
- THEN the destination bar is highlighted
- AND the save button is disabled until the destination is acknowledged

#### Scenario: later captures on the same day do not

- GIVEN a second capture on the same day
- WHEN the review screen opens
- THEN no further acknowledgement is required
- AND the destination shown is the one used for the first

#### Scenario: the exception is bounded to once a day

- GIVEN the three-tap expectation for a clean document
- WHEN the daily confirmation applies
- THEN it is the only deliberate exception to it
- AND it does not recur per document

---

### Requirement: thumbnail-with-the-read-region

The review screen SHALL show a document thumbnail, tapping a field SHALL box and zoom to the region the value was read from, and a value produced by a redundancy check SHALL highlight the regions of every operand that fed the check.
[Origen: Funcional Â§4.4 FR-REV-003; PDR Â§7.2]

#### Scenario: a field shows where its value came from

- GIVEN a value read from the document
- WHEN the user taps the field
- THEN a box is drawn around the region it was read from
- AND the thumbnail zooms to it

#### Scenario: a confirmed total shows all of its operands

- GIVEN a green total confirmed by `base + tax = total`
- WHEN the user taps it
- THEN the regions of the base, the tax and the total are highlighted together
- AND the user can see why the app reached that number rather than only that it did

---

### Requirement: six-core-fields-in-fixed-order

The review screen SHALL show the six core fields â€” `doc_date`, `supplier_name`, `supplier_tax_id`, `doc_number`, `gross_total` and `currency` â€” in that fixed order, with inline editing, large type and a colour per confidence state, and on opening SHALL place focus on the first field that was not read.
[Origen: Funcional Â§4.4 FR-REV-004; PDR Â§7.2, Â§5.1]

#### Scenario: the order is identical everywhere

- GIVEN documents arriving by different routes
- WHEN each is reviewed
- THEN the six fields appear in the same order in all cases

#### Scenario: focus goes to what needs attention

- GIVEN a document with no supplier name
- WHEN review opens
- THEN focus lands on `supplier_name`

#### Scenario: a fully read document focuses the first field

- GIVEN a document from which every core field was read
- WHEN review opens
- THEN focus lands on `doc_date`
- AND no field is skipped

---

### Requirement: amounts-block-collapse-rule

The amounts block SHALL collapse to a single confirming line when a redundancy check passes, and SHALL be expanded whenever it does not, including whenever an amount has no breakdown to check against at all.
[Origen: Funcional Â§4.4 FR-REV-005; PDR Â§7.2, Â§5.3]

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

---

### Requirement: advanced-section-collapsed

The advanced section â€” remaining mapped fields, `surcharges[]`, `doc_subtype` and the other extended groups â€” SHALL be collapsed by default on the review screen.
[Origen: Funcional Â§4.4 FR-REV-006; PDR Â§7.2, Â§5.2]

#### Scenario: it starts closed

- GIVEN any document
- WHEN review opens
- THEN the advanced section is closed

#### Scenario: a clean document shows no advanced field by default

- GIVEN a clean document
- WHEN its default view is inspected
- THEN no advanced field is visible

#### Scenario: it expands on demand

- GIVEN the advanced section closed
- WHEN the user expands it
- THEN the remaining mapped fields and the extended groups are shown

---

### Requirement: duplicate-notice

When the duplicate check matches, the review screen SHALL show a notice linking to the existing record and SHALL let the user proceed anyway, creating a second record deliberately.
[Origen: Funcional Â§4.4 FR-REV-007; Funcional Â§4.12 FR-DUP-002; PDR Â§7.2]

#### Scenario: the notice links to what already exists

- GIVEN a document the duplicate check has flagged
- WHEN the review screen is shown
- THEN a duplicate notice appears
- AND it links to the existing record

#### Scenario: proceeding anyway is allowed

- GIVEN the duplicate notice is shown
- WHEN the user chooses to proceed
- THEN a second record is created deliberately
- AND the app does not prevent it

---

### Requirement: save-button-names-the-destination

The save button SHALL be fixed at the bottom of the review screen and SHALL name the outcome, for example "Save to Expenses 2026", rather than reading a generic verb.
[Origen: Funcional Â§4.4 FR-REV-008; PDR Â§7.2]

#### Scenario: the label names the table

- GIVEN a destination whose table is `Expenses 2026`
- WHEN the review screen is shown
- THEN the save button's label contains that table name
- AND it contains no generic verb such as "Submit"

#### Scenario: the button stays in place

- GIVEN a long document scrolled to any position
- WHEN the screen is inspected
- THEN the save button is fixed at the bottom

---

### Requirement: never-block-a-save

The user SHALL always be able to save, and missing, unreadable or low-confidence fields SHALL never prevent a record from being created with the document attached.
[Origen: Funcional Â§4.4 FR-REV-009; Funcional Â§5 BR-14; PDR Â§4, Â§3.2]

#### Scenario: an empty document can still be saved

- GIVEN a document from which nothing could be read
- WHEN the user saves
- THEN a record is created with the attachment and no data

#### Scenario: only the daily confirmation may disable the button

- GIVEN any field state â€” missing, unreadable, red or amber
- WHEN the save button is inspected
- THEN it is enabled
- AND the daily destination confirmation is the only condition that may disable it

---

### Requirement: user-edits-are-authoritative

A value the user edits SHALL be the value sent, editing SHALL NOT re-impose a confidence colour, and an edited value SHALL NOT be recomputed by the pipeline.
[Origen: Funcional Â§4.4 FR-REV-010; PDR Â§4, Â§7.2]

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

---

### Requirement: discard-a-document

From review the user SHALL be able to discard the document, and a discard SHALL create no record and delete the local capture.
[Origen: Funcional Â§4.4 FR-REV-011; PDR Â§7.2; Funcional Â§6.2.3]

#### Scenario: discarding leaves nothing behind

- GIVEN a document under review
- WHEN the user discards it
- THEN no record is created
- AND no history entry remains
- AND the local file is deleted

---

## Out of Scope

- **What a confidence state means.** `validation-confidence` owns the three strengths,
  what may be shown as confirmed, and the rule that green is editable only after its lock
  is tapped. This screen renders the state and provides the lock affordance.
- **The duplicate criteria.** `document-history` owns them and the read-side check. This
  capability owns the notice, the link and the permission to proceed, which is why
  FR-REV-007 and FR-DUP-002 are carried as one requirement with both origins.
- **What a destination is.** `destinations-mapping` owns the tuple, the identifier
  storage, the per-field absent setting and everything about what may be written. The bar
  displays a destination and changes it.
- **The save itself and what follows it.** `ninox-send` owns the send, the read-back and
  the confirmation screen.
- **The state a discarded document passes through.** `document-history` owns the state
  machine and the file retention a discard triggers.
- **Where a value came from, and the coordinates of its region.**
  `extraction-pipeline` owns provenance and the reading; this capability draws the box.
- **The three-tap expectation itself.** It is stated in the PDR as a product expectation
  and is the reason the daily confirmation is bounded the way it is; this capability does
  not restate it as a requirement it cannot test.

---

## Cross-Capability References

- `validation-confidence` â€” determines the confidence state this screen renders, owns
  what may be shown as confirmed and owns the lock rule that
  `user-edits-are-authoritative` depends on.
- `document-history` â€” owns the duplicate criteria and sets the flag this screen's
  `duplicate-notice` presents, and owns the state machine a discard transitions.
- `destinations-mapping` â€” owns the destination the bar displays and changes, and the
  per-field absent setting behind it.
- `ninox-send` â€” owns the send and the read-back that the confirmation screen shows.
- `extraction-pipeline` â€” owns the provenance and the read regions this screen draws.
- `capture-intake` â€” owns the entry point the user returns to after a discard.
- `product-invariants` â€” owns `no-user-facing-reporting-or-export`, whose read-back
  exception is why this screen may show what the record actually stored.

---

## Open Questions

- **GAP-009** â€” the formula-field contrast's blind spot. Its mismatch is surfaced to the
  user here as a question about the mapping or the formula, which is where the wording
  matters; the check itself is `destinations-mapping`'s.
- **GAP-005** â€” a choice field written with text outside its options. If that case
  behaves unexpectedly, the error text the user sees is this screen's concern, though the
  containing behaviour is `destinations-mapping`'s.
- **Settled before writing.** FR-REV-007 and FR-DUP-002 are the same behaviour â€” notice,
  link, proceed â€” stated once in the module for review and once in the module for
  duplicates. They are carried here as a single requirement with both origins, and the
  criteria stay in `document-history`. Recorded in `openspec/project.md` Â§3.1.
- **An interaction the functional does not settle.** Whether the amounts block re-expands
  when the user edits a value after a passing check. `user-edits-are-authoritative`
  requires that editing re-imposes no confidence colour and does not recompute, and
  `amounts-block-collapse-rule` collapses only when a check passes â€” so this spec reads an
  edit as leaving the block as the check left it. It is recorded here rather than decided
  silently, because a reader could reasonably expect the opposite.
