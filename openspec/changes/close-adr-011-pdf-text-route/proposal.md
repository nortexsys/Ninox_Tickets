# Change: close-adr-011-pdf-text-route

## Why

ADR-011 is the last decision that blocks a requirement the MVP cut has already committed to, and
it is the one decision in the plan that cannot be taken by reading. `positional-pdf-text-extraction`
(FR-EXT-004) fixes the behaviour — a label binds the value nearest it in the document's **visual
layout**, never the nearest in extraction order — and ADR-011's closure criterion is that a library
is confirmed against that rule over the sample-invoice corpus, with a size check. Until that
confirmation exists, the requirement carries the note *Acceptance is blocked by ADR-011*,
`application-size` (NFR-SIZ-001) carries *the measurement cannot be made until a library is chosen*,
and GAP-002 stays `ABIERTO` and `BLOQUEANTE`. Everything the invoice route needs is written except
the thing that reads the page.

The reason it is a decision and not a lookup is that the two candidates do not merely differ in
ergonomics. The product owner fixed them on 2026-09-25 (D-5): **PdfBox-Android**, the ADR's own
proposal, Apache-2.0, a JVM library ported to Android that exposes word boxes; and a **PDFium-based
Flutter package (`pdfrx`)**, which wraps the engine Chrome renders PDFs with and would give one
implementation for Android and iOS — the only candidate with a path to R2 that is not a second
library. They differ in what a *word* is (a glyph run the library segments, versus a text object
PDFium emits), in how much of the binary ships, and in what the engine guarantees about a document
that carries an embedded XML. None of that is settled by reading either package's documentation; it
is settled by running both over the same corpus and comparing what comes out — which is why plan
v0.2 puts a date and a decision on this change, **Tue 6 Oct**, rather than just a task.

The failure this exists to prevent is named in the requirement, and it is the reason the criterion
was promoted from a nice-to-have to a hard condition in ADR v0.2. On document PRO1013-26 of the
16-document test, plain-text extraction put a label and its value on decoupled lines, and the
parser's last-resort fallback picked up an unrelated number — a commercial-register volume
reference, `Tomo 8.741` — instead of the total. A library that returns only a string of text, no
matter how correct that string is, reproduces that failure by construction, because the distance it
can measure is a distance in a buffer and not on the page. Both candidates here return coordinates,
so both can in principle satisfy the rule; which one actually does, on this corpus, is what the
evaluation measures.

One thing this change does **not** do is close the ADR in the ADR document. `docs/` is read-only for
the team (`AGENTS.md` §1.6); ADR-011's status line moves from *Proposed* to *Accepted* (or the
record is re-proposed) when the product owner writes it, on the evidence this change produces.

## What Changes

An **implementation-only change** (`skip_specs: true`, plan §8.2). No requirement is added,
modified, removed or renamed, and no living spec is touched. All code goes in `app/`, in the Mobile
lane's adapter folders, plus the evaluation harness and the numbers it reports.

* **The evaluation, before any adapter is kept** (plan §9 M1, T1.15; ADR-011's closure criterion;
  D-5). Both candidates built and run over the PDF half of the private corpus
  (`Paperdrop_corpus/inbox/`, prepared 2026-09-30: 14 files, 8 PDFs with a per-word reference
  extraction already produced with pdfplumber and one of them two pages). For each candidate, on
  every page: whether word-level coordinates are exposed at all, whether the word segmentation
  the *library* performs covers the label and the value as a reader would group them, and whether
  the label–value association rule of `positional-pdf-text-extraction` then binds the six expected
  totals the product owner confirms — the one per real invoice named in the status of 2026-09-30 —
  rather than a registry volume or any other number the page prints near a total label. Alongside
  it, the size measurement: `flutter build apk --debug` with and without each dependency, the delta
  reported with the decision (NFR-SIZ-001), never assumed. Both candidates are built; neither is
  deleted until the product owner has the comparison, so the losing candidate's numbers are in the
  record and not in a memory.
* **The winner, built as the PDF positional adapter behind a port** (plan §5). The chosen library
  behind a small interface in `app/lib/adapters/pdf_text/` that returns **pages of positioned
  words** — the platform-neutral input the core's layout reasoning consumes — so that the other
  adapter of this route (OCR, T1.16), the R2 iOS adapter, and any later engine swap produce the
  same input and no rule that decides a value lives in `app/`. Extraction is **read-only**
  (ADR-015): the source file is opened for reading, nothing is re-saved, re-flattened or
  re-compressed, and the bytes `implement-android-capture-and-store` hashed stay identical —
  verified against the intake hash, not by inspection.
