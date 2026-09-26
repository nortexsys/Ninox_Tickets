# Paperdrop for Ninox — MVP definition and delivery plan

**Version:** 0.2.1 — approved by the product owner (DEC-009); team, models and tooling fixed on 2026-09-25 (DEC-011)
**Date:** 2026-09-25
**Phase:** FASE 2, planning step ("features, tasks, milestones, delivery dates and test design", `AGENTS.md` §3)
**Supersedes:** `Paperdrop_MVP_Plan_v0.1_EN.md` (kept for history). What changed is listed in Annex A.
**Inputs added since v0.1:** the product owner's answers (`docs/Plan/Paperdrop_MVP_RESPUESTAS_1.md` and the conversation of 2026-09-25: MVP in about four weeks, five agents plus the product owner, same-day approvals) and the read-only spike `docs/Plan/SPIKE_GAP-022_schema_formula_fields.md`.

---

## 0. Summary

1. **The MVP is one honest end-to-end loop on Android:** configure a destination from lists (never typing a table or field name), capture a paper receipt or share a PDF invoice, read it on the device, validate it with the deterministic layer, review it, write one record with the original attached, and read it back.
2. **Everything built for the MVP is v1 code** (DEC-009). The MVP is a release cut of the approved specifications. Requirements are in the cut, partly in it (the deferred part is named), or deferred unchanged to R1/R2.
3. **Four weeks, not eleven.** v0.1 assumed one developer working sequentially. v0.2 plans for **five agents plus the product owner**, working in parallel lanes, with **same-day approvals**. Start Monday **2026-09-28**, alpha on the phone **2026-10-16**, MVP validated with users **2026-10-23**, buffer to **2026-10-30**.
4. **The real critical path is not code.** It is the product owner's approvals, one physical Android phone, the photographed corpus for ADR-010 and the calendar of 2–3 real users. §9.2 dates each of those inputs.
5. **GAP-022 was resolved by measurement, not by argument.** The spike showed that formula fields *can* be kept out of the app entirely, which is the product owner's rule (DEC-005). No read-only marker exists; that half is diagnosed, not anticipated. The decision is carried into the specs by the change `resolve-mvp-planning-gaps`, which is written, validated and waiting for approval.

## 1. Premises

| # | Premise | Consequence for the plan |
| --- | --- | --- |
| P1 | "Usable and validatable with the client, minimum indispensable" (`handoff.md` §2.1) | The cut keeps the **whole loop** and the **validation layer**, because the deterministic layer *is* the product thesis (`openspec/project.md` §1). It drops breadth: platforms, input paths, countries, extended fields, secondary surfaces. |
| P2 | "Reuse everything; no work without later use" (`handoff.md` §2.1) | No mock backends, no prototype UI, no Python in the app. Measurement harnesses are integration tests of the real pipeline. Deferred features are *not started*, never half-built. The pure-Dart core carries all logic so R2 (iOS) reuses it untouched. |
| P3 | OpenSpec is the method (`handoff.md` §2.2) | Every increment is an OpenSpec change. Implementation-only changes declare `skip_specs: true`; any change that alters behaviour carries a delta. §8. |
| P4 | Errors, tests and improvements must be documentable and flow back (`handoff.md` §2.3) | A feedback system is built in M0, before the first line of product code. §10. |
| P5 | The working contract holds (`AGENTS.md` §1) | Test base is always explicit (team `qCq3JS7q7ptoap8Yg`, database `db0000000000`); every write to Ninox needs the PO's approval; no corpus document or derivative enters the public repository. |

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
| FR-EXT-004 | MVP | **Closes ADR-011 in W2 (T1.15)** |
| FR-EXT-005 | R1 | Blocked by ADR-010; UC-14 |
| FR-EXT-006 … FR-EXT-011 | MVP | The thesis. BR-06, BR-07, BR-08 |
| FR-EXT-012 | MVP | |
| FR-EXT-013 | MVP | |
| FR-EXT-014 | MVP◐ | Label dictionaries for EN, DE, ES documents; further languages from Annex C → R1 |
| FR-EXT-015 | MVP | **ADR-010 screening in W3 (T2.5), benchmarked again in W4** |

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
| FR-REV-004, FR-REV-005 | MVP | GAP-019 decided: DEC-007 |
| FR-REV-006 | R1 | No advanced section while only core + `net_total`/`tax_total` are mappable; the two amounts sit in the amounts block |
| FR-REV-007 … FR-REV-011 | MVP | FR-REV-007 carries FR-DUP-002 |

### 4.5 Destinations — `destinations-mapping`

