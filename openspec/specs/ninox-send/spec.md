# ninox-send Specification

## Purpose
A create whose response is lost in a timeout is the most expensive failure this product
can have. The record may exist or it may not, the app cannot tell, and the obvious
instinct â€” retry â€” is precisely what writes a duplicate into someone's accounting. The
answer is not a retry policy but a **reconciliation**, and where the evidence is
genuinely ambiguous the app asks the user instead of guessing.

A second trap points the other way. An HTTP 500 from this API does not mean the server
is unwell: it is what an invalid or read-only field name returns. A client that reads 500
as an outage and retries forever will hammer the API over its own mapping mistake and
never mention it. That is why the retry behaviour is stated as a **matrix** of eleven
conditions rather than as guidance â€” the intuitive answer is wrong for at least four of
them, and nobody classifies eleven failure modes correctly at the moment of failure.

Third, the record is read back, and the **read-back is what the user is shown**. Fields
carrying formulas or defaults silently override what was submitted and the create
response does not reveal it, so showing the user what was sent would be showing them
something the app cannot vouch for.

---
## Requirements
### Requirement: create-attach-read-back

A send SHALL be three steps â€” create the record, attach the document to it, read the record back â€” and the confirmation SHALL present the read-back values as what is actually stored rather than what was sent.
[Origen: Funcional Â§4.7 FR-SND-001; Funcional Â§5 BR-18; PDR Â§9; ADR-004; Annex A (read after create)]

#### Scenario: the confirmation shows stored values

- GIVEN a completed send
- WHEN the confirmation is displayed
- THEN the values shown are those read back from Ninox

#### Scenario: a default that overrode a submitted value is visible

- GIVEN a table default that overrides a value the app submitted
- WHEN the record is read back
- THEN the confirmation shows the stored value
- AND the create response having not revealed the override is the reason the read-back exists

#### Scenario: the three steps happen in this order

- GIVEN any send
- WHEN its requests are inspected
- THEN they are a create, then an attachment to the created record, then a read of that record

---

### Requirement: payload-shape

Records SHALL be written as a nested object under a `fields` key keyed by field name, dates SHALL be sent as `YYYY-MM-DD` and stored verbatim, amounts SHALL be sent as integers in the currency's minor unit and rates as integers in basis points, and the document SHALL never be a mapping target.
[Origen: Funcional Â§4.7 FR-SND-002; Funcional Â§5 BR-22; ADR-004, ADR-016; Annex A (payload shape and dates)]

#### Scenario: a payload round-trips without a float

- GIVEN a record carrying a date and an amount
- WHEN it is sent and read back
- THEN the date is unchanged
- AND the amount is the same integer, with no float at any boundary

#### Scenario: the payload is keyed by name

- GIVEN a destination whose stored field identifiers have current names
- WHEN the payload is built
- THEN its keys are the current field names

#### Scenario: the attachment is not a field

- GIVEN any destination table, including one with no file-type field
- WHEN the document is attached
- THEN it is attached to the record itself
- AND no mapped field carries it

---

### Requirement: attachment-upload

The document SHALL be attached with a single multipart call to the record's files endpoint returning HTTP 200, and the app SHALL be able to read the attachment back with its name, size and content type.
[Origen: Funcional Â§4.7 FR-SND-003; ADR-004; Annex A (attachment upload)]

#### Scenario: the upload succeeds and is readable

- GIVEN a record that has been created
- WHEN the document is attached
- THEN the files endpoint returns HTTP 200
- AND a subsequent read returns its name, size and content type matching what was uploaded

#### Scenario: no record is created without its document

- GIVEN a document the user chose to save
- WHEN the send completes
- THEN the record carries the document
- AND a send that created a record but failed to attach it is treated as incomplete rather than as done

---

### Requirement: the-retry-matrix

Send errors SHALL be handled per the matrix below and in no other way.
[Origen: Funcional Â§4.7 FR-SND-004; Funcional Â§9.1, Â§9.3; PDR Â§9.1; ADR-004, ADR-013; Annex A (retry policy and error shape)]

