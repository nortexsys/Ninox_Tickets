# review-screen Specification

## Purpose
Review is the screen the user sees on every document, so it decides whether the
application feels light or heavy. The functional fixes an expectation for it honestly —
three taps on a clean document, five or six on a typical one — and every requirement here
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
[Origen: Funcional §4.4 FR-REV-001; PDR §7.2]

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
[Origen: Funcional §4.4 FR-REV-002; PDR §7.2, §7.3; Finding 4]

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
[Origen: Funcional §4.4 FR-REV-003; PDR §7.2]

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

The review screen SHALL show the six core fields — `doc_date`, `supplier_name`, `supplier_tax_id`, `doc_number`, `gross_total` and `currency` — in that fixed order, with inline editing, large type and a colour per confidence state, and on opening SHALL place focus on the first field that was not read.
[Origen: Funcional §4.4 FR-REV-004; PDR §7.2, §5.1]

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

### Requirement: advanced-section-collapsed

The advanced section — remaining mapped fields, `surcharges[]`, `doc_subtype` and the other extended groups — SHALL be collapsed by default on the review screen.
[Origen: Funcional §4.4 FR-REV-006; PDR §7.2, §5.2]

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
[Origen: Funcional §4.4 FR-REV-007; Funcional §4.12 FR-DUP-002; PDR §7.2]

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
[Origen: Funcional §4.4 FR-REV-008; PDR §7.2]

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
[Origen: Funcional §4.4 FR-REV-009; Funcional §5 BR-14; PDR §4, §3.2]

#### Scenario: an empty document can still be saved

- GIVEN a document from which nothing could be read
- WHEN the user saves
- THEN a record is created with the attachment and no data

#### Scenario: only the daily confirmation may disable the button

- GIVEN any field state — missing, unreadable, red or amber
- WHEN the save button is inspected
- THEN it is enabled
- AND the daily destination confirmation is the only condition that may disable it

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

### Requirement: discard-a-document

From review the user SHALL be able to discard the document, and a discard SHALL create no record and delete the local capture.
[Origen: Funcional §4.4 FR-REV-011; PDR §7.2; Funcional §6.2.3]

#### Scenario: discarding leaves nothing behind

- GIVEN a document under review
- WHEN the user discards it
- THEN no record is created
- AND no history entry remains
- AND the local file is deleted

---

### Requirement: country-shown-and-editable-per-ticket

The review screen SHALL show the country in force for the ticket, without the user
having to ask for it, and SHALL let the user change it there without leaving the
document; the change SHALL apply to the ticket it was made on, SHALL NOT by itself
re-read the document, and SHALL NOT alter a value already produced by the read —
amounts, dates and identifiers stay as they were read, and the new country SHALL take
effect only if and when the document is read again. The change SHALL be that ticket's
alone: the default country in the settings SHALL NOT change, and the next ticket SHALL
show the default from the settings again. Where the country in force has no row in the
country table, the screen SHALL say that the country has no row and that the ticket's
fields are to be filled by hand, and SHALL present no value on the ticket as read
(`countries-languages` · `country-is-an-input`). Showing and changing the country
SHALL NOT alter the order of the six core fields.
[Origen: Funcional §4.4 FR-REV-004; Funcional §4.11 FR-CTR-001; PDR §7.2; DEC-022]

#### Scenario: the ticket shows the country it was read under

- GIVEN a ticket captured while the default country is Germany
- WHEN the review screen opens
- THEN it shows Germany as that ticket's country

#### Scenario: the country can be changed without leaving the document

- GIVEN a ticket whose country is Germany
- WHEN the user changes it to Spain
- THEN Spain is in force for that ticket
- AND the document is still under review

#### Scenario: changing the country does not rewrite what was read

- GIVEN a ticket read with Germany in force, with its amounts and dates on screen
- WHEN the user changes the country to Spain
- THEN those values are unchanged
- AND the change has not re-read the document

#### Scenario: the six core fields keep their order

- GIVEN the six core fields in their fixed order
- WHEN the country is shown on the review screen
- THEN the order of the six is unchanged
- AND the country is not presented as one of them

