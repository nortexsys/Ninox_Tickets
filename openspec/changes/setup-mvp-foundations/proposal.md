# Change: setup-mvp-foundations

## Why

The MVP is built by five agents in parallel lanes, and every lane's first line of
code depends on the same ground existing first: the packages it writes into, the
toolchain those packages resolve against, the lints that reject its code, and the
CI job that judges it. If that ground is laid inside the first product changes,
each lane invents a piece of it and the pieces disagree — a `paperdrop_core` that
imports `dart:io` because nothing said it could not, an app built against a
different Flutter than CI, a dependency added without a licence entry because the
README table did not exist yet. None of that is a specification failure; it is a
foundation missing, and the fix is to build the foundation in one change that
touches no behaviour at all.

The foundations also carry the project's two irreversible risks, and both are
cheap only now. **Privacy:** the repository is public and the corpus holds a real
person's documents, so a check that refuses a token-like string, a valid check
letter on a Spanish identifier or a Luhn-passing card number has to exist before
any lane commits, not after the first leak. **Traceability:** the plan's whole
test design rests on a test being tagged with the scenario it proves
(plan §11.1), so the coverage script has to exist while the workspace is still
empty and its zero-covered report has to be the baseline every lane moves against
— written later, it would start from an unmeasured state and no one would know
what was missing.

Finally, the lanes cannot be let loose on the tree until the boundary between them
is enforced rather than agreed. `agents/roles.yaml` currently lets Mobile write
Ninox's folders, because it has a `writes` list and no denial. A change that
fixes that *and* proves it with a test is what makes the parallel plan safe; a
design note alone would not.

## What Changes

