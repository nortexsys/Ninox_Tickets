# Third-party notices

This repository vendors two third-party skill collections under `agents/skills/`.
They are instruction files for agents, not application code: nothing here is
compiled, imported or shipped in the product. They are committed rather than
referenced so that any agent working on any clone of this repository has them
without a setup step.

Both licences permit redistribution provided the copyright notice and the licence
text travel with the copies. Both are reproduced verbatim under
`agents/third-party/`.

---

## 1. `flutter/agent-plugins` — 25 skills

| | |
| --- | --- |
| Source | <https://github.com/flutter/agent-plugins> |
| Upstream path | `skills/` |
| Commit pinned | `e89522a8b0c23d282e0acc9538dd0b2cd164358b` (2026-09-17) |
| Licence | BSD 3-Clause — Copyright 2026 The Flutter Authors. All rights reserved. |
| Full text | `agents/third-party/flutter-agent-plugins.LICENSE` |
| Vendored to | `agents/skills/dart-*`, `agents/skills/flutter-*` (25 directories) |

Each copied directory is unmodified. The bundle's own `LICENSE` is not repeated
per directory; the single copy above covers the set.

## 2. `ninox-agent-skill` — 1 skill

| | |
| --- | --- |
| Source | <https://github.com/aguillensp-sudo/ninox-agent-skill> |
| Local checkout the copy came from | `C:\Users\admin\proyectos\ninox-agent-skill` |
| Commit pinned | `4c14ee42a0bed7b742fcfe324da4e7c9f70a8e34` (2026-09-25) |
| Licence | MIT — Copyright (c) 2026 Nortex Systems |
| Full text | `agents/third-party/ninox-agent-skill.LICENSE`, also `agents/skills/ninox/LICENSE` |
| Vendored to | `agents/skills/ninox/` |

The bundle is unmodified, except that the standalone repository's `.git/` and
`.gitignore` were not copied — they describe that repository, not this one. Its
`.gitattributes` **was** copied, and deliberately: it pins `* text=auto eol=lf`
inside the bundle, so the vendored copy checks out byte-identical on any platform.

**The copyright holder is the same organisation that owns this project.** The
copy is vendored anyway, for the same reason as the Flutter skills: an agent on
another machine must not depend on a path under one person's home directory.

### Privacy check before vendoring

The bundle was read in full before it was committed here. It contains no API
token, no credential, no name of a natural person and no tax identifier. Its
subject matter is *how not* to leak those: `references/credentials-and-safety.md`
and `scripts/check_credentials.py` exist to read a token from the environment and
verify it by length and effect, never by value. Rule §1.3 of `AGENTS.md` is
therefore respected by the copy, not merely by the original.

---

## What was deliberately not vendored

| Source | Reason |
| --- | --- |
| `dart-lang/skills` | A strict subset of `flutter/agent-plugins`. Its 15 `dart-*` skills are byte-identical in name and purpose to 15 of the 25 above. Installing both would put two entries in the agent catalog for one instruction set. |
| `callstack/agent-device` | Its four skills drive iOS/Android through a `agent-device` MCP server and target macOS-hosted Apple tooling. This is a Windows host and the product's iOS work is budgeted as a native extension (ADR-001), not as an agent-driven simulator session. |
| `VeryGoodOpenSource/vgv-ai-flutter-plugin` | The PO scoped this work to two sources. Independently, six of its fifteen skills drive their own scaffolding through a `very_good_cli` MCP server that this environment does not run, and three of them (`layered-architecture`, `ui-package`, `create-project`) mandate a repository layout. See DEC-004. |
| `flutter/agent-plugins`, `.agents/agents/reidbaker-agent/skills/` (6 skills) | These are the private skills of one named maintainer's agent persona inside the upstream repository (`api-review`, `code-documentation`, `code-review`, `grill-with-docs`, `natural-writing`, `unix-cli-best-practices`), not part of the published `skills/` collection. |

## Skills whose tooling does not exist here

Three of the vendored skills instruct an agent to call MCP tools that this
harness does not expose: `dart-fix-runtime-errors` (`get_runtime_errors`, `lsp`,
`hot_reload`), `flutter-fix-layout-issues` and `flutter-add-integration-test`
(Dart and Flutter MCP servers). They remain installed because their guidance is
still readable and correct, but an agent that loads one must fall back to
`flutter analyze`, `flutter test` and `flutter run` instead of expecting the tool
to be there. This is stated so that the dead end is recognised rather than
reported as a broken skill.

`dart-setup-ffi-assets` and `dart-use-ffigen` have no application in this
project: the product calls platform OCR and PDF APIs, and neither is reached
through Dart FFI. They are installed anyway because the whole `skills/` collection
of the chosen source was taken as a unit, as DEC-004 records. Pruning a vendored
collection one skill at a time is how a future refresh silently reinstates what was
deleted.

## Installed skills that carry an opinion the project has not adopted

Being installed is not the same as being authoritative. Several of the vendored
skills do not merely describe a technique; they recommend a package or a shape:

| Skill | What it recommends | State in this project |
| --- | --- | --- |
| `flutter-apply-architecture-best-practices` | A layered UI / Logic / Data split | The functional fixes no layering. Advisory only. |
| `flutter-setup-declarative-routing` | `go_router` via `MaterialApp.router` | No routing package is chosen anywhere in the approved documents. |
| `flutter-use-http-package` | `package:http` | No HTTP client is chosen. Note that `ninox` requires retry and error semantics this skill does not cover. |
| `flutter-setup-localization` | `flutter_localizations` + `intl` with ARB files | The functional requires an English and German interface (FR-CTR-006, NFR-I18N-001) and externalised strings from the MVP; the package choice is still open. |
| `flutter-implement-json-serialization` | Hand-written `fromJson`/`toJson` | Reasonable default, but it is a choice, not a requirement. |
| `dart-migrate-to-checks-package` | Rewrite `expect` calls to `package:checks` | Only meaningful once a test suite exists. |
| `dart-use-primary-constructors`, `dart-use-pattern-matching` | Recent Dart language features | Fine, but they raise the effective Dart SDK floor, which the documents do not pin. |

**Where one of these contradicts an approved decision, the approved decision
wins.** `openspec/` is the source of truth for behaviour (`AGENTS.md` §1.6) and a
skill is not a spec. An agent that finds a skill disagreeing with a requirement
records the divergence in `openspec/product-decisions.md` instead of following the
skill.