* **A synthetic public regression for the PRO1013-26 failure.** The corpus document itself never
  enters the repository; a synthetic PDF is generated for the test, reproducing the structure that
  failed — a label and its value on different lines, with a `Tomo n.nnn` registry volume printed
  nearer the label in extraction order — and the adapter is asserted to bind the total and not the
  volume. What ships in the repository is the synthetic file and the numbers; nothing else from the
  private corpus does.

## Requirements implemented

Identifiers as the functional spells them; the requirement name is the one that owns the behaviour
in `openspec/specs/`. Each item states the part this change satisfies.

* **FR-EXT-004** — `extraction-pipeline` · `positional-pdf-text-extraction`: the port and the
  adapter, and the evaluation the requirement's own acceptance note is waiting on. The adapter
  returns pages of positioned words, and the label–value association is verified on the corpus
  against the six expected totals. The two halves the requirement does not name are not this
  change's: the **association rule itself** — which label matches which value, in the visual
  layout — is Core's layout reasoning (T1.5), and it lives in `paperdrop_core` because a rule that
  decides a value may not live in an adapter; and the **route selection** that stops at positional
  text or falls through to OCR is T2.1's (`invoice-route-priority`, plan §4.2: the XML step is R1,
  and in the MVP a ZUGFeRD PDF still has a text layer and goes through positional text, so nothing
  built here is discarded).
* **NFR-SIZ-001** — `local-config-privacy` · `application-size`: the measurement half, which the
  requirement's own note says cannot be made until a library is chosen. The size delta each
  candidate introduces is measured and reported with the decision, both of them, before one is
  kept. The *acceptable* half is not a number this change invents: the functional states no
  threshold, `application-size` states none, and GAP-003 defers all metric thresholds to the first
  corpus screening — so the measurement is what this change delivers, and the verdict on it is the
  product owner's, taken with the decision on Tue 6 Oct.
* **NFR-LIC-001** — `local-config-privacy` · `no-agpl-component-ships` and `product-invariants` ·
  `proprietary-dependencies-declared`: the licence half of ADR-011's criterion. Both candidates are
  checked for their licence and for what the check actually catches — a PDFium binding ships a
  native binary built from the engine, and what that binary's licence covers is the thing to read,
  not the package's own licence file. No AGPL component is linked (`no-agpl-component-ships`, whose
  two scenarios name exactly this: the harness-only tool stays out of the build, and an exclusion
  is not reversed by a later convenience), the winning dependency is added to the README's
  dependency table with its licence and role, and the losing one's exclusion is recorded so it is
  not reintroduced for convenience later. PyMuPDF stays where the requirement puts it:
  test-harness only, used by the corpus's reference extraction, never linked into the app.

## Gaps and decisions this change acts on

* **GAP-002** (open, `BLOQUEANTE`) — ADR-011 proposed but not closed. The register's closure
  criterion is exactly this change's evaluation: confirmation against the positional-extraction
  criterion over the sample-invoice corpus, plus a size check. **This change does not close the
  gap in the register** — the register's own convention is that a closed entry names who closed it
  and when, and the closure date is the date of the product owner's decision, Tue 6 Oct, not the
  date the evaluation runs. The Spec lane closes the row afterwards, with the resolution carried
  into `positional-pdf-text-extraction` and `application-size` and the note *Acceptance is blocked
  by ADR-011* removed from both. Nothing here touches `openspec/gaps-register.md`.
* **D-5** (product owner, 2026-09-25, plan v0.1 §6.3, carried into v0.2): evaluate the proposal
  (PdfBox-Android) **and** a PDFium-based Flutter package, and decide on the positional criterion
  and the size check. This change evaluates both. The decision itself — which candidate, and
  whether the size delta is acceptable — is the product owner's to take, and is not recorded in
  `openspec/product-decisions.md` by this change, because the register's rule is that a decision
  that diverges from the functional is recorded when it is taken, and this change takes none.
* **D-10** not applicable — no step of this change calls Ninox. The evaluation runs on the private
  corpus on the product owner's device; there is no token, no network call and no test base in this
  change at all.
