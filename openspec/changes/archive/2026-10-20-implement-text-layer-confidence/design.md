# Design: implement-text-layer-confidence

Normative text: `validation-confidence` · `three-confidence-strengths` and `extraction-pipeline` ·
`consensus-by-majority` as archived on 2026-10-17 (read them first). DEC-018 in `product-decisions.md`.

## 1. Where the change lands

`consensus.dart` keeps `Single` meaning "one reading". The decision is in `extract_document.dart`,
at `_finalizeConfidence`: today `green && !agreed → amber`. New rule, applied per field:

* `agreed == true` → unchanged.
* `agreed == false`, route is text-layer (all passes `pdf-text`), the field has `Provenance.read`, **and**
  the field takes part in at least one identity that was **checkable** (every operand read, none derived)
  **and passed** (`CheckOutcome.passed`) → the state `assignConfidence` computed may stand (green).
* anything else → amber as today.

## 2. What "checkable and holds" means in code

Identities are the ones Core already has: base + tax = total (`sumMatchesTotal`, exact), tax within the
one tolerance of base × rate (`taxWithinTolerance`). A value qualifies when an identity it is an
operand of has `CheckOutcome.passed`. A lone total with no other printed figure has `CheckOutcome.none`
→ amber. A failed identity → `CheckOutcome.failed` → lowers confidence exactly as today, route
irrelevant. A derived operand never counts (PRE-008, BR-05): if any operand of the identity is
`derived`, the identity is not checkable for confirmation.

Non-amount fields (date, supplier tax id, currency, document number) have no identity of their own: they
stay amber from a text layer unless a check in `validation-confidence` already confirms them. Do not
invent identities for them.

## 3. Tests (host, `dart test` per package)

One test per scenario of the two modified requirements (6 in `validation-confidence`, 2 in
`extraction-pipeline`), plus: `pdf-mixed` never qualifies; OCR with the same numbers stays amber; a
text-layer total alone is amber; base + tax = total passing makes all three green; one off by one
minor unit fails and is not green; derived base blocks green; document `needsReview` follows.
Existing tests that assert "single pass is never green" are updated **only** for the text-layer case,
and each change is listed in the lane report.

## 4. Checks

`dart analyze`, `dart format`, `dart test` in `packages/paperdrop_core`, `privacy_check`, `core_purity`
at 0 findings. No device, no Ninox, no token. `app/` untouched (the app's own tests are re-run by the
orchestrator after the merge).
