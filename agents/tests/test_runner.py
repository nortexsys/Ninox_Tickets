"""Proves the lane runner's guarantees without calling any model API.

Run:  python -m pytest agents/tests -q   (from the repository root)
"""
from __future__ import annotations

import subprocess
import sys

import pytest
from langchain_core.messages import AIMessage, HumanMessage, ToolMessage

from agents.lanes.factory import build_lane_agent, may_write
from agents.lanes.models import _deepseek_class, make_model
from agents.lanes.runner import lane_env, lane_report_block, touched_files
from agents.tests.test_skills_loading import Recorder
from agents.tools.sync_skills import load_roles

ROLES = load_roles()["roles"]


@pytest.fixture(autouse=True)
def fresh_recorder():
    Recorder.seen = []


def test_lane_env_carries_no_secret():
    base = {"PATH": "p", "SYSTEMROOT": "s", "ANTHROPIC_API_KEY": "x", "DEEPSEEK_API_KEY": "x",
            "ATRIA_API_KEY": "x", "NINOX_API_KEY": "x", "NINOX_DB_ID": "x", "GITHUB_TOKEN": "x",
            "SOME_SECRET": "x", "DB_PASSWORD": "x"}
    for role in ("spec", "core", "ninox", "mobile", "qa"):
        assert lane_env(role, base=base) == {"PATH": "p", "SYSTEMROOT": "s"}


def test_only_the_ninox_lane_may_receive_the_token():
    for role in ("spec", "core", "mobile", "qa"):
        with pytest.raises(ValueError):
            lane_env(role, allow_ninox_token=True, base={})


@pytest.mark.parametrize("role,path,allowed", [
    ("core", "packages/paperdrop_core/lib/money.dart", True),
    ("core", "app/lib/main.dart", False),
    ("core", "agents/roles.yaml", False),
    ("ninox", "app/lib/features/wizard/wizard_screen.dart", True),
    ("ninox", "app/lib/features/review/review_screen.dart", False),
    ("mobile", "app/lib/features/review/review_screen.dart", True),
    ("qa", "packages/paperdrop_core/test/money_test.dart", True),
    ("qa", "packages/paperdrop_core/lib/money.dart", False),
    ("spec", "openspec/changes/x/specs/cap/spec.md", True),
    ("spec", "AGENTS.md", False),
])
def test_bounds_follow_roles_yaml(role, path, allowed):
    assert may_write(ROLES[role]["writes"], path) == allowed


def git(*args, cwd):
    subprocess.run(["git", "-c", "user.email=t@t", "-c", "user.name=t", *args], cwd=cwd, check=True,
                   capture_output=True)


def test_touched_files_sees_committed_staged_and_untracked(tmp_path):
    git("init", "-q", "-b", "main", cwd=tmp_path)
    (tmp_path / "README.md").write_text("x")
    git("add", ".", cwd=tmp_path)
    git("commit", "-q", "-m", "base", cwd=tmp_path)
    git("checkout", "-q", "-b", "change/probe", cwd=tmp_path)
    (tmp_path / "packages" / "paperdrop_core").mkdir(parents=True)
    (tmp_path / "packages" / "paperdrop_core" / "a.dart").write_text("x")
    git("add", ".", cwd=tmp_path)
    git("commit", "-q", "-m", "inside", cwd=tmp_path)
    (tmp_path / "README.md").write_text("changed by a shell command")
    (tmp_path / "stray.txt").write_text("untracked")
    files = touched_files(tmp_path)
    assert files == ["README.md", "packages/paperdrop_core/a.dart", "stray.txt"]
    outside = [p for p in files if not may_write(ROLES["core"]["writes"], p)]
    assert outside == ["README.md", "stray.txt"]


