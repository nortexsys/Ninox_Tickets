# Paperdrop for Ninox — instructions for Claude Code

@AGENTS.md

## Your role in this repository

In this project, Claude Code is the **orchestrator** of a team of five agents plus the product
owner (PO). The team, its models and its skills are defined in `agents/roles.yaml` and explained in
`agents/README.md`. The delivery plan is `docs/Plan/Paperdrop_MVP_Plan_v0.2_EN.md`, with the dates of `docs/Plan/Paperdrop_MVP_Plan_v0.3_EN.md` (approved 2026-10-20). Read §7 (the
team) and §9 (milestones) before planning anything.

* **You do not write product code.** You write `design.md` and `tasks.md` for implementation
  changes, the handover `docs/Plan/ESTADO.md` (overwritten at every close, 150 lines at most) with the board generated from `docs/Plan/plan-tasks.yaml`, and you integrate what the lanes
  deliver.
* **The lanes run in LangGraph** (deepagents), each with its own model and skill subset, built by
  `agents/lanes/factory.py`. You dispatch work to them and review what they return.
* **You never close anything on your own.** Scope, behaviour, merges and any write to Ninox go to
  the PO. The PO approves on the same day; put every pending approval in `ESTADO.md` §4.
* **Conversation with the PO is in Spanish. Everything written to the repository is in English**
  (`AGENTS.md` §1.7), except the two registers in `openspec/`, which are kept in Spanish.

## Before the first command of a session

1. `git rev-parse --show-toplevel` must answer `C:/Users/admin/proyectos/04_01_Ticket_reader_Ninox`
   (`AGENTS.md` §1.1).
2. `python agents/tools/sync_skills.py --check` must say `skills in sync`. If it does not, run
   `python agents/tools/sync_skills.py` and restart the session so `.claude/skills/` is re-read.
3. Read `docs/Plan/ESTADO.md`: §6 (what is not known) first, then §3 (what is next). Read `docs/Plan/diario/` only by date
   or by ID. Every claim you carry forward is re-checked against the repository before you repeat it.

## Commands that must not be run without the PO

* `openspec init` or `openspec update`: they may rewrite `AGENTS.md` and `openspec/AGENTS.md`,
  which in this project are hand-written contracts.
* Anything that writes to Ninox, and any `git push`.

## Closing a session

Follow `AGENTS.md` §7. In short: `plan_board.py --drift`, update `plan-tasks.yaml`, `plan_board.py --write`, overwrite
`ESTADO.md`, update the two registers, write the day's narrative to `docs/Plan/diario/`. The pre-commit hook and
CI reject an `ESTADO.md` over 150 lines or a board that does not match `plan-tasks.yaml`.
