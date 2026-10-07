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
| `lanes/factory.py` | Builds one LangGraph lane agent (deepagents) with exactly its role's skills, write permissions and, optionally, a `shell` tool |
| `lanes/models.py` | Turns a role's `model` entry into a chat model; reads its key from the Windows user environment |
| `lanes/runner.py` | The lane runner: worktree per lane, secret-free shell, checkpoints, bounds check and JSON report; smoke test |
| `tests/` | Proof of the above, with no API call |
| `.build/` | Generated and local state: per-role skill copies, lane worktrees, checkpoints, reports. Git-ignored |
| `requirements.txt` | Python dependencies of the lane runner (Python 3.11+) |

## Who runs where

| Role | Runtime | Model | Skills are loaded by |
| --- | --- | --- | --- |
| Orchestrator | **Claude Code** (the session the product owner talks to) | Opus 5.5 | Claude Code itself, from `.claude/skills/` |
| Spec | LangGraph (deepagents) | Atria Dawn Preview (`Atria-Dawn-Preview`) | `SkillsMiddleware`, source `agents/.build/skills/spec/` |
| Core | LangGraph (deepagents) | DeepSeek-V4-Pro-0813 (`deepseek-v4-pro`) | same, `…/core/` |
| Ninox | LangGraph (deepagents) | DeepSeek-V4.1-Flash (`deepseek-flash`) | same, `…/ninox/` |
| Mobile | LangGraph (deepagents) | DeepSeek-V4.1-Flash (`deepseek-flash`) | same, `…/mobile/` |
| QA | LangGraph (deepagents) | Sonnet 5 (`claude-sonnet-5`) | same, `…/qa/` |

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

## Running a lane

Python 3.11+ in a virtual environment **outside** the repository, on a short path (a long one breaks
a DLL load on Windows): `python -m venv C:\Users\admin\pdlv` (not under `%TEMP%`: Windows emptied a venv there on 2026-10-07 and left `pip` and `deepagents` broken), then `pip install -r agents/requirements.txt`.
From the repository root:

```powershell
python -m agents.lanes.runner smoke                     # every lane, one-line task, real model
python -m agents.lanes.runner run core --change <name> --task-file <task.md>
python -m agents.lanes.runner run core --change <name> --resume      # continue a stopped lane
python -m agents.lanes.runner check core --change <name>             # re-run the bounds check
```

**On Windows, run the runner in Python's UTF-8 mode** (`python -X utf8 -m agents.lanes.runner ...`):
deepagents' shell decodes command output with the locale's code page, and Flutter's UTF-8 output then
fails to decode and is lost (measured 2026-09-30: the Mobile lane re-ran commands that returned
nothing until it hit the step limit). **Do not start two lanes in the same second**: each run syncs
`.claude/skills/` at start, and two syncs at once collide on a locked file.

A run:

* works in `agents/.build/worktrees/<role>`, on branch `change/<name>` cut from `main`; one change
  per lane at a time. The lane commits there; it never pushes or merges;
* gets a `shell` tool whose environment has every secret removed (`*KEY*`, `*TOKEN*`, `*SECRET*`,
  `NINOX_*`, provider variables). `--allow-ninox-token` gives `NINOX_API_KEY` to the Ninox lane
  only, and needs the PO's approval; `NINOX_DB_ID` never reaches a lane;
* checkpoints to `agents/.build/checkpoints.sqlite`, thread `<role>:<change>`;
* writes a JSON report to `agents/.build/reports/`: files touched since `main`, those outside the
  role's `writes` (or inside its `denies`), commits, token usage, and the lane's own report block.
  Any such file makes the verdict `reject`.

A role's `denies` (roles.yaml) is checked before its `writes`: Mobile writes `app/**` except the
Ninox lane's wizard and send folders. `--model-from <role>` runs a lane on another lane's model —
a substitution the PO must know about; the report records it as `model_substituted_from`.

Verified on 2026-09-26: `pytest agents/tests` 28 passed; smoke test green on Spec, Core, Ninox and
Mobile with their real models (a shell call, then a one-line answer naming one of the lane's skills).

**Limit, stated so it is not discovered later.** Filesystem permissions bind deepagents' file tools,
not the shell. The runner's bounds check on the diff (any path outside the role's `writes` → reject)
is what enforces the boundary, and the orchestrator reads it before integrating anything. Until 2026-09-30 it had a hole: deepagents
matches paths without `DOTGLOB`, so the final `/**` deny missed `.github/` and `.claude/` and a lane
could write there unseen (the Spec lane did, to an allowlist). `lanes/factory.py` now sets `DOTGLOB`,
and `tests/test_runner.py` pins the dot-path cases. The shell
is not confined to the worktree either: on 2026-09-26 the Spec lane `cd`-ed into the main checkout
to read it. Lanes are told to stay in their worktree, and a run whose main checkout differs before
and after is rejected (`main_checkout_changed`) — the orchestrator then reads the diff, since its
own edits during the run trip the same check. The
`shell` tool is not deepagents' `execute`: deepagents 0.7.19 refuses filesystem permissions on a
backend that executes commands, and the permissions are kept because they give the lane an
immediate refusal instead of a rejection at review.

**DeepSeek's thinking mode** is on by default and rejects (HTTP 400) a tool-calling history without
each assistant turn's `reasoning_content`; `lanes/models.py` sends it back, which langchain-deepseek
1.1.1 does not. **Atria** is always streamed with a long socket timeout: its gateway cuts long
non-streamed requests (measured on BearingWorld). Atria also gets every all-text message as a plain
string: deepagents sends the system prompt as content blocks, and in that shape Atria's gateway mostly
misses it — measured on 2026-09-28, the Spec lane named its skill 1 time in 4 with blocks and 4 in 4
with a string, and before the fix it had been running without its system prompt most of the time.

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
