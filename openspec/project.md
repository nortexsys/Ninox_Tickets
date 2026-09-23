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

> **Status: approved by the product owner on 2026-09-23.** The table below is the
> decomposition written under that approval. A capability whose scope the product
> owner wants changed is amended **here**, before its proposal is written — not
> silently inside the proposal.

Naming: kebab-case, matching OpenSpec's convention. One capability owns one
`openspec/specs/<capability>/spec.md` and, while it is being written, one
`openspec/changes/add-<capability>/`.

The functional has 96 `FR-` requirements in 12 modules, 22 business rules, 18
non-functional requirements and 15 use cases. Twelve modules are not twelve
capabilities: three are too thin to stand alone, and the cross-cutting rules need
one owner each or they get written three times in three different wordings. That
is what produces contradictions between capabilities.

### 3.1 The tree

| # | Capability | Owns | Spec | ~Req |
| --- | --- | --- | --- | --- |
| 1 | `product-invariants` | The §1.2 negative requirements as testable "the app never…" statements, plus the invariants that **no FR module owns**: BR-09 (money as an integer in the minor unit, everywhere), BR-16 (never touch schema or records it did not create), BR-19 (the token is the only credential) | Lite | 13 |
| 2 | `countries-languages` | FR-CTR-001…007, **Annex B** (the country table: formats, check-digit algorithms and identifier types, legal rates, slots, rounding) and **Annex C** (keyword and negative-context dictionaries) | Lite | 11 |
| 3 | `capture-intake` | FR-CAP-001…009, BR-17 (byte integrity of a received file, carried by FR-CAP-005) | Lite | 9 |
| 4 | `extraction-pipeline` | FR-EXT-001…015, BR-06 (consensus by majority), BR-07 (derive by identity, never invent), BR-08 (legal rates and negative context gate tax candidates), BR-20 (dates come only from the document) | **Full** | 16 |
| 5 | `validation-confidence` | FR-VAL-001…014, BR-01 (determinism over coverage), BR-02 (a check confirms only if every operand was read), BR-03 (empty over false), BR-04 (never green without redundancy), BR-05 (derived values never raise confidence), BR-10 (the document number never reaches green), BR-11 (a supplier name is confirmable only via memory), BR-12 (currency carries its own evidence), BR-13 (absent is not zero) | **Full** | 15 |
| 6 | `destinations-mapping` | FR-DST-001…009, BR-15 (never write an unmapped field, carried by FR-DST-009), and **Annex A's mapping-facing rows**: names versus identifiers, choice fields, formula and read-only fields | Lite | 9 |
| 7 | `document-history` | FR-HIS-001…005 and **FR-DUP-001** (the duplicate *criteria* live with the store they are checked against, because the check is read-side) | Lite | 6 |
| 8 | `ninox-send` | FR-SND-001…008 — BR-18, BR-21 and BR-22 are carried by FR-SND-001, FR-SND-005 and FR-SND-002 respectively — and **Annex A's write-path rows**: payload shape, create response, merges, dates, error shape, retry policy, read-after-create, attachment upload | **Full** | 8 |
| 9 | `review-screen` | FR-REV-001…011, **FR-DUP-002** (the duplicate notice, the link and the permission to proceed, which is the same behaviour as FR-REV-007), and BR-14 (never block a save, carried by FR-REV-009) | Lite | 11 |
| 10 | `supplier-memory` | FR-MEM-001…004 | Lite | 5 |
| 11 | `setup-wizard` | FR-WIZ-001…008 | Lite | 8 |
| 12 | `local-config-privacy` | FR-CFG-001…004 and the whole NFR series: PRV-001…006, SEC-001…003, PRF-001…003, OFL-001, ACC-001, I18N-001, LIC-001, PLT-001, SIZ-001 | Lite | 22 |

Three capabilities are **Full**, by the same criterion as the reference project:
the failure is silent or expensive. They are `extraction-pipeline` (the pipeline
order and provenance are where the `derived_from_gross` tautology was born),
`validation-confidence` (the product's central claim, and the place where a wrong
rule confirms a wrong value without saying so) and `ninox-send` (a create whose
response was lost, retried blindly, puts duplicate records in a real ERP).

### 3.2 Recommended order

```
1. product-invariants          ← the contract every other spec cites; sets the format
2. countries-languages         ← the data (algorithms, legal rates, formats, dictionaries)
3. capture-intake              ← branch: independent of reading, needs only #1
4. extraction-pipeline         ← needs #1, #2
5. validation-confidence       ← needs #2, #4
6. destinations-mapping        ← needs #1, Annex A
7. document-history            ← needs #5, #6
8. ninox-send                  ← needs #6, #7 (history owns the state machine, send drives it)
9. review-screen               ← needs #5, #6
10. supplier-memory            ← needs #2, #5
11. setup-wizard               ← needs #6
12. local-config-privacy       ← needs #7, #10
```

