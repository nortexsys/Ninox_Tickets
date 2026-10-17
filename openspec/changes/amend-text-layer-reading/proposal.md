# Proposal: amend-text-layer-reading

## Why

Today, a PDF's text layer is read in a single pass. `extraction-pipeline` ·
`consensus-by-majority` (BR-06) is written for "several candidate readings", and a
single pass produces one candidate with nothing to compare it against, so the
pipeline records a `Single` consensus. `validation-confidence` ·
`three-confidence-strengths` (BR-04) then caps that reading below green: "an
amount with no independent figure to cross against SHALL never be green however
cleanly it was read." The combination means every PDF invoice whose amounts come
from its text layer — the common case, ahead of XML and ahead of OCR in
`invoice-route-priority` — goes to review regardless of how cleanly it was read,
because the cap was written for a recognition estimate, not for a deterministic
read of document content.

A PDF's text layer is not a recognition pass with a confidence score attached to
each character; it is the document's own encoded text, read out mechanically. Two
extractions of the same layer return the same string, because there is no sensor
noise and no model uncertainty to vary between them — the property that
`consensus-by-majority` and `three-confidence-strengths` exist to guard against,
several independent passes disagreeing, cannot occur on a text layer and so has
nothing to confirm by disagreeing. OCR-recognition readings — a photograph, a
rendered page of a scanned PDF, or a mixed page with no text layer at all — remain
estimates of what a pixel most likely represents, and keep needing agreement
between passes exactly as before.

The product owner decided on 2026-10-17 that a text-layer reading counts, on its
own, as a deterministic reading and may reach green. This is recorded as
**DEC-018**. The decision is narrow and explicit about what does not change: a
derived value still never confirms anything (PRE-008, BR-05), a failed arithmetic
check still lowers confidence rather than being overridden by the route, and
OCR-recognition readings still need agreement between passes. DEC-018 leaves the
exact green conditions for a text-layer reading to this change.

This change fixes those conditions. A value extracted from a PDF's text layer may
be green only when every operand it depends on was itself read from that layer —
never derived — **and** at least one arithmetic identity over those operands is
checkable and holds. The PO decided on 2026-10-17, as a follow-up to DEC-018, that
a checkable identity is not optional: a total read once from the text layer with
no base, no tax and no other operand printed alongside it to cross against stays
at the single-reading cap, amber, because — determinism of the layer
notwithstanding — there is still nothing printed to confirm it against. The text
layer removes the need for a **second pass**; it does not remove the need for a
**second printed figure**.

## What Changes

- `extraction-pipeline` — MODIFIED `consensus-by-majority`. The original text is
  kept in full. Added: a value read once from a PDF's text layer passes consensus
  on its own, because the text layer is deterministic and a second reading of it
  produces no variation to arbitrate; OCR-recognition readings are unaffected and
  continue to need a majority across passes. Two scenarios are added: a text-layer
  reading passing consensus alone, and an OCR reading still needing agreement.
- `validation-confidence` — MODIFIED `three-confidence-strengths`. The original
  text is kept in full. Added: a value read once from a PDF's text layer counts
  as confirmed by redundancy, and may be green, only when every operand it
  depends on was also read from that layer (none derived) **and** at least one
  arithmetic identity over those operands is checkable and holds; a text-layer
  reading with no checkable identity — nothing printed alongside it to cross
  against — stays at the single-reading cap, amber, exactly as an OCR reading
  does. This exception applies to the text-layer route only, never to an
  OCR-recognition reading, never to a derived operand (PRE-008, BR-05 —
  unchanged), and never when a checkable identity fails (unchanged: a failed
  check still lowers confidence). The existing scenario about a reading with
  nothing to cross against is split to name the OCR case explicitly as one that
  stays amber, and four scenarios are added: a text-layer reading with no
  checkable identity staying amber, a text-layer reading with a holding identity
  reaching green, a derived operand still blocking green on a text-layer
  reading, and a failed arithmetic check still lowering a text-layer reading.
- No requirement is added, removed or renamed.

## Capabilities

### New Capabilities

- None.

### Modified Capabilities

- `extraction-pipeline`: a text-layer reading passes consensus by itself; OCR
  readings are unaffected.
- `validation-confidence`: a text-layer reading with no derived operand, and at
  least one checkable arithmetic identity that holds, may be shown green; a
  text-layer reading with nothing printed to check an identity against stays
  amber; every other cap (derived operands, a failed check, OCR needing
  agreement) is unchanged.

## Spec type

Full — both `extraction-pipeline` and `validation-confidence` are Full in
`openspec/project.md` §3.1; this change amends one requirement in each and leaves
the rest of each capability's shape unchanged.

## Impact

- `openspec/specs/extraction-pipeline/spec.md` — `consensus-by-majority` amended
  on archive.
- `openspec/specs/validation-confidence/spec.md` — `three-confidence-strengths`
  amended on archive.
- No other living spec changes. `a-check-confirms-only-if-every-operand-was-read`
  and `read-all-printed-quantities-before-deriving` are cited because they already
  state the caps DEC-018 keeps (PRE-008, BR-05); neither's text changes.
- **Not this change's to do:** implementing the text-layer-passes-consensus-alone
  rule and the text-layer-green-requires-a-holding-identity rule in the
  extraction and confidence code, and the regression tests that confirm an OCR
  reading still requires agreement across passes and that a text-layer reading
  with no checkable identity still stays amber, are implementation work,
  dispatched to the Mobile lane after this change is archived. DEC-018 and this
  change authorise that work; they do not perform it.
