#!/usr/bin/env python3
"""Plan board for docs/Plan/ESTADO.md.

The board is generated from docs/Plan/plan-tasks.yaml, so a task's status is written in one place
and never retyped into the state file.

    plan_board.py --write   regenerate the board block in ESTADO.md, as of today (machine date)
    plan_board.py --check   ESTADO.md is within its line limit and its board block matches the YAML
                            as of the date the block itself declares (used by the hook and by CI)
    plan_board.py --drift   list OpenSpec changes whose merge is on main but whose tasks.md is not ticked,
                            and changes with no task in the YAML (needs the local git branches)
"""
from __future__ import annotations

import argparse
import datetime as dt
import re
import subprocess
import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[3]
TASKS = ROOT / "docs" / "Plan" / "plan-tasks.yaml"
STATE = ROOT / "docs" / "Plan" / "ESTADO.md"
MAX_LINES = 150
BEGIN = "<!-- BOARD:BEGIN -->"
END = "<!-- BOARD:END -->"
MILESTONES = ["M0", "M1", "M2", "M3"]
LABEL = {"DONE": "DONE", "IN_PROGRESS": "IN PROGRESS", "BLOCKED_PO": "BLOCKED PO", "NOT_STARTED": "NOT STARTED"}


def load() -> list[dict]:
    tasks = yaml.safe_load(TASKS.read_text(encoding="utf-8"))["tasks"]
    for t in tasks:
        if t["status"] not in LABEL:
            raise SystemExit(f"{t['id']}: unknown status {t['status']!r}")
        if t["status"] == "DONE" and not t.get("evidence"):
            raise SystemExit(f"{t['id']}: DONE without evidence")
        if t["ms"] not in MILESTONES:
            raise SystemExit(f"{t['id']}: unknown milestone {t['ms']!r}")
    return tasks


def is_late(t: dict, today: dt.date) -> bool:
    return t["status"] != "DONE" and t["due"] < today


def render(tasks: list[dict], today: dt.date) -> str:
    out = [BEGIN, f"Board as of {today.isoformat()} (generated from `plan-tasks.yaml`; do not edit by hand).", ""]
    out += ["| Milestone | Done | In progress | Not started | Late | Days late (oldest) |", "|---|---|---|---|---|---|"]
    for ms in MILESTONES:
        mt = [t for t in tasks if t["ms"] == ms]
        done = sum(t["status"] == "DONE" for t in mt)
        prog = sum(t["status"] in ("IN_PROGRESS", "BLOCKED_PO") for t in mt)
        notst = sum(t["status"] == "NOT_STARTED" for t in mt)
        late = [t for t in mt if is_late(t, today)]
        days = max(((today - t["due"]).days for t in late), default=0)
        out.append(f"| {ms} | {done} of {len(mt)} | {prog} | {notst} | {len(late)} | {days} |")
    out += ["", "Open tasks (everything not DONE):", "", "| Task | Due | Status | Change | Why it is not done |", "|---|---|---|---|---|"]
    for t in tasks:
        if t["status"] == "DONE":
            continue
        flag = LABEL[t["status"]] + (" · LATE" if is_late(t, today) else "")
        note = (t.get("evidence") or "").replace("|", "/")
        out.append(f"| {t['id']} {t['title']} | {t['due'].strftime('%d %b')} | {flag} | {t.get('change') or '-'} | {note} |")
    out.append(END)
    return "\n".join(out)


def block_of(text: str) -> str | None:
    m = re.search(re.escape(BEGIN) + r".*?" + re.escape(END), text, re.S)
    return m.group(0) if m else None


def cmd_write() -> int:
    today = dt.date.today()
    text = STATE.read_text(encoding="utf-8")
    if block_of(text) is None:
        print(f"no {BEGIN} ... {END} block in {STATE.name}", file=sys.stderr)
        return 1
    STATE.write_text(text.replace(block_of(text), render(load(), today)), encoding="utf-8", newline="\n")
    return 0


def cmd_check() -> int:
    text = STATE.read_text(encoding="utf-8")
    lines = len(text.splitlines())
    bad = []
    if lines > MAX_LINES:
        bad.append(f"ESTADO.md has {lines} lines, the limit is {MAX_LINES}")
    block = block_of(text)
    if block is None:
        bad.append("ESTADO.md has no board block")
    else:
        m = re.search(r"Board as of (\d{4}-\d{2}-\d{2})", block)
        as_of = dt.date.fromisoformat(m.group(1)) if m else dt.date.today()
        if block != render(load(), as_of):
            bad.append("the board block does not match plan-tasks.yaml; run plan_board.py --write")
    for b in bad:
        print("ESTADO check:", b, file=sys.stderr)
    return 1 if bad else 0


def git(*args: str) -> str:
    return subprocess.run(["git", "-C", str(ROOT), *args], capture_output=True, text=True, check=False).stdout


def cmd_drift() -> int:
    load()
    found = 0
    for d in sorted((ROOT / "openspec" / "changes").iterdir()):
        if d.name == "archive" or not (d / "tasks.md").exists():
            continue
        body = (d / "tasks.md").read_text(encoding="utf-8")
        total, ticked = len(re.findall(r"^- \[[ x]\]", body, re.M)), len(re.findall(r"^- \[x\]", body, re.M))
        merged = bool(git("log", "main", "--grep", f"Merge change/{d.name}", "-1", "--format=%h").strip())
        notes = []
        if merged and ticked < total:
            notes.append(f"merged on main but {ticked}/{total} ticked")
        if notes:
            found += 1
            print(f"{d.name}: " + "; ".join(notes))
    print(f"{found} change(s) with drift")
    return 0


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    g = ap.add_mutually_exclusive_group(required=True)
    g.add_argument("--write", action="store_true")
    g.add_argument("--check", action="store_true")
    g.add_argument("--drift", action="store_true")
    a = ap.parse_args()
    sys.exit(cmd_write() if a.write else cmd_check() if a.check else cmd_drift())
