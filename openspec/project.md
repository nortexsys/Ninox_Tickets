# Paperdrop for Ninox — Project context

This is the OpenSpec project context file. It is read before writing or reviewing
any specification. It answers three questions: what the project is, which
document is the source of truth for a given statement, and what shape a spec
must have to be accepted here.

---

## 1. What the project is

**Paperdrop for Ninox** is a free, open-source Android and iOS application,
published by Nortex Systems. It reads receipts and supplier invoices **on the
device** and writes **one record per document** into the user's own Ninox
database, with the original document attached.

It is a complement to Ninox, not a substitute. It puts documents in and does
nothing else. There is **no backend, no Paperdrop account, and no call to a
hosted model**.

The distinguishing asset is not reading but the **deterministic layer above
reading**: check digits, arithmetic over independently read values, legal-rate
checks and negative-context suppression confirm or correct a reading instead of
trusting it. This is the thesis the whole specification exists to protect, and
it is the reason provenance (`read` / `derived` / `repaired` / `from_xml`)
governs which check may confirm anything.

Intended repository: `github.com/nortexsys/Ninox_Tickets` — **public**.
All application code and all project documentation are written in **English**.

---

## 2. Source of truth — which document owns which statement

Statements in a spec must be traceable. When two documents disagree, the higher
row wins, and the disagreement is recorded in `openspec/product-decisions.md`.

| Priority | Document | Owns |
| --- | --- | --- |
| 1 | This repository's ADRs, `openspec/architecture/` | Architecture decisions taken after v0.2 |
| 2 | `docs/Fase 2. Define/Paperdrop_Funcional_v1.0_EN.md` | **The functional behaviour.** FR-/BR-/NFR-/UC- identifiers, screens, error taxonomy, acceptance criteria, Annexes A–E |
| 3 | `docs/Fase 1. Discover/Paperdrop_PDR_v0.2_EN.md` | Product definition: scope, principles, data model, confidence model, metrics |
| 4 | `docs/Fase 1. Discover/Paperdrop_ADR_v0.2_EN.md` | How the architecture decisions were taken. 19 records; 15 accepted, ADR-010 and ADR-011 still proposed |
| — | `docs/Fase 1. Discover/Funcional_App_NinoxTickets.md` | The original Spanish brief. **Superseded** by PDR v0.2. Retained for provenance only |
| — | `corpus_test/`, `REPORT-CORPUS.md` | Evidence. The product owner's per-record verdicts in `corpus_test/REPORT_after_review.md` are authoritative where they differ from the consultant's report |

**Rule.** A requirement that cannot cite one of these documents is not a
requirement. It is an invention, and it goes to `product-decisions.md` as a
decision to be taken, or to the gaps register as an open gap.

---

## 3. Capability tree

Decomposition of the functional into OpenSpec capabilities.

> **Status: proposed, pending product-owner approval.** Until the tree is
> approved, no `proposal.md` may be written against it. The definitive table
> with owning FR modules, dependency order and Lite/Full classification is
> recorded here on approval.

Naming: kebab-case, matching OpenSpec's convention
(`capture-intake`, `extraction-pipeline`, …). One capability owns one
`openspec/specs/<capability>/spec.md` and, while it is being written, one
`openspec/changes/add-<capability>/`.

---

## 4. Spec format — mandatory

A spec written here has these sections, in this order:

```
# <Capability Name> Specification

## Purpose
<One paragraph: the business problem this capability solves.>

---

## ADDED Requirements

---

### Requirement: <kebab-case-name>
The system SHALL <observable behaviour>.
[Origen: <document>, <FR-/BR-/NFR-/UC- identifier or section>]

#### Scenario: <name>
- GIVEN <context>
- WHEN <action>
- THEN <result>
- AND <additional result, if any>

---

## Out of Scope
- <behaviour excluded or deferred to a later version>

---

## Cross-Capability References
- `<capability>` — <what is invoked or depended on, and who owns it>

---

## Open Questions
- <gap, non-blocking, also recorded in the gaps register>
```

**Hard rules**

* Every requirement carries at least one scenario. No exceptions.
* Every requirement carries an `[Origen: ...]` tag naming the source document
  and the exact identifier. The tag is what makes the spec auditable.
* Scenarios use `####` — exactly four hashes. Three hashes silently fails to
  register as a scenario.
* Normative language: **SHALL** / **MUST** for mandatory, **SHOULD** for
  desirable, **MAY** for optional and explicitly not promised. `should` and
  `may` in lower case are not normative and must not carry behaviour.
