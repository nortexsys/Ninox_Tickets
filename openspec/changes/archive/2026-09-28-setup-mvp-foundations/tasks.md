# Tasks: setup-mvp-foundations

Plan v0.2 M0 (Mon 28 – Tue 29 Sep). Each task names its owner and what "done" means. A task is
done when its check passes, not when its files exist.

## 1. Orchestrator

- [x] 1.1 **T0.5 — workspace.** Root `pubspec.yaml` (workspace), `analysis_options.yaml`,
      `packages/paperdrop_core`, `packages/ninox_client`, `app/` per design §2–§4, each with one
      smoke test. *Done when* `dart pub get`, `dart analyze --fatal-infos`,
      `dart format --set-exit-if-changed .`, `dart test` (both packages) and `flutter test` (app)
      are green on Flutter 3.47.5.
- [x] 1.2 **T0.5 — README** with the Dependencies table (design §9, NFR-LIC-001). *Done when*
      every dependency in the three `pubspec.yaml` files appears in it with its licence.
- [x] 1.3 **T0.5 — Android build.** `flutter build apk --debug`: built 2026-09-28, green
      (`app/build/app/outputs/flutter-apk/app-debug.apk`, ~143 MB). SDK licences accepted by the
      PO the same day. Installed and run on the PO's phone (Samsung Galaxy S22, SM-S901B,
      Android 16 / API 36) over wireless adb debugging: launches, shows "Paperdrop for Ninox",
      screenshot verified.
- [x] 1.4 **Lane boundaries** (design §5): `denies` in `agents/roles.yaml` and in
      `agents/lanes/factory.py`; runner's bounds check honours it. *Done when* a test proves Mobile
      cannot write `app/lib/features/wizard/` by file tool nor pass the bounds check with it.
- [x] 1.5 **T0.10 — encoding guard**: `.github/scripts/encoding_guard.py` and its allowlist
      (DEC-010, GAP-024, plan §6.3 and the T0.10 row). *Done when* it passes on the tree and fails
      on a planted double-encoded section sign in a `.md` and inside a `.docx` (proved by a test).
- [x] 1.6 **T0.4 — move `tools/` and `sql/`** to `Paperdrop_corpus\prototype\` (D-7, GAP-017).
      *Done when* neither folder exists in the tree. **Done 2026-09-26.**
- [x] 1.7 Integrate the lanes' branches, run every CI command locally, archive the change with
      OpenSpec 1.13.2, and write the status file. Integrated and verified 2026-09-26, approved the
      same day; 1.3 done 2026-09-28. Archived 2026-09-28.

## 2. QA

- [x] 2.1 **T0.3 — CI** `.github/workflows/ci.yml` with the jobs of design §6 (`analyze`,
      `format`, `test` + coverage artefact, `core-purity`, `privacy`, `no-ninox-db-id`, and the
      `encoding` job wired to task 1.5's script). Scripts in `.github/scripts/`, each with an
      allowlist that names a file and a reason. *Done when* every script passes on the tree, and
      each of `core-purity`, `privacy` and `no-ninox-db-id` fails on a planted violation (proved
      by a test in `.github/scripts/tests/`).
- [x] 2.2 **T0.7 — templates**: `.github/ISSUE_TEMPLATE/bug.md`, `spec-gap.md`, `improvement.md`;
      `validation/benchmarks/_template.md`, `validation/sessions/_template.md` (plan §10.2).
      *Done when* the bug template carries the mandatory no-real-data check.
- [x] 2.3 **T0.7 — scenario coverage**: `.github/scripts/scenario_coverage.py` (design §7), wired
      into CI as an artefact. *Done when* it lists every scenario of the 12 living specs, reports
      0 covered on the empty workspace, and flags a tag that matches no scenario (proved by a test).
- [x] 2.4 **T0.8 — corpus convention**: `validation/corpus-convention.md` (design §8), with no
      document content. *Done when* it defines layout, naming and the ground-truth JSON format.

## 3. Spec

- [x] 3.1 `proposal.md` for this change: why, what changes, the requirements it makes
      enforceable, what it defers. *Done when* `openspec validate setup-mvp-foundations --strict`
      passes on 1.13.2.

## 4. Product owner

- [x] 4.1 Approve this design (plan §9.2, Tue 29 Sep). **Approved 2026-09-26.**
- [ ] 4.2 **T0.8 — confirm the ground truth** of the 16 documents, drafted by the orchestrator in
      the private corpus from `corpus_test/REPORT_after_review.md` (by Fri 2 Oct).
- [x] 4.3 Install the Android SDK (accepting its licences) and connect the phone — **done
      2026-09-28**: Android Studio was already installed; `cmdline-tools` added and licences
      accepted; phone connected over wireless adb debugging.
- [x] 4.4 Move `ANTHROPIC_API_KEY` from the repository's `.env` into the Windows user environment
      and delete the `.env` (`AGENTS.md` §1.3). **Done 2026-09-28** (PO).
- [ ] 4.5 First push, which runs CI for the first time.
