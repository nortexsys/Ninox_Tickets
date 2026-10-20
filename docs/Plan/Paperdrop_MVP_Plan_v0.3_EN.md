# Paperdrop for Ninox — MVP replan

**Version:** 0.3 — **APPROVED by the product owner on 2026-10-20** (DEC-026): D1, D2, D3 and D5 as proposed. **D4 and D6 are choices, not proposals, and are still open** (§8). Supersedes the dates of v0.2.1.
**Date:** 2026-10-20 (Tue)
**Base:** `Paperdrop_MVP_Plan_v0.2_EN.md` (v0.2.1). This document is a delta: whatever it does not mention stays as in v0.2.
**Evidence:** `docs/Plan/ESTADO.md` §1–§2 and `docs/Plan/plan-tasks.yaml`, both read against `main` (`d2013b2`) on 2026-10-20.

---

## 1. Why a replan

v0.2 put the alpha on **Fri 16 Oct** and the validation with users on **20–23 Oct**. On 20 Oct the board reads:

| Milestone | Done | Late | Oldest delay |
| --- | --- | --- | --- |
| M0 | 9 of 10 | 1 | 18 days (T0.8, ground truth of the 16 documents) |
| M1 | 13 of 16 | 3 | 11 days |
| M2 | 3 of 6 | 3 | 6 days |
| M3 | 0 of 4 | — | not started |

The delay is **not code**. The code of nearly every M1 and M2 task is merged on `main`. What is open needs the phone or the PO:

* nothing has been run on a device except the OCR passes and the live send: shell and navigation (T1.12), scanner and share intent (T1.13), the review screen (T2.2), `ExtractionService` end to end (T2.1 part C);
* no release build exists (T2.6);
* the ADR-010 screening has no report (T2.5), although the PO's hand verdicts on the 19 photographs exist since 2026-10-20;
* the supervised sessions have nothing to put in front of users.

Three things also changed the scope since v0.2, with the PO's approval. v0.2 does not mention them:

* **DEC-022 / DEC-023 / DEC-024:** the country is an *input*, not a detection result; the readers of the PO's prototype (App Cust) were adopted for the photo route; a second read on request is part of the MVP.
* **DEC-018:** the text layer of a PDF counts as a deterministic reading on its own.
* **A measured gate for the photo route** (scorer against the PO's verdicts) replaced "fix and hope". Earlier photo-route fixes were never measured against reality (the PO's own complaint, 2026-10-20).

## 2. What this plan decides

| # | Decision | Proposal | Why |
| --- | --- | --- | --- |
| D1 | New dates | Alpha **Fri 23 Oct**; validation sessions **Wed 28 – Thu 29 Oct**; triage **Fri 30 Oct**; MVP report **Mon 2 Nov** | §3 |
| D2 | What "alpha" means | A **signed APK** installed on the PO's S22 (and on the users' phones if they bring them). The Play internal testing track leaves R0 and moves to R1 | Nothing in the sessions needs the store. The sessions are supervised, on a phone the PO controls. The Play track adds an account, a review wait and a signing setup that nobody has tried yet |
| D3 | Photo route stays in R0 | **Yes.** It does not move to R1 (v0.2 §9.3 allowed it) | It is where the PO has invested the measurement and it carries the use case of a paper receipt. The gate of §5 decides its quality, not its calendar |
| D4 | ML Kit packaging | PO chooses before **Wed 21 Oct**: bundled (+12.5 MB, offline from first launch) or Play-services model (+99 KB, needs the model download on first use) | The release build cannot start without it |
| D5 | Users | "Available when needed" is the PO's answer (2026-10-20). To fix: **how much notice** each user needs. The plan assumes **48 hours** and asks the PO to call them on **Mon 26 Oct** for 28–29 Oct | The sessions have no date until a user says yes |
| D6 | T0.8 | The ground truth of the 16 documents is confirmed, or the task is closed as superseded by the 19-photograph verdicts | Its due date was 2 Oct; the board shows it 18 days late and nobody has said it matters |

## 3. Calendar

```
            Tue 20 ─ Thu 22 Oct          Fri 23 Oct     Mon 26 ─ Tue 27   Wed 28 ─ Thu 29   Fri 30     Mon 2 Nov
Orchestr.   board · archive · gate  ──►  ALPHA (APK)     ·                 ·                triage      MVP report
Mobile      S22 runs: T1.12 T1.13 T2.2   release build   fixes             fixes
            T2.1 C harness
QA          T2.5 screening report   ──►  ·              T3.1 benchmark    T3.2 SESSIONS     T3.3
PO          D4 · D5 · D6 · T2.5 OK       installs APK    calls the users   sits with users   approves thresholds
```

