# `agents/` — the agent team's configuration

How the agents that build Paperdrop for Ninox are organised, which model each one runs, and which
skills each one is given. It replaces the former `.dsh/` directory (DeepSeek Harness), which is no
longer used (DEC-011).

## Layout

| Path | What it is |
| --- | --- |
| `roles.yaml` | **The single source of truth**: role → runtime, model, skills, write paths |
| `skills/` | The 26 vendored skills, stored once: `ninox` plus 25 `dart-*` / `flutter-*` from `flutter/agent-plugins` (provenance in `../THIRD-PARTY-NOTICES.md`) |
| `third-party/` | Licence texts of the two vendored sources |
| `tools/sync_skills.py` | Materialises each role's subset of `skills/` (`--check` for CI) |
| `lanes/factory.py` | Builds one LangGraph lane agent (deepagents) with exactly its role's skills and write permissions |
| `tests/` | Proof that each lane sees only its own skills and cannot write outside its paths |
| `.build/` | Generated per-role skill copies for the LangGraph lanes. Git-ignored |
| `requirements.txt` | Python dependencies of the lane runner (Python 3.11+) |

## Who runs where

| Role | Runtime | Model | Skills are loaded by |
| --- | --- | --- | --- |
| Orchestrator | **Claude Code** (the session the product owner talks to) | Opus 5.5 | Claude Code itself, from `.claude/skills/` |
| Spec | LangGraph (deepagents) | Atria Dawn Preview | `SkillsMiddleware`, source `agents/.build/skills/spec/` |
| Core | LangGraph (deepagents) | DeepSeek-V4-Pro-0813 | same, `…/core/` |
| Ninox | LangGraph (deepagents) | DeepSeek-V4.1-Flash | same, `…/ninox/` |
| Mobile | LangGraph (deepagents) | DeepSeek-V4.1-Flash | same, `…/mobile/` |
| QA | LangGraph (deepagents) | Sonnet 5 | same, `…/qa/` |

## How a skill reaches an agent

1. A skill lives once in `agents/skills/<name>/SKILL.md`.
2. `roles.yaml` lists which roles get it.
3. `python agents/tools/sync_skills.py` copies each role's subset:
   * the orchestrator's into `.claude/skills/`, which Claude Code discovers natively and which is
     committed, because Claude Code reads it when the session opens;
   * every LangGraph role's into `agents/.build/skills/<role>/`, regenerated each time a lane starts.
4. A lane is built with `agents.lanes.factory.build_lane_agent(role, worktree, model)`. deepagents
   mounts that role's directory read-only at `/skills/` and puts only those skills' names and
   descriptions in the system prompt. The agent reads a full `SKILL.md` only when a task calls for it
   (progressive disclosure). The worktree is the lane's filesystem root; writes are allowed only
   under the role's `writes` patterns.

Verified on 2026-09-25 with deepagents 0.7.19 / LangGraph 1.2.12: `python -m pytest agents/tests`
(9 tests; a recording fake model, no API call) proves each lane is told about exactly its skills, can
read a skill's body, cannot write under `/skills/`, and cannot write outside its paths.

**Limit, stated so it is not discovered later.** Filesystem permissions bind deepagents' file tools,
not a shell. When the lane runner adds shell execution (plan T0.9), the orchestrator's review of the
diff (any path outside the role's `writes` → reject) is what enforces the boundary.

## Rules

* **No loose `.md` directly in `skills/`.** deepagents and Claude Code both treat each immediate
  subdirectory as a skill; `sync_skills.py` refuses a store with a loose `.md`, a missing
  `SKILL.md`, a name that differs from its directory, or an empty description.
* **A skill is not a rule.** It cannot override `AGENTS.md` or `openspec/`, and it cannot authorise a
  write to Ninox. Where a skill disagrees with an approved requirement, the requirement wins and the
  divergence is recorded in `openspec/product-decisions.md`.
* **Changing `roles.yaml` changes what an agent is told.** Record it like any other tooling decision.
* **API keys come from the Windows user environment,** never from a file, exactly like
  `NINOX_API_KEY` (`AGENTS.md` §1.3). Only the Ninox lane ever receives `NINOX_API_KEY`.

## Refreshing a vendored source

```powershell
# flutter/agent-plugins
git clone --depth 1 https://github.com/flutter/agent-plugins.git $env:TEMP\fa
git -C $env:TEMP\fa log -1 --format="%H %cs"
Copy-Item $env:TEMP\fa\skills\* agents\skills\ -Recurse -Force

# ninox-agent-skill
git clone --depth 1 https://github.com/aguillensp-sudo/ninox-agent-skill.git $env:TEMP\nin
git -C $env:TEMP\nin log -1 --format="%H %cs"
Copy-Item $env:TEMP\nin\SKILL.md, $env:TEMP\nin\README.md, $env:TEMP\nin\LICENSE agents\skills\ninox\ -Force
Copy-Item $env:TEMP\nin\references, $env:TEMP\nin\scripts agents\skills\ninox\ -Recurse -Force

python agents\tools\sync_skills.py
```

Record the new commit in `../THIRD-PARTY-NOTICES.md` in the same change.
