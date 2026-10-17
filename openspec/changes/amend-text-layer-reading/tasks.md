# Tasks: amend-text-layer-reading

Spec lane. Spec work only — no code task. Implementing the text-layer consensus
rule, the text-layer-green-requires-a-holding-identity rule and their regression
tests belongs to the Mobile lane and is dispatched separately, after this change
is archived and DEC-018 is on the record.

- [x] 1.1 Write `proposal.md`: DEC-018, why `consensus-by-majority` and
      `three-confidence-strengths` cap every text-layer PDF below green today, and
      the exact conditions under which a text-layer reading may be green, kept to
      what DEC-018 leaves to this change.
- [x] 1.2 Write the delta spec `specs/extraction-pipeline/spec.md`: MODIFIED
      `consensus-by-majority`, reproducing the original requirement text in full,
      adding that a text-layer reading passes consensus alone, and adding the two
      scenarios (a text-layer reading passing consensus alone, an OCR reading
      still needing agreement between passes).
- [x] 1.3 Write the delta spec `specs/validation-confidence/spec.md`: MODIFIED
      `three-confidence-strengths`, reproducing the original requirement text in
      full, adding the text-layer exception to the "nothing to cross against"
      cap with its two conditions (every operand read from the layer, no derived
      operand, **and** at least one checkable identity that holds), splitting the
      existing "nothing to cross against" scenario to name the OCR case, and
      adding the four new scenarios (a text-layer reading with no checkable
      identity staying amber, a text-layer reading with a holding identity
      reaching green, a derived operand still blocking green on a text-layer
      reading, a failed arithmetic check still lowering a text-layer reading).
- [x] 1.4 `openspec validate amend-text-layer-reading --strict` green.
- [x] 1.5 `openspec validate --specs --strict` green (the living specs unaffected
      by this change stay green).
- [x] 1.6 Follow-up (PO, 2026-10-17): tighten the green condition so that a
      checkable identity is **required**, not merely checked when available — a
      text-layer reading of a single operand, with nothing printed alongside it
      to cross against, stays amber. Updated `proposal.md`, this file, and the
      `validation-confidence` delta spec accordingly; `extraction-pipeline`'s
      delta needed no change, because consensus (which value is resolved) is
      independent of confidence (whether that value may show green). Re-ran both
      validations, green.

## Orchestrator and product owner

- [ ] 2.1 PO review and approval of this change.
- [ ] 2.2 `openspec archive amend-text-layer-reading -y`, then restore
      `extraction-pipeline`'s and `validation-confidence`'s `Purpose`,
      `Out of Scope`, `Cross-Capability References` and `Open Questions` per
      `openspec/AGENTS.md` §4.1 (archiving a MODIFIED-only change keeps them,
      per the 2026-09-25 precedent, but verify rather than assume).
- [ ] 2.3 Dispatch the Mobile lane: the text-layer-passes-consensus-alone rule,
      the text-layer-green-requires-a-holding-identity rule (every operand read,
      none derived, and at least one checkable identity holding), and the
      regression tests confirming a derived operand, a failed arithmetic check,
      a text-layer reading with no checkable identity, and any OCR-recognition
      reading are unaffected and keep their existing caps.
