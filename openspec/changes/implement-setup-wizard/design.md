# Design: implement-setup-wizard

Owner: Ninox lane. Written by the orchestrator on 2026-10-07. Scenarios of `openspec/specs/setup-wizard/`
and `destinations-mapping/` are not restated here: the lane reads them and each test cites its
scenario. This design adds what a scenario cannot say — where the code lives, how the steps are
computed, the matching's data and constants, the one permission widening this change needs, and what
the demo of Fri 9 Oct does and does not require.

## 1. Rules that bind every file of this change

* Code goes in `app/lib/features/wizard/` and its tests in `app/test/features/wizard/` — the Ninox
  lane's folders — **plus the four paths §7 widens for this change and no others**.
* The wizard reaches Ninox through `NinoxPort` only (`packages/ninox_client`). It builds no URL, sends
  no request of its own and parses no Ninox JSON. `package:http` appears in exactly one place, the
  composition function of §3 that builds the real adapter; every widget and controller takes a
  `NinoxPort` and is tested on a fake.
* **No environment variable is read anywhere in the wizard** — token, team, database or host
  (`AGENTS.md` §1.3–§1.4). The team and the database are chosen from the lists the port returns and
  stored in the destination. The identifiers of the test base appear in no fixture.
* **The token** is held in a `String` only for as long as a step needs it. It is never in a log line,
  an exception message, a `toString`, widget state that outlives the step, a route argument, a file or
  a fixture. A test stringifies the controller, the state and every error the wizard can show, and
  searches them for the token.
* **No test makes a network call and none needs a token.** Every Ninox answer in a test is a fixture
  or a fake `NinoxPort`. The live run is T1.9's, under D-10 and the product owner's approval of
  `--allow-ninox-token`.
* All user-visible text is an `app_en.arb` key (plan §2: English, every string externalised from
  day one). No string literal in a widget.
* Checks, from inside `app/` for Flutter commands (never `dart test` or `flutter test` from the
  repository root, memory note): `flutter analyze --fatal-infos`, `dart format --set-exit-if-changed .`,
  `flutter test`; from the root `python .github/scripts/no_ninox_db_id.py`,
  `python .github/scripts/privacy_check.py` (after `git add`), `python .github/scripts/encoding_guard.py`,
  `python .github/scripts/scenario_coverage.py`.

## 2. Layout of the feature

```
app/lib/features/wizard/
  wizard_routes.dart            `wizardRoutes` — the one entry point router.dart imports
  wizard_controller.dart        the state machine of §3
  wizard_step.dart              WizardStep, WizardState (immutable)
  destination.dart              Destination, FieldMapping, AbsentSetting
  data/
    token_store.dart            abstract TokenStore (read, write, clear)
    keystore_token_store.dart   the Android Keystore implementation
    destination_store.dart      abstract + file-backed implementation (no secret in it)
    port_factory.dart           NinoxPortFactory + the one composition with package:http
  token/token_screen.dart       + the system-browser launcher port
  choose/choose_screen.dart     one widget for team, database and table
  mapping/mapping_screen.dart
  summary/summary_screen.dart
  matching/
    field_matcher.dart          the two-stage matcher of §5
    type_rules.dart             Ninox field type → target kind, as data
    similarity.dart             normalisation and the score
app/test/features/wizard/       one folder per subfolder above
```

`wizard_routes.dart` exports `final List<RouteBase> wizardRoutes` and takes what it needs
(controller factory, `onFinished`) from `deps` passed by the router; it **imports nothing from
`router.dart`**, which would be a cycle — the closing screen's "capture a document" calls an
`onFinished` callback the router supplies, and the router already knows `captureRoute`.

## 3. The state machine (FR-WIZ-001, FR-WIZ-002)

`WizardStep { token, team, database, table, mapping }` — exactly these five; the summary is the
closing view of the mapping step's completion (spec `five-screens-at-most`: *at most five screens*, the
summary is "the closing summary" of `plain-language-summary-and-first-document-offer`) and the lane
reports if the scenario text reads otherwise rather than adding a sixth step.

