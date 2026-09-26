# Paperdrop for Ninox — MVP definition and delivery plan

**Version:** 0.1 — draft for product-owner review
**Date:** 2026-09-24
**Phase:** FASE 2, planning step ("features, tasks, milestones, delivery dates and test design", `AGENTS.md` §3)
**Status:** Proposal. Nothing in this document changes behaviour. Where the plan needs a behaviour to change, it names the gap or decision that would carry it, per `openspec/AGENTS.md` §6 and `openspec/product-decisions.md`.

**Inputs read for this plan (all in this session):** `docs/handoff.md`, `AGENTS.md`, `openspec/project.md`, `openspec/AGENTS.md`, `openspec/gaps-register.md`, `openspec/product-decisions.md`, the 12 specs in `openspec/specs/`, Funcional v1.0 (§1–§4, §6.1, §10–§12, Annex A), ADR v0.2 (ADR-001…004, ADR-010, ADR-011, §3), `corpus_test/REPORT_after_review.md`, and the project's own Ninox skill (`C:\Users\admin\proyectos\ninox-agent-skill`).

---

## 0. Summary

1. **The MVP is one honest end-to-end loop on Android:** configure a destination from lists (never typing a table or field name), capture a paper receipt or share a PDF invoice, read it on the device, validate it with the deterministic layer, review it, and write one record with the original attached — then read it back.
2. **Everything built for the MVP is v1 code.** The MVP is a *release cut* of the approved specifications, not a prototype. No requirement is re-specified for the MVP; requirements are either in the cut, partly in it (with the missing part named), or deferred to R1/R2 unchanged.
3. **Two open architecture decisions sit on the MVP's critical path** — ADR-011 (PDF text library) and ADR-010 (photo recognition engine). The plan closes ADR-011 inside the MVP and runs ADR-010's screening inside the MVP, both with the application's own pipeline, so the measurement harness is the product and not a throwaway.
4. **A new blocking gap was found while planning (proposed GAP-022).** The specs require the mapping step to exclude fields "the schema marks as formula or read-only". The project's own Ninox skill measured a whole subscription — 566 tables, 8,048 fields — and found **no such marker**. `FR-WIZ-004` and `FR-DST-004` as written cannot be implemented. §6 proposes how to resolve it.
5. **Delivery:** six milestones, M0–M5, eleven working weeks plus one buffer week, from 2026-09-28 to an MVP validated with users on **2026-12-11** (buffer to 2026-12-18). The estimate assumes one full-time developer working with coding agents; §8.3 states how it scales.

---

## 1. Premises

| # | Premise | Consequence for the plan |
| --- | --- | --- |
| P1 | "Usable and validatable with the client, minimum indispensable" (`handoff.md` §2.1) | The cut keeps the **whole loop** and the **validation layer**, because the deterministic layer *is* the product thesis (`openspec/project.md` §1). It drops breadth: platforms, input paths, countries, extended fields, secondary surfaces. |
| P2 | "Reuse everything; no work without later use" (`handoff.md` §2.1) | No mock backends, no prototype UI, no Python in the app. Measurement harnesses are integration tests of the real pipeline. Deferred features are *not started*, never half-built. The pure-Dart core carries all logic so R2 (iOS) reuses it untouched. |
| P3 | OpenSpec is the method (`handoff.md` §2.2) | Every increment is an OpenSpec change. Implementation-only changes declare `skip_specs: true`; any change that alters behaviour carries a delta. §7. |
| P4 | Errors, tests and improvements must be documentable and flow back (`handoff.md` §2.3) | A feedback system is built in M0, before the first line of product code. §9. |
| P5 | The working contract holds (`AGENTS.md` §1) | Test base is always explicit (team `qCq3JS7q7ptoap8Yg`, database `jd1m8n8l4j7i`); every write to Ninox needs the PO's approval; no corpus document or derivative enters the public repository. |

---

## 2. The MVP in one page

**Platform:** Android only. Flutter, one codebase (ADR-001); iOS is R2 and reuses everything except the native Share Extension.

**User journey covered:**

```
first run ─► token (system browser + paste) ─► team ─► database ─► table ─► mapping (pre-filled) ─► summary
                       (steps with one option are skipped — FR-WIZ-002)
capture ─► [camera: platform scanner → PDF]  or  [file picker / Android share: PDF or image, byte-for-byte]
        ─► extraction on device (photo route: OCR · invoice route: positional PDF text)
        ─► consensus → read all quantities → derive by identity → validate (FR-EXT-001)
        ─► review (6 core fields + amounts block, green/amber/red, never blocks a save)
        ─► send: create → attach → read back (retry matrix, uncertain-create reconciliation)
        ─► confirmation with deep link ─► history (states, retry, duplicates)
```

**In the cut:** use cases UC-01, UC-02, UC-03, UC-05, UC-06, UC-07, UC-09, UC-11, and UC-10 in part (queue while the app is open).

