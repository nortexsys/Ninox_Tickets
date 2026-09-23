# Proposal — supplier-memory

## Why

A supplier name is the one core field the product cannot confirm by arithmetic. Unlike a
total, which two independently read values can corroborate, a name has no identity to
check against — so the app has exactly one honest way to become sure of one, and it is
remembering it. That is what this capability is: the store that turns a second sighting of
a supplier into a confirmed name.

The whole value of the store rests on a single safeguard. If it were indexed by whatever
the recognition produced, a misread identifier would enter it, and later be presented to
the user as **confirmed** — the app would have laundered an uncertain reading into a
certainty, which is precisely the failure the product exists to avoid. So the memory is
indexed only by identifiers that passed their check digit (FR-MEM-002), and an identifier
that fails neither creates nor matches an entry, however plausible the name beside it.

And because the store holds supplier data the user may not want retained, its deletion has
to be real rather than a flag.

## What Changes

- Add one capability spec, `supplier-memory`, with **4 requirements**: FR-MEM-001…004.
- States the boundary explicitly: this capability owns the **store**, its indexing
  safeguard and its deletion; the rule that a supplier name may be shown as confirmed
  *only* from this store is `validation-confidence`'s (BR-11, FR-VAL-010) and is referenced
  rather than restated.
- **No behaviour changes.** Every requirement traces to FR-MEM.

## Capabilities

### New Capabilities

- `supplier-memory`: what the store learns and from where, the check-digit indexing
  safeguard, the name it offers on review, and genuine deletion.

### Modified Capabilities

- None. No approved specification's requirements change.

## Impact

- `openspec/specs/supplier-memory/spec.md` — new.
- No application code, dependency, schema or API is touched by this proposal.
- `validation-confidence` owns whether the name may be presented as confirmed;
  `countries-languages` owns the check-digit algorithm the safeguard applies;
  `local-config-privacy` owns exporting the store and clearing it as part of the wider
  data-clearing action.

---

## Spec type

Lite. Four requirements, all observable, and the failure they prevent — an uncertain
identifier becoming a confirmed name — is caught by the safeguard's own scenario rather
than by a subtle contract. The confidence semantics it depends on are owned by a
capability that already carries a Full spec.

## Problem statement

Names are read unreliably and cannot be corroborated by arithmetic. A store that
accumulates them from confirmed documents is the only way to reach certainty about one,
and it is also a new place where a wrong value can become durable. The safeguard has to be
structural — the store accepts only identifiers that passed their check digit — rather
than a matter of care at the point of use.

## Scope

### In scope

| Group | What it covers |
| --- | --- |
| What it learns (FR-MEM-001) | A local store of supplier identifier–name pairs, learned from documents the user has confirmed, holding no entry the user did not confirm |
| The safeguard (FR-MEM-002) | Indexed only by identifiers that passed their check digit. An identifier that fails neither creates nor matches an entry, even when the name beside it is plausible |
| Presentation (FR-MEM-003) | On review, the name the memory holds for a recognised supplier is offered |
| Deletion (FR-MEM-004) | A data-clearing action that genuinely empties the memory, after which no pair can be matched |

### Out of scope

- **Whether the name may be presented as confirmed.** `validation-confidence` owns that
  rule (BR-11, FR-VAL-010): a supplier name is presentable as confirmed only when this
  store supplies it from an identifier that passed its check digit. This capability owns
  the store that makes that possible.
- **The check-digit algorithms and the identifier types.** `countries-languages` owns
  them, including that the three Spanish formats never share code. The safeguard applies
  a validator; it does not define one.
- **Exporting and clearing the store as part of a wider action.** `local-config-privacy`
  owns the configuration export and the local data clearing that includes this store.
  This capability owns that the memory's own clearing is genuine.
- **Where the name is displayed.** `review-screen` owns the field, its position and its
  colour; this capability supplies the candidate.
- **The document's provenance and confidence.** `extraction-pipeline` and
  `validation-confidence` own those.

## Source documents

- `docs/Fase 2. Define/Paperdrop_Funcional_v1.0_EN.md` §4.9 (FR-MEM-001…004), §5 BR-11,
  §6.3 (local stores).
- `docs/Fase 1. Discover/Paperdrop_PDR_v0.2_EN.md` §6.2 (what never reaches green),
  §11 (privacy and local stores).
- `docs/Fase 1. Discover/Paperdrop_ADR_v0.2_EN.md` — ADR-009 (the supplier memory and its
  check-digit safeguard).
- Record 1413 of the 16-document test, where a supplier name was read from a real receipt,
  and the fourth PDR principle on preferring an empty field to an invented one.

## Key design constraints

1. **The safeguard is structural, not careful.** Only an identifier that passed its check
   digit indexes or matches. A plausible name beside a failed identifier changes nothing.
2. **The store holds only what the user confirmed.** Learning from an unconfirmed document
   would make the memory a second recognition engine rather than a record of decisions.
3. **Deletion empties it.** After clearing, no pair can be matched and a previously
   recognised supplier is offered no longer — not hidden, not flagged, gone.
4. **The confidence rule lives elsewhere and is not restated.** `what-never-reaches-green`
   in `validation-confidence` owns what may be shown as confirmed. A second copy of that
   rule here would be a copy that drifts.
5. **No invented content.** The functional does not specify the store's file format, its
   size limits or its matching beyond the identifier. Where the export is concerned,
   `local-config-privacy` owns what the file contains.

## Open questions at proposal stage

- **None blocking.** GAP-005 (a choice field outside its options) touches
  `destinations-mapping`; GAP-004 (upload limits) touches `ninox-send`; GAP-001 and
  GAP-002 touch the extraction routes. None bears on this capability.
- **To confirm while reviewing:** whether the memory should be learned from *sent*
  documents or from *user-confirmed* ones. The functional says "documents the user has
  confirmed" and its acceptance says the store contains no entry the user did not confirm.
  This proposal reads that as the user having accepted the value — which, given
  `never-block-a-save`, can include saving a document the app read poorly. If the product
  owner means "confirmed" more narrowly — only documents whose fields were not corrected —
  that narrows `the-memory-learns-supplier-pairs` and is worth settling before the spec is
  implemented, because the two readings diverge exactly when a name was wrong.
