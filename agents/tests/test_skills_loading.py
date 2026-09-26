"""Proves that each LangGraph lane is told about exactly its own skills, and can read them.

No real model is called: a recording fake chat model captures the messages deepagents sends.
Run:  python -m pytest agents/tests -q   (from the repository root)
"""
from __future__ import annotations

import re
from pathlib import Path

import pytest
from langchain_core.language_models.fake_chat_models import GenericFakeChatModel
from langchain_core.messages import AIMessage

from agents.lanes.factory import build_lane_agent
from agents.tools.sync_skills import load_roles, sync, check

ROLES = load_roles()
LANES = [r for r, s in ROLES["roles"].items() if s["runtime"] == "langgraph"]
ALL_SKILLS = sorted({s for spec in ROLES["roles"].values() for s in spec["skills"]})


class Recorder(GenericFakeChatModel):
    seen: list = []

    def bind_tools(self, tools, **kwargs):
        return self

    def _generate(self, messages, stop=None, run_manager=None, **kwargs):
        type(self).seen.append(messages)
        return super()._generate(messages, stop=stop, run_manager=run_manager, **kwargs)


def system_text(messages) -> str:
    return "\n".join(str(m.content) for m in messages if m.type == "system")


@pytest.fixture(scope="module", autouse=True)
def materialised():
    sync(ROLES)
    assert check(ROLES) == 0


@pytest.mark.parametrize("role", LANES)
def test_lane_sees_exactly_its_skills(role, tmp_path):
    Recorder.seen = []
    model = Recorder(messages=iter([AIMessage(content="done")]))
    agent = build_lane_agent(role, tmp_path, model, resync=False)
    agent.invoke({"messages": [{"role": "user", "content": "hello"}]})
    prompt = system_text(Recorder.seen[0])
    own = set(ROLES["roles"][role]["skills"])
    for s in own:
        assert s in prompt, f"{role} was not told about its skill {s}"
    for s in set(ALL_SKILLS) - own:
        assert not re.search(rf"\b{re.escape(s)}\b", prompt), f"{role} was told about {s}, not its skill"


def test_lane_can_read_a_skill_body_and_cannot_write_it(tmp_path):
    from deepagents.backends import CompositeBackend, FilesystemBackend
    from agents.tools.sync_skills import BUILD
    backend = CompositeBackend(default=FilesystemBackend(root_dir=tmp_path, virtual_mode=True),
                               routes={"/skills/": FilesystemBackend(root_dir=BUILD / "ninox", virtual_mode=True)})
    body = backend.read("/skills/ninox/SKILL.md")
    assert "name: ninox" in str(body)


@pytest.mark.parametrize("path,allowed", [
    ("/skills/dart-add-unit-test/SKILL.md", False),   # skills are read-only
    ("/app/lib/main.dart", False),                     # outside core's `writes`
    ("/packages/paperdrop_core/lib/x.dart", True),     # inside core's `writes`
])
def test_core_write_permissions(path, allowed, tmp_path):
    call = AIMessage(content="", tool_calls=[{"name": "write_file", "args": {"file_path": path, "content": "x"}, "id": "c1"}])
    Recorder.seen = []
    model = Recorder(messages=iter([call, AIMessage(content="done")]))
    agent = build_lane_agent("core", tmp_path, model, resync=False)
    out = agent.invoke({"messages": [{"role": "user", "content": "write"}]})
    tool_msgs = [m for m in out["messages"] if m.type == "tool"]
    assert tool_msgs, "no tool result"
    denied = "denied" in str(tool_msgs[0].content).lower() or "permission" in str(tool_msgs[0].content).lower()
    assert denied != allowed, f"{path}: {tool_msgs[0].content}"
    written = (tmp_path / path.lstrip("/")).exists()
    assert written == allowed
    assert not (Path("agents/.build/skills/core/dart-add-unit-test/SKILL.md").read_text(encoding="utf-8") == "x")