Slip against v0.2: **alpha +7 days, sessions +8 days, MVP report +10 calendar days (6 working days)**. The buffer week of v0.2 (26–30 Oct) is consumed. There is no buffer left after this plan; §6 says what happens if a date still slips.

## 4. Task changes

Dates are in force since the approval of 2026-10-20. `plan-tasks.yaml` keeps the v0.2 date next to each one (`v02_due`), so the board shows the slip.

| Task | v0.2 | v0.3 | Note |
| --- | --- | --- | --- |
| T1.10, T1.12, T1.13 | 9 Oct | **Thu 22 Oct** | Close with the device pass T2.7 |
| T2.1 | 16 Oct | **Thu 22 Oct** | Part C is the device harness run on the S22 |
| T2.5 | 14 Oct | **Thu 22 Oct** | Report written against the PO's verdicts; closes or amends GAP-001 |
| **T2.7 (new)** | — | **Thu 22 Oct** | Mobile + QA: device pass of shell, scanner, share intent, review screen on the S22; numbers and screenshots outside the repository |
| **T2.8 (new)** | — | **Fri 23 Oct** | Orchestrator: signed release APK (needs D4). Replaces "internal track" |
| T2.6 | 16 Oct | **Fri 23 Oct** | Alpha = T2.8 installed |
| T3.1 | 23 Oct | **Tue 27 Oct** | Benchmark over both halves of the acceptance corpus |
| T3.2 | 22 Oct | **Thu 29 Oct** | Sessions on 28–29 Oct, users called on 26 Oct |
| T3.3 | 23 Oct | **Fri 30 Oct** | Triage and fixes |
| T3.4 | 23 Oct | **Mon 2 Nov** | Thresholds (GAP-003), MVP report, R1 backlog by evidence |
| Archive closure (not a plan task) | — | **Wed 21 Oct** | The orchestrator archives every merged change; the residue goes to the board |

## 5. Gates (what "done" means from now on)

1. **A task is DONE only with evidence read in the session** (`plan-tasks.yaml`, `evidence`). "Merged" is not "done" for anything that touches the phone: it is done after the S22 run.
2. **Photo-route changes** merge only if the scorer against the PO's verdicts says: no correct field breaks, wrong fields do not increase, at least one improves (memory `photo-route-ground-truth-and-gate`).
3. **A milestone closes when the board says so**, not when the work seems finished. The board is regenerated at every close (`plan_board.py --write`) and CI rejects a stale one.
4. **No lane fails silently.** The daily close lists which lane ran, on which model, with what report.

## 6. Risks and cut line

| Risk | Trigger | Response |
| --- | --- | --- |
| The S22 is not reachable (wireless adb pairs per wifi network) | No device run by **Wed 21 Oct** | The PO pairs it on the current network (`adb pair`); if there is no phone by Thu 22 Oct, T2.7 and the alpha slip day for day |
| The gate for the photo route fails on `main` | Scorer shows a correct field broken | Revert the merge (`git revert -m 1`); the photo route goes to the sessions in its last passing state |
| No APK by Fri 23 Oct | Release build fails | Sessions run on the **debug build on the PO's S22**, driven by the user with the PO next to them. The sessions are supervised, so this does not need a distributed build. The APK follows after |
| Users cannot come on 28–29 Oct | PO calls on Mon 26 and nobody can | Sessions move to **Mon 2 – Tue 3 Nov**; the MVP report to Fri 6 Nov. This is the only slip this plan allows without a new replan |
| Scope creep during the sessions | A request outside §4 of v0.2 | Becomes an *Improvement* issue for R1; nothing enters R0 unless the PO says so |

**Cut line, if two dates slip:** leave R0, in this order, (1) the rescaled and contrast photo passes (DEC-017 already says they are removed if they add neither agreement nor accuracy), (2) mixed PDFs (`pdf-mixed`, GAP-033, no corpus case), (3) the foreground queue (FR-CAP-009 part). The loop (capture → read → review → send → read back) and the validation layer do not leave.

## 7. What does not change

Scope matrix (§4 of v0.2), architecture, the team and its roles, the privacy gate, the rule that every write to Ninox needs the PO's approval, and the test environment. **One correction to v0.2 §1, P5:** the test database is **`jd1m8n8l4j7i`** (`JI-PRUEBAS-CLAUDE`), team `qCq3JS7q7ptoap8Yg`; `db0000000000` was wrong (`AGENTS.md` §1.4, corrected 2026-10-07).

## 8. Decisions

Approved 2026-10-20: D1 (dates), D2 (APK instead of Play track), D3 (photo stays), D5 (48 hours of notice assumed; the PO calls the users on Mon 26 Oct). **Open:** D4 (ML Kit form, by Wed 21 Oct; without it T2.8 cannot start) and D6 (T0.8: confirm the 16-document ground truth, or close it as superseded).
