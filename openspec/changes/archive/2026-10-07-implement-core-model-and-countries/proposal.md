# Change: implement-core-model-and-countries

## Why

Every lane of M1 codes against the same two things: how money and rates are represented, and what
an extracted document looks like. If Ninox builds a payload and Mobile builds a store before those
exist, each invents its own, and the first integration (plan §9, M2) finds three representations of
one amount. Plan v0.2 §7.2 makes this the only coupling between lanes in week 1: Core publishes the
money and canonical-model types (T1.1–T1.2) first, and the other lanes code against them.

The same change then lays the country data the reading layer stands on (T1.3–T1.4): the ES and DE
rows of the country table, the check-digit algorithms, format inference and the label dictionaries.

## What Changes

An **implementation-only change** (`skip_specs: true`, plan §8.2). No requirement is added,
modified, removed or renamed, and no living spec is touched. All code goes in
`packages/paperdrop_core/`.

* **T1.1 — money and rate types** (design §2): an amount is an integer in its currency's minor
  unit, with the ISO 4217 exponent taken from a table and never assumed; a rate is an integer in
  basis points; arithmetic is exact and never passes through a floating-point value.
* **T1.2 — canonical model** (design §3): the fields of Funcional §6.1.1 and §6.1.2, each value
  carrying one of the four provenance tags and a confidence state, the explicit absent and
  `not_in_xml` states, the edited marker, tax slots and `surcharges[]` as `{ label, amount_minor }`.
* **T1.3 — country table ES + DE and check digits** (design §4, detailed before its dispatch).
* **T1.4 — format inference and dictionaries EN/DE/ES** (design §5, detailed before its dispatch).

## Requirements implemented

Identifiers as the functional spells them; the requirement name is the one that owns the behaviour
in `openspec/specs/`.

* **BR-09** — `product-invariants` · `money-as-integer-minor-units`: the representation half, inside
  the core. The local store and the payload halves are Mobile's and Ninox's, built on these types.
* **FR-EXT-011** — `extraction-pipeline` · `provenance-on-every-value`: the model makes an untagged
  value unrepresentable. That provenance never reaches the payload is proven when Ninox builds it.
* **FR-EXT-010** (the `surcharges[]` shape only, GAP-020) — the entry shape of Funcional §6.1.2. The
  suppression rule that fills it is T1.6.
* **T1.3–T1.4:** FR-CTR-003, FR-CTR-004, FR-VAL-005, FR-CTR-005, FR-VAL-013 (format side),
  FR-EXT-010 and FR-EXT-014 (dictionaries). Listed in full when design §4–§5 are detailed.

## Gaps and decisions this change acts on

* **GAP-020** (closed) — `surcharges[]` implemented exactly as Funcional §6.1.2.
* **GAP-027** (opened and closed 2026-09-28, DEC-013) — PRE-006 said the canonical model is *not*
  extended with a document subtype or a double currency; Funcional §6.1.2 and two living specs carry
  `doc_subtype`, `gross_total_document_currency` and `gross_total_card_currency`. The product owner
  ruled that the functional governs. The three fields are outside the MVP cut (plan v0.2 §2: the MVP
  maps the six core fields plus `net_total` and `tax_total`, no `choice` field), so they are added
  in R1, after the MVP.
* **GAP-028** (opened and closed 2026-09-28) — Funcional §6.1.1 lists "memory" as a provenance of
  `supplier_name`, while FR-EXT-011 and §6.2.1 define four tags. The product owner ruled that the
  functional is the source of truth and nothing is changed; the model keeps the four tags and records
  the value's source (document, memory, user) apart, which satisfies both statements.

## Deferred

* The confidence *rules* (which state a value earns) are T1.7; the model only holds the state.
* The tolerance of FR-VAL-006 (`base × rate ≈ tax`, one minor unit per tax line) is T1.7. T1.1
  offers the exact product, not a rounding policy.
* Serialisation for the local store is Mobile's (T1.14); the Ninox payload is Ninox's (T1.11).

## Impact

`packages/paperdrop_core/` only. No living spec changes; no functional change.
`openspec validate implement-core-model-and-countries --strict` passes with zero deltas.