* Requirement names are kebab-case and unique within the capability.
* Requirements are written in **English**. Identifiers (`FR-EXT-006`, `BR-09`,
  `UC-11`, `ADR-014`, `Annex B`) are reproduced exactly as the functional
  spells them — never translated, never renumbered.
* Money is an integer in the currency's minor unit. Tax rates are integers in
  basis points. Dates are `YYYY-MM-DD`. These are representation rules, not
  examples: a scenario that shows `19.99` for EUR is wrong.

### Delta specs inside a change

`openspec/changes/add-<capability>/specs/<capability>/spec.md` uses the
operation blocks `## ADDED Requirements`, `## MODIFIED Requirements`,
`## REMOVED Requirements`, `## RENAMED Requirements`. A `MODIFIED` block must
reproduce the entire existing requirement, scenarios included, or detail is lost
when the change is archived. `REMOVED` states **Reason** and **Migration**.

Every capability in the approved tree is new, so the first change of each is a
single `ADDED` block. The other operation blocks are supported for later use.

---

## 5. What `openspec validate --strict` actually enforces

Measured against `@fission-ai/openspec@1.4.1` with two throwaway probes
(`_convention-probe`, `_convention-negatives`), since a validator that accepts
everything is worth nothing.

| Rule | Enforced? |
| --- | --- |
| A requirement with no scenario at all | **Yes** — `ERROR: "<name>" must include at least one scenario` |
| `### Scenario:` with three hashes | **Yes, indirectly** — not recognised as a scenario, so the requirement fails as having none |
| Four-hash `#### Scenario:` | **Yes** — accepted |
| Non-bold `GIVEN` / `WHEN` / `THEN` / `AND` bullets | **Accepted** — the BearingWorld style passes strict validation |
| Bold `**WHEN**` / `**THEN**` bullets | **Accepted** |
| A scenario with only `THEN` and no `WHEN` | **No** — passes silently |
| A requirement with no SHALL / MUST keyword | **No** — passes silently |

**Consequence.** The validator guarantees structural integrity — every
requirement has at least one properly formed scenario — and guarantees nothing
about whether a scenario is complete or a requirement is normative. The last two
rows are enforced by review, not by the tool. A reviewer who relies on
`validate --strict` alone will let empty scenarios through.

---

## 6. Lite versus Full

* **Full** — reserved for capabilities where ambiguity is expensive or the
  failure is silent: the extraction pipeline's ordering and provenance rules,
  the confidence model, and the send pipeline's retry and reconciliation
  contract. Full specs carry a detailed error contract and explicit edge cases.
* **Lite** — everything else. Requirements stay behavioural: clear scope, few
  concrete acceptance scenarios.

The classification is recorded in each `proposal.md` under **Spec type**, as in
the reference project.

---

## 7. Registers

Two registers carry state that does not belong in a spec, and both are
append-only in spirit: an entry is closed, never deleted.

* `openspec/gaps-register.md` — one row per open hole or pending decision.
  `BLOQUEANTE` means the affected requirement cannot be written until it is
  resolved; `NO BLOQUEANTE` means the spec is written and the gap is recorded in
  its `Open Questions`.
* `openspec/product-decisions.md` — one row per decision taken during this phase
  that diverges from the approved functional. **The functional is not edited**;
  this register is the traceability layer between the two.

The gaps register carries an `Ámbito` column (`Spec` or `Proyecto`) so that
specification gaps and project-operational gaps live in one place without being
confused with each other.

---

## 8. Directory structure

```
04_01_Ticket_reader_Ninox/
├── openspec/                     ← the specifications. Source of truth for behaviour
│   ├── project.md                ← this file
│   ├── AGENTS.md                 ← how an agent must work in this project
│   ├── architecture/             ← ADRs taken during this phase
│   ├── changes/                  ← proposals in progress, one per capability
│   ├── changes/archive/          ← completed changes, after archive
│   ├── specs/                    ← approved capabilities, the living truth
│   ├── gaps-register.md
│   └── product-decisions.md
├── docs/                         ← source documents. Read-only reference
│   ├── Fase 1. Discover/         ← PDR v0.2, ADR v0.2, original brief
│   └── Fase 2. Define/           ← Funcional v1.0
├── corpus_test/                  ← the 16-document test. `out/` and `inbox/` never published
├── sql/                          ← prototype schema. Not published (carries a natural person's data)
├── tools/                        ← prototype scripts. Not published (same reason)
├── out/                          ← OCR experiments. Never published
├── AGENTS.md                     ← project working contract, read every session
└── .gitignore                    ← the confidentiality gate
```
