# Proposal — capture-intake

## Why

Intake is where a document is either preserved or silently damaged, and the damage
is invisible. A ZUGFeRD or Factur-X invoice is a PDF with a legally authoritative
XML embedded as an attachment, and that XML is the single highest-quality input the
product has: reading it is deterministic, every field arrives with provenance
`from_xml`, and no recognition is involved. **Re-saving that PDF destroys the
embedded XML.** The pipeline would then fall back to text extraction or OCR, get a
worse result, and report nothing wrong — the app would look like it had simply read
the document less well.

The functional states the rule that prevents it (FR-CAP-005, BR-17, ADR-007,
ADR-015) and the 16-document test's operating rules repeat it: a PDF/A-3 is never
opened by anything capable of writing it back. That is a requirement about what the
app must **not** do to a file it did not create, and it is the sort of requirement
that disappears the first time someone adds a convenience re-save "to normalise the
format".

There is a second half. The original prototype did its own perspective correction
and binarisation, and the functional explicitly does not port it: camera capture
goes through the platform's document scanner (ADR-006). A removed pre-processing
stage comes back easily, because it looks like an improvement.

## What Changes

- Add one capability spec, `capture-intake`, with **9 requirements**: FR-CAP-001…009.
  FR-CAP-005 carries BR-17, which is the same rule — the business-rule ownership map
  in `project.md` §3.4 already records them as one.
- States the boundary for the one rule the functional states twice: this capability
  owns the **intake mechanism** for a mail container, while the prohibition on
  reading a message body is `product-invariants`' `never-read-message-body`. The
  split is now a row in `project.md` §3.3 rather than something the second spec
  writer has to guess.
- **No behaviour changes.** Every requirement traces to FR-CAP or BR-17.

## Capabilities

### New Capabilities

- `capture-intake`: one entry point reached by four paths, the platform document
  scanner for camera capture, multi-page handling, byte-integrity of a received
  file, mail containers, the attachment selection rule, the iOS share hand-off, and
  capture without connectivity.

### Modified Capabilities

- None. No approved specification's requirements change.

## Impact

- `openspec/specs/capture-intake/spec.md` — new.
- No application code, dependency, schema or API is touched by this proposal.
- `extraction-pipeline` consumes what this capability hands over, and must not
  assume a format it has not checked. `document-history` owns the queued state that
  `capture-intake` requires for an offline save.

---

## Spec type

Lite. The behaviour is short and concrete, and its failure mode is not a silent
wrong value but a lost input quality — loud in the acceptance test, which compares
the SHA-256 of the attachment against the input before and after extraction. It is
not a Full spec for the same reason it is the first capability in the order: it is
mechanism, not contract.

## Problem statement

Four ways in, one pipeline out. The app must know precisely what it received —
a capture it built itself, or a file it was handed and must not touch — because the
difference decides whether the app is allowed to modify the bytes at all. Getting
that distinction wrong is not a formatting problem: it silently downgrades an
e-invoice from a deterministic read to a recognition estimate, and the record then
looks merely imprecise instead of wrong.

The same distinction governs multi-page handling, the mail containers that arrive
with a document plus the sender's signature image, and the iOS Share Extension,
which cannot run recognition inside its memory ceiling and must hand the document
to the app.

## Scope

### In scope

| Group | What it covers |
| --- | --- |
| One entry point, four paths (FR-CAP-001) | System document scanner, gallery or file picker, share-in from another app, and a mail attachment shared as `.msg` or `.eml`. All four deliver into the same pipeline and the same review screen |
| Camera capture (FR-CAP-002, FR-CAP-004) | The platform document scanner — ML Kit Document Scanner on Android, VisionKit document camera on iOS — and never a raw camera view. The prototype's pre-processing is not ported |
| Multi-page (FR-CAP-003) | Several pages are one expense: one record, one multi-page attachment, every page read before consolidation |
| Byte integrity (FR-CAP-005, BR-17) | A file the app did not generate is attached exactly as received. No re-save, re-render, flatten or re-compress, and opening a file for extraction is read-only by construction |
| Mail containers (FR-CAP-006, FR-CAP-007) | Only attachments are ingested. A container with a document plus a signature image selects the document silently; two plausible candidates are offered to the user |
| iOS share hand-off (FR-CAP-008) | The Share Extension hands the document to the app, which opens directly into review. Android uses a share-intent filter and needs no separate component |
| Offline capture (FR-CAP-009) | Capture and extraction work with no connectivity, and an offline save queues the send instead of failing it |

