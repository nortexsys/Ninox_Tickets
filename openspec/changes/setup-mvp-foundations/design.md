# Design: setup-mvp-foundations

Implementation-only change (`skip_specs: true`, plan v0.2 §8.2). It builds the ground every lane
stands on from Wednesday 30 September: the Dart workspace, the CI that guards it, the templates
that route findings, and the lane boundaries. It implements no behaviour of any capability; the
requirements it makes enforceable are listed in `proposal.md`.

Sources: plan v0.2 §5 (skeleton), §7 (team), §9 M0 (T0.3, T0.5, T0.7, T0.8, T0.10), §10
(documentation system), §11 (test design); `openspec/project.md` §5 (OpenSpec 1.13.2);
`AGENTS.md` §1.

---

## 1. Toolchain — pinned

| Tool | Version | Why pinned |
| --- | --- | --- |
| Flutter | **3.47.5** stable (framework `6a19cca564`, 2026-09-17) | Every lane and CI build with the same SDK; an unpinned CI moves under the lanes |
| Dart | **3.13.4** (bundled) | Pub workspaces need Dart ≥ 3.6; `environment.sdk: ^3.13.0` everywhere |
| OpenSpec | **1.13.2** | `openspec/project.md` §5 |
| Python (CI scripts, lane runner) | 3.12 in CI, ≥ 3.11 locally | `agents/requirements.txt` |