`product-invariants` and `countries-languages` go first for a practical reason and
not a conceptual one: they are short, they are almost pure data and statement, and
they let the product owner validate the spec **format** on content where a mistake
costs little. The three Full capabilities then get full attention with the format
already agreed.

### 3.3 Boundary decisions taken here, so they are not re-argued per capability

Each of these is a place where two capabilities could both claim the same
behaviour. The owner is named; the other capability may only reference it.

| Shared behaviour | Owner | The other side |
| --- | --- | --- |
| *That* a check-digit validator runs and what its outcome does to confidence | `validation-confidence` | `countries-languages` owns *which* algorithm (NIF vs NIE vs CIF are three) and the identifier types |
| *That* a legal-tax-rate check gates a candidate | `validation-confidence` | `countries-languages` owns *which* rates are legal, per country |
| The **list** of negative-context terms | `countries-languages` (Annex C) | `extraction-pipeline` owns the **application rule** — what happens to a number found inside a suppressed term's influence radius (FR-EXT-010, BR-08). The radius parameter lives with the rule, not with the list |
| The prohibition on reading a message body | `product-invariants` (`never-read-message-body`, from the §1.2 negative list) | `capture-intake` owns the intake mechanism: what a container ingests, what happens when it carries no document attachment, and the attachment selection rule (FR-CAP-006, FR-CAP-007). The functional states this twice — once as a non-goal, once as a module requirement — so the split is inherited from the source and is made explicit here rather than left to whoever writes the spec second |
| **The legal-tax-rate check** | `validation-confidence` (FR-VAL-007, BR-08 first half) owns *that the check runs* | `countries-languages` owns which rates are legal; `extraction-pipeline` owns the **gate**, i.e. that no rate may be used for a derivation until the check has admitted it (FR-EXT-009). Three statements of one rule in the functional, split into three distinct jobs |
| **Currency** | `extraction-pipeline` (FR-EXT-013) owns **reading** it, from the printed ISO code, the symbol and the issuer country | `validation-confidence` (FR-VAL-009, BR-12) owns its **confidence state** and that an unsustained currency suppresses the amounts. Reading and trusting are different statements and the functional writes both |
| **Format inference, dates and `doc_date`** | `countries-languages` (FR-CTR-005) owns the **format-inference algorithm** — day greater than twelve, grouping pattern | `validation-confidence` (FR-VAL-013) owns **date coherence** and the ambiguous case; `extraction-pipeline` (BR-20) owns that `doc_date` is never taken from a filename or an email timestamp. Three owners, three statements, one subject |
| **`not_in_xml`** | `extraction-pipeline` (FR-EXT-003) owns **producing** the status, because the XML route is what discovers it | `validation-confidence` (BR-13, FR-VAL-012) owns **what the status means** for absent-versus-zero at the destination. `not_in_xml` is not the same claim as `absent`, and only validation needs to know the difference |
| **Check-digit validators** | `validation-confidence` (FR-VAL-005) owns that each validator exists, runs, and is accepted against the standard valid and invalid test vectors | `countries-languages` (Annex B.2) owns each **algorithm**, including that the three Spanish formats never share code. FR-CTR-004 and FR-VAL-005 state that separation twice; it is owned once, in `countries-languages`, and referenced here |
| The per-field "if absent, write 0" **setting** | `destinations-mapping` (FR-DST-006) | `validation-confidence` owns the principle that an absent value is not a zero (FR-VAL-012) |
| The duplicate **criteria** (hash; supplier + date + total) | `document-history` (FR-DUP) | `review-screen` owns only the notice and the link (FR-REV-007) |
| The document **state machine** | `document-history` (FR-HIS-002) | `ninox-send` drives the transitions; it does not define the states |
| Whether a supplier name may be shown as confirmed | `validation-confidence` (BR-11) | `supplier-memory` owns the store, the indexing safeguard and its deletion |
| Formula/read-only fields excluded from mapping, and the post-write formula contrast | `destinations-mapping` (FR-DST-004, FR-DST-005) | `ninox-send` performs the read-back that the contrast consumes |
| Interface language strings (EN/DE) | `local-config-privacy` (NFR-I18N-001) | `countries-languages` owns document dictionaries, which are independent of interface language (FR-CTR-006) |
| The consequence of a 500 (mapping error vs server error) | `ninox-send` (§9.3) | `destinations-mapping` owns what a valid mapping is |

### 3.4 Business-rule ownership — one home per rule

The 22 business rules are cross-cutting by design, and §5 of the functional
declares the catalogue normative: where a screen or a pipeline step appears to
conflict with a rule, the rule wins. That makes it tempting to restate them
wherever they bite — and restating a rule in two capabilities is how two
capabilities end up disagreeing.

Each rule therefore has **exactly one owning capability**. The owning spec writes
the requirement; the capability named in the last column implements it and may
only reference it.

