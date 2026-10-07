# Tasks: implement-setup-wizard

Plan v0.2 M1, Ninox lane, W1–W2. A task is done when its check passes, not when its files exist. Every
check is run on Flutter 3.47.5 / Dart 3.13.4, **from inside `app/`** for Flutter commands:
`flutter analyze --fatal-infos`, `dart format --set-exit-if-changed .`, `flutter test`; and from the
repository root `python .github/scripts/no_ninox_db_id.py`, `python .github/scripts/privacy_check.py`
(after `git add`), `python .github/scripts/encoding_guard.py`, `python .github/scripts/scenario_coverage.py`.
**No task makes a network call and none needs a token** (design §1). Dispatches A–D are those of
design §8; stop a dispatch on a green commit.

## 1. Ninox — dispatch A: the state machine and the token step (T1.10)

- [ ] 1.1 **Permission widening** (design §7) — done by the orchestrator in `agents/roles.yaml` before
      this dispatch, not by the lane. *Done when* `python -m agents.lanes.runner check ninox --change
      implement-setup-wizard` reports the four paths of design §7 as writable and everything else
      outside the Ninox lane's folders as not.
- [ ] 1.2 **`WizardStep`, `WizardState`, `WizardController`** (design §3). *Done when*
      `[setup-wizard/steps-auto-omit-when-there-is-nothing-to-choose]` — with one team, one database
      and one table the visible steps are token and mapping and no screen exists for the others; with
      several, each step is visible; a zero-option list stays on its step with its message; "back" skips
      omitted steps both ways; at most five steps exist in any state
      (`[setup-wizard/five-screens-at-most]`); a controller built with an initial `Destination`
      reopens at the right step.
- [ ] 1.3 **Token step, `TokenStore`, `SystemBrowser`** (design §4). *Done when*
      `[setup-wizard/token-step-via-the-system-browser]` — the browser is opened through the port and
      never a WebView (a test finds no `webview` in `app/pubspec.yaml` or `app/lib/`); an invalid token
      keeps the user on the step; a valid one delivers the team list **without a second call**; an
      unparsable host is reported at the field without a call; an unreachable host is reported at this
      step; every row of the outcome table of design §4 has a test; the token reaches `TokenStore`
      **only after** the call succeeds; and a test stringifies the controller, the state and every
      message the step can show and finds no token.
- [ ] 1.4 **Keystore implementation** (design §4). *Done when* `KeystoreTokenStore` implements
      `TokenStore` on `flutter_secure_storage` and is covered by a test on that package's own test
      double; the device behaviour is **not** claimed here (design §9).

## 2. Ninox — dispatch B: team, database and table

- [ ] 2.1 **`ChooseScreen`** for team, database and table (design §2–§3). *Done when* one widget
      serves the three steps from the lists the controller holds, a selection advances and triggers the
      next call (`listDatabases`, `listTables`) exactly once, and the tables arrive with their fields so
      the mapping step needs no further call (the fake counts calls).
- [ ] 2.2 **Routes and strings** (design §2, §7): `wizard_routes.dart`, the single `...wizardRoutes`
      line in `router.dart`, the `wizard`-prefixed keys in `app_en.arb`, the three dependencies in
      `app/pubspec.yaml`. *Done when* the app builds and the router reaches the wizard, no widget
      holds a string literal, `wizard_routes.dart` imports nothing from `router.dart`, and the diff of
      this task touches only the four paths of design §7 beside the wizard's own folders. If an Android
      manifest line is needed, the lane stops and reports **blocked** with the exact lines.

## 3. Ninox — dispatch C and D: matching, mapping, summary

- [ ] 3.1 **Type rules** (design §5): `type_rules.dart`, taking the Ninox type names from the `ninox`
      skill's reference. *Done when* each row is a test, a type absent from the table is never a
      candidate, and the filter runs before similarity (a test replaces the similarity with one that
      throws and a wrong-typed field still never reaches it).
- [ ] 3.2 **Matcher** (design §5): normalisation, the score, the threshold and margin as named
      constants, the one-to-one rule. *Done when* the six fixtures of design §5 give their outcomes —
      the German table proposes date, total and supplier, the table without a date-like field leaves
      `doc_date` unmapped with **no weak suggestion**, two equally plausible dates leave it unmapped,
      and the type filter settles the number-or-text `doc_number` — and the matcher's only input type is
      `NinoxTable`, so a formula field cannot be a candidate. Tag
      `[setup-wizard/two-stage-matching-with-a-strict-threshold]`; no test pins the number 0.85.
- [ ] 3.3 **`MappingScreen`** (design §5). *Done when*
      `[setup-wizard/pre-filled-proposals]` — fields open pre-filled where the matcher proposes and
      visibly unmapped (not an empty selector) where it does not; the picker offers only candidates of
      the right kind; each mapped field carries its absent setting, default empty
      (`[destinations-mapping/per-field-absent-setting]`); and the step completes with all, some or
      none mapped (`[setup-wizard/no-mapping-is-mandatory]`).
- [ ] 3.4 **`Destination`, its store and the summary** (design §6). *Done when* the destination
      round-trips through the store with identifiers and no token, `summarise` names the mapped and the
      unmapped fields, says *only the document will be attached, with no data* when nothing is mapped,
      and the final screen calls `onFinished` and offers capture
      (`[setup-wizard/plain-language-summary-and-first-document-offer]`).

## 4. Closing — orchestrator

- [ ] 4.1 `openspec validate implement-setup-wizard --strict` and `openspec validate --all --strict`
      green; the bounds verdict of every dispatch lists no write outside design §7 and the wizard's
      folders; no read of the production-database variable of `AGENTS.md` §1.4 and no test-base identifier anywhere (`no_ninox_db_id.py`).
- [ ] 4.2 **The live run** — T1.9's, not this change's: the wizard reading the user's real teams,
      databases, tables and fields, with `--allow-ninox-token`, by the product owner's approval and
      against the test base only. Not scheduled until the product owner approves it.
- [ ] 4.3 On archive: **revert the widening of design §7** in `agents/roles.yaml` and record it in the
      daily status; the dictionary gap for `supplier_tax_id` and `currency` (design §5) goes to the
      product owner as a possible new gap, **not** opened by the orchestrator.