| Req | Cut | Note |
| --- | --- | --- |
| FR-DST-001 | MVP◐ | Model holds N destinations; the interface uses one. Switching → R1 |
| FR-DST-002, FR-DST-003 | MVP | |
| FR-DST-004 | MVP | Resolved by DEC-005: formula fields never shown; spec change `resolve-mvp-planning-gaps` (§6.1) |
| FR-DST-005 | R1 | Uses the `fn` expression of the full schema (GAP-025); GAP-009 |
| FR-DST-006 | MVP | The per-field absent setting (PRE-001) |
| FR-DST-007 | R1 | MVP maps no `choice` field, so GAP-005 is out of scope by construction |
| FR-DST-008, FR-DST-009 | MVP | Host never compiled in (ADR-017) |

### 4.6 Wizard — `setup-wizard`

| Req | Cut | Note |
| --- | --- | --- |
| FR-WIZ-001 … FR-WIZ-003 | MVP | |
| FR-WIZ-004 | MVP | One call returns tables with their writable fields; formula fields are omitted by `.../tables` (§6.1) |
| FR-WIZ-005 … FR-WIZ-008 | MVP | |

### 4.7 Send — `ninox-send` (Full)

| Req | Cut | Note |
| --- | --- | --- |
| FR-SND-001 … FR-SND-004 | MVP | BR-18, BR-22 |
| FR-SND-005 | MVP | `perPage`/`page` verified; ordering checked in T1.8 before coding (GAP-023) |
| FR-SND-006, FR-SND-007 | MVP | FR-SND-007 is a documentation line |
| FR-SND-008 | MVP◐ | Merge used for the attachment-only retry. Corrections → R1 with FR-HIS-003 |

### 4.8 History, duplicates, memory, configuration, countries

| Req | Cut | Note |
| --- | --- | --- |
| FR-HIS-001, FR-HIS-002, FR-HIS-004, FR-HIS-005 | MVP | |
| FR-HIS-003 | R1 | UC-12 |
| FR-DUP-001, FR-DUP-002 | MVP | Protects the user's database during validation |
| FR-MEM-001 … FR-MEM-004 | R1 | FR-MEM-001 as decided in DEC-008 |
| FR-CFG-001 … FR-CFG-003 | R1 | Before any public build |
| FR-CFG-004 | MVP | Keystore; biometrics deferred by the functional |
| FR-CTR-001 … FR-CTR-003, FR-CTR-005 | MVP◐ | Detection restricted to the rows present |
| FR-CTR-004 | MVP◐ | ES and DE rows; AT and CH → R1 |
| FR-CTR-006 | MVP◐ | English UI; German UI → R1 |
| FR-CTR-007 | R1 | With the CH row |

### 4.9 Business rules and invariants

All 22 business rules apply **in full** to whatever is in the cut; none is relaxed for an MVP. BR-11 (a supplier name is confirmable only via memory) means that in the MVP a supplier name is never green — which is the specified behaviour when the memory is empty, not a deviation. Every negative requirement of `product-invariants` is tested in the MVP (§11.3).

### 4.10 Non-functional requirements

| NFR | Cut |
| --- | --- |
| NFR-PRV-001, NFR-PRV-006, NFR-SEC-001, NFR-SEC-002, NFR-SEC-003, NFR-PRF-002, NFR-PLT-001, NFR-LIC-001 | MVP |
| NFR-PRF-001, NFR-PRF-003 | MVP — measured in the supervised sessions of W4, which also produce the thresholds (GAP-003) |
| NFR-SIZ-001 | MVP — measured when ADR-011 closes |
| NFR-OFL-001 | MVP◐, as FR-CAP-009 |
| NFR-ACC-001 | MVP◐ — semantic labels on every control (also what device automation relies on, §12); full audit → R1 |
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

## 6. Planning findings — resolved

### 6.1 GAP-022 — formula fields: resolved (DEC-005)

**What the spike measured** (GET only, test base, 2026-09-25):