| Rule | Owned by | Implemented by |
| --- | --- | --- |
| BR-01 determinism over coverage | `validation-confidence` | FR-VAL-014, FR-VAL-001 |
| BR-02 a check confirms only if every operand was read | `validation-confidence` | FR-VAL-002 |
| BR-03 empty over false | `validation-confidence` | abstention; FR-VAL-009, FR-VAL-012 |
| BR-04 never green without redundancy | `validation-confidence` | FR-VAL-001 |
| BR-05 derived values never raise confidence | `validation-confidence` | FR-VAL-002, FR-VAL-008 |
| BR-06 consensus by majority, never by maximum | `extraction-pipeline` | FR-EXT-006 |
| BR-07 derive by identity; never invent a rate | `extraction-pipeline` | FR-EXT-008 |
| BR-08 legal rates and negative context gate tax candidates | `extraction-pipeline` | FR-EXT-009, FR-EXT-010 |
| BR-09 integer minor units; one tolerance only | `product-invariants` *(representation)* | FR-VAL-006 *(the tolerance)* |
| BR-10 the document number never reaches green | `validation-confidence` | FR-VAL-010 |
| BR-11 a supplier name is confirmable only via memory | `validation-confidence` | FR-VAL-010 |
| BR-12 currency carries its own evidence | `validation-confidence` | FR-VAL-009 |
| BR-13 absent is not zero; the destination decides | `validation-confidence` *(the principle)* | FR-VAL-012; the setting is FR-DST-006, owned by `destinations-mapping` |
| BR-14 never block a save | `review-screen` | FR-REV-009 |
| BR-15 never write an unmapped field | `destinations-mapping` | FR-DST-009 |
| BR-16 never touch schema or records the app did not create | `product-invariants` | the §1.2 negative requirements |
| BR-17 byte-integrity of received files | `capture-intake` | FR-CAP-005 |
| BR-18 the record is always read back | `ninox-send` | FR-SND-001 |
| BR-19 the token is the only credential | `product-invariants` | §1.2 negative, §2.4 contract 3 |
| BR-20 dates come only from the document | `extraction-pipeline` | FR-VAL-013 *(format inference)* |
| BR-21 never blindly retry a create | `ninox-send` | FR-SND-005 |
| BR-22 the attachment is never a mapping target | `ninox-send` | FR-SND-002 |

Two rules are deliberately split, because the rule text contains two different
kinds of statement. **BR-09** states a representation invariant (money as an
integer in the minor unit, in the model, the local store *and* the payload) and a
tolerance rule; the invariant is project-wide and belongs to
`product-invariants`, the tolerance is a validation check. **BR-13** states a
principle (an absent value is not a zero) and a per-field configuration (which of
the two the user wants); the principle is `validation-confidence`, the setting is
`destinations-mapping`. In both cases the split is written down so a reader of
either spec can find the other half.

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
* **The first line of a requirement body must contain SHALL or MUST.** The strict
  validator reads only the first line as the requirement's text (§5), so a
  normative statement that begins on line 2 passes review and then fails
  validation. Found the hard way, on `countries-languages`.
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
| A requirement whose **first line** carries no SHALL or MUST | **Yes** — `ERROR: "<name>" must contain SHALL or MUST` |

**Consequence.** The validator guarantees structural integrity — every requirement
has at least one properly formed scenario, and a normative keyword on its first
line — and guarantees nothing about whether a scenario is complete. That last row
is enforced by review or not at all: a reviewer who relies on `validate --strict`
alone will let an empty scenario through.

**The first-line rule, and a correction to an earlier version of this table.** The
validator reads **only the first line** of a requirement body as that requirement's
text. Measured with `openspec change show <id> --json --deltas-only`:
`requirement.text` holds the first line and nothing after it. So a requirement
whose normative statement begins on line 2 fails validation, and one whose first
line happens to contain the word SHALL passes even if the rest of the body is not
normative at all. The full body is **not** lost — `openspec archive` carries every
line into the consolidated spec, verified on `product-invariants` — so this is a
validation and reporting artifact, not data loss.

An earlier version of this table recorded that SHALL/MUST was **not** enforced.
That was wrong, and it was wrong because the throwaway probe used to measure it was
flawed: the probe's requirement read *"This requirement deliberately avoids any
SHALL or MUST keyword"*, which contains both keywords. The probe tested nothing,
and its silence was recorded as a finding. Corrected here — and it is the reason a
rule in this project is measured before it is written down, including when the
measurement says what the author expected.

**A change with only a proposal cannot pass, and that is by design.** Measured on
the first change, `add-product-invariants`: with `proposal.md` present and no
delta spec, `validate --strict` fails with *"Change must have at least one delta.
No deltas found."* The proposal is reviewed **before** the spec is written, so a
change is legitimately red between those two moments. That is not a defect to work
around: validation belongs to the capability's definition of done
(`AGENTS.md` §4), not to the review of its proposal. Do not add a placeholder spec
file to make the red go away.

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
