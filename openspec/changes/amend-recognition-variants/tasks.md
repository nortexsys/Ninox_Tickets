# Tasks: amend-recognition-variants

Spec lane. Spec work only — no code task. Writing
`app/lib/adapters/ocr/image_decoder.dart`, narrowing
`app/test/tool/no_image_processing_test.dart`, and measuring `p4-contrast` (and
any new photo-route variant) in T2.5 belong to the Mobile lane and are dispatched
separately, after this change is archived and DEC-017 is on the record.

- [x] 1.1 Write `proposal.md`: the decision, why `platform-document-scanner`'s
      current wording conflicts with it, and that ADR-006's intent is kept rather
      than reversed.
- [x] 1.2 Write the delta spec `specs/capture-intake/spec.md`: MODIFIED
      `platform-document-scanner`, reproducing the original requirement text in
      full, adding the recognition-variant definition and its constraints,
      narrowing the scenario *the app carries no pre-processing of its own*, and
      adding the two new scenarios (*a recognition variant is never persisted*,
      *the attached image is the scanner's output, byte for byte*).
- [x] 1.3 Record **DEC-017** in `openspec/product-decisions.md`, in Spanish, in
      the table's format, covering: the decision, what it contradicts, that
      ADR-006's intent is kept, that it also covers the `p4-contrast` pass already
      shipped in `implement-photo-route`, that the guard test is narrowed to admit
      decoding in exactly `app/lib/adapters/ocr/image_decoder.dart`, that the
      contrast pass's usefulness is measured in T2.5 and removed if it adds
      nothing, and the date and who decided.
- [x] 1.4 `openspec validate amend-recognition-variants --strict` green.
- [x] 1.5 `openspec validate --specs --strict` green (the 12 living specs
      unaffected by this change stay green).

## Orchestrator and product owner

- [ ] 2.1 PO review and approval of this change.
- [ ] 2.2 `openspec archive amend-recognition-variants -y`, then restore
      `capture-intake`'s `Purpose`, `Out of Scope`, `Cross-Capability References`
      and `Open Questions` per `openspec/AGENTS.md` §4.1 (archiving a MODIFIED-only
      change keeps them, per the 2026-09-25 precedent, but verify rather than
      assume).
- [ ] 2.3 Dispatch the Mobile lane: `image_decoder.dart`, the narrowed guard test,
      and the photo-route recognition-variant implementation; dispatch T2.5 to
      measure `p4-contrast` and any new variant, removing either if it adds no
      agreement or accuracy.
