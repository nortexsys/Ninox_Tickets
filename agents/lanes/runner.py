"""Lane runner: run one LangGraph lane on one change, in its own git worktree, and report back.

    python -m agents.lanes.runner run core --change setup-mvp-foundations --task-file T1.1.md
    python -m agents.lanes.runner run core --change setup-mvp-foundations --resume
    python -m agents.lanes.runner check core --change setup-mvp-foundations
    python -m agents.lanes.runner smoke [ROLE ...]

What a run guarantees (plan v0.2, T0.9):
  * one worktree per lane, at agents/.build/worktrees/<role>, on branch change/<name>, cut from main;
  * a shell whose environment carries no secret: every *KEY*/*TOKEN*/*SECRET* variable and every
    NINOX_*/ANTHROPIC_*/DEEPSEEK_*/ATRIA_* variable is removed. Only the Ninox lane may receive
    NINOX_API_KEY, and only when asked for explicitly. NINOX_DB_ID never reaches a lane (AGENTS.md §1.4);
  * a SQLite checkpoint per (role, change), so a stopped lane resumes where it was;
  * a JSON report in agents/.build/reports/: files touched since main, and every one of them that
    lies outside the role's `writes` — any such file makes the verdict `reject`. Filesystem
    permissions do not bind the shell; this check does.

A lane never pushes, never merges and never writes to Ninox; the orchestrator integrates and the PO
approves (CLAUDE.md).
"""
from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import tempfile
import time
from datetime import datetime, timezone
from pathlib import Path

from agents.lanes.factory import build_lane_agent, may_write
from agents.lanes.models import make_model, user_env
from agents.tools.sync_skills import REPO, load_roles, sync

DOT_BUILD = REPO / "agents" / ".build"
WORKTREES = DOT_BUILD / "worktrees"
REPORTS = DOT_BUILD / "reports"
CHECKPOINTS = DOT_BUILD / "checkpoints.sqlite"
BASE = "main"
CHANGE_NAME = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")
SECRET_VAR = re.compile(r"KEY|TOKEN|SECRET|PASSW|CREDENTIAL|^NINOX_|^ANTHROPIC|^DEEPSEEK|^ATRIA|^OPENAI|^LANGSMITH",
                        re.IGNORECASE)
REPORT_BLOCK = re.compile(r"```json\s*(\{.*?\})\s*```", re.DOTALL)

LANE_PROMPT = """\
You are the {role} lane of Paperdrop for Ninox. You work on change `{change}`, on git branch `{branch}`,
in a worktree that is your filesystem root and your shell's working directory.

Rules, from AGENTS.md and CLAUDE.md — they override any skill:
* Write only under: {writes}. Anything else is rejected at review, including files a shell command creates.
* Commit your work on your branch with git. Never push, never merge, never switch branches.
* Never write to Ninox. Never use NINOX_DB_ID. Never print, log or commit a credential.
* Everything you write is in English. Requirement identifiers are copied exactly, never invented.
* If a task needs a decision that is not written in openspec/ or in the change's design.md, stop and
  list it under "blocked" — do not guess.

End your final message with a fenced ```json block:
{{"summary": "...", "done": ["..."], "files": ["..."], "tests": ["command -> result"],
  "scenarios": ["requirement/scenario covered"], "blocked": ["what, and what decision it needs"]}}
"""


def git(*args: str, cwd: Path | None = None) -> str:
    out = subprocess.run(["git", *args], cwd=cwd or REPO, capture_output=True, text=True, encoding="utf-8")
    if out.returncode != 0:
        raise RuntimeError(f"git {' '.join(args)}: {out.stderr.strip()}")
    return out.stdout.strip()


def lane_env(role: str, *, allow_ninox_token: bool = False, base: dict[str, str] | None = None) -> dict[str, str]:
    """The shell environment of a lane: the runner's own, minus every secret."""
    env = {k: v for k, v in (os.environ if base is None else base).items() if not SECRET_VAR.search(k)}
    if allow_ninox_token:
        if role != "ninox":
            raise ValueError("only the ninox lane may receive NINOX_API_KEY")
        token = user_env("NINOX_API_KEY")
        if not token:
            raise RuntimeError("NINOX_API_KEY is not set in the Windows user environment")
        env["NINOX_API_KEY"] = token
    return env