The Flutter SDK lives outside the repository (`C:\Users\admin\sdk\flutter` on the PO's machine),
on a short path: Gradle and Flutter nest deep and Windows still has a 260-character limit.

## 2. Workspace layout

A Dart pub workspace, exactly the skeleton of plan §5:

```
pubspec.yaml                    workspace root: name paperdrop_workspace, publish_to none
analysis_options.yaml           shared analyzer settings (§3)
packages/paperdrop_core/        pure Dart. No Flutter, no dart:io, no network
packages/ninox_client/          pure Dart + package:http. The port of ADR-003 and its classic adapter
app/                            Flutter application (Android only in the MVP)
tool/benchmark/                 not created now: QA creates it in W3 (T2.x)
```

* **One resolution for the whole workspace** (`resolution: workspace` in each member). A version
  conflict between lanes surfaces at `pub get`, not at integration.
* **`paperdrop_core` may import nothing but `dart:core`, `dart:collection`, `dart:math`,
  `dart:convert`, `dart:typed_data` and its own files.** Everything that decides a value lives
  there (plan §5), and it runs on a laptop in milliseconds. A CI guard (T0.3) fails on any other
  import in `packages/paperdrop_core/lib/`.
* **`ninox_client` depends on `paperdrop_core` and `http` only.** It never reads an environment
  variable to pick a target (`AGENTS.md` §1.4): team and database are constructor arguments.
* **`app` depends on both.** The platform adapters (scanner, file intake, OCR port, PDF-text
  port) live in `app/lib/adapters/`; they produce pages of positioned words and nothing else.

Initial `app/lib/` structure, so each lane knows its folder before writing a line:

```
app/lib/main.dart                         Mobile
app/lib/app/                              Mobile: shell, routing, theme, localisation
app/lib/adapters/                         Mobile: scanner, intake, ocr, pdf_text
app/lib/store/                            Mobile: local store
app/lib/features/capture/                 Mobile
app/lib/features/review/                  Mobile
app/lib/features/history/                 Mobile
app/lib/features/wizard/                  Ninox (FR-WIZ-*, setup-wizard)
app/lib/features/send/                    Ninox (ninox-send)
app/test/features/wizard/, .../send/      Ninox
```

Routing to the wizard and send screens is registered by Mobile in `app/lib/app/`, from a
single exported entry point per Ninox feature (`wizard_routes.dart`, `send_routes.dart`), so
Mobile never edits Ninox's folders and Ninox never edits the shell.

## 3. Analyzer and format

* Root `analysis_options.yaml`: `package:lints/recommended.yaml`, plus
  `strict-casts`, `strict-inference`, `strict-raw-types`; errors on `unused_import`,
  `missing_return`-class diagnostics; `prefer_single_quotes`, `always_declare_return_types`,
  `avoid_print` (a lane that prints may print a token), `unawaited_futures`.
* `app/analysis_options.yaml` includes `package:flutter_lints/flutter.yaml` and the same
  language modes.
* `dart format` with the default line length (80) — no project style to argue about; CI
  checks it (`--set-exit-if-changed`).
* **Money is never a `double`** (the `flutter-implement-json-serialization` skill says the same;
  `openspec/project.md` §4). No lint can express it; Core's tests and QA's review do.

## 4. Android application

| Setting | Value | Source |
| --- | --- | --- |
| `applicationId` / namespace | **`com.nortexsys.paperdrop`** | DEC-006's recommendation: no third-party mark in the permanent id |
| Display name | **Paperdrop for Ninox** | DEC-006 |
| `minSdk` | **24** (Android 7.0) — Flutter 3.47.5's default | NFR-PLT-001 leaves the minimum to this document. 24 covers the ML Kit document scanner and text recognition (ADR-006, ADR-010, both ≥ 21) and the Android Keystore APIs that NFR-SEC-001 needs (≥ 23). Raising it later is cheap; lowering it is not |
| `compileSdk` / `targetSdk` | **36** — Flutter 3.47.5's default | Play requires a recent target |
| Platforms | Android only | MVP (DEC-009); iOS is R2 and is added with `flutter create --platforms ios` then |
| Internet permission | Declared in the main manifest | ninox-send; the negative checklist (plan §11.3) checks the hosts, not the permission |

## 5. Lane boundaries (roles.yaml)

`agents/roles.yaml` already gives Ninox `app/lib/features/wizard/**` and `.../send/**`, and gives
Mobile all of `app/**`. That overlap would let Mobile write Ninox's folders. Fix:

* a new optional `denies` list per role, checked **before** `writes` (deny wins);
* Mobile: `denies` = Ninox's four folders (lib and test, wizard and send);
* Ninox: `writes` += `app/test/features/wizard/**`, `app/test/features/send/**`.

Enforced twice, like every write path: by the file tools (deepagents permissions) and by the
runner's bounds check on the diff. A test proves both for Mobile.

## 6. CI (T0.3, QA) — `.github/workflows/ci.yml`

Pinned Flutter 3.47.5; runs on push to `main` and on pull requests; **no secret is ever
configured** (the repository is public; plan §7.2).

| Job | Fails when |
| --- | --- |
| `analyze` | `dart analyze --fatal-infos` reports anything, in any workspace member |
| `format` | `dart format --output=none --set-exit-if-changed .` changes a file |
| `test` | any test fails: `dart test` in each package, `flutter test` in `app/`; coverage (lcov) uploaded as an artefact. **No coverage threshold yet**: thresholds are GAP-003 |
| `core-purity` | `packages/paperdrop_core/lib/` imports anything outside §2's list |
| `privacy` | a tracked file contains: a path into the private corpus (`Paperdrop_corpus`, `docs/corpus/`, `corpus_test/inbox`, `corpus_test/out`); a Spanish DNI/NIE with a valid check letter other than the synthetic `12345679S` (DEC-001); a card number that passes Luhn (13–19 digits) not on the allowlist; a token-like string (long base64/hex, `sk-…`, `Bearer …`) |
| `no-ninox-db-id` | the string `NINOX_DB_ID` appears in any tracked file outside an explicit allowlist of the files that state the rule (GAP-012) |
| `encoding` | double-encoded text (UTF-8 read as cp1252 and saved again, GAP-024) appears in a `*.md` or inside a `.docx`'s XML, outside the allowlist of lines that describe the defect (T0.10) |
| `agents` | already exists (`agents.yml`): `sync_skills --check` and the lane-runner tests |

The checks are Python scripts in `.github/scripts/`, each runnable locally with the same result
(`python .github/scripts/<check>.py`), and each with an allowlist file next to it that names a
file and a reason, never a bare pattern. The privacy check is deliberately stricter than needed:
a false positive costs an allowlist line; a false negative publishes a person.

CI cannot run before the first push, which is the PO's. Until then "CI green" means: every job's
command run locally, on the PO's machine, green — and recorded so in the status file.

## 7. Documentation system (T0.7, QA)

Exactly plan §10.2: three issue templates in `.github/ISSUE_TEMPLATE/` (bug with the mandatory
no-real-data check, spec-gap, improvement), and `validation/benchmarks/_template.md`,
`validation/sessions/_template.md`.

**Scenario-tag coverage** (plan §11.1): `.github/scripts/scenario_coverage.py` reads every
`### Requirement:` and `#### Scenario:` in `openspec/specs/*/spec.md`, and every test name in
`packages/**/test/` and `app/test/`. A test proves a scenario when its name contains the tag
`[<capability>/<requirement-name>]` **and** the scenario's name verbatim, case-insensitive:

```dart
test('[setup-wizard/two-stage-matching-with-a-strict-threshold] below the threshold the field stays unmapped', ...);
```

It writes a Markdown report (per capability: scenarios, covered, uncovered, and tags that match
no scenario — a renamed scenario must not leave an orphan test silently passing) to the path it
is given. CI uploads it; the orchestrator commits it to `docs/Plan/test-traceability.md`. The
first report, on the empty workspace, shows 0 covered of every scenario — that is the baseline.

## 8. Private corpus convention (T0.8, QA + PO)

`validation/corpus-convention.md` (public) describes the private corpus **without content**:
folder layout under `C:\Users\admin\proyectos\Paperdrop_corpus\`, the file naming, and the
ground-truth format — one JSON per document with, per field, the expected value, whether it is
printed or derived, and the PO's confirmation date. The ground truth itself lives only in the
private corpus. The first ground truth, for the 16 documents of the end-to-end test, is drafted
from `corpus_test/REPORT_after_review.md` (the PO's verdicts are authoritative) and **confirmed by
the PO**, by Fri 2 Oct (plan §9.2).

The corpus folder sits under `C:\Users\admin`, which is itself a misconfigured git repository
(`AGENTS.md` §1.1). Nothing is committed there; the risk is the same one the project already
lives with, and is recorded, not solved, here.

## 9. README and dependencies (NFR-LIC-001)

A root `README.md`: what the product is (one paragraph, from PDR v0.2), the layout of §2, how to
build and test, and a **Dependencies** table — every dependency of the shipped app with its
licence, proprietary ones marked. In M0 the app carries only Flutter's own and `http`; the
proprietary ones already decided for later changes (Google ML Kit document scanner, ADR-006;
ML Kit text recognition, ADR-010 proposed) are listed as *planned*, so the table is never behind
the code. No AGPL component (PyMuPDF, iText) ever enters `app/` or a package.

## 10. What this change does not do

* No behaviour. `paperdrop_core` and `ninox_client` ship a library file and one smoke test each.
* No Ninox access of any kind.
* No push, no store listing, no signing configuration (release signing is R1).
* The wizard picker's endpoint (`.../tables` vs `.../schema`, plan §6.1) is decided in
  `implement-setup-wizard`, not here. Recommendation carried over: `.../tables`.

## 11. Risks

| Risk | Mitigation |
| --- | --- |
| No Android SDK, JDK or phone on the build machine yet | The workspace, analysis and all tests run without them. Installing the Android SDK requires accepting Google's SDK licences — the PO's act, not an agent's. "Runs on the PO's phone" (T0.5) waits for it |
| Windows path length under `agents/.build/worktrees/` | Short SDK path; if a Mobile build breaks, move the worktree root outside the repository |
| The privacy check blocks legitimate text | Allowlist with a reason per line; reviewed by the orchestrator |
| CI unproven until the first push | Every job's command is run locally before merge |
