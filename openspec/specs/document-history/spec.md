# document-history Specification

## Purpose
Because mapping is optional, this is the **only** place a document's confidence and
provenance can be inspected after the fact. A user who mapped nothing gets records in
Ninox carrying an attachment and nothing else; if history did not survive the send,
nothing on the device would say which records the app had been unsure about. History
is therefore a first-class surface, not a convenience view.

It is also where the document **state machine** lives. The states are not labels.
`queued`, `uncertain` and `failed` are three different situations â€” waiting, genuinely
unknown, and known to have failed â€” and collapsing them is how a create whose response
was lost gets retried and duplicated. `capture-intake` and `ninox-send` drive
transitions of a machine that is defined here.

And it owns the duplicate **criteria**, checked read-side against this store. That is
not a preference: `destinations-mapping` forbids relying on a marker field in the user's
table, so a write-side duplicate check would have nothing to rely on. The notice the
criteria produce belongs to `review-screen`; the criteria belong here.

---
## Requirements
### Requirement: content-of-a-history-entry

Every capture SHALL produce a local history entry holding the thumbnail, the extracted values **with their provenance**, the destination, the state, the confidence, the document hash, and the Ninox record identifier once sent.
[Origen: Funcional Â§4.8 FR-HIS-001; PDR Â§7.5; Funcional Â§6.3]

#### Scenario: all eight items are present

- GIVEN a completed capture
- WHEN its history entry is opened
- THEN the thumbnail, the values, the destination, the state, the confidence, the hash and â€” once sent â€” the record identifier are all present

#### Scenario: provenance is visible locally though it is never sent

- GIVEN a sent document
- WHEN its detail is inspected
- THEN the provenance of its values is shown
- AND that provenance was never written to Ninox

---

### Requirement: document-states

A history entry SHALL carry exactly one state of `pending`, `queued`, `extracting`, `reviewing`, `sending`, `uncertain`, `sent`, `failed` or `duplicate-flagged`, and its transitions SHALL be those of the state machine in Â§6.2.3 of the functional.
[Origen: Funcional Â§4.8 FR-HIS-002; Funcional Â§6.2.3 (the document state machine); PDR Â§7.5]

#### Scenario: an offline save is queued, not failed

- GIVEN a save performed with no connectivity
- WHEN its entry is inspected
- THEN it reads `queued`
- AND it does not read `failed`

#### Scenario: a lost create response is uncertain, not failed

- GIVEN a create whose response was lost
- WHEN its entry is inspected
- THEN it reads `uncertain`
- AND it is not collapsed into `failed` or into `sent`

#### Scenario: a completed send carries its record identifier

- GIVEN a send that completed
- WHEN its entry is inspected
- THEN it reads `sent`
- AND its Ninox record identifier is populated

#### Scenario: no entry holds two states at once

- GIVEN any entry in any moment
- WHEN its state is read
- THEN exactly one of the nine values is held

---

### Requirement: correction-and-re-send

From a history entry the user SHALL be able to correct values and re-send, and the result SHALL be an update of the same record rather than a new one.
[Origen: Funcional Â§4.8 FR-HIS-003; PDR Â§7.5, Â§9.1]

#### Scenario: a correction updates rather than duplicates

- GIVEN a `sent` entry the user corrects
- WHEN it is re-sent
- THEN the record identified by that entry is updated
- AND no second record is created

#### Scenario: the correction reaches the record it came from

- GIVEN an entry carrying its Ninox record identifier
- WHEN a correction is issued
- THEN it targets that identifier
- AND no other record is touched

---

### Requirement: file-retention

Local document images SHALL be deleted once a send is confirmed, since the document is in Ninox by then, and SHALL be retained while an item is pending or failed.
[Origen: Funcional Â§4.8 FR-HIS-004; PDR Â§7.5; Funcional Â§6.3]

#### Scenario: a confirmed send releases the local file

- GIVEN an entry in the `sent` state
- WHEN the local store is inspected
- THEN the document file is gone
- AND the thumbnail remains

#### Scenario: an unresolved item keeps its file

- GIVEN an entry in the `failed` state
- WHEN its detail is opened
- THEN its local file is still available

#### Scenario: retention follows the state, not a timer

- GIVEN an entry that has been pending for a long time
- WHEN retention is evaluated
- THEN its file is retained because the item is unresolved
- AND no elapsed time alone has deleted it

---

### Requirement: history-is-the-uncertainty-trace

