# Proposal — ninox-send

## Why

A create whose response is lost in a timeout is the single most expensive failure the
product can have. The record may exist or it may not, the app cannot tell, and the
obvious instinct — retry — is exactly what writes a duplicate into the user's
accounting. That is the failure the functional records as Finding 1, and it is why this
capability is a Full spec: the answer is not a retry policy but a reconciliation, and the
app must also be willing to ask the user when the evidence is genuinely ambiguous.

The same test sharpened a second trap. An HTTP 500 from this API does not mean the
server is unwell: it is what an invalid or read-only field name returns. So a client that
treats 500 as an outage and retries forever will hammer the API over its own mapping
mistake, and never tell the user. The retry matrix exists to make that impossible, and it
is stated as a matrix rather than as guidance precisely because eleven conditions with
eleven different right answers cannot be left to judgement at the moment of failure.

Third, the record must be **read back** and the read-back is what the user is shown.
Fields carrying formulas or defaults silently override submitted values and the create
response does not reveal it, so showing the user what was sent would be showing them
something the app cannot vouch for.

## What Changes

- Add one capability spec, `ninox-send`, with **8 requirements**: FR-SND-001…008. BR-18,
  BR-21 and BR-22 are carried by FR-SND-001, FR-SND-005 and FR-SND-002 respectively.
- Owns **Annex A's write-path rows**: payload shape, create response, merges, dates,
  error shape, retry policy, read-after-create and attachment upload. The mapping-facing
  rows belong to `destinations-mapping` per `project.md` §3.1.
- **No behaviour changes.** Every requirement traces to FR-SND.

## Capabilities

### New Capabilities

- `ninox-send`: the three-step send, the payload shape, the attachment upload, the eleven
  conditions of the retry matrix, the reconciliation of an uncertain create, the deep
  link back to the record, the visibility that creating a record may trigger automations,
  and merge semantics for corrections and retries.

### Modified Capabilities

- None. No approved specification's requirements change.

## Impact

- `openspec/specs/ninox-send/spec.md` — new.
- No application code, dependency, schema or API is touched by this proposal.
- Consumes the destination `destinations-mapping` resolves and the values
  `validation-confidence` settled. Drives the state machine `document-history` defines.
  Performs stages 5 to 7 of the pipeline order `extraction-pipeline` fixes.

---

## Spec type

**Full.** Three reasons. The failure is **irreversible**: a duplicate record in a real
ERP is not something the app can undo, and it is indistinguishable from a legitimate
second expense. The conditions are **many and each has a different right answer** —
eleven rows in the matrix, where the intuitive answer is wrong for at least four of
them. And the semantics are **counter-intuitive by design**: a 500 is a mapping error
rather than an outage, and the only thing the app may show the user is what it read
back rather than what it sent.

## Problem statement

Writing a record into someone else's business system, over a network, with no
transaction and no backend of its own, means every failure has to be classified before
it is acted on. Some are safe to retry, one is never safe to retry, one requires the
record to be re-derived rather than re-attempted, and several require the user. The app
must also be honest that creating a record may trigger automations inside the user's
database that it cannot see.

## Scope

### In scope

| Group | What it covers |
| --- | --- |
| The three steps (FR-SND-001, BR-18) | Create the record, attach the document, read the record back. The read-back is what the user is shown, because formulas and defaults override submitted values and the create response does not reveal it |
| Payload (FR-SND-002, BR-22) | A nested object under a `fields` key, keyed by field **name**; dates as `YYYY-MM-DD` stored verbatim; amounts as integers in the minor unit and rates in basis points. The attachment is never a mapping target |
| Attachment (FR-SND-003) | A single multipart call to the record's files endpoint returning HTTP 200, and the ability to read the attachment back with its name, size and content type |
| Retry matrix (FR-SND-004) | Eleven conditions with a stated behaviour each: no connectivity queues; a lost create response is `uncertain` and is never blindly retried; attachment or read-back timeouts take bounded exponential backoff; 401/403 re-enters the token with no retry; 404 sends the user to the destination with no retry; 500 refreshes the schema once, retries once, then reports a mapping error; a created record with a failed attachment retries the attachment only |
| Reconciliation (FR-SND-005, BR-21) | Read the destination table's most recent records using `createdAt` and `createdBy`, which exist regardless of mapping, and match against the mapped fields within a short window. Exactly one match adopts it; no match creates the record; ambiguity asks the user, and the app never guesses |
| Deep link (FR-SND-006) | Built entirely from data already held — team, database and table from the destination, record identifier from the create response — with no extra call and no credentials, degrading to opening the database if the URL shape changes |
| Automations (FR-SND-007) | Creating a record may trigger automations the API does not expose; the read-back is the only visibility and the user-facing documentation says so |
| Merges (FR-SND-008) | A correction or a retry sends only what changed; fields not sent are preserved, so a failed attachment retries without touching the record and a correction does not wipe unrelated fields |