def test_one_worktree_per_lane_on_its_change_branch(tmp_path, monkeypatch):
    from agents.lanes import runner
    repo = tmp_path / "repo"
    repo.mkdir()
    git("init", "-q", "-b", "main", cwd=repo)
    (repo / "README.md").write_text("x")
    git("add", ".", cwd=repo)
    git("commit", "-q", "-m", "base", cwd=repo)
    monkeypatch.setattr(runner, "REPO", repo)
    monkeypatch.setattr(runner, "WORKTREES", tmp_path / "wt")
    path = runner.ensure_worktree("core", "setup-probe")
    assert runner.git("branch", "--show-current", cwd=path) == "change/setup-probe"
    assert runner.ensure_worktree("core", "setup-probe") == path          # reused, not recreated
    with pytest.raises(RuntimeError, match="one change per lane"):
        runner.ensure_worktree("core", "another-change")
    with pytest.raises(ValueError):
        runner.ensure_worktree("mobile", "Not_Kebab")


def test_shell_runs_in_the_worktree_without_secrets(tmp_path, monkeypatch):
    monkeypatch.setenv("NINOX_DB_ID", "must-not-leak")
    probe = f'"{sys.executable}" -c "import os; print(os.environ.get(\'NINOX_DB_ID\', \'absent\'), os.getcwd())"'
    call = AIMessage(content="", tool_calls=[{"name": "shell", "args": {"command": probe}, "id": "c1"}])
    model = Recorder(messages=iter([call, AIMessage(content="done")]))
    agent = build_lane_agent("core", tmp_path, model, resync=False, shell_env=lane_env("core"))
    out = agent.invoke({"messages": [{"role": "user", "content": "probe"}]})
    result = str([m for m in out["messages"] if m.type == "tool"][0].content)
    assert "absent" in result and "must-not-leak" not in result
    assert str(tmp_path).lower() in result.lower()


def test_checkpoint_resumes_a_thread(tmp_path):
    from langgraph.checkpoint.sqlite import SqliteSaver
    config = {"configurable": {"thread_id": "core:probe"}}
    db = str(tmp_path / "cp.sqlite")
    with SqliteSaver.from_conn_string(db) as saver:
        agent = build_lane_agent("core", tmp_path, Recorder(messages=iter([AIMessage(content="first")])),
                                 checkpointer=saver, resync=False)
        agent.invoke({"messages": [{"role": "user", "content": "one"}]}, config)
    with SqliteSaver.from_conn_string(db) as saver:
        agent = build_lane_agent("core", tmp_path, Recorder(messages=iter([AIMessage(content="second")])),
                                 checkpointer=saver, resync=False)
        out = agent.invoke({"messages": [{"role": "user", "content": "two"}]}, config)
    texts = [m.content for m in out["messages"] if m.type in ("human", "ai")]
    assert texts == ["one", "first", "two", "second"]


def test_deepseek_passes_reasoning_back():
    model = _deepseek_class()(model="deepseek-flash", api_key="not-a-key")
    history = [
        HumanMessage("hi"),
        AIMessage(content="", additional_kwargs={"reasoning_content": "thought-1"},
                  tool_calls=[{"name": "ls", "args": {}, "id": "c1"}]),
        ToolMessage("[]", tool_call_id="c1"),
        AIMessage(content="done", additional_kwargs={"reasoning_content": "thought-2"}),
        HumanMessage("again"),
    ]
    wire = [m for m in model._get_request_payload(history)["messages"] if m["role"] == "assistant"]
    assert [m.get("reasoning_content") for m in wire] == ["thought-1", "thought-2"]


def test_unconfirmed_model_is_refused():
    with pytest.raises(ValueError):
        make_model({"name": "x", "provider": "TO-CONFIRM", "id": "TO-CONFIRM", "api_key_env": "X"})


def test_lane_report_block_is_parsed():
    text = 'Done.\n```json\n{"summary": "s", "blocked": []}\n```'
    assert lane_report_block(text) == {"summary": "s", "blocked": []}
    assert lane_report_block("no block") is None