def ensure_worktree(role: str, change: str, *, base: str = BASE) -> Path:
    """The lane's worktree on change/<change>, created from `base` on first use."""
    if not CHANGE_NAME.match(change):
        raise ValueError(f"change name {change!r} must be kebab-case")
    if Path(git("rev-parse", "--show-toplevel")).resolve() != REPO.resolve():
        raise RuntimeError(f"{REPO} is not the repository root (AGENTS.md §1.1)")
    path, branch = WORKTREES / role, f"change/{change}"
    if path.exists():
        current = git("branch", "--show-current", cwd=path)
        if current != branch:
            raise RuntimeError(f"{path} is on {current!r}, not {branch!r}: finish that change first "
                               f"(one change per lane at a time)")
        return path
    path.parent.mkdir(parents=True, exist_ok=True)
    if git("branch", "--list", branch):
        git("worktree", "add", str(path), branch)
    else:
        git("worktree", "add", "-b", branch, str(path), base)
    return path


def touched_files(worktree: Path, *, base: str = BASE) -> list[str]:
    """Every path changed since the merge base with `base`: committed, staged, unstaged or untracked."""
    merge_base = git("merge-base", base, "HEAD", cwd=worktree)
    changed = git("diff", "--name-only", merge_base, cwd=worktree).splitlines()
    untracked = git("ls-files", "--others", "--exclude-standard", cwd=worktree).splitlines()
    return sorted({p for p in changed + untracked if p})


def check_bounds(role: str, worktree: Path, *, base: str = BASE) -> dict:
    writes = load_roles()["roles"][role].get("writes", [])
    files = touched_files(worktree, base=base)
    outside = [p for p in files if not may_write(writes, p)]
    return {"files_touched": files, "outside_writes": outside,
            "verdict": "reject" if outside else "review"}


def lane_report_block(text: str) -> dict | None:
    blocks = REPORT_BLOCK.findall(text or "")
    if not blocks:
        return None
    try:
        return json.loads(blocks[-1])
    except json.JSONDecodeError:
        return None


def final_text(messages) -> str:
    for m in reversed(messages):
        if m.type == "ai" and m.content:
            if isinstance(m.content, str):
                return m.content
            return "".join(b.get("text", "") for b in m.content if isinstance(b, dict))
    return ""


def token_usage(messages) -> dict:
    total = {"input_tokens": 0, "output_tokens": 0}
    for m in messages:
        usage = getattr(m, "usage_metadata", None) or {}
        for k in total:
            total[k] += usage.get(k, 0)
    return total


def write_report(report: dict) -> Path:
    REPORTS.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    path = REPORTS / f"{report['role']}-{report.get('change', 'smoke')}-{stamp}.json"
    path.write_text(json.dumps(report, indent=2, ensure_ascii=False), encoding="utf-8")
    return path


def run_lane(role: str, change: str, task: str | None, *, resume: bool = False,
             allow_ninox_token: bool = False, base: str = BASE, recursion_limit: int = 400) -> dict:
    from langgraph.checkpoint.sqlite import SqliteSaver

    data = load_roles()
    spec = data["roles"][role]
    if task is None and not resume:
        raise ValueError("a new run needs a task")
    model = make_model(spec["model"])
    worktree = ensure_worktree(role, change, base=base)
    branch = f"change/{change}"
    prompt = LANE_PROMPT.format(role=role, change=change, branch=branch, writes=", ".join(spec["writes"]))
    thread = f"{role}:{change}"
    CHECKPOINTS.parent.mkdir(parents=True, exist_ok=True)
    started = time.time()
    with SqliteSaver.from_conn_string(str(CHECKPOINTS)) as saver:
        sync(data)
        agent = build_lane_agent(role, worktree, model, system_prompt=prompt, checkpointer=saver, resync=False,
                                 shell_env=lane_env(role, allow_ninox_token=allow_ninox_token))
        payload = None if task is None else {"messages": [{"role": "user", "content": task}]}
        out = agent.invoke(payload, {"configurable": {"thread_id": thread}, "recursion_limit": recursion_limit})
    text = final_text(out["messages"])
    report = {
        "role": role, "change": change, "branch": branch, "worktree": str(worktree),
        "model": spec["model"]["id"], "thread_id": thread, "resumed": resume,
        "seconds": round(time.time() - started, 1), "usage": token_usage(out["messages"]),
        **check_bounds(role, worktree, base=base),
        "commits": git("log", "--oneline", f"{base}..HEAD", cwd=worktree).splitlines(),
        "lane_report": lane_report_block(text), "final_message": text,
    }
    report["path"] = str(write_report(report))
    return report


