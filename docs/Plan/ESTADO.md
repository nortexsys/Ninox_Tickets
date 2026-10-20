# ESTADO · Paperdrop for Ninox

**What this file is:** the handover. State only, **150 lines at most** (`plan_board.py --check` enforces it in
the pre-commit hook and in CI). It is overwritten at every close following `CLAUDE.md` "Closing ritual";
nothing is appended under yesterday's content. History goes to `docs/Plan/diario/<date>.md`, decisions to
`openspec/product-decisions.md`, gaps to `openspec/gaps-register.md`, rules to `AGENTS.md`. Task status is
written in `docs/Plan/plan-tasks.yaml` and nowhere else.

Start with §6, then §3.

---

**2026-10-20 · Status: OPEN (written from `main` at `d2013b2`; plan v0.3 approved the same day).** `main` is 60 commits
ahead of `origin/main` (`3eb209a`) and **has not been pushed**. Nothing was written to Ninox in this session.

## 1 · What was checked today, and against what

| Claim | Verified against | Result |
|---|---|---|
| Repository root | `git rev-parse --show-toplevel` | Worktree of `04_01_Ticket_reader_Ninox`, branch `claude/project-status-methodology-4704e2` at `d2013b2` = `main` |
| `main` against the remote | `git log origin/main..main` | 60 commits unpushed |
| T2.2 review screen and T2.4 negative checklist are on `main` | `git log main --grep` | Merged 2026-10-18 (`e2d4ef3`, `1d5ed74`). `AGENTS.md` §3 still said "in flight" |
| Gaps 031–040 are in the register | `openspec/gaps-register.md` | Filed. 031, 035–038, 040 closed; 032–034 and 039 open. The status of 2026-10-17 said they were not filed |
| CI scripts on `main` | run locally | `core_purity` 0, `no_ninox_db_id` 0, `encoding_guard` 0, **`privacy_check` 1 finding** (§5) |
| Tests | **not run this session** | Last known: app 423, core 265, ninox_client 272 (status 2026-10-10 tree), not re-run on `main` since |
| Merged changes against their `tasks.md` | `plan_board.py --drift` | 20 changes were merged with open tasks and none archived; **15 archived on 2026-10-20**; 5 remain (§5) |
| Task status | `plan-tasks.yaml` against `main` | Board in §2 |

## 2 · Where we are against the plan

<!-- BOARD:BEGIN -->
Board as of 2026-10-20 (generated from `plan-tasks.yaml`; do not edit by hand).

| Milestone | Done | In progress | Not started | Late | Days late (oldest) |
|---|---|---|---|---|---|
| M0 | 9 of 10 | 1 | 0 | 1 | 18 |
| M1 | 13 of 16 | 3 | 0 | 0 | 0 |
| M2 | 3 of 8 | 2 | 3 | 0 | 0 |
| M3 | 0 of 4 | 0 | 4 | 0 | 0 |

Open tasks (everything not DONE):

