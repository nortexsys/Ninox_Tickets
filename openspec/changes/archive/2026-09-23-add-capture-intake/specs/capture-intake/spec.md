# Capture and Intake Specification

## Purpose

Four ways in, one pipeline out — and the pipeline has to know precisely what it
received, because the answer decides whether the app is allowed to touch the bytes
at all.

A document the app captured with the camera is the app's own product: it may crop
it, deskew it and assemble it into a PDF. A document it was handed — a PDF shared
from another app, a structured e-invoice, an attachment pulled from a mail
container — is somebody else's file, and the app may read it but never write it.
That distinction is load-bearing rather than tidy. A ZUGFeRD or Factur-X invoice is
a PDF with a legally authoritative XML embedded as an attachment, and re-saving that
PDF destroys the XML. The pipeline would then fall back to text extraction or OCR,
produce a worse result, and report nothing wrong: the record would look merely
imprecise instead of downgraded. The acceptance condition for this capability is
therefore a hash comparison, not an inspection.

The second thing this capability owns is a **removal**. The prototype ran its own
perspective correction and binarisation; ADR-006 replaces that with the platform's
document scanner and the functional does not port the prototype's stage. A deleted
pre-processing step returns by itself, because it looks like an improvement.

---

## ADDED Requirements

---

### Requirement: one-entry-point-four-paths

The app SHALL offer exactly one capture entry point, reached by four paths: the
system document scanner, the device gallery or file picker, share-in from another
application, and a mail attachment shared as `.msg` or `.eml`. All four SHALL
deliver into the same pipeline.
[Origen: Funcional §4.1 FR-CAP-001; PDR §3.1, §7.1]

#### Scenario: every path lands on the same screen

- GIVEN a document arriving by each of the four paths in turn
- WHEN it reaches review
- THEN the field set presented is identical in all four cases
- AND the available actions are identical in all four cases

---

### Requirement: platform-document-scanner

Camera capture SHALL use the platform's document scanner — ML Kit Document Scanner
on Android, VisionKit document camera on iOS — and SHALL never present a raw camera
view. Edge detection, perspective correction, contrast enhancement and multi-page
chaining SHALL come from the platform, and the prototype's pre-processing stage
SHALL NOT be ported.
[Origen: Funcional §4.1 FR-CAP-002; PDR §7.1; ADR-006]

#### Scenario: the platform crops and deskews the capture

- GIVEN a photographed receipt
- WHEN the capture reaches extraction
- THEN it has been cropped and deskewed by the platform scanner

#### Scenario: the app carries no pre-processing of its own

- GIVEN the application's own code
- WHEN it is inspected for image processing
- THEN it contains no perspective-correction and no binarisation routine
- AND no stage re-enhances an image the platform scanner already produced

---

### Requirement: multi-page-is-one-expense

Several captured or shared pages SHALL produce one record with one multi-page
attachment, and extraction SHALL read every page before consolidating into a single
canonical model.
[Origen: Funcional §4.1 FR-CAP-003; PDR §7.1, §5.3]

#### Scenario: a two-page receipt is one record

- GIVEN a receipt captured as two pages
- WHEN it is saved
- THEN exactly one record is created
- AND exactly one attachment is created, containing both pages in order
- AND a field read from either page appears in the same review screen

---

### Requirement: camera-captures-are-assembled

A document produced by the device's own camera capture SHALL be assembled into a
single PDF — cropped, deskewed and enhanced by the platform scanner — and that
assembled PDF SHALL be what is attached.
[Origen: Funcional §4.1 FR-CAP-004; PDR §7.1; ADR-007; Funcional §2.4 contract line 8]

#### Scenario: one captured page becomes a PDF

- GIVEN a camera capture of a single page
- WHEN it is saved
- THEN the attachment is a PDF

#### Scenario: several captured pages become one PDF

- GIVEN a camera capture of several pages
- WHEN it is saved
- THEN the attachment is a single PDF containing every page in capture order

---

### Requirement: received-files-are-attached-byte-for-byte