The controller holds `WizardState`: the endpoint, the validated credentials, the three lists
(`teams`, `databases`, `tables`), the three chosen ids, and the mapping. **Which steps are shown is
computed**, never stored: `visibleSteps(state)` is `token`, then each of `team`, `database`, `table` whose
list does **not** hold exactly one option, then `mapping`.

* A list of **one** option is chosen automatically and its step produces **no screen**, not a
  pre-confirmed one. A single-option subscription therefore shows token and mapping only.
* A list of **zero** options is not specified by the functional. The step stays where it is with a
  plain-language explanation (an `app_en.arb` string); the lane records this in its report as a case it
  decided, and does not invent a way to continue.
* "Back" skips omitted steps in both directions, and a destination can be **edited later through the
  same sequence** — the controller takes an optional initial `Destination`, so nothing is wired to
  first-run state (the R1 reasons in the proposal's *Deferred*).
* Each step's call is made when the previous step completes: `listTeams` at the token step,
  `listDatabases(teamId)` after a team, `listTables(teamId, databaseId)` after a database. The tables
  come **with their fields**, so the mapping step makes no further call.

**Composition.** `NinoxPortFactory = NinoxPort Function(NinoxEndpoint, NinoxCredentials)`. The app's
composition (in `data/port_factory.dart`) builds `ClassicNinoxAdapter(endpoint:, credentials:, client: http.Client())`;
tests pass a factory returning a fake. The controller is the only caller of the factory.

## 4. The token step (FR-WIZ-003, FR-DST-008, FR-CFG-004)

* **Obtaining the token.** Instructions text; a *Paste* action reading the clipboard
  (`Clipboard.getData`), trimming it and filling an obscured field; and an *Open Ninox settings*
  action that opens the page through a launcher port
  (`abstract interface class SystemBrowser { Future<bool> open(Uri url); }`) implemented with
  `url_launcher`'s `launchUrl(url, mode: LaunchMode.inAppBrowserView)` — Custom Tabs on Android — and
  **never** a WebView the app controls. A test asserts that neither `app/pubspec.yaml` nor `app/lib/`
  mentions `webview` (NFR-SEC-002). The settings URL is a constant in one file; the lane takes it from
  the `ninox` skill's reference and, if the skill does not state it, reports that rather than inventing
  one. No username or password is ever requested (`token-is-the-only-credential`).
* **The advanced setup** holds the host field, collapsed, defaulting to `NinoxEndpoint.cloud`. Input is
  parsed with `NinoxEndpoint.parse`; a `null` is reported at the field as "not a valid host" and the
  validating call is not made.
* **Validation by effect, one call.** The step builds the port from the parsed endpoint and the pasted
  token and calls `listTeams()`. That single call validates the token **and** the host, and its result
  is the next step's list. Mapping of the outcome to what the user sees:

  | Outcome | The user sees | State |
  | --- | --- | --- |
  | a list of teams | (moves on) | token written to the keystore, lists kept |
  | `Unauthorized` | the token is not accepted | stays on the step |
  | `TransportFailure` | the host could not be reached — check the address and the connection | stays on the step |
  | `UnexpectedResponse` | the address answered but is not a Ninox API | stays on the step |
  | `ServerError`, `RateLimited` | Ninox answered with an error — try again | stays on the step |

  `NotFound` and any other `NinoxFailure` take the last row. The messages never contain the token or the
  response body.
* **Storage.** The token is written through `TokenStore` **only after** the call succeeds, to the
  Android Keystore (`flutter_secure_storage`, the Keystore-backed mode) and nowhere else: not a file,
  not shared preferences, not a log. The host and the ids are not secret and go to the destination
  store of §6. The clearing action is R1's, but `TokenStore.clear()` exists so R1 does not reopen it.
* The widget tests drive the step with a fake store and a fake browser, and `[setup-wizard/token-step-via-the-system-browser]`
  covers: the browser is opened with the launcher and not otherwise, an invalid token keeps the user on
  the step, a valid one produces the team list **without a second call** (the fake counts calls), and an
  unreachable host is reported at this step.

## 5. The mapping step (FR-WIZ-004 … FR-WIZ-007, FR-DST-006)

**What is mappable** (plan §2 "Mappable fields"): the six core fields, in the order the canonical
document declares them — `doc_date`, `supplier_name`, `supplier_tax_id`, `doc_number`, `gross_total`,
`currency` — plus `net_total` and `tax_total`. **Target kinds in the MVP are `string`, `number`,
`date`**; `choice` and per-slot tax fields are R1.

**Candidates.** The mapping step's input is the `NinoxTable` the port returned. `.../tables` omits
formula fields (DEC-005, GAP-022), so a formula field is not a candidate **at any stage because the
matcher is only ever given what the port returned**; there is no filter, and no call to `.../schema`.

**Stage 1 — the hard type filter** (`matching/type_rules.dart`). A table of data: each target field's
kind, and for each kind the Ninox type names it may bind. Date → date kinds only; amounts → number
kinds only; text → string kinds only. The Ninox type names are read from the `ninox` skill's reference
and written once in this file with a test per row; a type the table does not list (choice, files,
anything unknown) is never a candidate. The filter runs **before** any similarity is computed — a test
makes `similarity.dart` throw and proves a wrong-typed field never reaches it.

**Stage 2 — similarity against the synonym dictionary** (`matching/similarity.dart`). The synonyms
are **`paperdrop_core`'s `labelTerms`**, which the proposal says the wizard consumes and extends with
no term of its own, taken by `LabelKind` and **across every language** (a German table is matched
whatever the interface language):

| Mappable field | Synonym source |
| --- | --- |
| `doc_date` | `LabelKind.date` |
| `supplier_name` | `LabelKind.supplier` |
| `doc_number` | `LabelKind.docNumber` |
| `gross_total` | `LabelKind.total` |
| `net_total` | `LabelKind.base` |
| `tax_total` | `LabelKind.tax` |
| `supplier_tax_id`, `currency` | **none exists in Annex C** — compared only with the field's own canonical name (`supplier tax id`, `currency`); the lane reports this as a dictionary gap and adds no term |

Both the candidate's name and each term are normalised the same way (lower case, diacritics removed,
camel-case and `_`/`-` split, punctuation dropped, whitespace collapsed). The score is the **greater**
of the whole-string similarity (one minus normalised edit distance) and the token-set similarity,
taken as the maximum over the field's synonyms. It is integer-free arithmetic on a field name — no
money — so `double` is allowed **in `app/`**; the no-float rule is the core's.

