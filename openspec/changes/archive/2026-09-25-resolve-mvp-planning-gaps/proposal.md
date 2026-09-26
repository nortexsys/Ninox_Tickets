# Change: resolve-mvp-planning-gaps

## Why

The MVP planning step (`docs/Plan/Paperdrop_MVP_Plan_v0.2_EN.md`) closed four gaps whose
resolution changes what an approved requirement says. The functional is not edited
(`AGENTS.md` §1.6); the resolutions are recorded in `openspec/product-decisions.md` and
carried into the living specs by this change.

* **GAP-022 → DEC-005.** Four requirements assumed that the table schema *marks* formula and
  read-only fields. It does not. A read-only spike on 2026-09-25
  (`docs/Plan/SPIKE_GAP-022_schema_formula_fields.md`, test base `jd1m8n8l4j7i`, GET only)
  measured that the classic table listing **omits** formula fields altogether — 727 of 2,143
  fields, with no exception, per table — while the database schema carries them with an `fn`
  key. No read-only marker exists anywhere. The product owner's rule is that formula fields
  must never appear in the app. That rule is now implementable exactly; the read-only half is
  not, and is handled through the existing retry matrix rather than an invented marker.
* **GAP-019 → DEC-007.** Whether editing an amount after a passing check re-expands the
  amounts block. Decided: the block stays as the check left it, and the edited value is
  marked as edited.
* **GAP-018 → DEC-008.** What "confirmed" means for the supplier memory. Decided: a pair is
  learned only from a supplier name the user typed or corrected; a name the user left
  untouched is not learned.

## What Changes

* `destinations-mapping` — MODIFIED `formula-and-read-only-fields-are-not-mapping-candidates`.
* `setup-wizard` — MODIFIED `table-listing-returns-the-schema` and
  `two-stage-matching-with-a-strict-threshold`.
* `review-screen` — MODIFIED `amounts-block-collapse-rule` and `user-edits-are-authoritative`.
* `supplier-memory` — MODIFIED `the-memory-learns-supplier-pairs`.

No requirement is added, removed or renamed. Requirement names are kept, including the words
"read-only" in `formula-and-read-only-fields-are-not-mapping-candidates`, so that every
cross-reference in the other ten specs stays valid.

## Capabilities

- `destinations-mapping`
- `setup-wizard`
- `review-screen`
- `supplier-memory`

## Spec type

Lite — all four capabilities are Lite in `openspec/project.md` §3.1.

## Impact

* **Endpoint choice is design, not spec.** The requirements state the observable behaviour:
  a formula field never reaches the mapping. Whether the implementation relies on the table
  listing's omission or on the schema's `fn` key is recorded in the plan and belongs to
  `design.md` of `implement-setup-wizard`.
* **`ninox-agent-skill` is now partly wrong.** Its `references/rest-api.md` and
  `references/schema-and-fields.md` state that no formula marker and no paging exist. Both
  were measured on the wrong endpoint or with the wrong parameter names. The skill and its
  vendored copy in `.dsh/skills/ninox` must be updated before an implementation agent reads
  them (plan task T0.6).

## After archive

Measured on a throwaway copy of `openspec/` with OpenSpec 1.4.1 on 2026-09-25: archiving this
change applies six `MODIFIED` requirements, keeps every other requirement, and — unlike the
archive of a change that *creates* a spec (`openspec/AGENTS.md` §4.1) — keeps `Purpose`,
`Out of Scope`, `Cross-Capability References` and `Open Questions` intact.
`openspec validate --all --strict` stays green afterwards.

Two `Open Questions` entries then describe questions this change answers, and must be
rewritten by hand, without retyping any requirement:

1. `review-screen` — the entry "An interaction the functional does not settle" (GAP-019):
   replace with a pointer to DEC-007 and the new scenario of `amounts-block-collapse-rule`.
2. `supplier-memory` — the entry "To confirm while reviewing" (GAP-018): replace with a
   pointer to DEC-008. Note that the reading adopted is **neither** of the two the entry
   described: a pair is learned from a name the user typed or corrected, and never from an
   untouched one.

Then mark GAP-018, GAP-019 and GAP-022 `CERRADO` in `openspec/gaps-register.md` with a
pointer to the archive folder.