A document that arrives already as a file SHALL be attached exactly as received,
byte for byte, and the app SHALL never re-save, re-render, flatten or re-compress
it. Opening a file for extraction — reading a text layer, extracting an embedded
XML, rendering a page for OCR — SHALL be read-only by construction.
[Origen: Funcional §4.1 FR-CAP-005; Funcional §5 BR-17; ADR-007, ADR-015; Funcional §2.4 contract line 8; Finding 6]

#### Scenario: the attachment is the input

- GIVEN a PDF shared from another application
- WHEN the record is sent
- THEN the SHA-256 of the attached file equals the SHA-256 of the input
- AND the equality holds both before and after extraction has run

#### Scenario: an embedded e-invoice XML survives

- GIVEN a ZUGFeRD or Factur-X PDF whose XML is embedded as an attachment
- WHEN the document is processed and attached
- THEN the embedded XML is still present in the attached file
- AND it can still be extracted from it

#### Scenario: reading never writes

- GIVEN a stage that opens a received file to read a text layer, extract an embedded XML or render a page
- WHEN that stage completes
- THEN the file on disk is unmodified
- AND no temporary re-save of the original has replaced it

---

### Requirement: mail-containers-ingest-attachments-only

Sharing a `.msg` or `.eml` item SHALL ingest only its attachments, and a container
that carries no document attachment SHALL produce no record.
[Origen: Funcional §4.1 FR-CAP-006; PDR §3.2, §7.1]

#### Scenario: a container with a document produces a record

- GIVEN a mail container holding a message body and one document attachment
- WHEN it is captured
- THEN the record is created from the attachment
- AND no extracted value, history entry or attached file carries any part of the container other than the attachment

#### Scenario: a container with no document attachment produces nothing

- GIVEN a mail container carrying no attachment
- WHEN it is captured
- THEN no record is created
- AND the user is told, rather than left with an empty review screen

---

### Requirement: attachment-selection-rule

Where a mail container carries more than one attachment, the app SHALL select the
document, preferring the largest PDF or image by content and excluding
signature-scale images and their typical filenames. Where more than one plausible
candidate remains, the app SHALL offer the list and let the user choose.
[Origen: Funcional §4.1 FR-CAP-007; PDR §7.1; 16-document test]

#### Scenario: an invoice and a signature image

- GIVEN a container holding an invoice-scale PDF and a signature-scale PNG
- WHEN it is captured
- THEN the PDF is selected
- AND the user is not asked, because the choice was not ambiguous

#### Scenario: two plausible candidates

- GIVEN a container holding two invoice-scale PDFs
- WHEN it is captured
- THEN the app offers the list of candidates
- AND no candidate is selected on the user's behalf

#### Scenario: the signature image is never treated as a document

- GIVEN a container whose only non-signature attachment is the document
- WHEN the selection runs
- THEN a signature-scale image is never the selected candidate
- AND its typical filename does not make it a candidate at all

---

### Requirement: ios-share-hands-the-document-to-the-app

On iOS the Share Extension SHALL hand the document to the application and the app
SHALL open directly into review, while the extension SHALL not run recognition and
SHALL not render the review screen. Android intake SHALL use a share-intent filter
and needs no separate component.
[Origen: Funcional §4.1 FR-CAP-008; ADR-001]

#### Scenario: sharing on iOS lands on review

- GIVEN a document shared from the platform's mail client on iOS
- WHEN the share completes
- THEN the app opens on the review screen
- AND no intermediate view was rendered inside the extension

#### Scenario: the extension stays inside its memory ceiling

- GIVEN the Share Extension running on iOS
- WHEN it hands the document over
- THEN it has run no recognition
- AND its memory use has stayed within the platform's ceiling

---

### Requirement: capture-without-connectivity

Capture and extraction SHALL work with no connectivity, and a save performed
offline SHALL queue the send rather than fail it.
[Origen: Funcional §4.1 FR-CAP-009; PDR §3.1; ADR-002]