| Endpoint | Formula fields |
| --- | --- |
| `GET .../databases/{db}/tables` | **Omitted altogether.** 1,416 fields returned out of 2,143; the 727 missing are exactly the formula fields, per table, with no exception |
| `GET .../databases/{db}/schema` (and `.../databases/{db}`, identical plus `settings`) | Present, with key `fn` holding the expression (e.g. `(D+J)` for `YB`'s `Importe total`). `fn` present ⇔ `base == "fn"`, 727/727 |
| Either | **No read-only marker.** `canWrite` is a Ninox expression ("editable when"), `readRoles`/`writeRoles` are role grants |

On `YB` the result matches the product owner's own account exactly: two formula fields (`Importe total`, `Año`), everything else writable.

**Behaviour (spec, via `resolve-mvp-planning-gaps`):** formula fields never reach the mapping or any screen that builds it; a send that fails with HTTP 500 after the schema refresh and single retry is reported as a mapping error naming the mapped fields, and the app does not write again to find the culprit.

**Design recommendation for `implement-setup-wizard` (not spec):** build the picker on **`.../tables`**. It is the endpoint the classic API was chosen for (ADR-003), it is compact, and its omission of formula fields already satisfies the rule. `.../schema` is ~1.5 MB on the test base, looks like the workspace's internal serialisation, and its behaviour on a password-protected database is untested (GAP-025). It is needed only in R1, for the formula-total contrast of FR-DST-005, where the `fn` expression even tells the app which mapped fields the total is computed from. The spike report concluded the opposite ("the picker must read `/schema`"); the disagreement is about robustness, not about the facts, and is for the implementation agent's `design.md` to settle with the product owner.

**Consequence outside the app — done.** `ninox-agent-skill` stated that no formula marker exists and that the record list does not page. It was corrected on 2026-09-25 (commit `4c14ee4`) and re-vendored into `agents/skills/ninox` (T0.6).

### 6.2 GAP-023 — reconciliation read: mostly resolved

`perPage` and `page` page correctly; the default page is 100 records; `limit` and `pageSize` are ignored. Still unverified: that `order`/`desc` actually sort (the spike counted records, it did not check their order), and whether `sinceSq` works with another coordinate. T1.8 closes it read-only before the reconciliation is coded.

### 6.3 New findings recorded

* **GAP-024 — corrupted text encoding.** Nine of the twelve living specs carried double-encoded characters (`§` → `Â§`), including inside requirement blocks and `[Origen]` tags. They were **repaired and verified**: after a mechanical cp1252 → UTF-8 re-encoding, all 91 requirement blocks are byte-identical to the archived deltas the product owner approved, and `validate --all --strict` stays green. The **Funcional v1.0 is affected in both formats** (541 occurrences in the `.md`, 694 inside the `.docx`), since its first commit. It is read-only; repairing it needs a product-owner decision of the same kind as DEC-001. Identifiers are ASCII, so traceability is not lost.
* **GAP-025 — the full database schema is not a stable contract.** Not needed by the MVP if §6.1's recommendation is followed.

### 6.4 Decisions taken on 2026-09-25

All recommendations of v0.1 §6.3 were approved (D-1 … D-10), with these product-owner specifics:

| Item | Decision |
| --- | --- |
| GAP-022 | Formula fields never appear in the app (DEC-005) |
| GAP-011 | Name verified free; product name **Paperdrop for Ninox** (DEC-006) |
| GAP-012 | `NINOX_DB_ID` is **not** renamed; agents are instructed, and a CI check enforces it (T0.3) |
| GAP-006 | Not testable in-house; the Ninox community is asked after the MVP |
| GAP-018 | Only names the user typed or corrected are learned (DEC-008) |
| GAP-019 | Block stays as the check left it; edited values marked (DEC-007) |
| GAP-020, GAP-021 | Closed as recommended |
| Plan | About four weeks; five agents plus the PO; same-day approvals (DEC-009) |

**Nothing is open for the product owner at the planning level.** Models and framework are fixed (§7.5, DEC-011); the Funcional's encoding was repaired (DEC-010, GAP-024 closed).

---

## 7. The agent team

### 7.1 Roles

| Agent | Mission | Main virtue | Model | Writes to | May not |
| --- | --- | --- | --- | --- | --- |
| **Orchestrator** | Turns the scope matrix into changes and tasks, writes `design.md`/`tasks.md`, assigns lanes, integrates, keeps the daily approvals queue, enforces `AGENTS.md` | Reasoning and judgement, plus reliable long-horizon tool use | Opus 5.5, in **Claude Code** | `openspec/changes/*/design.md`, `tasks.md`, `docs/Plan/status/` | Write product code; close a gap or take a decision; merge without the PO |
| **Spec** | Deltas, gaps and decisions registers; the only one who edits `openspec/specs/` (through changes) | Fidelity to sources | Atria Dawn Preview (LangGraph) | `openspec/` except `design.md`/`tasks.md` | Write code; archive without the PO |
| **Core** | `paperdrop_core`: money, model, provenance, countries, check digits, layout reasoning, solver, confidence — test-first against the scenarios | Correct code under strict rules | DeepSeek-V4-Pro-0813 (LangGraph) | `packages/paperdrop_core/` | Touch I/O, Flutter or the network |
| **Ninox** | `ninox_client`, wizard, send pipeline, reconciliation; **the only agent holding the token** and access to the test base | Careful code and careful tool use | DeepSeek-V4.1-Flash (LangGraph) | `packages/ninox_client/`, wizard and send code in `app/` | Write to Ninox without the standing approval D-10's bounds; use any environment variable to pick a target |
| **Mobile** | Flutter app shell, review/history screens, Android adapters (scanner, intake, PDF text, OCR), local store | Platform integration | DeepSeek-V4.1-Flash (LangGraph) | `app/` except the Ninox-owned parts | Put logic that decides a value outside `paperdrop_core` |
| **QA / verification** | Scenario-tag coverage, negative checklist, privacy gate, contract fixtures, benchmark runner, device runs, triage of findings into §10 | Scepticism and rigour | Sonnet 5 (LangGraph) | tests, `validation/`, issues | Write product code; mark its own findings fixed |
| **Product owner** | Approves changes, merges, writes to Ninox, decisions; provides corpus and users | — | — | registers (decisions) | — |

The orchestrator never closes anything on its own: scope, behaviour and anything written to Ninox are escalated to the product owner, even when it believes it knows the answer.

### 7.2 How they work together

```
Orchestrator ── change + tasks ──► lane agent (own worktree, own branch: change/<name>)
lane agent  ── PR, tests tagged by scenario ──► QA verifies (scenario coverage, negative checks, privacy)
QA          ── verdict ──► Orchestrator integrates ──► PO approves merge (same day)
anything that changes behaviour ──► Spec (delta) ──► PO approves ──► lane resumes
```

* **One change per lane at a time.** A lane blocked on a decision picks the next task of its own change, never another lane's.
* **Shared contract first.** On day 2 Core publishes the money and canonical-model types (T1.1–T1.2); Ninox and Mobile code against them from then on. It is the only coupling between lanes in week 1.
* **Daily status, one file.** The orchestrator writes `docs/Plan/status/<date>.md` by 17:00 Madrid: done, blocked, **approvals waiting for the PO**, risks. Same-day approval means the PO clears that queue before the next morning.
* **Token isolation.** The Ninox agent runs live tests on the PO's machine. The token never enters CI, since the repository is public. CI runs contract tests on sanitised recorded responses only.

### 7.3 Runtime and skills (DEC-011)

* **Orchestrator — Claude Code.** The product owner works in Claude Code; the orchestrator is that session. `CLAUDE.md` imports `AGENTS.md`; its skills are in `.claude/skills/` (`ninox`, `dart-run-static-analysis`, `dart-collect-coverage`), discovered natively.
* **The other five — LangGraph, through `deepagents` 0.7.19.** Each lane is built by `agents/lanes/factory.py` with its own model, its worktree as filesystem root, its skills mounted read-only at `/skills/`, and write permission only under its `writes` paths (`agents/roles.yaml`).
* **Skills are stored once** in `agents/skills/` and assigned per role in `agents/roles.yaml`; `agents/tools/sync_skills.py` materialises each subset (`--check` in CI). deepagents' `SkillsMiddleware` gives progressive disclosure: names and descriptions in the prompt, full `SKILL.md` on demand. Proven by `agents/tests/` (9 tests, no API call): every lane is told about exactly its skills and cannot write outside its paths.
* **Not built yet (T0.9):** the lane runner around the factory — shell execution, git worktrees, the report back to the orchestrator, checkpointing. File permissions do not bind a shell, so the orchestrator's diff review is the enforcement once a shell exists.

### 7.4 Why five agents and not more

A sixth coding lane would share files with Mobile: review and history screens sit on top of the same store and navigation. Parallelism beyond three coding lanes buys merge conflicts, not speed. The bottleneck the extra agent cannot remove is the product owner's review. §9.2 is built around that.

### 7.5 Models — final selection (PO, 2026-09-25)

| Agent | Model | Why |
| --- | --- | --- |
| Orchestrator | Opus 5.5 | Where a wrong decomposition is most expensive |
| Spec | Atria Dawn Preview | Already validated by the PO on the Bearingworld project; text-only is no constraint for specs |
| Core | DeepSeek-V4-Pro-0813 | Raised from Flash: the deterministic layer is where a silent error costs most |
| Ninox, Mobile | DeepSeek-V4.1-Flash | Fast and cheap; errors surface in tests and in QA |
| QA | Sonnet 5 | A different model family from the coders, so it does not share their blind spots |

The provider model identifiers are **TO-CONFIRM** in `agents/roles.yaml` and are checked against each provider's documentation in T0.9, before first use. API keys (`ANTHROPIC_API_KEY`, `DEEPSEEK_API_KEY`, `ATRIA_API_KEY`) come from the Windows user environment, never from a file.

Still worth re-evaluating in week 3, not blocking: **agent-device** for QA on the physical Android phone over adb (DEC-004 discarded it on macOS grounds).

---

## 8. Method: OpenSpec for implementation

### 8.1 Tool version — measured, not assumed

Measured on 2026-09-25 on throwaway copies of `openspec/`:

| Version | `skip_specs: true` in `.openspec.yaml` | `archive --skip-specs -y` | Existing specs with `validate --all --strict` |
| --- | --- | --- | --- |
| 1.4.1 (in use) | **Not honoured**: a change with no delta fails validation | Works; the warning is non-blocking | Green |
| 1.13.2 (latest) | Honoured: "zero deltas accepted" | — | Green (plus an informational note on long requirement text) |

**Recommendation (T0.1):** pin 1.13.2, re-run the measurements of `openspec/project.md` §5 on it, and record the result there. If the product owner prefers to stay on 1.4.1, implementation changes are archived with `--skip-specs -y` and their red `validate` is recorded as an accepted deviation in `openspec/AGENTS.md`.

### 8.2 One change per increment

| Kind of change | Spec delta | Files |
| --- | --- | --- |
| Implements already-specified requirements | none — `skip_specs: true` | `proposal.md` (requirement names satisfied, parts deferred), `design.md`, `tasks.md` |
| Changes behaviour | `MODIFIED` / `ADDED` / `REMOVED` per `openspec/project.md` §4 | as above plus `specs/<capability>/spec.md` |

Rules: tasks of at most one day in this plan; a task is done when its tests pass and are tagged with the scenario they prove; archive ritual unchanged. **Measured on a dry run:** archiving a `MODIFIED` change keeps `Purpose`, `Out of Scope`, `Cross-Capability References` and `Open Questions`; only the archive that *creates* a spec drops them.

### 8.3 Changes of the MVP

| # | Change | Lane | Week |
| --- | --- | --- | --- |
| 0 | `resolve-mvp-planning-gaps` (**written and validated; awaiting approval**) | Spec | W1 Mon |
| 1 | `setup-mvp-foundations` | Orchestrator + QA | W1 |
| 2 | `implement-core-model-and-countries` | Core | W1–W2 |
| 3 | `implement-validation-and-extraction-core` | Core | W2 |
| 4 | `implement-ninox-client` | Ninox | W1 |
| 5 | `implement-setup-wizard` | Ninox | W1–W2 |
| 6 | `implement-send-pipeline` | Ninox | W2 |
| 7 | `implement-android-capture-and-store` | Mobile | W1 |
| 8 | `close-adr-011-pdf-text-route` | Mobile | W2 |
| 9 | `implement-photo-route` (ADR-010 screening) | Mobile | W2–W3 |
| 10 | `implement-review-history-duplicates` | Mobile | W3 |
| 11 | `integrate-mvp-alpha` | Orchestrator + all | W3 |
| 12 | `validate-mvp` | QA + PO | W4 |

---

## 9. Milestones, tasks, dates and deliverables

### 9.1 Calendar

```
            Mon 28 Sep ─ W1 ─ Fri 2 Oct │ Mon 5 ─ W2 ─ Fri 9 Oct │ Mon 12 ─ W3 ─ Fri 16 Oct │ Mon 19 ─ W4 ─ Fri 23 Oct │ buffer to 30 Oct
Orchestr.   M0 foundations ────────────┼─ integration plan ─────┼─ INTEGRATION → ALPHA ────┼─ fix loop, MVP report ───┤
Spec        change 0 ───────────────────┼─ deltas on demand ─────┼──────────────────────────┼─ findings → deltas ──────┤
Core        model · countries · digits ─┼─ solver · confidence ──┼─ fixes from integration ─┼──────────────────────────┤
Ninox       client · wizard ────────────┼─ send · reconciliation ┼─ live tests · fixes ──────┼──────────────────────────┤
Mobile      shell · scanner · intake ───┼─ ADR-011 · PDF · OCR ──┼─ review · history · ADR-010┼─────────────────────────┤
QA          CI · privacy · tags ────────┼─ contracts · negatives ┼─ benchmark · device QA ──┼─ sessions · triage ──────┤
```

### M0 — Foundations · Mon 28 – Tue 29 Sep

| Task | Owner | Content | Done when |
| --- | --- | --- | --- |
| T0.1 | Orchestrator | Verify repository root (`AGENTS.md` §1.1); pin OpenSpec (§8.1) and re-measure | Result in `openspec/project.md` §5 |
| T0.2 | Spec + PO | ~~Approve and archive `resolve-mvp-planning-gaps`~~ | **Done 2026-09-25** |
| T0.3 | QA | CI: analyze, format, test, coverage; **privacy job** (corpus paths, identifiers, token-like strings); **job failing on any mention of `NINOX_DB_ID`** (GAP-012) | CI green on the empty workspace |
| T0.4 | PO | Move `tools/` and `sql/` to `Paperdrop_corpus` (GAP-017) | Folders gone from the tree |
| T0.5 | Orchestrator | Dart workspace per §5, lints, README dependency declaration (NFR-LIC-001), applicationId (DEC-006) | App builds and runs on the PO's phone |
| T0.6 | Ninox + PO | ~~Correct `ninox-agent-skill` and re-vendor it~~ | **Done 2026-09-25** (commit `4c14ee4`, pinned in `THIRD-PARTY-NOTICES.md`) |
| T0.7 | QA | Feedback templates of §10; scenario-tag coverage script | First report generated |
| T0.8 | QA + PO | Private corpus convention and ground truth for the 16 documents (Funcional §10.3) | 16 documents annotated, PO-confirmed |
| T0.9 | Orchestrator | **Lane runner** around `agents/lanes/factory.py`: confirm the provider model ids in `agents/roles.yaml`; shell execution and git worktree per lane; a structured report back to the orchestrator; LangGraph checkpointer; `sync_skills.py --check` in CI. Smoke test: each lane answers a one-line task with its real model | Every lane runs a real task on its model |
| T0.10 | Orchestrator | Encoding guard: a CI job that fails on double-encoded text (`Â§`, `â€`) in `*.md` and inside `.docx` XML (GAP-024 must not come back). Allowlist only the lines that *describe* the defect: DEC-010, GAP-024, and §6.3 and this row of the plan | CI job green |

**Gate M0 (Tue 29 Sep):** foundations merged; lanes open Wednesday. Core may start T1.1 on Tuesday, since it needs only the package skeleton.

### M1 — Parallel build · Wed 30 Sep – Fri 9 Oct

**Core lane**

| Task | Content | Req |
| --- | --- | --- |
| T1.1 | Money and rate types (minor units, ISO 4217 exponent, basis points) — **shared contract, day 2** | BR-09 |
| T1.2 | Canonical model, provenance, field states, `surcharges[]` per Funcional §6.1.2 — **shared contract** | FR-EXT-011 |
| T1.3 | Country table ES + DE; check digits EAN-13, IBAN, `ES_NIF`, `ES_NIE`, `ES_CIF`, `DE_USTID` with standard vectors | FR-CTR-003, FR-CTR-004, FR-VAL-005 |
| T1.4 | Format inference; label and negative-context dictionaries EN/DE/ES | FR-CTR-005, FR-VAL-013, FR-EXT-010, FR-EXT-014 |
| T1.5 | Layout reasoning over positioned words; consensus by majority | FR-EXT-004 (logic), FR-EXT-006 |
| T1.6 | Amount solver: read all, derive by identity, legal-rate gate, suppression; currency evidence | FR-EXT-007 … FR-EXT-010, FR-EXT-013 |
| T1.7 | Confidence, repair, never-green rules, absent-not-zero; Annex D.1–D.5 as acceptance tests; the five failed documents as private regressions | FR-VAL-001 … FR-VAL-014 |

**Ninox lane**

| Task | Content | Req |
| --- | --- | --- |
| T1.8 | Port and classic adapter (host as configuration); contract tests; read-only check of `order`/`desc` (GAP-023) | ADR-003, FR-DST-008 |
| T1.9 | Live write tests under D-10; attachment size and timing from Spain (GAP-004) | GAP-004 |
| T1.10 | Token (system browser, paste, keystore); wizard steps with auto-omit; mapping (type filter, synonyms, strict threshold, absent setting, DEC-005 behaviour); summary | FR-WIZ-001 … FR-WIZ-008, FR-DST-006, FR-CFG-004 |
| T1.11 | Send: create → attach → read back; retry matrix; reconciliation; deep link | FR-SND-001 … FR-SND-006 |

**Mobile lane**

| Task | Content | Req |
| --- | --- | --- |
| T1.12 | App shell, navigation, externalised strings, semantic labels | NFR-I18N-001, NFR-ACC-001 (part) |
| T1.13 | Scanner → PDF; file picker; Android share intent; byte-for-byte storage and hash | FR-CAP-001 … FR-CAP-005 |
| T1.14 | Local store and document state machine | FR-HIS-001, FR-HIS-002 |
| T1.15 | **ADR-011 evaluation, decision by Tue 6 Oct**; PDF positional adapter | ADR-011, FR-EXT-004, NFR-SIZ-001 |
| T1.16 | OCR adapter (ML Kit) and multi-pass strategy | FR-EXT-006, FR-EXT-015 |

**QA lane:** contract fixtures review, negative checklist harness (Funcional §10.6), benchmark runner on device (Funcional §10.3).

**Demo, Fri 9 Oct:** the wizard reading the user's real teams, databases, tables and fields, and a send with read-back; the core green on Annex D; ADR-011 decided.

### M2 — Integration and alpha · Mon 12 – Fri 16 Oct

| Task | Owner | Content |
| --- | --- | --- |
| T2.1 | Orchestrator | Route selection and multi-page consolidation wired end to end (FR-EXT-001, FR-EXT-002, FR-EXT-012) |
| T2.2 | Mobile | Review screen (FR-REV-001 … FR-REV-011 in the cut, with DEC-007) |
| T2.3 | Mobile | History, retry, file retention, duplicates (FR-HIS-004, FR-HIS-005, FR-DUP-001, FR-DUP-002); foreground queue (FR-CAP-009 part) |
| T2.4 | QA | Negative release checklist automated |
| T2.5 | Mobile + QA | **ADR-010 screening, Wed 14 Oct**, on the photographed corpus |
| T2.6 | Orchestrator | Alpha on the internal testing track, **Fri 16 Oct** |

### M3 — Validation with users · Mon 19 – Fri 23 Oct

| Task | Owner | Content |
| --- | --- | --- |
| T3.1 | QA | Benchmark over both halves of the acceptance corpus (Funcional §10.1) |
| T3.2 | QA + PO | Supervised sessions, **Tue 20 – Thu 22 Oct**: median time and taps, untouched, green and abstention rates (Funcional §10.4) |
| T3.3 | QA → Orchestrator | Triage through §10; fix loop |
| T3.4 | Orchestrator + PO | Proposed thresholds (GAP-003), MVP report, R1 backlog by evidence — **Fri 23 Oct** |

**Buffer:** Mon 26 – Fri 30 Oct.

### 9.2 What the plan needs from the product owner, by date

| By | Input |
| --- | --- |
| Mon 28 Sep | ~~Approve `resolve-mvp-planning-gaps`~~ — approved and archived 2026-09-25 |
| Tue 29 Sep | Approve `setup-mvp-foundations` design; move `tools/` and `sql/` |
| Fri 2 Oct | Confirm the ground truth of the 16 documents |
| **Thu 1 Oct** | **PDF half of the acceptance corpus** in `Paperdrop_corpus` — needed before the ADR-011 decision of Tue 6 Oct (added 2026-09-25; the first version of this table missed it) |
| **Fri 9 Oct** | **~15 photographed documents** (thermal hospitality and fuel) **and ≥1 scanned PDF** in `Paperdrop_corpus`, as original camera files, never re-sent through a messaging app; confirm their ground truth by Mon 12. **Keep the paper originals until 23 Oct**: the ADR-010 screening re-captures them with the app's own scanner |
| Fri 9 Oct | 2–3 users booked for 20–22 Oct, each with a Ninox table they use |
| Every day | Clear the approvals queue in `docs/Plan/status/` |

A day lost on an approval or an input moves the milestone behind it by a day. The buffer week absorbs up to five.

### 9.3 Critical path

```
change 0 approved ─► T1.10 mapping
T1.1/T1.2 shared contract ─► every lane
T1.5 layout ─► T1.15 PDF adapter + ADR-011 ─► T2.1 integration ─► T2.6 alpha ─► T3.2 sessions
T1.6 solver ─► T1.16 OCR ─► T2.5 ADR-010 screening (needs the photographed corpus, Fri 9 Oct)
```

If the photographed corpus or the screening slips, the photo route moves to R1 without rework (v0.1 D-2) and the alpha ships with the invoice route alone.

---

## 10. Documentation system for errors, tests and improvements (handoff §2.3)

### 10.1 Where each kind of finding goes

| Finding | Recorded in | Flows to |
| --- | --- | --- |
| **Bug** — the app does not do what a spec scenario says | GitHub issue, template *Bug*, citing capability, requirement name and scenario | Fix + a regression test tagged with that scenario |
| **Spec gap** — the spec is silent, ambiguous or contradicts reality | `openspec/gaps-register.md` (GAP-nnn) and an issue linking to it | A spec change with a delta, then implementation |
| **Product change** — the PO decides to behave differently | `openspec/product-decisions.md` (DEC-nnn) | A spec change with a delta |
| **Improvement** outside v1 | Issue, template *Improvement*, label `R1`/`R2`/`later` | Release backlog; enters a change only when scheduled |
| **Measurement** — benchmark or session result | `validation/benchmarks/<release>.md`, `validation/sessions/<date>.md` | Thresholds (GAP-003), regressions become bugs |
| **Failing document** | Private corpus with ground truth — **never** the repository | A regression case in the private benchmark; a synthetic reproduction in the public tests where possible |

### 10.2 Templates to add in M0

* `.github/ISSUE_TEMPLATE/bug.md` — capability, requirement name, scenario, steps, expected (from the scenario), actual, build, device. A mandatory check: *"No real document, name, tax identifier, plate or card number is included."*
* `.github/ISSUE_TEMPLATE/spec-gap.md` — the ambiguity, the source identifiers, whether it blocks, proposed GAP text.
* `.github/ISSUE_TEMPLATE/improvement.md` — problem, evidence, proposed release.
* `validation/benchmarks/_template.md` — build, corpus version (hash, not content), per-field accuracy per route, green rate, abstention rate.
* `validation/sessions/_template.md` — anonymised participant code, document kind, seconds, taps, fields edited, observations.

### 10.3 Triage rule

```
Does the app contradict a spec scenario?          yes → Bug
Is the spec silent, wrong or ambiguous here?      yes → GAP → spec change
Does the PO want different behaviour?             yes → DEC → spec change
Is it outside the v1 scope of the functional?     yes → Improvement (R1/R2/later)
```

Nothing is fixed silently: a code change without an issue or a register entry is not accepted in review.

---

## 11. Test design

### 11.1 Scenario-tagged tests

Every test names the scenario it proves: `[setup-wizard/two-stage-matching-with-a-strict-threshold] below the threshold the field stays unmapped`. A script run in CI lists the scenarios in `openspec/specs/` and reports those with no test, producing `docs/Plan/test-traceability.md` on each run. The scenarios already written are the acceptance tests; they are not re-authored.

### 11.2 Test layers

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

### 11.3 Negative release checklist (Funcional §10.6), automated in W3

No backend call (network log contains only the configured Ninox host) · no schema mutation (no request to a schema-changing endpoint) · no credential beyond the token · no unmapped field key in any payload · no telemetry artefact in the build · no mail-body byte (R1, with `.msg`/`.eml`).

---

## 12. Agent skills (handoff §3.2)

Stored once in `agents/skills/` (26 skills: `ninox` and 25 `dart-*`/`flutter-*`, DEC-004), assigned per role in `agents/roles.yaml` (DEC-011), and loaded as described in §7.3. Four vendored skills are assigned to no role on purpose: the two FFI skills (no FFI in this product), `dart-use-primary-constructors` (raises the SDK floor, not decided) and `dart-migrate-to-checks-package` (only if `package:checks` is adopted). The `ninox` skill was corrected on 2026-09-25 to match the spike (T0.6).

---

## 13. Risks

| Risk | Effect | Mitigation |
| --- | --- | --- |
| Approvals slower than same day | Every milestone slips day for day | Daily approvals queue (§7.2); buffer week |
| Photographed corpus late | ADR-010 screening and photo route slip | Photo route moves to R1 without rework |
| ML Kit fails the screening | Photo route below threshold | Same; Tesseract evaluated in R1 |
| One phone for three lanes | Device contention in W2–W3 | QA owns a device slot schedule; the core and client need no device |
| Lanes diverge on shared types | Integration week lost | Shared contract on day 2; changes to it go through the orchestrator |
| An agent picks up `NINOX_DB_ID` | Test records in a production ERP | Prompt rule plus CI check (T0.3); only the Ninox agent holds the token |
| The skill misleads an agent | Wrong implementation of the mapping or paging | T0.6 before the Ninox lane starts |
| Private corpus leaks into the public repo | Personal data published | CI privacy job; corpus outside the tree |
| Scope creep | Dates slip | Anything outside §4 becomes an *Improvement* issue |

---

## 14. Housekeeping noticed (not acted on)

* Uncommitted as of 2026-09-25: everything produced in the planning step — `docs/Plan/`, `agents/`, `.claude/skills/`, `CLAUDE.md`, `THIRD-PARTY-NOTICES.md`, `docs/handoff.md`, the register and spec edits. `Ticket_reader_Ninox/` (an untracked folder inside the repository root) is still unexplained. The first commit of M0 should take the planning step as one reviewed commit, not mixed with code.
* A blank line inside the decisions table of `openspec/product-decisions.md` (between DEC-002 and DEC-003) split the table in two. It was removed when DEC-005 … DEC-009 were added.

---

## Annex A — What changed from v0.1

| Area | v0.1 | v0.2 |
| --- | --- | --- |
| Duration | 11 weeks + 1 buffer, to 11 Dec | ~4 weeks + 1 buffer, to 23 Oct (30 Oct with buffer) |
| Team | One full-time developer (assumed, not asked) | Five agents plus the PO, roles in §7 |
| Approvals | Within two working days | Same day, through a daily queue |
| GAP-022 | Proposed, options A/B/C | Resolved by measurement; DEC-005; spec change written |
| GAP-023 | Proposed, spike planned | Mostly resolved by the spike; ordering left to T1.8 |
| OpenSpec | `skip_specs` assumed | Measured: 1.4.1 no, 1.13.2 yes |
| Registers | GAP-022/023 added | Gaps closed or annotated per the PO's answers; GAP-024/025 added; DEC-005 … DEC-009 |
| Specs | — | Encoding of nine living specs repaired and verified (GAP-024); Funcional repaired (DEC-010) |
| Team and tooling | Profiles only | Concrete models; Claude Code orchestrator; LangGraph lanes via deepagents; per-role skills with tests (DEC-011) |