**The threshold, as an implementation constant and not a requirement.** `proposalThreshold = 0.85` and
`proposalMargin = 0.05`, each a named constant in `field_matcher.dart`: a core field is **proposed** only
if its best candidate scores at least the threshold **and** beats the second best by at least the
margin; otherwise it is **unmapped** — an ambiguous pair is a non-suggestion, which is the failure mode
the functional names. A Ninox field is proposed for at most one core field (highest score first; the
loser may fall to its next candidate only if that clears both tests). The numbers are a starting point,
stated here so the lane has one; the spec requires the **outcome**, so the tests assert outcomes on named
fixtures and no test pins the value 0.85. They are re-examined on the first real tables of the demo.

**Fixtures** (synthetic, invented names): an English table; a German table with `Belegdatum`, `Betrag`,
`Lieferant` (the spec's scenario: date, total and supplier all proposed); a Spanish table; a table with
no date-like field (`doc_date` stays unmapped, no weak suggestion); a table where a number field and a
text field both resemble `doc_number` (the type filter decides); a table with two equally plausible date
fields (ambiguous → unmapped).

**The absent setting** (`FR-DST-006`). Each *mapped* field carries `AbsentSetting { empty, zero }`,
default `empty`, stored on the `FieldMapping` — a property of the destination field and never of the
canonical model. Its consumer is Core's `finalize` (`implement-validation-and-extraction-core`, design
§5); the wizard hardcodes neither outcome. No mapping is mandatory: the step completes with all, some or
none mapped.

**What the screen shows.** Per field: its name, the proposed target (or a visibly *unmapped* state —
not an empty dropdown), a picker over the candidates of the right kind, and the absent setting for a
mapped one. How this is drawn is the wizard's own; how the **review** screen draws the same fields is T2.2's.