### Out of scope

- **What a destination is and what its fields may be.** `destinations-mapping` owns the
  tuple, identifier storage, choice fields, formula and read-only fields, the per-field
  absent setting and the prohibition on writing an unmapped field, together with Annex
  A's mapping-facing rows.
- **The values being written and whether they may be trusted.**
  `validation-confidence` and `extraction-pipeline` own those.
- **The states the send drives.** `document-history` defines `queued`, `sending`,
  `uncertain`, `sent` and `failed`. This capability transitions them and does not
  define them.
- **Which documents exist to be sent, and their local retention.**
  `document-history` owns retention, and `capture-intake` owns intake.
- **Talking to the user about a mismatch between a formula field and the extracted
  total.** `destinations-mapping` owns that contrast; this capability performs the
  read-back it consumes.

## Source documents

- `docs/Fase 2. Define/Paperdrop_Funcional_v1.0_EN.md` §4.7 (FR-SND-001…008), §5
  BR-18, BR-21, BR-22, §9 (error handling, the retry matrix and the semantics of 500),
  **Annex A** (the write-path rows), §2.4 contract line 6.
- `docs/Fase 1. Discover/Paperdrop_PDR_v0.2_EN.md` §9 (the send), §9.1 (retry and
  reconciliation), §9.2 (the deep link).
- `docs/Fase 1. Discover/Paperdrop_ADR_v0.2_EN.md` — ADR-003 (the client behind a port),
  ADR-004 (the verified contract and its still-open points), ADR-008 (the deep link),
  ADR-013 (reconciliation of an uncertain create).
- The 16-document test: sixteen real uploads returning 200, and the disposable-record
  verification of the files endpoint.

## Key design constraints

1. **A lost create is never retried blindly.** It is reconciled, and if the evidence is
   ambiguous the user is asked. The one outcome that must be impossible is two records
   where the user expected one.
2. **A 500 is a mapping error, not an outage.** It is what an invalid or read-only field
   name returns. Refresh the schema once, retry once, then tell the user about the
   mapping. Retrying it forever is the failure mode.
3. **The read-back is the truth shown to the user, not the submitted payload.** Formulas
   and defaults silently override what was sent, and the create response does not say so.
4. **The retry matrix is a matrix because the answer differs per condition.** Sleep
   before a 401 is pointless; a retry after a lost create is dangerous; a retry after an
   attachment timeout is safe because it cannot duplicate a record.
5. **Merge semantics make retry possible at all.** Because fields not sent are
   preserved, a failed attachment can be retried and a correction can be partial. Without
   it, every retry would risk wiping values the user had already accepted.
6. **The app cannot see automations and says so.** The read-back is the only visibility,
   and the documentation carries the admission rather than leaving the user to discover
   it.
7. **No invented content.** Annex A records still-open points — the maximum file size, a
   multi-page PDF near that limit, a choice field written with text matching no option,
   and real upload timings from the primary market. The spec records them as open and
   resolves none of them.

## Open questions at proposal stage

- **None blocking, four bearing on the capability.** **GAP-004** — Annex A's still-open
  upload points: maximum file size, multi-page PDF behaviour near that limit, a choice
  field outside its options, and real upload timings from the primary market rather than
  from a cloud container. **GAP-005** — the choice-field case, contained by
  `destinations-mapping` offering only existing options. **GAP-008** — the deep link is
  not a published vendor contract, which is why FR-SND-006 degrades rather than fails.
  **GAP-009** — the formula contrast's blind spot, which the reconciliation window and
  the read-back do not close either.
- **To confirm while reviewing:** whether the maximum file size should be stated as a
  requirement with a placeholder threshold or left entirely to `destination-mapping`'s
  per-field concerns. This proposal leaves it open, because the functional leaves it open
  and inventing a limit would make the spec assert something untested — the same reason
  the photo route's accuracy threshold is not stated in `extraction-pipeline`.