This is an **implementation-only change** (`skip_specs: true` in
`.openspec.yaml`, plan §8.2: "Implements already-specified requirements — no
spec delta"). It changes **no behaviour and carries no spec delta**: no
requirement is added, modified, removed or renamed, and no living spec is
touched. Its output is the ground under every later change, and the requirements
it makes *enforceable* — not satisfied — are listed in the next section.

* **Toolchain pinned.** Flutter **3.47.5** stable (Dart **3.13.4**), OpenSpec
  **1.13.2**, Python 3.12 in CI. Every lane and CI build against the same SDK.
* **Dart pub workspace** (design §2): a workspace root (`pubspec.yaml`,
  `publish_to: none`, one resolution for all members) and three packages —
  `packages/paperdrop_core/` (pure Dart; nothing but `dart:core`,
  `dart:collection`, `dart:math`, `dart:convert`, `dart:typed_data` and its own
  files), `packages/ninox_client/` (pure Dart + `http`, its team and database as
  constructor arguments, never an environment variable) and `app/` (Flutter,
  Android only in the MVP). The initial `app/lib/` folders exist so each lane
  writes into its own directory, and Mobile registers the wizard and send routes
  from `app/lib/app/` through one exported entry point per Ninox feature, so
  neither lane edits the other's folders.
* **Analyzer and format** (design §3): a shared root `analysis_options.yaml`
  (`package:lints/recommended.yaml`, strict casts, strict inference, strict raw
  types, `unused_import`, `unused_local_variable` and `dead_code` raised to
  errors, and the lint rules `always_declare_return_types`, `avoid_print` — a
  lane that prints may print a token — `prefer_single_quotes`,
  `unawaited_futures`, `prefer_final_locals` and `directives_ordering`), an
  `app/` variant that adds `package:flutter_lints/flutter.yaml`, and
  `dart format` at the default line length, checked in CI.
* **Android application settings** (design §4): `applicationId` and namespace
  `com.nortexsys.paperdrop`, display name **Paperdrop for Ninox**, `minSdk` 24,
  `compileSdk`/`targetSdk` 36, Android only, and the internet permission declared
  in the main manifest.
* **Lane boundaries** (design §5): a new `denies` list per role in
  `agents/roles.yaml` and `agents/lanes/factory.py`, checked **before** `writes`
  so deny wins; Mobile is denied Ninox's four folders, and Ninox's `writes`
  gains its two test directories. The runner's bounds check honours it, and a
  test proves Mobile cannot reach `app/lib/features/wizard/` by file tool or by
  the bounds check.
* **CI** (design §6, `.github/workflows/ci.yml`): jobs `analyze`, `format`,
  `test` with the lcov coverage artefact and **no threshold** (thresholds are
  GAP-003), `core-purity`, `privacy`, `no-ninox-db-id`, `encoding` and the
  existing `agents` job. Each check is a Python script in `.github/scripts/`
  with an allowlist that names a file and a reason, and each of `core-purity`,
  `privacy`, `no-ninox-db-id` and the encoding guard is proven to fail on a
  planted violation.
* **Documentation templates and routing** (design §7, plan §10): three issue
  templates in `.github/ISSUE_TEMPLATE/` (`bug.md` with the mandatory
  *no-real-data* check, `spec-gap.md`, `improvement.md`), and
  `validation/benchmarks/_template.md` with `validation/sessions/_template.md`,
  so a finding has a named destination from day one.
* **Scenario-coverage report** (design §7): `.github/scripts/scenario_coverage.py`
  reads every `### Requirement:` and `#### Scenario:` in the living specs and
  every test name in the packages and the app, proves a scenario when a test name
  carries the tag `[<capability>/<requirement-name>]` **and** the scenario's name
  verbatim, and reports uncovered scenarios and tags that match no scenario. The
  first report — 0 covered, on the empty workspace — is the baseline, and it is
  committed to `docs/Plan/test-traceability.md`.
* **Private-corpus convention** (design §8): `validation/corpus-convention.md`
  describes the private corpus **without content**: the folder layout under
  `Paperdrop_corpus\`, the file naming, and the ground-truth JSON format — per
  field the expected value, whether it is printed or derived, and the product
  owner's confirmation date. No document content enters the repository; the
  ground truth itself stays in the private corpus.
* **README and the dependency table** (design §9): a root `README.md` with the
  product in one paragraph, the layout, how to build and test, and a
  **Dependencies** table — every dependency of the shipped app with its licence,
  proprietary ones marked, the already-decided ML Kit components listed as
  *planned* so the table is never behind the code, and no AGPL component ever
  entering `app/` or a package.

Two M0 tasks that are already executed are carried by this change and not
repeated: the OpenSpec pin re-measured into `openspec/project.md` §5 (T0.1), and
the move of `tools/` and `sql/` out of the repository to
`Paperdrop_corpus\prototype\` (T0.4, GAP-017, done 2026-09-26).

## Requirements made enforceable

The change implements none of these. Each is an already-approved requirement
whose acceptance condition could not previously be checked, because the thing
that checks it did not exist; the foundation is what makes the check possible.
Identifiers are as the functional spells them, and each cites the requirement
name that already owns the behaviour in `openspec/specs/`.

* **NFR-LIC-001 — Declared dependencies.** The README's Dependencies table lists
  every dependency with its licence, proprietary ones marked, and the
  already-decided Google ML Kit components as *planned* so the table is never
  behind the code. Owned by `product-invariants`' `proprietary-dependencies-declared`;
  the AGPL half is `local-config-privacy`' `no-agpl-component-ships`.
* **NFR-PLT-001 — Platforms.** The functional fixes Android and iOS as the only
  surfaces and explicitly leaves the minimum OS versions to the SDD ("Minimum OS
  versions are fixed in the SDD, not here"). Design §4 sets `minSdk` 24 —
  covering the ML Kit scanner and text recognition of ADR-006 and ADR-010 (both
  ≥ 21) and the Android Keystore APIs of NFR-SEC-001 (≥ 23) — with
  `compileSdk`/`targetSdk` 36. Owned by `product-invariants`'
  `no-desktop-application`; this change supplies the number the functional
  declined to name.
* **NFR-PRF-002 — Reading requires no network.** The `core-purity` job fails when
  `packages/paperdrop_core/lib/` imports anything outside its allowed set, so no
  future lane can put a network dependency into the code that reads and
  validates. Owned by `capture-intake`' `capture-without-connectivity`.

The CI `privacy`, `no-ninox-db-id` and `encoding` jobs are **not** in this list.
They protect the repository — no personal data or credential is published
(`AGENTS.md` §1.2–§1.4), the production database is never named by a variable
(GAP-012), and the repaired encoding of the sources of truth does not come back
(GAP-024) — and they are listed under the gaps and decisions below. A repository
check is not the acceptance condition of a product requirement: proving that no
backend, no telemetry and no second credential exist in a build is the negative
release checklist of plan §11.3, which QA automates in W3, and the app shell this
change ships still holds a hardcoded title string, so NFR-I18N-001 is not
enforceable yet either.

**Gaps and decisions this change acts on.** Each exists in the register it
belongs to and is acted on as recorded there; none is closed by this change.

* **GAP-012** (`NINOX_DB_ID` pointed at a production database; gaps register,
  `NO BLOQUEANTE`, `ABIERTO`) — the CI `no-ninox-db-id` job is the mitigation the
  register names: it fails when the string appears in any tracked file outside an
  allowlist of the files that state the rule. The risk stays alive outside the
  repository, as the register says; this change is the check, not the closure.
* **GAP-017** (real personal data in `tools/` and `sql/`; gaps register,
  `NO BLOQUEANTE`, decision D-7) — `tools/` and `sql/` moved out of the tree to
  `Paperdrop_corpus\prototype\`, executed as task 1.6 / T0.4 and marked done
  2026-09-26. The register closes on execution, so this change carries it.
* **GAP-024** (double-encoded text in the sources of truth; gaps register,
  `NO BLOQUEANTE`, `CERRADO` under DEC-010) — the CI `encoding` job keeps the
  repaired state from coming back: it fails on double-encoded text in a `*.md`
  or inside a `.docx`'s XML, outside the allowlist of the lines that describe the
  defect.
* **DEC-006** (product decisions register — the product is **Paperdrop for
  Ninox**) — the Android `applicationId` `com.nortexsys.paperdrop` and the
  display name *Paperdrop for Ninox* apply it. The register's Ninox-trademark
  caveat is a store-publication concern and is not addressed here.
* **DEC-010** (product decisions register — the functional's encoding was
  repaired) — the `encoding` CI job is the guard that makes the repair
  irreversible.

## Deferred

Design §10, restated so the boundary with the first product changes is explicit.

* **No behaviour.** `paperdrop_core` and `ninox_client` each ship a library file
  and one smoke test. No value is read, derived, validated or written, and no
  Ninox call is made. The first real code in each package belongs to
  `implement-core-model-and-countries`, `implement-validation-and-extraction-core`
  and `implement-ninox-client`.
* **No push, no store listing, no release signing** — release signing is R1, and
  DEC-006 still requires reading Ninox's trademark guidelines before any store
  listing, which no change here does.
* **`tool/benchmark/` is not created.** QA creates it in W3 (T2.x), as an
  integration test of the shipped pipeline over the private corpus.
* **No coverage threshold.** The `test` job uploads the lcov artefact only;
  thresholds are GAP-003, deferred to the MVP validation.
* **The wizard picker's endpoint** (`.../tables` vs `.../schema`, plan §6.1) is
  decided in `implement-setup-wizard`, not here. The recommendation carried over
  is `.../tables`.
* **The photographed corpus and the ground truth** are the product owner's
  inputs, not this change's: the convention describes the format, the PO
  confirms the 16-document ground truth by Fri 2 Oct.
* **The privacy risk of the corpus folder itself** (it sits under
  `C:\Users\admin`, itself a misconfigured git repository, design §8) is
  recorded here, not solved.

## Impact

**Affected paths.** New, and created by this change: `pubspec.yaml`,
`analysis_options.yaml`, `packages/paperdrop_core/`, `packages/ninox_client/`,
`app/` (including `app/android/` with the settings of design §4),
`README.md`, `.github/workflows/ci.yml`, the scripts and allowlists of
`.github/scripts/`, `.github/ISSUE_TEMPLATE/`, `validation/` with
`corpus-convention.md` and the two templates, and
`docs/Plan/test-traceability.md` for the coverage report. Modified:
`agents/roles.yaml` and `agents/lanes/factory.py` for the `denies` list, and
`openspec/project.md` §5 for the re-measured OpenSpec pin. Files **removed** from
the tree: `tools/` and `sql/`, moved to `Paperdrop_corpus\prototype\`.

**No living spec changes.** The twelve approved capabilities in
`openspec/specs/` are untouched: no `ADDED`, `MODIFIED`, `REMOVED` or `RENAMED`
block, no requirement renamed, no `[Origen:]` tag altered. Nothing is written to
`openspec/specs/`, and `design.md` and `tasks.md` are the orchestrator's and are
not edited here. `openspec validate setup-mvp-foundations --strict` passes on
1.13.2 with `skip_specs: true` and zero deltas accepted; the twelve living specs
stay green under `validate --all --strict`.

**No functional change, and no new decision.** The functional is read-only
(`AGENTS.md` §1.6); this change records nothing in
`openspec/product-decisions.md`, because it takes no decision that diverges from
an approved requirement — it fixes the minimum Android version that NFR-PLT-001
explicitly left to the SDD, and the register entry for that number belongs to the
change that first depends on it being one way rather than another.
