"""Build one LangGraph lane agent (deepagents) with exactly the skills its role is allowed.

What this module guarantees, and what agents/tests/ proves:

  * a lane sees ONLY its role's skills (roles.yaml), through deepagents' SkillsMiddleware,
    with progressive disclosure: name + description in the system prompt, full SKILL.md on demand;
  * the skills are mounted read-only at /skills/, and the lane's worktree is its filesystem root;
  * filesystem writes are allowed only under the role's `writes` patterns (first match wins);
  * with `shell_env`, the lane also gets a `shell` tool, run in the worktree with exactly that
    environment and nothing inherited.

The shell is a separate tool, not deepagents' `execute`: deepagents 0.7.19 refuses filesystem
permissions on a backend that executes commands, and the permissions are worth keeping — they turn
an out-of-bounds write by a file tool into an immediate refusal the lane can react to. They do not
bind the shell, so the runner's diff check (agents/lanes/runner.py) is the enforcement.
"""
from __future__ import annotations

from pathlib import Path

from deepagents import create_deep_agent
from deepagents.backends import CompositeBackend, FilesystemBackend, LocalShellBackend
from deepagents.middleware.filesystem import FilesystemPermission, _check_fs_permission
from langchain_core.tools import StructuredTool

from agents.tools.sync_skills import BUILD, load_roles, sync

SKILLS_MOUNT = "/skills/"


def lane_permissions(writes: list[str], denies: list[str] = ()) -> list[FilesystemPermission]:
    """First match wins: skills are read-only, then the role's `denies`, then its `writes`, then nothing."""
    rules = [FilesystemPermission(operations=["write"], paths=[SKILLS_MOUNT + "**"], mode="deny")]
    if denies:
        rules.append(FilesystemPermission(operations=["write"], paths=list(denies), mode="deny"))
    rules += [
        FilesystemPermission(operations=["write"], paths=list(writes), mode="allow"),
        FilesystemPermission(operations=["write"], paths=["/**"], mode="deny"),
    ]
    return rules


def may_write(writes: list[str], path: str, denies: list[str] = ()) -> bool:
    """Whether a lane with these `writes`/`denies` may write `path` (repository-relative), by deepagents' own rule."""
    return _check_fs_permission(lane_permissions(writes, denies), "write", "/" + path.lstrip("/")) == "allow"


def shell_tool(worktree: Path, env: dict[str, str], timeout: int) -> StructuredTool:
    runner = LocalShellBackend(root_dir=Path(worktree), virtual_mode=True, env=env, inherit_env=False,
                               timeout=timeout)

    def shell(command: str) -> str:
        result = runner.execute(command)
        return f"{result.output}\n[exit code {result.exit_code}]"

    return StructuredTool.from_function(
        shell, name="shell",
        description=("Run a shell command (Windows cmd) in your worktree and return its output and exit code. "
                     "Use it for git, dart and flutter. Files it creates outside your write paths are "
                     f"rejected at review. Times out after {timeout} s."))


def build_lane_agent(role: str, worktree: Path, model, *, system_prompt: str | None = None,
                     tools=(), checkpointer=None, resync: bool = True,
                     shell_env: dict[str, str] | None = None, shell_timeout: int = 600):
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
    tools = list(tools)
    if shell_env is not None:
        tools.append(shell_tool(Path(worktree), shell_env, shell_timeout))
    return create_deep_agent(
        model=model,
        tools=tools,
        system_prompt=system_prompt,
        skills=[SKILLS_MOUNT],
        backend=backend,
        permissions=lane_permissions(spec.get("writes", []), spec.get("denies", [])),
        checkpointer=checkpointer,
        name=f"paperdrop-{role}",
    )
