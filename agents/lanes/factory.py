"""Build one LangGraph lane agent (deepagents) with exactly the skills its role is allowed.

The skills part of the lane runner. What this module guarantees, and what
agents/tests/test_skills_loading.py proves:

  * a lane sees ONLY its role's skills (roles.yaml), through deepagents' SkillsMiddleware,
    with progressive disclosure: name + description in the system prompt, full SKILL.md on demand;
  * the skills are mounted read-only at /skills/, and the lane's worktree is its filesystem root;
  * filesystem writes are allowed only under the role's `writes` patterns (first match wins).

What it does NOT do yet (plan v0.2, T0.9): shell execution, git worktree management, reporting back
to the orchestrator, checkpointing. Filesystem permissions do not bind a shell tool, so when one is
added the orchestrator's diff review (paths outside `writes` => reject) is the enforcement.
"""
from __future__ import annotations

from pathlib import Path

from deepagents import create_deep_agent
from deepagents.backends import CompositeBackend, FilesystemBackend
from deepagents.middleware.filesystem import FilesystemPermission

from agents.tools.sync_skills import BUILD, load_roles, sync

SKILLS_MOUNT = "/skills/"


def lane_permissions(writes: list[str]) -> list[FilesystemPermission]:
    return [
        FilesystemPermission(operations=["write"], paths=[SKILLS_MOUNT + "**"], mode="deny"),
        FilesystemPermission(operations=["write"], paths=list(writes), mode="allow"),
        FilesystemPermission(operations=["write"], paths=["/**"], mode="deny"),
    ]


def build_lane_agent(role: str, worktree: Path, model, *, system_prompt: str | None = None,
                     tools=(), checkpointer=None, resync: bool = True):
    data = load_roles()
    spec = data["roles"].get(role)
    if spec is None or spec.get("runtime") != "langgraph":
        raise ValueError(f"{role!r} is not a langgraph role in agents/roles.yaml")
    if resync:
        sync(data)
    skills_dir = BUILD / role
    backend = CompositeBackend(
        default=FilesystemBackend(root_dir=Path(worktree), virtual_mode=True),
        routes={SKILLS_MOUNT: FilesystemBackend(root_dir=skills_dir, virtual_mode=True)},
    )
    return create_deep_agent(
        model=model,
        tools=list(tools),
        system_prompt=system_prompt,
        skills=[SKILLS_MOUNT],
        backend=backend,
        permissions=lane_permissions(spec.get("writes", [])),
        checkpointer=checkpointer,
        name=f"paperdrop-{role}",
    )