#### Scenario: a document is captured and saved in aeroplane mode

- GIVEN a device in aeroplane mode
- WHEN a document is captured
- THEN it is captured, extracted, reviewed and saved
- AND the save does not fail

#### Scenario: the offline save is queued, not lost

- GIVEN a document saved while offline
- WHEN the history is inspected before connectivity returns
- THEN its entry reads as queued
- AND the send happens once connectivity returns, without the user re-entering the document

---

## Out of Scope

- **Reading the document.** For a camera capture this capability produces a PDF and
  stops. The route priority, the consensus rule, the derivation threshold and the
  provenance tags are `extraction-pipeline`.
- **The prohibition on reading a message body.** That invariant is
  `product-invariants`' `never-read-message-body`, traceable to the §1.2 negative
  list. This capability owns only what a container ingests and how a candidate is
  chosen, and it references that invariant rather than restating it.
- **The queued state itself.** FR-CAP-009 requires that an offline save queues
  rather than fails; the document state machine and the definition of the queued
  state belong to `document-history`.
- **The send, its retry matrix and its reconciliation.** `ninox-send` owns them,
  including the still-open maximum upload size (GAP-004), which is what a
  multi-page attachment near that limit runs into.
- **Where the record is written.** `destinations-mapping` owns the destination and
  the mapping.
- **The exact parameters that identify a signature image.** The requirement states
  the observable outcome — a signature-scale image is never the selected candidate
  — and deliberately does not fix dimensions or filename patterns: the functional
  names the pattern without numbers, and inventing numbers here would make the spec
  assert something its source does not.
- **The cost of the iOS native work.** ADR-001 budgets it; its estimate is a FASE 3
  matter and is tracked as GAP-007.

---

## Cross-Capability References

- `product-invariants` — owns `never-read-message-body`, the prohibition this
  capability's `mail-containers-ingest-attachments-only` implements on the intake
  side, and `no-backend-and-no-account`, which is why capture must work offline.
- `extraction-pipeline` — consumes the PDF or file this capability hands over and
  owns everything that happens to it afterwards, including the route priority that
  makes byte integrity matter (FR-EXT-002).
- `document-history` — owns the document state machine, and therefore the queued
  state that `capture-without-connectivity` requires.
- `ninox-send` — owns the send pipeline, the retry matrix and the reconciliation of
  an uncertain create, which is where a queued document eventually lands.
- `destinations-mapping` — owns the destination the user picks.
- `local-config-privacy` — owns the permission surfaces the capture path depends on
  (camera, storage) as far as their user-facing behaviour goes.

---

## Open Questions

- **None blocking.** Two open entries in `openspec/gaps-register.md` bear on this
  capability:
  - **GAP-007** — the iOS Share Extension's native work is budgeted rather than
    discovered, and its cost is a FASE 3 estimate; a native bridge to Vision may be
    required. The behaviour here is specified and testable; the estimate is not this
    spec's to make.
  - **GAP-004** — the maximum attachment size is still open, which a multi-page
    document near that limit runs into. That is a `ninox-send` concern; this
    capability only requires that multi-page documents become one multi-page
    attachment.
- **Deliberately left to implementation, recorded so it is not read as an
  omission.** The parameters of the attachment selection rule — which dimensions
  and which filename patterns mark a signature image — are not fixed here. The
  functional names the pattern ("signature scale", `image001.png`) without giving
  numbers, and the 16-document test produced exactly one instance of it. Writing
  numbers would make this spec assert more than its source does, and the observable
  outcome is what the acceptance test can actually check. If the product owner
  wants the parameters fixed, they belong in this requirement rather than in a
  dictionary annex, because they are selection logic and not vocabulary.
- **A note on the container that is not a document.** The 16-document test found
  that a `.msg` from a mail client carries the document plus the sender's signature
  image as a second attachment. That single observation is the origin of
  `attachment-selection-rule`, and it is one document rather than a pattern: the
  rule is written to prefer the larger document and to ask when it cannot tell,
  which degrades safely if a second case behaves differently.