#### Scenario: the next ticket goes back to the default

- GIVEN the default country in the settings is Germany
- AND a ticket whose country the user changed to Spain
- WHEN the next document is captured and its review screen opens
- THEN that ticket shows Germany, the default from the settings
- AND the earlier ticket still shows Spain

#### Scenario: a country without a row is announced on the ticket

- GIVEN a ticket whose country in force has no row in the country table
- WHEN the review screen opens
- THEN it says that the country has no row and that the fields are to be filled by
  hand
- AND no value on the ticket is presented as read for that country

---

### Requirement: second-read-is-requested-and-shown-running

The review screen SHALL offer the user a second read of the document on request ("re-read to refine") and SHALL show that it is running while it runs, so that the wait is not mistaken for a block and the result is not mistaken for the first read's. When the second read finishes, the screen SHALL show the values it filled or refined, and SHALL keep every value the user edited or typed as the user's — with the user's value and its edited mark, whatever the second read returned (`user-edits-are-authoritative`). The screen SHALL allow the save while a second read runs and SHALL NOT make it a condition of saving (BR-14, `never-block-a-save`).
[Origen: Funcional §4.4 FR-REV-009; Funcional §4.4 FR-REV-010; Funcional §5 BR-14; DEC-007; DEC-024]

#### Scenario: the user asks for a second read

- GIVEN a document under review whose first read is on screen
- WHEN the user asks for a second read
- THEN the second read starts on the same document
- AND the screen shows that it is running

#### Scenario: the screen shows that the second read is running and then stops showing it

- GIVEN a second read under way
- WHEN it finishes, whether or not it filled anything
- THEN the screen no longer shows it as running
- AND the values it produced are on screen

#### Scenario: a value the user edited is not overwritten by the second read

- GIVEN a total the user typed on the review screen
- WHEN the second read returns another total
- THEN the screen still shows the user's total
- AND it is still marked as edited

#### Scenario: a value the user did not touch may be filled or refined

- GIVEN an empty field, and a date the first read produced that the user has not
  touched
- WHEN the second read returns a value for each
- THEN the screen shows what the second read produced for them

#### Scenario: a save is not held back by a second read

- GIVEN a second read running on the document under review
- WHEN the user saves
- THEN the save proceeds
- AND the second read has not become a condition of saving

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

- `validation-confidence` — determines the confidence state this screen renders, owns
  what may be shown as confirmed and owns the lock rule that
  `user-edits-are-authoritative` depends on.
- `document-history` — owns the duplicate criteria and sets the flag this screen's
  `duplicate-notice` presents, and owns the state machine a discard transitions.
- `destinations-mapping` — owns the destination the bar displays and changes, and the
  per-field absent setting behind it.
- `ninox-send` — owns the send and the read-back that the confirmation screen shows.
- `extraction-pipeline` — owns the provenance and the read regions this screen draws.
- `capture-intake` — owns the entry point the user returns to after a discard.
- `product-invariants` — owns `no-user-facing-reporting-or-export`, whose read-back
  exception is why this screen may show what the record actually stored.

---

## Open Questions

- **GAP-009** — the formula-field contrast's blind spot. Its mismatch is surfaced to the
  user here as a question about the mapping or the formula, which is where the wording
  matters; the check itself is `destinations-mapping`'s.
- **GAP-005** — a choice field written with text outside its options. If that case
  behaves unexpectedly, the error text the user sees is this screen's concern, though the
  containing behaviour is `destinations-mapping`'s.
- **Settled before writing.** FR-REV-007 and FR-DUP-002 are the same behaviour — notice,
  link, proceed — stated once in the module for review and once in the module for
  duplicates. They are carried here as a single requirement with both origins, and the
  criteria stay in `document-history`. Recorded in `openspec/project.md` §3.1.
- **Settled on 2026-09-25 (GAP-019, DEC-007).** Editing a value after a passing check leaves
  the amounts block as the check left it, and the edited value is marked as edited. Carried
  into `amounts-block-collapse-rule` and `user-edits-are-authoritative` by the change archived
  at `openspec/changes/archive/2026-09-25-resolve-mvp-planning-gaps`.