* **ADR-011 / ADR-014 / ADR-015** — the library decision this change evaluates, the route priority
  that puts positional text second, and the read-only rule that is now an explicit filter on
  candidate evaluation. ADR-014's consequence — that the chosen library must also be able to
  extract an embedded file without modifying it — is **R1**, since the XML step is R1, and is noted
  as a property to measure, not a requirement to satisfy: a candidate that cannot do it read-only
  is not thereby rejected for the MVP, but the finding goes into the decision record, because R1
  will need it.

## Deferred

Design and tasks are the orchestrator's; the boundary below is stated so the changes around this
one do not have to renegotiate it.

* **T1.5's layout reasoning** (`implement-validation-and-extraction-core`, Core lane, plan §9 M1) —
  the rule that consumes this change's output. This change produces pages of positioned words and
  asserts the binding on the corpus; the rule itself is Core's, and is written against the
  platform-neutral input this adapter and the OCR adapter both produce.
* **T1.16 — the OCR adapter** (`implement-photo-route`, plan §8.3 change 9, W2–W3): ML Kit text
  recognition behind the same kind of port, the multi-pass strategy and the ADR-010 screening. This
  change defines the shape the OCR adapter fills; it recognises nothing.
* **T2.1 — route selection and multi-page consolidation** (plan §9 M2): the wiring of
  `invoice-route-priority`, stopping at positional text and falling through to OCR when a page has
  no text layer. This change's adapter reports whether a page yielded words at all, which is what
  the fall-through needs; the decision to fall through is T2.1's.
* **R1 — the XML step** (`structured-xml-extraction`, FR-EXT-003): the embedded-file extraction of
  ADR-014, which the chosen library must additionally support read-only. Measured here as a
  property, not implemented.
* **R2 — iOS**: `pdfrx` would give one implementation for both platforms if it wins. If PdfBox-Android
  wins, the iOS adapter is PDFKit (ADR-011's own proposal) and is R2's, on a port this change
  defines — which is the point of putting the adapter behind an interface now rather than after R2.
* **The acceptance thresholds** — GAP-003 defers every metric threshold to the first corpus
  screening. No threshold for the positional criterion or for the size delta is stated by this
  change, and none is invented to make a comparison easier: the numbers are reported, the product
  owner decides.

## Impact

`app/` only — the adapter interface and the chosen implementation in `app/lib/adapters/pdf_text/`,
the evaluation harness (a device integration run over the private corpus, not a CI test), and the
synthetic public regression test. `packages/` change: this change consumes `paperdrop_core`'s
positioned-word types if T1.5 has published them, and otherwise defines them locally and hands them
to Core — the orchestrator decides which, since T1.15 and T1.5 are concurrent lanes (plan §7.2's
shared-contract rule). `README.md` gains one row in the dependency table with the winner's licence
and role; the runner-up is recorded as evaluated and excluded, so the table is never behind the
decision. No living spec changes; no functional change; no new decision is taken, so nothing is
recorded in `openspec/product-decisions.md`. `openspec validate close-adr-011-pdf-text-route
--strict` passes with zero deltas.

**The private corpus never enters the repository.** The evaluation reads
`Paperdrop_corpus/inbox/`, which is outside the tree by design (`AGENTS.md` §2.1, the corpus
convention), and what comes back into the repository is **numbers**: per-page word counts,
per-candidate binding results against the six expected totals, the measured size deltas, and the
synthetic regression PDF. No document content, no supplier name, no tax identifier, no printed
value from a real invoice is reproduced — the six totals themselves are confirmed by the product
owner and stay in the private corpus's ground truth, not here. The CI privacy job enforces this
rather than hoping for it.

**Two things this change does not do, stated plainly.** Closing ADR-011 **in the ADR document** —
moving its status from *Proposed* to *Accepted*, or re-proposing it — is the product owner's:
documents in `docs/` are read-only for the team (`AGENTS.md` §1.6), and a divergence is recorded in
`openspec/product-decisions.md` rather than applied by editing the source. And GAP-002's row in the
register is **not changed** by this change: it is closed after the decision, by the Spec lane, with
the resolution dated Tue 6 Oct and carried into the two living specs. No step of this change uses
the environment variable that points at a production database (`AGENTS.md` §1.4) — nothing in it
reaches Ninox at all.