### Out of scope

- **Reading the document.** For camera captures this capability produces a PDF and
  stops. What happens to it — the route priority, the consensus rule, the
  provenance tags — is `extraction-pipeline`.
- **The prohibition on reading a message body.** That invariant is
  `product-invariants`' `never-read-message-body`. This capability owns what a
  container ingests and how a candidate is chosen, and references the invariant
  rather than restating it.
- **The queued state itself.** FR-CAP-009 requires that an offline save queues
  rather than fails; the document state machine and the queued state belong to
  `document-history`.
- **The retry and reconciliation of a queued send.** `ninox-send` owns that.
- **Deciding where the record goes.** `destinations-mapping` owns the destination.

## Source documents

- `docs/Fase 2. Define/Paperdrop_Funcional_v1.0_EN.md` §4.1 (FR-CAP-001…009),
  §5 BR-17, §1.2 (the message-body non-goal), §2.4 contract line 8.
- `docs/Fase 1. Discover/Paperdrop_PDR_v0.2_EN.md` §3.1 (inputs), §3.2 (non-goals),
  §5.3 (multi-page), §7.1 (capture).
- `docs/Fase 1. Discover/Paperdrop_ADR_v0.2_EN.md` — ADR-001 (one Flutter codebase,
  native Share Extension), ADR-002 (no backend, offline capture), ADR-006 (the
  platform scanner), ADR-007 and ADR-015 (a file attaches to the record, byte
  integrity), ADR-014 (route priority, which is *why* byte integrity matters).
- `REPORT-CORPUS.md` and the 16-document test: the container that carried a
  document plus a signature image is where the selection rule came from.

## Key design constraints

1. **The distinction between captured and received is load-bearing.** Only a
   document the app generated may be assembled; a document it received is never
   written to. Every requirement here follows from that one distinction, and the
   acceptance test for it is a hash comparison, not an inspection.
2. **Extraction must be read-only by construction, not by discipline.** Reading a
   text layer, extracting an embedded XML or rendering a page for OCR are all
   read-only operations, and the requirement says so explicitly. A pipeline that
   "opens and saves" a PDF/A-3 has already lost the e-invoice route, and nothing
   downstream will report it.
3. **A removed pre-processing stage must stay removed.** The prototype's own
   perspective correction and binarisation are not ported (ADR-006). The spec says
   this as a requirement, because "improving" the scanner output is the natural
   next instinct and it reintroduces a whole class of failure the platform scanner
   already solves.
4. **The iOS extension is budgeted, not discovered.** ADR-001 records that the
   Share Extension cannot run recognition or render review inside its memory
   ceiling. The requirement states the hand-off; the cost of the native work is a
   FASE 3 estimate and is already tracked as GAP-007.
5. **The selection rule must be able to say "ask".** FR-CAP-007 prefers the
   document silently when the choice is obvious and offers the list when it is not.
   A rule that always picks something is worse than one that admits ambiguity —
   the same principle as the confidence model.
6. **No invented content.** Where the functional fixes a threshold or names a
   platform component, it is reproduced. Where it does not — for instance the exact
   dimensions or filename patterns that identify a signature image — that is
   recorded as an `Open Question` rather than invented.

## Open questions at proposal stage

- **None blocking.** Two entries in `openspec/gaps-register.md` bear on this
  capability:
  - **GAP-007** (iOS Share Extension native work) — its cost is a FASE 3 estimate
    and a native bridge to Vision may be required. The behaviour is specified and
    the requirement can be written; the estimate cannot.
  - **GAP-004** (attachment-upload limits, still open for maximum file size)
    touches multi-page documents near that limit, which is `ninox-send`'s
    requirement rather than this one.
- **To confirm while reviewing:** whether the selection rule's parameters — the
  dimensions and filename patterns that identify a signature image — belong in this
  spec or in the dictionary annex. The functional names the pattern ("signature
  scale", `image001.png`) without fixing numbers. This proposal reads it as a
  requirement with the observable outcome stated and the parameters left to the
  implementation, unless the product owner wants the numbers written down.