**Deferred:** UC-04 (e-invoice XML) and UC-14 (scanned PDF) → R1; UC-08 (`.msg`/`.eml`), UC-12 (correct and re-send), UC-13 (device migration), UC-15 (supplier memory) → R1; iOS → R2.

**Countries:** universal core plus ES and DE rows. AT and CH rows → R1.
**Interface:** English, every string externalised from day one; German → R1.
**Mappable fields:** the six core fields plus `net_total` and `tax_total` (the product owner's own `YB` table maps base and deductible VAT and computes the total by formula — the 16-document test). Target field kinds: `string`, `number`, `date`. `choice` fields and per-slot tax fields → R1.
**Destinations:** the data model holds several (FR-DST-001); the MVP interface configures and uses one.
**Distribution:** Google Play internal testing track (or signed APK). No public store listing — that is FASE 3 and depends on GAP-011.

---

## 3. Release map

| Release | Goal | Content |
| --- | --- | --- |
| **MVP** (this plan) | Validate the loop and the thesis with real users on real documents | §2 above; requirement-level cut in §4 |
| **R1 — v1.0 Android, public** | Close the functional's v1 scope on Android and publish | e-invoice XML (FR-EXT-003), scanned-PDF OCR (FR-EXT-005), `.msg`/`.eml` (FR-CAP-006/007), AT/CH rows and Swiss rounding, German UI, supplier memory, correction and re-send, configuration export/import/clearing, several destinations, choice fields, tax-slot mapping, read-region highlights, formula-total contrast, background queue, privacy notice, store publication (FASE 3) |
| **R2 — iOS parity** | Same product on iOS | VisionKit scanner, Vision OCR adapter, PDFKit adapter if ADR-011 keeps two libraries, Share Extension (FR-CAP-008, GAP-007) |

---

## 4. Requirement-level scope matrix

Legend: **MVP** fully in the cut · **MVP◐** in the cut with the named part deferred · **R1** / **R2** deferred unchanged. Identifiers are the functional's (§4); spec names are in `openspec/specs/`.

### 4.1 Capture — `capture-intake`

| Req | Cut | Note |
| --- | --- | --- |
| FR-CAP-001 | MVP◐ | Scanner, file picker, Android share-in. `.msg`/`.eml` path → R1 |
| FR-CAP-002 | MVP | ML Kit Document Scanner (Android) |
| FR-CAP-003 | MVP | Multi-page from the scanner and from PDFs |
| FR-CAP-004 | MVP | |
| FR-CAP-005 | MVP | Carries BR-17; hash stored for FR-DUP-001 |
| FR-CAP-006 | R1 | |
| FR-CAP-007 | R1 | |
| FR-CAP-008 | R2 | iOS Share Extension, GAP-007 |
| FR-CAP-009 | MVP◐ | Capture and extraction offline: in. Queued send retried when connectivity returns **while the app is open**; background delivery → R1 |

### 4.2 Extraction — `extraction-pipeline` (Full)

| Req | Cut | Note |
| --- | --- | --- |
| FR-EXT-001 | MVP | Pipeline order fixed; steps 5–7 live in the send pipeline, step 7 as in FR-DST-005 (R1) |
| FR-EXT-002 | MVP◐ | Positional text, then OCR for photos. XML step → R1; a ZUGFeRD PDF still has a text layer and goes through positional text in the MVP, so nothing built is discarded |
| FR-EXT-003 | R1 | |
| FR-EXT-004 | MVP | **Closes ADR-011 in M3** |
| FR-EXT-005 | R1 | Blocked by ADR-010; UC-14 |
| FR-EXT-006 … FR-EXT-011 | MVP | The thesis. BR-06, BR-07, BR-08 |
| FR-EXT-012 | MVP | |
| FR-EXT-013 | MVP | |
| FR-EXT-014 | MVP◐ | Label dictionaries for EN, DE, ES documents; further languages from Annex C → R1 |
| FR-EXT-015 | MVP | **ADR-010 screening in M3, measured again in M5** |

### 4.3 Validation — `validation-confidence` (Full)

| Req | Cut | Note |
| --- | --- | --- |
| FR-VAL-001 … FR-VAL-004 | MVP | |
| FR-VAL-005 | MVP◐ | EAN-13, IBAN mod 97, `ES_NIF`, `ES_NIE`, `ES_CIF` (three separate algorithms), `DE_USTID` format; `DE_STNR` not validated. `AT_UID`, `CH_UID` → R1 |
| FR-VAL-006 … FR-VAL-010 | MVP | FR-VAL-008 is Annex D.2, the flagship example |
| FR-VAL-011 | MVP◐ | The model carries slots and validates them (UC-06; record 1425 had two rates). Mapping individual slots → R1 |
| FR-VAL-012 … FR-VAL-014 | MVP | |

### 4.4 Review — `review-screen`

| Req | Cut | Note |
| --- | --- | --- |
| FR-REV-001, FR-REV-002 | MVP | |
| FR-REV-003 | MVP◐ | Thumbnail and full-screen view. Read-region box and operand highlighting → R1 (the core keeps the coordinates from M1, so R1 only draws them) |
| FR-REV-004, FR-REV-005 | MVP | GAP-019 must be decided before M4 |
| FR-REV-006 | R1 | No advanced section while only core + `net_total`/`tax_total` are mappable; the two amounts sit in the amounts block |
| FR-REV-007 … FR-REV-011 | MVP | FR-REV-007 carries FR-DUP-002 |

### 4.5 Destinations — `destinations-mapping`

| Req | Cut | Note |
| --- | --- | --- |
| FR-DST-001 | MVP◐ | Model holds N destinations; the interface uses one. Switching → R1 |
| FR-DST-002, FR-DST-003 | MVP | |
| FR-DST-004 | MVP — **blocked by proposed GAP-022** | As written it cannot be built; §6 |
| FR-DST-005 | R1 | Depends on GAP-022's resolution; GAP-009 |
| FR-DST-006 | MVP | The per-field absent setting (PRE-001) |
| FR-DST-007 | R1 | MVP maps no `choice` field, so GAP-005 is out of scope by construction |
| FR-DST-008, FR-DST-009 | MVP | Host never compiled in (ADR-017) |

### 4.6 Wizard — `setup-wizard`

| Req | Cut | Note |
| --- | --- | --- |
| FR-WIZ-001 … FR-WIZ-003 | MVP | |
| FR-WIZ-004 | MVP — **blocked by proposed GAP-022** | One call returning tables with fields is verified; the formula annotation is not available |
| FR-WIZ-005 … FR-WIZ-008 | MVP | |

### 4.7 Send — `ninox-send` (Full)

| Req | Cut | Note |
| --- | --- | --- |
| FR-SND-001 … FR-SND-004 | MVP | BR-18, BR-22 |
| FR-SND-005 | MVP — **with a spike** | Reconciliation reads recent records; the API ignored `limit`/`pageSize` (proposed GAP-023) |
| FR-SND-006, FR-SND-007 | MVP | FR-SND-007 is a documentation line |
| FR-SND-008 | MVP◐ | Merge used for the attachment-only retry. Corrections → R1 with FR-HIS-003 |

### 4.8 History, duplicates, memory, configuration, countries

| Req | Cut | Note |
| --- | --- | --- |
| FR-HIS-001, FR-HIS-002, FR-HIS-004, FR-HIS-005 | MVP | |
| FR-HIS-003 | R1 | UC-12 |
| FR-DUP-001, FR-DUP-002 | MVP | Protects the user's database during validation |
| FR-MEM-001 … FR-MEM-004 | R1 | GAP-018 decides FR-MEM-001 first |
| FR-CFG-001 … FR-CFG-003 | R1 | Before any public build |
| FR-CFG-004 | MVP | Keystore; biometrics deferred by the functional |
| FR-CTR-001 … FR-CTR-003, FR-CTR-005 | MVP◐ | Detection restricted to the rows present |
| FR-CTR-004 | MVP◐ | ES and DE rows; AT and CH → R1 |
| FR-CTR-006 | MVP◐ | English UI; German UI → R1 |
| FR-CTR-007 | R1 | With the CH row |

### 4.9 Business rules and invariants

All 22 business rules apply **in full** to whatever is in the cut; none is relaxed for an MVP. BR-11 (a supplier name is confirmable only via memory) means that in the MVP a supplier name is never green — which is the specified behaviour when the memory is empty, not a deviation. Every negative requirement of `product-invariants` is tested in the MVP (§10.3).

### 4.10 Non-functional requirements

| NFR | Cut |
| --- | --- |
| NFR-PRV-001, NFR-PRV-006, NFR-SEC-001, NFR-SEC-002, NFR-SEC-003, NFR-PRF-002, NFR-PLT-001, NFR-LIC-001 | MVP |
| NFR-PRF-001, NFR-PRF-003 | MVP — measured in the supervised sessions of M5, which also produce the thresholds (GAP-003) |
| NFR-SIZ-001 | MVP — measured when ADR-011 closes |
| NFR-OFL-001 | MVP◐, as FR-CAP-009 |
| NFR-ACC-001 | MVP◐ — semantic labels on every control (also what makes device automation work, §11); full audit → R1 |
| NFR-I18N-001 | MVP◐ — externalised strings, English only |
| NFR-PRV-002 … NFR-PRV-005 | R1 — privacy notice and clearing, required before a public build |

---

## 5. Architecture skeleton for reuse (input to the design step)

The functional names no framework on purpose; `design.md` belongs to each implementation change. The skeleton below is the **minimum structure that makes the reuse premise true**, and is proposed for the first `design.md` (change `setup-mvp-foundations`).

```
paperdrop/                         (Dart pub workspace)
├── packages/paperdrop_core/       pure Dart, no Flutter, no I/O
│     money & rates (minor units, basis points) · canonical model · provenance · field state
│     country table (Annex B) · check digits · format inference · dictionaries (Annex C)
│     consensus · amount solver · derive-by-identity · legal-rate gate · negative context
│     confidence · layout reasoning over positioned words (label ↔ nearest value)
├── packages/ninox_client/         pure Dart + http; the port of ADR-003 and its classic adapter
├── app/                           Flutter: screens, local store, platform adapters
│     adapters: scanner · file intake · OCR engine (port) · PDF text (port)
└── tool/benchmark/                on-device integration test that runs the real pipeline over the private corpus
```

Why this shape pays off:

* **Everything that decides a value lives in `paperdrop_core`,** and consumes a platform-neutral input: pages of positioned words. OCR and PDF text adapters only produce that input. R2 (iOS) adds adapters and reuses the core untouched; the ADR-010 decision swaps an adapter without touching a rule.
* **The core is testable on a laptop in milliseconds,** which is where Annex D's worked examples and the scenario-tagged acceptance tests run on every commit.
* **The benchmark is an integration test of the shipped pipeline,** so ADR-010's screening, ADR-011's confirmation and the per-release benchmark of Funcional §10.4 are the same artefact.
* The Python prototype (`corpus_test/src/`) is **ported, not wrapped**: its amount-solving approach (FR-EXT-007 cites `solve_amounts.py`) is re-implemented in the core, and its five known failures become regression tests.

---

## 6. Findings from planning that need a decision

### 6.1 Proposed GAP-022 — the schema carries no formula or read-only marker (BLOQUEANTE for FR-DST-004, FR-WIZ-004)

**Evidence.** `ninox-agent-skill/references/rest-api.md` and `schema-and-fields.md`, VERIFIED across 566 tables and 8,048 fields: a field object carries only `id`, `name`, `type`, plus `choices` for choice fields and reference keys for relations. No `formula`, `readonly` or `computed` key exists. The skill states explicitly: *"If a design document claims the schema marks formula fields, that claim is wrong."* PDR v0.2 §7.4/§8, Funcional FR-DST-004 and FR-WIZ-004, and the archived specs `destinations-mapping` (`formula-and-read-only-fields-are-not-mapping-candidates`) and `setup-wizard` (`table-listing-returns-the-schema`) all assume the marker.

**Why it matters.** Offering a formula field guarantees an HTTP 500 on every send (PDR §7.4). The total of the `YB` table used in the 16-document test is exactly such a field, and it was invisible to the consultant for the same reason (PRE-003).

**Options.**

| Option | Behaviour | Cost / risk |
| --- | --- | --- |
| A — human filter plus diagnosis *(recommended)* | Candidates are filtered by type only. The mapping step states in one line that fields computed by a formula cannot receive values. On a 500 the retry matrix already refreshes the schema and retries once (FR-SND-004); the second failure is reported as a **mapping error naming the mapped fields** and sends the user to the mapping. Optionally the user may designate "a total Ninox computes" for FR-DST-005 (R1). | No invented marker, no extra writes. The first failed send is the detection. |
| B — probe on a test write | Detect formula fields by writing to them | **Rejected:** violates BR-16 and `AGENTS.md` §1.5; writes into the user's database to learn its shape. |
| C — infer from record values | Read existing records and guess | **Rejected:** a formula value is indistinguishable in a read. |

**What resolving it takes.** A decision (DEC-004 in `product-decisions.md`), and a spec change with `MODIFIED` deltas for the two requirements named above — the functional is not edited (`AGENTS.md` §1.6). Scheduled as T0.9 in M0 so M2 builds the right thing.

### 6.2 Proposed GAP-023 — reconciliation needs "the most recent records", and the list endpoint did not page (NO BLOQUEANTE, spike in M2)

**Evidence.** `ninox-agent-skill/references/rest-api.md`, VERIFIED NEGATIVE: `?limit=2` and `?pageSize=2` were accepted and ignored; the whole table came back. FR-SND-005 reads "the destination table's most recently created records". On a table with years of expenses that is a full download on a mobile network, at exactly the moment the network was already failing.

**Resolution path.** A read-only spike (T2.3) against the test base, checking the vendor-documented parameters before any is relied on (the skill forbids guessing names), and the `sequence` value that every record carries. If no bounded read exists, the reconciliation still works but its cost must be stated, and the ambiguous branch (ask the user) remains the safety net.

### 6.3 Decisions requested from the product owner before or during M0

| ID | Decision | Recommendation | Needed by |
| --- | --- | --- | --- |
| D-1 | MVP cut of §2 and §4 | Approve as proposed | M0 |
| D-2 | Photo route in the MVP or first in R1 | **Keep it** (both journeys carry equal weight, §2.2 of the functional). If the calendar tightens, it is the one block that can move to R1 without rework | M0 |
| D-3 | GAP-022 resolution | Option A | M0 |
| D-4 | ADR-010 approach | Implement the **platform engine** (ML Kit) behind the port and *confirm* it in the screening; evaluate Tesseract only if ML Kit fails the screening. Building both now is work with no later use if ML Kit passes, and the openness argument is already weakened by ADR-006's Play Services scanner (ADR-010, "coupling to note") | M3 |
| D-5 | ADR-011 candidates | Evaluate the proposal (PdfBox-Android) **and** a PDFium-based Flutter package exposing character boxes, which would give one implementation for Android and iOS. Decide on the positional criterion and the size check | M3 |
| D-6 | GAP-019 (amounts block after an edit) | Keep the block as the check left it, mark the edited value as "edited" | M4 |
| D-7 | GAP-017 (personal data left in `tools/`, `sql/`) | Move both folders out of the repository tree, into `Paperdrop_corpus`, before the first commit of code | M0 |
| D-8 | GAP-011 (name) | Check now: the Android `applicationId` is permanent once published | M0 |
| D-9 | Validation users | Who, how many (recommend the PO plus 2–3 real Ninox users), which Ninox tables | M4 |
| D-10 | Writes to the test base | A standing approval for the M2/M4 automated tests, bounded to team `qCq3JS7q7ptoap8Yg`, database `jd1m8n8l4j7i`, one disposable table, with deletes of records the test created | M2 |

---

## 7. Method: OpenSpec for implementation

### 7.1 One change per increment

| Kind of change | Spec delta | Files |
| --- | --- | --- |
| Implements already-specified requirements | none — `.openspec.yaml` declares `skip_specs: true` | `proposal.md` (what is built, which requirement names it satisfies, which parts are deferred), `design.md`, `tasks.md` |
| Changes behaviour (e.g. GAP-022) | `MODIFIED` / `ADDED` / `REMOVED` delta, per `openspec/project.md` §4 | as above plus `specs/<capability>/spec.md` |

**Measure before relying on it.** `skip_specs` is documented for current OpenSpec releases; the project measured version 1.4.1 (`openspec/project.md` §5). T0.1 verifies the installed version accepts the marker; if it does not, the recorded alternative is `openspec archive <change> --skip-specs -y` and an accepted-deviation note in `openspec/AGENTS.md`, exactly as the "more than 10 deltas" warning was handled.

### 7.2 Rules carried into every change

* `proposal.md` lists requirement **names** from `openspec/specs/` and the functional identifier they come from. A requirement partly implemented says which part (the MVP◐ rows above).
* `tasks.md` holds tasks of **at most two days**, each with a checkable done condition.
* A task is done when its tests pass **and** those tests are tagged with the scenario they prove (§10.1).
* Archive ritual unchanged (`openspec/AGENTS.md` §4.1), plus the session closing ritual (`AGENTS.md` §7).
* The implementation agent writes `design.md` and `tasks.md`; the specification agent keeps its role and only acts on deltas.

### 7.3 Changes of the MVP

| # | Change | Milestone | Spec delta |
| --- | --- | --- | --- |
| 1 | `setup-mvp-foundations` | M0 | none |
| 2 | `resolve-formula-field-detection` | M0 | MODIFIED `destinations-mapping`, `setup-wizard` (after D-3) |
| 3 | `implement-core-model-and-countries` | M1 | none |
| 4 | `implement-validation-layer` | M1 | none |
| 5 | `implement-extraction-core` | M1 | none |
| 6 | `implement-ninox-client` | M2 | none |
| 7 | `implement-setup-wizard` | M2 | none |
| 8 | `implement-send-pipeline` | M2 | none (a delta only if GAP-023 changes FR-SND-005) |
| 9 | `implement-android-capture` | M3 | none |
| 10 | `close-adr-011-pdf-text-route` | M3 | ADR record in `openspec/architecture/` |
| 11 | `implement-photo-route` | M3 | ADR-010 screening record |
| 12 | `implement-review-screen` | M4 | none (GAP-019 decision recorded) |
| 13 | `implement-history-and-duplicates` | M4 | none |
| 14 | `validate-mvp` | M5 | whatever the findings require |

---

## 8. Milestones, tasks, dates and deliverables

Calendar: Monday 2026-09-28 start. Weeks are working weeks (W1 = 28 Sep – 2 Oct).

### M0 — Foundations and decisions · W1 (28 Sep – 2 Oct)

| Task | Content | Done when |
| --- | --- | --- |
| T0.1 | Verify repository root (`AGENTS.md` §1.1); install OpenSpec, measure `skip_specs` | Measured result written in `openspec/project.md` §5 |
| T0.2 | PO decision session D-1 … D-8 | Each decision recorded (DEC-/GAP- rows) |
| T0.3 | Name check (GAP-011), choose `applicationId` | GAP-011 closed or renamed |
| T0.4 | Move `tools/`, `sql/` out of the tree (GAP-017, if D-7) | `git check-ignore` no longer needed for them |
| T0.5 | Install the selected agent skills (§11) | Listed in `docs/Plan/` and working |
| T0.6 | Flutter/Dart workspace per §5; lints; `README` dependency declaration (NFR-LIC-001) | Empty app builds and runs on the PO's Android phone |
| T0.7 | CI: analyze, format, test, coverage; **privacy job** that fails on corpus paths, known identifiers and token-like strings | CI green on the empty workspace |
| T0.8 | Feedback system of §9: issue templates, `validation/` folder, triage rule | Templates merged |
| T0.9 | Spec change `resolve-formula-field-detection` (after D-3) | `openspec validate --strict` green, PO approval |
| T0.10 | Private corpus convention: path outside the repo, ground-truth format of Funcional §10.3 (`present` / `absent` / `illegible` / `not_in_xml`, minor units, basis points) | 16-document set annotated in that format |

**Deliverables:** repository scaffold; CI with privacy gate; feedback templates; decision records; approved GAP-022 spec change.

### M1 — Deterministic core · W2–W3 (5 – 16 Oct)

| Task | Content | Req |
| --- | --- | --- |
| T1.1 | Money and rate types: integer minor units, ISO 4217 exponent, basis points | BR-09 |
| T1.2 | Canonical model, provenance tags, field states; `surcharges[]` as Funcional §6.1.2 shapes it (GAP-020 is ownership, the shape exists) | FR-EXT-011 |
| T1.3 | Country table: ES and DE rows | FR-CTR-003, FR-CTR-004, Annex B |
| T1.4 | Check digits: EAN-13, IBAN, `ES_NIF`, `ES_NIE`, `ES_CIF`, `DE_USTID`, with standard valid/invalid vectors | FR-VAL-005 |
| T1.5 | Date and decimal format inference | FR-CTR-005, FR-VAL-013 |
| T1.6 | Label and negative-context dictionaries (EN, DE, ES) | FR-EXT-014, FR-EXT-010, Annex C |
| T1.7 | Layout reasoning: label ↔ nearest value over positioned words | FR-EXT-004 (logic half) |
| T1.8 | Consensus by majority | FR-EXT-006 |
| T1.9 | Amount solver: read all, derive by identity, legal-rate gate, suppression | FR-EXT-007 … FR-EXT-010 |
| T1.10 | Currency evidence and its confidence | FR-EXT-013, FR-VAL-009 |
| T1.11 | Confidence states, repair, never-green rules, absent-not-zero | FR-VAL-001 … FR-VAL-014 |
| T1.12 | Annex D.1 – D.5 as acceptance tests; the five failed documents of the 16-document test as private regression cases | §10.6 |

**Deliverables:** `paperdrop_core` 0.1 with scenario-tagged tests; Annex D green; regression report on the 16 documents (private).

### M2 — Ninox client, wizard and send · W4–W5 (19 – 30 Oct)

| Task | Content | Req |
| --- | --- | --- |
| T2.1 | Ninox port and classic adapter: teams, databases, tables with fields, records, files; host as configuration | ADR-003, FR-DST-008 |
| T2.2 | Contract tests on sanitised recorded responses; live **read-only** tests on the test base | Annex A |
| T2.3 | Spike GAP-023: bounded read of recent records | FR-SND-005 |
| T2.4 | Token: system browser, paste, immediate validation, keystore | FR-WIZ-003, FR-CFG-004 |
| T2.5 | Wizard steps with auto-omit | FR-WIZ-001, FR-WIZ-002 |
| T2.6 | Mapping: type filter, multilingual synonyms, strict threshold, absent setting, GAP-022 behaviour | FR-WIZ-005, FR-WIZ-006, FR-DST-006 |
| T2.7 | Summary and first-document offer | FR-WIZ-007, FR-WIZ-008 |
| T2.8 | Send: create → attach → read back; names resolved from stored identifiers | FR-SND-001 … FR-SND-003, FR-DST-003 |
| T2.9 | Retry matrix and uncertain-create reconciliation, with fault-injection tests | FR-SND-004, FR-SND-005 |
| T2.10 | Deep link with degradation | FR-SND-006 |
| T2.11 | Live write tests on the test base (needs D-10); measure upload size/timing from Spain (GAP-004) | GAP-004 |

**Deliverables:** demo — configure a destination from lists in under two minutes and send a document; GAP-023 and GAP-004 measurements recorded.

### M3 — Capture and reading · W6–W7 (2 – 13 Nov)

| Task | Content | Req |
| --- | --- | --- |
| T3.1 | Platform scanner → assembled PDF, multi-page | FR-CAP-002 … FR-CAP-004 |
| T3.2 | File picker and Android share intent; byte-for-byte storage and hash | FR-CAP-001, FR-CAP-005 |
| T3.3 | ADR-011 evaluation (D-5): positional criterion on the sample-invoice corpus, size check; ADR record | ADR-011, NFR-SIZ-001 |
| T3.4 | PDF positional text adapter | FR-EXT-004 |
| T3.5 | OCR adapter (ML Kit) and multi-pass strategy feeding consensus | FR-EXT-006, FR-EXT-015 |
| T3.6 | Route selection and multi-page consolidation | FR-EXT-001, FR-EXT-002, FR-EXT-012 |
| T3.7 | On-device benchmark runner over the private corpus: per-field accuracy after validation, `read`/`from_xml` only | Funcional §10.3 |
| T3.8 | ADR-010 screening on ~15 photographed documents incl. thermal hospitality and fuel | ADR-010 |

**Deliverables:** ADR-011 closed; ADR-010 screening report; first benchmark report.

### M4 — Review, history, alpha · W8–W9 (16 – 27 Nov)

| Task | Content | Req |
| --- | --- | --- |
| T4.1 | Local store and document state machine | FR-HIS-001, FR-HIS-002 |
| T4.2 | Review: destination bar and daily confirmation, six fields, amounts block, colours and lock, focus on the first unread field, save naming the destination, never block, edits authoritative, discard | FR-REV-001 … FR-REV-011 (cut) |
| T4.3 | Thumbnail and viewer | FR-REV-003 (part) |
| T4.4 | Duplicate check and notice | FR-DUP-001, FR-DUP-002 |
| T4.5 | History list and detail, retry, file retention | FR-HIS-004, FR-HIS-005 |
| T4.6 | Foreground queue on connectivity return | FR-CAP-009 (part) |
| T4.7 | Externalised strings, semantic labels | NFR-I18N-001, NFR-ACC-001 (part) |
| T4.8 | Negative release checklist automated (§10.3) | Funcional §10.6 |
| T4.9 | Alpha to the internal testing track | — |

**Deliverables:** alpha build; negative-test report; exploratory QA report (§11, agent-device).

### M5 — Validation with users · W10–W11 (30 Nov – 11 Dec)

| Task | Content |
| --- | --- |
| T5.1 | Acceptance corpus with two equal halves, annotated (private) — Funcional §10.1 |
| T5.2 | Benchmark run and report |
| T5.3 | Supervised sessions (Funcional §10.4): median time and taps per document, untouched rate, green rate, abstention rate |
| T5.4 | Triage every finding through §9 |
| T5.5 | Fix cycle |
| T5.6 | Proposed thresholds (closes GAP-003), MVP report, R1 backlog ordered by evidence |

**Deliverables:** MVP release candidate; validation report; updated registers; R1 plan.

**Buffer:** W12 (14 – 18 Dec).

### 8.1 Critical path

```
T0.9 (GAP-022) ─► T2.6 mapping
T1.7 layout ─► T3.4 PDF adapter ─► T3.3 ADR-011 ─► T3.7 benchmark ─► T5.2
T1.9 solver ─► T3.5 OCR ─► T3.8 ADR-010 screening ─► T5.2
T2.8 send ─► T4.2 review ─► T4.9 alpha ─► T5.3 sessions
```

### 8.2 Demo points

| Date | What can be shown |
| --- | --- |
| 16 Oct (end M1) | The core deciding values on Annex D and on the 16 documents, in tests |
| 30 Oct (end M2) | The wizard reading the user's real teams, databases, tables and fields, and a send with read-back |
| 13 Nov (end M3) | Real documents read on the phone; ADR decisions with numbers |
| 27 Nov (end M4) | The full loop on the phone (alpha) |
| 11 Dec (end M5) | MVP validated with users, with metrics |

### 8.3 Assumptions behind the dates

One full-time-equivalent developer working with coding agents, PO available for decisions within two working days, a physical Android device with Play Services. At half-time the calendar roughly doubles; a second developer would parallelise M2 with M1 (they share only the money types of T1.1).

---

## 9. Documentation system for errors, tests and improvements (handoff §2.3)

### 9.1 Where each kind of finding goes

| Finding | Recorded in | Flows to |
| --- | --- | --- |
| **Bug** — the app does not do what a spec scenario says | GitHub issue, template *Bug*, citing capability, requirement name and scenario | Fix + a regression test tagged with that scenario |
| **Spec gap** — the spec is silent, ambiguous or contradicts reality | `openspec/gaps-register.md` (GAP-nnn) and an issue linking to it | A spec change with a delta, then implementation |
| **Product change** — the PO decides to behave differently | `openspec/product-decisions.md` (DEC-nnn) | A spec change with a delta |
| **Improvement** outside v1 | Issue, template *Improvement*, label `R1`/`R2`/`later` | Release backlog; enters a change only when scheduled |
| **Measurement** — benchmark or session result | `validation/benchmarks/<release>.md`, `validation/sessions/<date>.md` | Thresholds (GAP-003), regressions become bugs |
| **Failing document** | Private corpus with ground truth — **never** the repository | A regression case in the private benchmark; a synthetic reproduction in the public tests where possible |

### 9.2 Templates to add in M0

* `.github/ISSUE_TEMPLATE/bug.md` — capability, requirement name, scenario, steps, expected (from the scenario), actual, build, device. A mandatory check: *"No real document, name, tax identifier, plate or card number is included."*
* `.github/ISSUE_TEMPLATE/spec-gap.md` — the ambiguity, the source identifiers, whether it blocks, proposed GAP text.
* `.github/ISSUE_TEMPLATE/improvement.md` — problem, evidence, proposed release.
* `validation/benchmarks/_template.md` — build, corpus version (hash, not content), per-field accuracy per route, green rate, abstention rate.
* `validation/sessions/_template.md` — anonymised participant code, document kind, seconds, taps, fields edited, observations.

### 9.3 Triage rule

```
Does the app contradict a spec scenario?          yes → Bug
Is the spec silent, wrong or ambiguous here?      yes → GAP → spec change
Does the PO want different behaviour?             yes → DEC → spec change
Is it outside the v1 scope of the functional?     yes → Improvement (R1/R2/later)
```

Nothing is fixed silently: a code change without an issue or a register entry is not accepted in review.

---

## 10. Test design

### 10.1 Scenario-tagged tests

Every test names the scenario it proves: `[setup-wizard/two-stage-matching-with-a-strict-threshold] below the threshold the field stays unmapped`. A script run in CI lists the scenarios in `openspec/specs/` and reports those with no test, producing `docs/Plan/test-traceability.md` on each run. The scenarios already written are the acceptance tests; they are not re-authored.

### 10.2 Test layers

| Layer | Where | What |
| --- | --- | --- |
| Unit | `paperdrop_core`, `ninox_client` — laptop, CI | Check digits, money, solver, confidence, Annex D, dictionaries |
| Contract | `ninox_client` — CI, recorded sanitised responses | Annex A rows; retry matrix with fault injection |
| Live read | Test base, explicit IDs | Enumeration, schema, list parameters |
| Live write | Test base, **with approval** (D-10) | Create → attach → read back → delete own records |
| Widget | `app` — CI | Review states, wizard omission, never-block |
| Device integration | Physical Android | Capture, adapters, benchmark runner |
| Exploratory | Physical Android, agent-device | Bug reports into §9 |
| Supervised | Users | Funcional §10.4 |

### 10.3 Negative release checklist (Funcional §10.6), automated from M4

No backend call (network log contains only the configured Ninox host) · no schema mutation (no request to a schema-changing endpoint) · no credential beyond the token · no unmapped field key in any payload · no telemetry artefact in the build · no mail-body byte (R1, with `.msg`/`.eml`).

---

## 11. Agent skills (handoff §3.2)

| Skill source | Verdict | Use in this plan |
| --- | --- | --- |
| Own `ninox-agent-skill` | **Adopt, mandatory** | The verified API contract; source of GAP-022 and GAP-023; its read-only client for live tests |
| `dart-lang/skills` (BSD-3) | **Adopt selectively** | unit tests, static analysis, coverage, pattern matching (sealed provenance/state types), mocks, dependency conflicts. Skip FFI skills unless D-5 selects an FFI library |
| `flutter/agent-plugins` (BSD-3) | **Adopt selectively** | widget tests, integration tests, localisation, HTTP package, architecture, JSON serialisation (never parsing money as `double`). The `flutter-platform-integration` path in `docs/skills_proposed.md` could not be found in the repository's published skill list — to be confirmed |
| `callstack/agent-device` (MIT) | **Adopt in M4–M5** | Drive the alpha on a physical Android phone over adb; its `dogfood` skill produces exploratory bug reports that go through §9. Needs Node 22.12+ and semantic labels in the app. Could replace the separate `phone-harness` |
| VGV `vgv-ai-flutter-plugin` (MIT) | **Adopt two skills** | *Security* (static review: token storage, logging, secrets — BR-19, NFR-SEC-001) and *License Compliance* (NFR-LIC-001, no AGPL). Do not mix its architecture/state-management skills with the Flutter team's: one source per concern |
| Dart MCP server (official) | **Add** | Lets agents analyse, test and inspect the running app; several Flutter skills assume it |

---

## 12. Risks

| Risk | Effect | Mitigation |
| --- | --- | --- |
| ML Kit fails the screening | Photo route below threshold | D-2 lets the photo route move to R1 without rework; Tesseract evaluated then |
| No bounded record read (GAP-023) | Slow reconciliation on large tables | Spike in W4; ambiguity branch asks the user |
| Attachment limits (GAP-004) | Large scanned PDFs fail | Measured in T2.11; clear error, never silent |
| Private corpus leaks into the public repo | Personal data published | CI privacy job (T0.7); corpus path outside the tree |
| An environment variable points at production (GAP-012) | Test records in a real ERP | Tests take explicit IDs only; recommend renaming `NINOX_DB_ID` on the developer machine so nothing can pick it up by default |
| Scope creep inside the MVP | Dates slip | Anything outside §4 becomes an *Improvement* issue, never a task |

---

## 13. Housekeeping noticed while reading (not acted on)

* An untracked folder `Ticket_reader_Ninox/` exists **inside** the repository root, and `docs/handoff.md` is untracked; `docs/skills_proposed.md` has uncommitted edits.
* `docs/handoff.md` cites paths under `04_01_Ticket_reader_Ninox`, which is correct; the older folder `C:\Users\admin\proyectos\Ticket_reader_Ninox` is empty and is not the project (`AGENTS.md` §2.1).