| Task | Due | Status | Change | Why it is not done |
|---|---|---|---|---|
| T0.8 Ground truth of the 16 documents | 02 Oct | IN PROGRESS · LATE | - | not verified this session; the PO's verdicts of 2026-10-20 cover the 19 photographs only |
| T1.10 Token, wizard steps, mapping, summary | 22 Oct (v0.2: 09 Oct) | IN PROGRESS | implement-setup-wizard | 17 of 19 tasks; open 4.1 (validate) and 4.3 (revert roles.yaml widening on archive); change not archived |
| T1.12 App shell, navigation, strings | 22 Oct (v0.2: 09 Oct) | IN PROGRESS | - | app/lib has capture, extraction, review, wizard; not run on a phone |
| T1.13 Scanner to PDF, picker, share intent, byte-for-byte storage | 22 Oct (v0.2: 09 Oct) | IN PROGRESS | implement-android-capture-and-store | code merged; needs a real phone to close |
| T2.1 Route selection and consolidation wired end to end | 22 Oct (v0.2: 16 Oct) | IN PROGRESS | implement-extraction-orchestration | parts A and B merged; part C (device harness for ExtractionService) needs the phone |
| T2.5 ADR-010 screening on the photographed corpus | 22 Oct (v0.2: 14 Oct) | IN PROGRESS | - | the PO's verdicts exist since 2026-10-20 and a scorer gates photo-route merges; no screening report has been written; GAP-001 still open |
| T2.6 Alpha: the signed APK installed on the S22 (plan v0.3 D2) | 23 Oct (v0.2: 16 Oct) | NOT STARTED | - | needs a release build; none exists |
| T2.7 Device pass on the S22: shell, scanner, share intent, review screen (plan v0.3) | 22 Oct | NOT STARTED | - | needs the phone reachable over wireless adb; numbers and screenshots stay outside the repository |
| T2.8 Signed release APK (plan v0.3, replaces the internal testing track) | 23 Oct | NOT STARTED | - | needs D4 (ML Kit packaging form) from the PO |
| T3.1 Benchmark over both halves of the acceptance corpus | 27 Oct (v0.2: 23 Oct) | NOT STARTED | - |  |
| T3.2 Supervised sessions with 2-3 users | 29 Oct (v0.2: 22 Oct) | NOT STARTED | - | whether users are booked is not recorded anywhere (ESTADO §6) |
| T3.3 Triage and fix loop | 30 Oct (v0.2: 23 Oct) | NOT STARTED | - |  |
| T3.4 Thresholds, MVP report, R1 backlog | 02 Nov (v0.2: 23 Oct) | NOT STARTED | - |  |
<!-- BOARD:END -->

Reading: plan v0.3 (approved 2026-10-20, DEC-026) moved the dates; the board shows the v0.2 date next to each.
Code for nearly every M1 and M2 task is merged. What is open needs the phone or the PO: device runs (T2.7), the
screening report (T2.5), the release APK (T2.8, needs D4), then the sessions of 28–29 Oct. T0.8 is the only
task late against the v0.3 dates.

## 3 · What is next, in this order

1. **Device pass, Tue 20 – Thu 22 Oct (T2.7, T2.1 C, T1.12, T1.13).** Needs the S22 reachable over wireless adb
   (pairing is per wifi network: the PO runs `adb pair`). Hard date: no device run by Wed 21 Oct slips the alpha.
2. **Photo route, T2.5.** Score every change with the scorer kept in the private corpus against the PO's verdicts of
   2026-10-20 (gate in memory `photo-route-ground-truth-and-gate`). Write the screening report for GAP-001.
3. **Signed release APK and alpha, Fri 23 Oct (T2.8, T2.6).** Blocked on D4 (§4 item 3). Fallback in plan v0.3 §6:
   sessions run on the debug build on the PO's S22.
4. **Sessions plan:** the PO calls the users on Mon 26 Oct for Wed 28 – Thu 29 Oct (48 hours of notice assumed).
5. **Finish the archive closure (§5):** the `error-500` re-recording (`verify-live-send-pipeline` 2.4,
   `implement-ninox-send-pipeline` 2.3), `SendJournal` wiring (2.4), `roles.yaml` revert (wizard 4.3), then archive.
6. **Repair the scenario-coverage report** (§5), then read it before M3.

## 4 · Approvals waiting for the PO

| # | What | Needed by |
|---|---|---|
| 1 | ~~Plan v0.3~~ approved 2026-10-20 (D1, D2, D3, D5). **D6 open:** confirm the ground truth of the 16 documents (T0.8) or close it as superseded by the 19-photograph verdicts | now |
| 2 | `git push` of `main` (60 commits) | when the PO decides |
| 3 | **D4 open:** ML Kit packaging, bundled +12.5 MB or Play-services model +99 KB. T2.8 cannot start without it | Wed 21 Oct |
| 4 | `adb pair` of the S22 on the current wifi, so the device pass can start | Wed 21 Oct |
| 5 | Users for T3.2: "available when needed" (PO, 2026-10-20). Approved with 48 hours of notice assumed (D5); call them on Mon 26 Oct for 28–29 Oct | Mon 26 Oct |
| 6 | Leftover branches: `change/fix-photo-ocr-amount-parsing` (unmerged), `backup/pre-push-main-20261007`, `claude/ticket-reader-ninox-session1-ee5bf1` — keep or delete | whenever |

