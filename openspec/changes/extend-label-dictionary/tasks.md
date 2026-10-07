# Tasks: extend-label-dictionary

Core lane. A task is done when its check passes. Dart commands from inside `packages/paperdrop_core`:
`dart analyze --fatal-infos`, `dart format --set-exit-if-changed .`, `dart test`; from the repository
root `python .github/scripts/core_purity.py`, `python .github/scripts/scenario_coverage.py`, and after
`git add` `python .github/scripts/privacy_check.py` (read its exit status, do not pipe it).

- [ ] 1.1 **Extraction extension** (design): `IMPORTE LIQUIDO` and `Belegdatum`, consulted by the lookup
      after the Annex C seeds. *Done when* the Annex C test passes **unedited**, both terms bind a value
      on a synthetic page, the accented spelling matches, and no extension term collides with a
      negative-context term.
- [ ] 1.2 **`columnNameTerms`** (design). *Done when* the list holds the five entries of design, is
      exported from `paperdrop_core.dart`, is read by no extraction code, and extraction over a page
      containing `Tax Invoice` or `Betrag` binds nothing from them.
- [ ] 2.1 `openspec validate extend-label-dictionary --strict` green (orchestrator); record the matcher's
      consumption of `columnNameTerms` as the next Ninox dispatch.