| Condition | Behaviour |
| --- | --- |
| No connectivity | Queued, and sent automatically when connectivity returns |
| Timeout or network error on create | Outcome `uncertain`; reconciliation per `reconciliation-of-an-uncertain-create`; **never** a blind retry |
| Timeout on attachment or on read-back | Bounded exponential backoff, because neither can duplicate a record |
| HTTP 401 or 403 | An authentication problem: the user re-enters the token; no retry |
| HTTP 404 | The database or table no longer exists: the user is sent to the destination; no retry |
| HTTP 500 | Refresh the schema, retry **exactly once**, then report a **mapping error** rather than a server outage |
| Record created, attachment failed | Retry the attachment only |

#### Scenario: a 500 is reported as a mapping error

- GIVEN an HTTP 500 from a create
- WHEN it is handled
- THEN the schema is refreshed and the request retried exactly once
- AND a second failure is reported to the user as a mapping error rather than as an outage

#### Scenario: a 500 is never retried forever

- GIVEN a client that treats 500 as a server outage and retries indefinitely
- WHEN it is tested
- THEN it fails this requirement

#### Scenario: a timed-out create is not retried

- GIVEN a create whose response was lost
- WHEN the failure is classified
- THEN it is not retried
- AND it enters reconciliation instead

#### Scenario: an attachment timeout is safe to retry

- GIVEN a timeout while uploading the attachment of an already-created record
- WHEN it is handled
- THEN it is retried with bounded exponential backoff
- AND no second record can result

#### Scenario: an authentication failure asks for the token

- GIVEN HTTP 401 or 403
- WHEN it is handled
- THEN the user is asked to re-enter the token
- AND no automatic retry is attempted

#### Scenario: a vanished destination is not retried

- GIVEN HTTP 404
- WHEN it is handled
- THEN the user is sent to the destination
- AND no retry is attempted

#### Scenario: a failed attachment retries alone

- GIVEN a record that was created but whose attachment failed
- WHEN the retry runs
- THEN only the attachment is retried
- AND the record itself is not re-created

---

### Requirement: reconciliation-of-an-uncertain-create

A create whose response was lost SHALL enter the `uncertain` state and trigger a read-side reconciliation against the destination table's most recently created records, using `createdAt` and `createdBy` and the mapped fields within a short time window: exactly one match adopts that record, no match creates one, and ambiguity asks the user because the app never guesses.
[Origen: Funcional Â§4.7 FR-SND-005; Funcional Â§5 BR-21; PDR Â§9.1; ADR-013; Finding 1]

#### Scenario: the POST landed but the response was lost

- GIVEN a create whose POST reached Ninox and whose response was lost
- WHEN reconciliation runs
- THEN exactly one record exists after the flow
- AND the existing record is adopted and the flow continues to the attachment step

#### Scenario: the POST did not land

- GIVEN a create whose POST did not reach Ninox
- WHEN reconciliation runs
- THEN no matching record is found
- AND the record is created
- AND exactly one record exists after the flow

#### Scenario: ambiguity is surfaced rather than guessed

- GIVEN two near-identical candidate matches, or too few mapped fields to compare
- WHEN reconciliation runs
- THEN the uncertainty is surfaced to the user
- AND the user chooses
- AND the app does not decide

#### Scenario: the reconciliation does not depend on mapping

- GIVEN a destination with no field mapped at all
- WHEN reconciliation runs
- THEN `createdAt` and `createdBy` are available to narrow the candidates
- AND no marker field is required to exist

---

### Requirement: deep-link-back-to-the-record

After a successful send the confirmation SHALL offer a link to open the record in Ninox built entirely from data the app already holds, with no additional API call and no credentials, and the button SHALL degrade to opening the database if the URL structure no longer resolves.
[Origen: Funcional Â§4.7 FR-SND-006; PDR Â§9.2; ADR-008; Funcional Â§2.4 contract line 3]

#### Scenario: the record opens

- GIVEN a completed send
- WHEN the link is used
- THEN it opens the created record
- AND no additional API call was made to build it

#### Scenario: a changed URL shape degrades instead of failing

- GIVEN an artificially broken URL shape
- WHEN the button is used
- THEN it opens the database rather than showing an error

---

### Requirement: automations-may-run-and-the-read-back-is-the-visibility

The app SHALL treat creating a record as an action that may trigger automations inside the user's Ninox database which the API does not expose, and the user-facing documentation SHALL say so.
[Origen: Funcional Â§4.7 FR-SND-007; ADR-004 (note); Annex A (note)]