## 5 · Open, and only open

* **`privacy_check` fails on `main`:** `openspec/changes/add-amount-coherence-rules/proposal.md:19` names a
  corpus path (`corpus-file` rule). CI is red until that line is reworded. Not fixed: it is a PO-approved
  change.
* **`docs/Plan/test-traceability.md` reads 4 test names against 304 scenarios** (capture-intake 0 of 18). Either
  tests do not carry scenario tags or the script misses them. Until known, no coverage figure is usable.
* **Gaps open:** GAP-001 (ADR-010, blocks `FR-EXT-005`, `FR-EXT-015`, `UC-14`), 003 (thresholds, closes with
  M3), 005, 006, 007, 008, 009, 012, 023, 025, 029, 030, 032, 033, 034, 039 (parts 2, 3). Register is the source.
* **Not archived (5, from `plan_board.py --drift`):** `implement-ninox-send-pipeline` 9/11 (2.3 `error-500`
  not re-recorded; 2.4 no `SendJournal` in `app/`), `verify-live-send-pipeline` 8/9 (same `error-500`),
  `implement-photo-passes` 8/9 (2.2 no record the PO read the pass numbers), `implement-setup-wizard` 17/19
  (4.1 cannot pass: no spec deltas; 4.3 revert `agents/roles.yaml` on archive), `implement-validation-and-extraction-core`
  15/16 (6.2 waits for QA's private runs). Also unarchived: `implement-android-capture-and-store` 10/10 ticked.
* **`openspec validate --all --strict` is red, 7 failures, none new:** "must have at least one delta" on the open
  changes without a `specs/` folder, and on `fix-photo-ocr-amount-parsing`. The 12 specs pass. `AGENTS.md` §3 said it
  was green; it is not for the changes.
* **Archived with indirect evidence (PO to confirm or revert):** six merges do not record the PO's approval in their
  message (`implement-country-detection`, `-extraction-orchestration`, `-photo-route`, `-history-retry-duplicates`,
  `-text-layer-confidence`); S22 tasks of `fix-photo-total-without-identity`, `fix-text-pdf-extraction-yield`,
  `implement-photo-route`, `adopt-app-cust-readers` were ticked from the runs in `diario/2026-10-17.md`, not from a
  run of each change alone. Mixed PDFs (point 5, GAP-033) was never answered.
* **Lane models (DEC-025, 2026-10-20):** Spec runs on `claude-sonnet-5-5` and QA on `claude-sonnet-5`, both through
  Abacus RouteLLM (`ABACUS_API_KEY`, user registry). Core, Ninox and Mobile stay on DeepSeek. Abacus does not report
  tokens to the lane report (`usage` is 0): spend is read in Abacus's own panel. The key was exposed in a chat
  filename on 2026-10-20: regenerate it in Abacus and store it again.
* **Accuracy of the photo route** is measured only against the PO's verdicts of 2026-10-20; the contrast pass and
  the rescaled passes still have to earn their place (DEC-017).
* **Live-run leftovers:** the `error-500` fixture re-recording; maximum attachment size (PO accepted "good
  enough" on 2026-10-09).

## 6 · What is not known

* Whether the S22 is reachable now, and which wifi it is on (wireless adb pairs per network).
* Whether the 16-document ground truth (T0.8, due 2 Oct) was ever confirmed in full. The 2026-10-20 verdicts cover
  the 19 photographs only.
* Whether the full test suite is green on `main`. It has not been run since the merges of 18–20 Oct.
* Whether the two PDF-corpus halves and the photographed corpus are complete in `Paperdrop_corpus`.
* How much notice the users need. They are available on request (PO, 2026-10-20); nobody is booked.
