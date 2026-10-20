# ESTADO · Paperdrop for Ninox

**What this file is:** the handover. State only, **150 lines at most** (`plan_board.py --check` enforces it in
the pre-commit hook and in CI). It is overwritten at every close following `CLAUDE.md` "Closing ritual";
nothing is appended under yesterday's content. History goes to `docs/Plan/diario/<date>.md`, decisions to
`openspec/product-decisions.md`, gaps to `openspec/gaps-register.md`, rules to `AGENTS.md`. Task status is
written in `docs/Plan/plan-tasks.yaml` and nowhere else.

Start with §6, then §3.

---

**2026-10-20, 11:20 UTC · Status: OPEN (first state file; written from `main` at `d2013b2`).** `main` is 60 commits
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
| Merged changes against their `tasks.md` | `plan_board.py --drift` | **19 changes are merged on `main` with unticked or partly ticked tasks, and none is archived** |
| Task status | `plan-tasks.yaml` against `main` | Board in §2 |

## 2 · Where we are against the plan

<!-- BOARD:BEGIN -->
Board as of 2026-10-20 (generated from `plan-tasks.yaml`; do not edit by hand).

| Milestone | Done | In progress | Not started | Late | Days late (oldest) |
|---|---|---|---|---|---|
| M0 | 9 of 10 | 1 | 0 | 1 | 18 |
| M1 | 13 of 16 | 3 | 0 | 3 | 11 |
| M2 | 3 of 6 | 2 | 1 | 3 | 6 |
| M3 | 0 of 4 | 0 | 4 | 0 | 0 |

Open tasks (everything not DONE):

| Task | Due | Status | Change | Why it is not done |
|---|---|---|---|---|
| T0.8 Ground truth of the 16 documents | 02 Oct | IN PROGRESS · LATE | - | not verified this session; the PO's verdicts of 2026-10-20 cover the 19 photographs only |
| T1.10 Token, wizard steps, mapping, summary | 09 Oct | IN PROGRESS · LATE | implement-setup-wizard | 17 of 19 tasks; open 4.1 (validate) and 4.3 (revert roles.yaml widening on archive); change not archived |
| T1.12 App shell, navigation, strings | 09 Oct | IN PROGRESS · LATE | - | app/lib has capture, extraction, review, wizard; not run on a phone |
| T1.13 Scanner to PDF, picker, share intent, byte-for-byte storage | 09 Oct | IN PROGRESS · LATE | implement-android-capture-and-store | code merged; needs a real phone to close |
| T2.1 Route selection and consolidation wired end to end | 16 Oct | IN PROGRESS · LATE | implement-extraction-orchestration | parts A and B merged; part C (device harness for ExtractionService) needs the phone |
| T2.5 ADR-010 screening on the photographed corpus | 14 Oct | IN PROGRESS · LATE | - | the PO's verdicts exist since 2026-10-20 and a scorer gates photo-route merges; no screening report has been written; GAP-001 still open |
| T2.6 Alpha on the internal testing track | 16 Oct | NOT STARTED · LATE | - | needs a release build; none exists |
| T3.1 Benchmark over both halves of the acceptance corpus | 23 Oct | NOT STARTED | - |  |
| T3.2 Supervised sessions with 2-3 users | 22 Oct | NOT STARTED | - | whether users are booked is not recorded anywhere (ESTADO §6) |
| T3.3 Triage and fix loop | 23 Oct | NOT STARTED | - |  |
| T3.4 Thresholds, MVP report, R1 backlog | 23 Oct | NOT STARTED | - |  |
<!-- BOARD:END -->

Reading: the plan assumed M1 closed on 9 Oct and the alpha on 16 Oct. Code for nearly every M1 and M2 task
is merged. What is open is what needs the phone or the PO: device runs, a release build, the screening
report, and the supervised sessions. M3 started on Mon 19 Oct with no alpha to put in front of users.

## 3 · What is next, in this order

1. **Replan decision (PO).** Draft `docs/Plan/Paperdrop_MVP_Plan_v0.3_EN.md` written 2026-10-20, **not approved**:
   alpha 23 Oct as a signed APK, sessions 28–29 Oct, MVP report 2 Nov; decisions D1–D6 in its §2. Dates in
   `plan-tasks.yaml` change only after approval.
2. **Photo route, T2.5.** Score every change with `Paperdrop_corpus\tools\score.py` against the PO's verdicts of
   2026-10-20 (gate in memory `photo-route-ground-truth-and-gate`). Write the screening report for GAP-001.
3. **Release build and alpha (T2.6).** Needs the phone and the PO; blocked on item 4 of §4.
4. **Device harness (T2.1 C) and phone runs of T1.12, T1.13, T2.2.** Need the S22 on wireless adb.
5. **Administrative closure of the 19 merged changes:** tick `tasks.md`, `openspec validate`, archive
   (a lane task; list from `plan_board.py --drift`). Closes T1.10 (revert the `roles.yaml` widening, task 4.3).
6. **Repair the scenario-coverage report** (§5), then read it before M3.

## 4 · Approvals waiting for the PO

| # | What | Needed by |
|---|---|---|
| 1 | Plan v0.3 draft: D1 dates, D2 APK not Play track, D3 photo stays, D5 notice users need, D6 T0.8 | today |
| 2 | `git push` of `main` (60 commits) | when the PO decides |
| 3 | ML Kit packaging (D4): bundled +12.5 MB, or Play-services model +99 KB | Wed 21 Oct |
| 4 | Whether a release build and alpha track are wanted before the sessions | before T2.6 |
| 5 | Users for T3.2: "available when needed" (PO, 2026-10-20). Call them on Mon 26 Oct for 28–29 Oct; how much notice they need is not known | Mon 26 Oct |
| 6 | Leftover branches: `change/fix-photo-ocr-amount-parsing` (unmerged), `backup/pre-push-main-20261007`, `claude/ticket-reader-ninox-session1-ee5bf1` — keep or delete | whenever |

## 5 · Open, and only open

* **`privacy_check` fails on `main`:** `openspec/changes/add-amount-coherence-rules/proposal.md:19` names a
  corpus path (`corpus-file` rule). CI is red until that line is reworded. Not fixed: it is a PO-approved
  change.
* **`docs/Plan/test-traceability.md` reads 4 test names against 304 scenarios** (capture-intake 0 of 18). Either
  tests do not carry scenario tags or the script misses them. Until known, no coverage figure is usable.
* **Gaps open:** GAP-001 (ADR-010, blocks `FR-EXT-005`, `FR-EXT-015`, `UC-14`), 003 (thresholds, closes with
  M3), 005, 006, 007, 008, 009, 012, 023, 025, 029, 030, 032, 033, 034, 039 (parts 2, 3). Register is the source.
* **Not archived:** all 19 changes in `plan_board.py --drift`; `close-adr-011-pdf-text-route` is 17 of 17 ticked.
* **Atria quota:** Spec and QA lanes run on DeepSeek by the PO's order of 2026-10-17 (memory
  `lanes-use-deepseek-until-told`). Do not recharge or switch without being told.
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