#### Scenario: the documentation carries the admission

- GIVEN the user-facing documentation
- WHEN it is read
- THEN it states that creating a record may trigger automations the app cannot see

#### Scenario: the confirmation shows what was stored, not what was sent

- GIVEN a record whose automations altered a value
- WHEN the confirmation is displayed
- THEN the altered value is what is shown, because it is what the read-back returned

---

### Requirement: updates-are-merges

A correction or a retry SHALL send only what changed, so that fields not sent are preserved and a failed attachment can be retried without touching the record.
[Origen: Funcional Â§4.7 FR-SND-008; ADR-004; Annex A (updates are merges); PDR Â§9.1]

#### Scenario: a correction leaves the rest untouched

- GIVEN a sent record and a correction to one field
- WHEN the update is sent
- THEN every other mapped value is unchanged in the read-back

#### Scenario: retrying an attachment changes nothing but the attachment

- GIVEN a successful create with a failed attachment
- WHEN the attachment is retried
- THEN no other field of the record changes

---

## Out of Scope

- **What a destination is and what its fields may be.** `destinations-mapping` owns the
  tuple, identifier storage, choice fields, formula and read-only fields, the per-field
  absent setting and `never-write-an-unmapped-field`, together with Annex A's
  mapping-facing rows: names versus identifiers, choice fields, formula and read-only
  fields.
- **The values being written and whether they may be trusted.** `validation-confidence`
  decides what may be shown as confirmed and `extraction-pipeline` produces the values
  and their provenance. This capability writes what it is given.
- **The states the send drives.** `document-history` defines `queued`, `sending`,
  `uncertain`, `sent` and `failed`. This capability transitions them; it does not define
  them, and the record identifier it receives from the create is what history stores.
- **Which documents exist to be sent, and their local retention.** `document-history`
  owns retention once a send is confirmed.
- **The formula-field contrast.** `destinations-mapping` owns it and consumes the
  read-back this capability performs; `GAP-009` records its blind spot there.
- **A maximum upload size.** Still open as **GAP-004** along with multi-page behaviour
  near it and real upload timings from the primary market. No threshold is stated here,
  because the functional states none and inventing one would assert something untested.

---

## Cross-Capability References

- `destinations-mapping` â€” resolves the destination this capability sends to and owns
  Annex A's mapping-facing rows. The split of Annex A between the two capabilities is
  recorded in `openspec/project.md` Â§3.1.
- `validation-confidence` â€” decides which values may be written and what absent means at
  the destination; this capability transports the decision.
- `extraction-pipeline` â€” produces the values and the provenance, and fixes stages 5 to 7
  of the pipeline order that this capability performs.
- `document-history` â€” defines the state machine this capability drives, and stores the
  record identifier the create returns.
- `capture-intake` â€” produces the file this capability attaches, and owns byte integrity,
  which is why an attachment can be retried without re-deriving it.
- `product-invariants` â€” owns BR-16, never touch schema or records the app did not
  create, which bounds the reconciliation to the app's own recently created records, and
  BR-21's prohibition on a blind retry.

---

## Open Questions

- **GAP-004** â€” Annex A's still-open upload points: the maximum file size, a multi-page
  PDF near that limit, a choice field written with text matching none of its options, and
  real upload timings from the primary market rather than from a cloud container. This
  capability contains what it can â€” the attachment is retried alone, and a created record
  with a failed attachment is never treated as done â€” and states no threshold it cannot
  test.
- **GAP-005** â€” a choice field written with text outside its options. Contained by
  `destinations-mapping` offering only existing options; the residual case is open.
- **GAP-008** â€” the deep link is not a published vendor contract, which is exactly why
  `deep-link-back-to-the-record` requires degradation to opening the database rather than
  an error.
- **GAP-009** â€” the formula-field contrast's blind spot. Neither the read-back nor the
  reconciliation window closes it: it does not catch a total misread and then used to
  derive its own components, because the formula reproduces the error.
- **A note on why the matrix is a matrix.** The eleven conditions have different correct
  answers and the intuitive answer is wrong for several of them: a 500 is a mapping error
  rather than an outage; a lost create must not be retried; a 401 makes sleeping
  pointless. Stating them as a table rather than as principles is deliberate, because the
  moment of failure is the worst moment to classify a failure mode.
