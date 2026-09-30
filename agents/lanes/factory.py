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
from deepagents.middleware import filesystem as _deepagents_fs
from deepagents.middleware.filesystem import FilesystemPermission, _check_fs_permission
from langchain.agents.middleware import ToolErrorMiddleware
from langchain_core.tools import StructuredTool

from agents.tools.sync_skills import BUILD, load_roles, sync

SKILLS_MOUNT = "/skills/"

# deepagents 0.7.19 matches permission paths with wcmatch and no DOTGLOB, so `**` skips any path
# segment that starts with a dot, and a path no rule matches is allowed. Without this, the final
# `/**` deny missed `.github/` and `.claude/`: on 2026-09-30 the Spec lane wrote
# `.github/scripts/no_ninox_db_id_allowlist.txt` and neither the file tools nor the bounds check saw
# it. The flag is read at call time, so setting it here fixes both.
_deepagents_fs._FS_WCMATCH_FLAGS |= _deepagents_fs.wcglob.DOTGLOB


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


def _tool_error_to_model(exc: Exception, request) -> str | None:
    """A file tool asked for a path outside the worktree, or a missing one: tell the lane, don't crash.

    deepagents 0.7.19 raises ValueError for a path outside the backend's root, and the ToolNode
    re-raises it, which ended a 90-minute Spec run on 2026-09-26. Anything else still propagates."""
    if isinstance(exc, (ValueError, OSError)):
        return (f"`{request.tool_call['name']}` failed: {type(exc).__name__}: {exc}. Use a path relative to "
                f"your worktree root (it starts with /), and stay inside the worktree.")
    return None


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
        middleware=[ToolErrorMiddleware(on_error=_tool_error_to_model)],
        checkpointer=checkpointer,
        name=f"paperdrop-{role}",
    )
