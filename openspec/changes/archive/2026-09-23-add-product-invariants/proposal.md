# Proposal — product-invariants

## Why

Every other capability in the tree describes what the app **does**. None of them
describes what the app must **never** do — and the functional states those as
normative, testable requirements: §1.2 re-expresses the PDR's non-goals as
negative requirements and commits the acceptance corpus of §10 to a negative check
for each of them. Three business rules, BR-09, BR-16 and BR-19, are also not owned
by any `FR-` module.

Without a home these end up in one of two states, and both are bad: unverified
because nobody's spec covers them, or restated inside whichever capability happens
to touch them — and an invariant restated in three places is an invariant that
drifts. This capability is the single home.

## What Changes

- Add one capability spec, `product-invariants`, with **13 requirements**: ten
  from the §1.2 negative list — its two items on schema and on records the app did
  not create are the same statement and are carried as a single requirement — plus
  BR-09 as a representation invariant, plus the two lines of the §2.4 technical
  contract that no `FR-` module carries (line 2, no user data leaving the device,
  and line 5, proprietary dependencies declared).
- It also establishes the spec format every later capability copies: `Purpose`,
  `ADDED Requirements` with `[Origen: …]` traceability and GIVEN/WHEN/THEN
  scenarios, `Out of Scope`, `Cross-Capability References`, `Open Questions`.
- **No behaviour changes.** Every requirement traces to a statement already
  approved in the functional, the PDR or the technical contract. This capability
  gives them a testable form and one owner, and adds nothing.

## Capabilities

### New Capabilities

- `product-invariants`: the invariants that no `FR-` module owns — the v1 scope
  boundary as testable "the app never…" statements, the credential invariant, the
  schema-and-records invariant, and the representation invariant for money and
  tax rates.

### Modified Capabilities

- None. This is the first capability; `openspec/specs/` is empty.

## Impact

- `openspec/specs/product-invariants/spec.md` — new.
- No application code, no dependency, no schema and no API is touched.
- Every other capability in the tree cites this one instead of restating a rule
  it owns. `validation-confidence` and `capture-intake` reference it for the two
  contract lines whose mechanism they own.

---

## Spec type

Lite.

## Problem statement

Paperdrop writes records into a third party's business system — the user's own
Ninox database — from a device the app does not control, with no backend and no
account. That shape makes a small set of statements non-negotiable, and every one
of them is a statement about restraint rather than about capability: what the app
will not store, will not send, will not read and will not touch.

They are also the easiest requirements in the project to lose, precisely because
nobody builds them. A feature is visible in the interface; a boundary is visible
only when it is crossed. The functional put them in §1.2 as normative negative
requirements for that reason.

## Scope

### In scope

| Group | What it covers |
| --- | --- |
| v1 scope boundary | No desktop application · no backend service and no Paperdrop account · header-level records only, never line items · no reporting, reconciliation or export beyond the configuration file · no multi-user or team features · no cross-device synchronisation · no telemetry in public builds |
| Third-party system | The app never creates, renames or deletes fields or tables, and never deletes or modifies a record it did not create (BR-16) |
| Credentials and data | The Ninox API token is the only credential and no username or password is ever requested, stored or transmitted (BR-19); no user data leaves the device except toward the user's own Ninox database |
| Reading restraint | A `.msg` or `.eml` container is never opened for its body; only the document attachment it carries is used |
| Representation | Money is an integer in the currency's minor unit and tax rates are integers in basis points, in the model, the local store **and** the Ninox payload (BR-09) |
| Declared dependencies | Every proprietary dependency is declared in the repository README |

### Out of scope

- **The mechanism behind each invariant.** This capability states the boundary and
  says who implements it; it does not describe the implementation. Byte-integrity
  of a received file is BR-17 and belongs to `capture-intake`; the token's storage
  is FR-CFG-004 (`local-config-privacy`) and its acquisition is FR-WIZ-003
  (`setup-wizard`); the confidence principle of contract line 4 is
  `validation-confidence`.
- **Anything the app does.** Positive behaviour belongs to the capability that
  owns the module: capture, extraction, validation, review, destinations, send,
  history, memory, wizard, configuration.
- **The per-field tolerance rule.** BR-09 carries both a representation invariant
  and a tolerance. The invariant is here; the tolerance (`base × rate ≈ tax`, at
  most one minor unit per tax line) is FR-VAL-006 in `validation-confidence`.
- **Legal or licensing advice.** The README obligation is a requirement on the
  repository, not an assessment of any particular licence.

## Source documents

- `docs/Fase 2. Define/Paperdrop_Funcional_v1.0_EN.md` §1.2 (the negative
  requirements, declared normative and testable), §2.4 (the eight lines of the
  technical contract, with their traces), §5 BR-09, BR-16, BR-19.
- `docs/Fase 1. Discover/Paperdrop_PDR_v0.2_EN.md` §3.2 (non-goals), §4 (product
  principles), §11 (privacy claim), Annex A (technical contract, eight lines).
- `docs/Fase 1. Discover/Paperdrop_ADR_v0.2_EN.md` — ADR-002 (no backend, no
  account), ADR-007 (a file attaches to the record, not to a field), ADR-016
  (integer minor units), ADR-018 (token through the system browser).

## Key design constraints

1. **These are requirements, not intentions.** Each one is written so that a
   negative check can fail loudly. §1.2 already commits the acceptance corpus of
   §10 to one negative check per statement; this spec is where each check has a
   named requirement to attach to.
2. **Stated once, referenced elsewhere.** The nine boundary decisions in
   `openspec/project.md` §3.3 and the business-rule ownership map in §3.4 name
   this capability as owner for exactly BR-09, BR-16 and BR-19. No other spec may
   restate them; it references them.
3. **A contract line with no `FR-` module still needs an owner, and the mapping
   is not one-to-one.** Of the eight contract lines of §2.4: lines **1, 2, 3, 5
   and 7** live wholly here; line **6** is split three ways and this capability
   owns only its schema-and-records half, while "never write an unmapped field" is
   BR-15 in `destinations-mapping` and "never retry a create blindly" is BR-21 in
   `ninox-send`; line **4** is `validation-confidence` (BR-01, BR-02, BR-05); line
   **8** is `capture-intake` (BR-17). Five wholly here, one split, two elsewhere —
   written down so that the lines that do *not* live here cannot be forgotten,
   which is what almost happened to line 2 before this list existed.
4. **No invented detail.** Where a statement's enforcement point is genuinely
   undecided, it is not guessed: it becomes an `Open Question` and an entry in the
   gaps register. The three `FR-` modules that could be expected to own some of
   this material are named, and their boundaries are already fixed in §3.3.

## Open questions at proposal stage

- **None blocking.** Two existing entries in `openspec/gaps-register.md` bear on
  this capability and neither prevents it being written:
  - **GAP-011** (name availability) — the product's name appears in no requirement
    here; it is a project matter.
  - **GAP-012** (`NINOX_DB_ID` pointed at a production database) — this capability
    is where the credential invariant is stated, so the operating rule that
    forbids that variable is worth recording as a scenario rather than assumed.
- **For the product owner to confirm while reviewing:** whether "no reporting,
  reconciliation or data export beyond the configuration file" should also forbid
  *reading* the record back for display after send, which FR-SND-001 requires.
  The reading is an explicit part of the send pipeline (BR-18), so this spec's
  reading is that the prohibition is on *features offered to the user*, not on the
  app's own read-back. Worth confirming before the spec is written, because the
  two statements otherwise look like they contradict each other.