SMOKE_TASK = ("Use the shell tool to run `echo lane-ok`. Then answer in one line: the command's output, "
              "followed by the name of one skill listed in your Skills section (not a tool).")


def smoke(roles: list[str]) -> list[dict]:
    """Each lane answers a one-line task with its real model: a tool call, the shell and its skills."""
    data = load_roles()
    sync(data)
    results = []
    for role in roles:
        spec = data["roles"][role]
        started = time.time()
        result = {"role": role, "model": spec["model"].get("id")}
        try:
            with tempfile.TemporaryDirectory(prefix="pdl-") as tmp:
                agent = build_lane_agent(role, Path(tmp), make_model(spec["model"]), resync=False,
                                         shell_env=lane_env(role), shell_timeout=60)
                out = agent.invoke({"messages": [{"role": "user", "content": SMOKE_TASK}]},
                                   {"recursion_limit": 20})
            text = final_text(out["messages"])
            ran = any(m.type == "tool" and "lane-ok" in str(m.content) for m in out["messages"])
            named_own_skill = any(s in text for s in spec["skills"])
            result.update(ok=ran and "lane-ok" in text and named_own_skill, used_shell=ran,
                          named_own_skill=named_own_skill, reply=text.strip()[:300],
                          usage=token_usage(out["messages"]))
        except Exception as e:  # a smoke test reports every lane, it does not stop at the first failure
            result.update(ok=False, error=f"{type(e).__name__}: {str(e)[:300]}")
        result["seconds"] = round(time.time() - started, 1)
        results.append(result)
    return results


def main(argv: list[str] | None = None) -> int:
    lanes = [r for r, s in load_roles()["roles"].items() if s["runtime"] == "langgraph"]
    p = argparse.ArgumentParser(prog="python -m agents.lanes.runner")
    sub = p.add_subparsers(dest="cmd", required=True)
    r = sub.add_parser("run", help="run a lane on a change")
    r.add_argument("role", choices=lanes)
    r.add_argument("--change", required=True)
    g = r.add_mutually_exclusive_group()
    g.add_argument("--task")
    g.add_argument("--task-file", type=Path)
    r.add_argument("--resume", action="store_true", help="continue the lane's checkpointed thread")
    r.add_argument("--allow-ninox-token", action="store_true", help="ninox lane only; needs the PO's approval")
    c = sub.add_parser("check", help="re-run the bounds check of a lane's worktree")
    c.add_argument("role", choices=lanes)
    c.add_argument("--change", required=True)
    s = sub.add_parser("smoke", help="one-line task per lane on its real model")
    s.add_argument("roles", nargs="*", help=f"default: all of {', '.join(lanes)}")
    a = p.parse_args(argv)

    if a.cmd == "smoke":
        unknown = set(a.roles) - set(lanes)
        if unknown:
            p.error(f"not a lane: {', '.join(sorted(unknown))}")
        results = smoke(a.roles or lanes)
        print(json.dumps(results, indent=2, ensure_ascii=False))
        write_report({"role": "all", "change": "smoke", "results": results})
        return 0 if all(x["ok"] for x in results) else 1
    if a.cmd == "check":
        if not (WORKTREES / a.role).exists():
            p.error(f"{a.role} has no worktree")
        report = check_bounds(a.role, ensure_worktree(a.role, a.change))
        print(json.dumps(report, indent=2))
        return 0 if report["verdict"] == "review" else 1
    task = a.task_file.read_text(encoding="utf-8") if a.task_file else a.task
    report = run_lane(a.role, a.change, task, resume=a.resume, allow_ninox_token=a.allow_ninox_token)
    print(json.dumps({k: v for k, v in report.items() if k != "final_message"}, indent=2, ensure_ascii=False))
    return 0 if report["verdict"] == "review" else 1


if __name__ == "__main__":
    sys.exit(main())