History SHALL be treated as a first-class surface rather than an optional extra, because mapping the review metadata is optional and a user who mapped nothing has no other way to see which records were uncertain.
[Origen: Funcional Â§4.8 FR-HIS-005; PDR Â§7.5]

#### Scenario: confidence survives the send with nothing mapped

- GIVEN a destination with no field mapped at all
- WHEN a past document is examined
- THEN its confidence and its provenance are still inspectable in history
- AND they survived the send

#### Scenario: history is not treated as disposable

- GIVEN a completed send
- WHEN the entry is considered for removal
- THEN it is retained, because it is the only record of how sure the app was

---

### Requirement: duplicate-criteria

A document SHALL be flagged as a duplicate when its hash matches an earlier send, or when supplier, date and total together match one, and the check SHALL run against local history before a save.
[Origen: Funcional Â§4.12 FR-DUP-001; PDR Â§7.2; Funcional Â§5 BR-15; ADR-013]

#### Scenario: the same file captured twice matches on hash

- GIVEN a file already sent
- WHEN the same file is captured again
- THEN it is flagged on the hash criterion

#### Scenario: two photographs of one receipt match on their content

- GIVEN two different photographs of the same receipt
- WHEN the second is captured
- THEN it is flagged on supplier, date and total together

#### Scenario: two documents from one supplier on one day do not match

- GIVEN two different documents from the same supplier dated the same day with different totals
- WHEN the second is captured
- THEN it is not flagged as a duplicate

#### Scenario: the check is read-side and cannot use a marker field

- GIVEN the prohibition on writing an unmapped field
- WHEN duplicate prevention is implemented
- THEN it reads local history rather than a field in the user's table
- AND no marker field is assumed to exist

---

## Out of Scope

- **The duplicate notice, its link and the permission to proceed.** FR-DUP-002 and
  FR-REV-007 describe that behaviour and both belong to `review-screen`. This capability
  owns the criteria, the read-side check and the `duplicate-flagged` state.
- **Driving the state transitions.** `ninox-send` performs the send and drives the
  machine defined here; it owns the retry matrix and the reconciliation that resolves
  `uncertain`.
- **What causes the `queued` state.** `capture-intake` requires that an offline save
  queues rather than fails; this capability defines what `queued` means.
- **The confidence and provenance of a value.** `validation-confidence` and
  `extraction-pipeline` own those. This capability stores and displays them.
- **Clearing what is stored here.** `local-config-privacy` owns the data-clearing
  action (FR-CFG-003) and the export that can carry a destination and a mapping to
  another device.
- **Supplier memory.** `supplier-memory` owns its own store, safeguard and deletion.

---

## Cross-Capability References

- `ninox-send` â€” drives every transition of the state machine defined here, and owns
  the reconciliation that resolves `uncertain`. The record identifier this capability
  stores is what makes `correction-and-re-send` an update rather than a duplicate.
- `capture-intake` â€” requires that an offline save queues rather than fails, which is
  this capability's `queued` state.
- `review-screen` â€” owns the duplicate notice, the link to the existing record and the
  permission to proceed (FR-REV-007, FR-DUP-002), and presents the duplicate-flag state
  this capability determines.
- `destinations-mapping` â€” owns `never-write-an-unmapped-field`, which is the reason
  the duplicate check is read-side.
- `validation-confidence` â€” owns the confidence this capability stores as a property of
  an entry.
- `extraction-pipeline` â€” owns the provenance this capability stores without sending it.
- `local-config-privacy` â€” owns clearing local data and the configuration export, and
  `supplier-memory` owns the other local store.

---

## Open Questions

- **None blocking.** GAP-004 (attachment-upload limits) and GAP-005 (a choice field
  written outside its options) concern `ninox-send` and `destinations-mapping`.
  GAP-009 (the formula contrast's blind spot) is recorded against
  `destinations-mapping`. GAP-001 and GAP-002 concern the extraction routes. None
  touches this capability.
- **Settled before writing.** FR-DUP-002 describes the review screen's notice, link and
  permission to proceed, which is the same behaviour as FR-REV-007. Both are left to
  `review-screen` and this capability keeps the criteria, the check and the
  `duplicate-flagged` state â€” because the criteria depend on local history, while the
  notice depends on the review screen. The correction is recorded in
  `openspec/project.md` Â§3.1.
- **The transitions themselves are referenced, not restated.** Â§6.2.3 of the functional
  holds the state machine's transition table. Reproducing it here would create a second
  copy to drift; `document-states` requires that the transitions are that table's and
  names where it lives.