## 6. Destination and persistence

```
Destination(endpoint, teamId, databaseId, tableId, mappings: List<FieldMapping>)
FieldMapping(coreField, ninoxFieldId, ninoxFieldName, absent: AbsentSetting)
```

**Identifiers, not names** (FR-DST-003): the ids are what identifies a table or field; the names are kept
only to display and are re-resolved at send time (T1.11). `DestinationStore` writes a JSON file in the
app's documents directory with `path_provider` (already a dependency) — **no secret in it**: not the
token, and the host is a public address. The data model holds several destinations (FR-DST-001) and the
MVP configures one: the file holds a list of one.

**The summary** (FR-WIZ-008). A pure function `summarise(Destination) → SummaryText` over `app_en.arb`
templates, naming the mapped and the unmapped core fields; with nothing mapped it states that *only the
document will be attached, with no data*. The final screen offers to capture a document of any kind and
calls `onFinished`. Tests cover all, some and none.

## 7. The permission widening — approved by the product owner on 2026-10-07

For this change **only**, the Ninox lane's `writes` in `agents/roles.yaml` is extended with:

| Path | What the wizard may do there, and nothing else |
| --- | --- |
| `/app/pubspec.yaml` | add three dependencies: `flutter_secure_storage`, `url_launcher`, `http` |
| `/pubspec.lock` | the lock file the workspace regenerates (the only file the status of 2026-09-30 and 2026-10-02 recorded outside `app/`) |
| `/app/lib/l10n/**` | add `wizard`-prefixed keys to `app_en.arb`; the generated Dart is the output of `flutter gen-l10n` |
| `/app/lib/app/router.dart` | add the single line `...wizardRoutes` and its import |

Mobile's `/app/**` write access is unchanged, and so are its `denies` of the wizard and send folders.
The widening is **reverted** when this change is archived; the orchestrator does that and records it.
`app/android/**` is **not** widened. Two things there may be needed — the `<queries>` entry that lets
`url_launcher` see a Custom Tabs provider on Android 11+, and any Keystore setting
`flutter_secure_storage` asks for beyond `minSdk` 24 (already set) — and if the lane finds either
necessary it reports **blocked** with the exact lines, and Mobile adds them. The bounds verdict of the
runner reports any write outside the table above.

## 8. Sequence and the demo

The Ninox lane is one lane, so its work is sequential. Four dispatches, each ending on a green commit.

| # | Tasks | Result |
| --- | --- | --- |
| A | 1.1 widening; 1.2 state machine; 1.3 token step and stores | the token step against fakes |
| B | 2.1 choose steps; 2.2 routes and l10n | team → database → table with auto-omit, reachable from the router |
| C | 3.1 type rules; 3.2 matcher | matching proven on the fixtures |
| D | 3.3 mapping screen; 3.4 destination store and summary | the five screens and the summary |

**The demo of Fri 9 Oct** is *the wizard reading the user's real teams, databases, tables and fields* —
a live run, on the product owner's machine, with the product owner's token, and **it needs the approval
of `--allow-ninox-token` that is still open (T1.9)**. It needs dispatches A and B and the live run;
C and D are not required to show it. Dispatch C does not depend on A or B (it is pure Dart over
`NinoxTable`), so if the lane is slow on the token step the orchestrator reorders to B-first and tells
the product owner the day it happens.

## 9. Risks recorded, not decided

* **Time.** Today is Wed 7 Oct; A and B need to land by Thu 8 Oct for the demo. The lane lost a day to
  provider failures on 2 Oct. The cut line above is the plan if A or B slips.
* **`url_launcher`'s in-app browser** on a device without a Custom Tabs provider falls back to an
  external browser; that is still "the platform's system browser" and never an app WebView.
* **`flutter_secure_storage`** and Android backup: the plugin's Keystore mode keeps the key off the
  backup; `FR-CFG-004`'s *a backup yields nothing in plaintext* is verified on the device in the
  T1.12–T1.13 session, not by a unit test.
* **The threshold** will be wrong on some real table. The failure it must have is an unmapped field, not
  a wrong one — which is why it is strict and why the margin exists.
