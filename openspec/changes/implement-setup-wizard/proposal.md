# Change: implement-setup-wizard

## Why

Configuration is the one part of the product the user cannot skip and the part they do once, and
nothing after it is testable until it exists: until a destination can be chosen from lists read out
of the user's own Ninox, there is no mapping, no send and no review. Plan v0.2 §9 puts this change in
W1–W2, right after the client it stands on, precisely so that the two changes that follow — the send
pipeline and the integration of M2 — code against a destination rather than against a placeholder,
and so that the demo of Fri 9 Oct is *the wizard reading the user's real teams, databases, tables
and fields*, which is the first end-to-end evidence the app works on a real workspace.

Two things that look like screen design are actually the risk the requirement set exists to bound,
and both are decided here rather than rediscovered later. **The mapping step pre-fills proposals so
the user corrects rather than constructs**, and its threshold is deliberately strict, because the
failure mode the functional names is a mediocre suggestion a user confirms without reading — a field
mapped to the wrong column does not fail loudly, it writes a plausible value into the wrong place,
and the read-back then reports that the app succeeded. Leaving `doc_date` unmapped looks worse and
behaves better. **The token never enters a WebView the app controls**: it is obtained through the
platform's own system browser, which is a contract line rather than a convenience, and it lands in
the platform keystore and nowhere else.

Two boundaries are fixed by the changes around this one. The wizard reads Ninox through
`packages/ninox_client`'s **port only** — the enumeration, the payload contract and the host
validation are `implement-ninox-client`'s, and nothing here re-implements a call — and the mapping
step builds its picker on `.../tables`, the endpoint the classic API was chosen for, whose omission
of formula fields already satisfies DEC-005's rule without a filter of the app's own
(`docs/Plan/SPIKE_GAP-022_schema_formula_fields.md` §3, plan §6.1).

## What Changes

An **implementation-only change** (`skip_specs: true`, plan §8.2). No requirement is added,
modified, removed or renamed, and no living spec is touched. All code goes in `app/lib/features/wizard/`,
the Ninox lane's own folder, and reads Ninox through `packages/ninox_client`'s port only.

* **The token step** (plan §9 M1, T1.10). Instructions for obtaining a Ninox API token, a
  paste-from-clipboard action, and an option to open Ninox's settings page in the platform's own
  system browser — Custom Tabs on Android, SFSafariViewController on iOS — and **never** a WebView
  the app controls. The token is validated immediately, and that validating call is also the one
  that returns the list the next step needs, so a valid token costs one round trip and no second
  one. The host of `NinoxEndpoint` is validated at this step **exactly as the token is**, by its
  effect, so an unreachable or invalid host is reported here and not deferred to the first send.
  The accepted token goes to the platform keystore and never to a file, a log or a widget state.
* **The team, database and table steps, with auto-omit** (plan §9 M1). Each step shows the list the
  previous step's call already produced, and each is **omitted altogether** when its list holds
  exactly one option — not hidden, not pre-confirmed: omitted, so a single-option subscription puts
  the user on token and mapping only. The table listing carries each table's writable fields with
  it, so reaching the mapping step needs no further network call.
* **The mapping step** (plan §9 M1). Each of the six core fields shown as a **pre-filled proposal**
  over the table's real fields, and visibly unmapped — not an empty selector — where nothing
  plausible exists. Two-stage matching: a **hard type filter first** (a date only ever against a
  date field, an amount only against a number field, a text value only against a text field), then
  string similarity against the multilingual synonym dictionary, with a threshold strict enough
  that below it the field stays unmapped rather than proposed. Formula fields never reach the step,
  because the listing endpoint omits them. Each mapped field carries the per-field **absent
  setting** — leave empty, the default, or write zero. No mapping is mandatory.
* **The summary** (plan §9 M1). A plain-language statement of the consequence — naming exactly
  which core fields will be saved and which will not, or that only the document will be attached
  with no data — and a final screen that offers to capture a first document of any kind rather than
  returning the user to an empty application.

## Requirements implemented

Identifiers as the functional spells them; the requirement name is the one that owns the behaviour
in `openspec/specs/`. Each item states the part this change satisfies, because three of these
requirements have a half that belongs to a later change.

* **FR-WIZ-001** — `setup-wizard` · `five-screens-at-most`: in full. Token, team, database, table,
  mapping — and no sixth step is introduced, including when steps are auto-omitted.
* **FR-WIZ-002** — `setup-wizard` · `steps-auto-omit-when-there-is-nothing-to-choose`: in full. The
  team, database and table steps are skipped automatically when their list holds exactly one
  option, and a one-option list produces no step at all rather than a step pre-confirmed.
* **FR-WIZ-003** — `setup-wizard` · `token-step-via-the-system-browser`: in full. The settings page
  opens in the platform's system browser, the app renders no login of its own, a pasted token is
  validated immediately and an invalid one keeps the user on the step, and the validating call
  delivers the next step's list so no second round trip follows. **The credential invariant** is
  `product-invariants`' `token-is-the-only-credential`, which this step implements rather than
  restating: no Ninox username or password is ever requested, and NFR-SEC-002's no-app-controlled-
  WebView is satisfied by the same screen.
* **FR-WIZ-004** — `setup-wizard` · `table-listing-returns-the-schema`: in full, on
  `NinoxPort.listTables`, which returns tables **with their fields** in one call. Formula fields do
  not reach the mapping step — not because the app filters them out, but because `.../tables`
  omits them (727 of 2,143 fields on the test base, with no exception), which is the only
  implementation of DEC-005 that needs no marker and no guess. The app does **not** promise to
  exclude read-only fields in advance, because no marker exists; a mapped field that later fails
  with HTTP 500 is diagnosed as a mapping error by the send pipeline, not probed by this one.
* **FR-WIZ-005** — `setup-wizard` · `pre-filled-proposals`: in full. Every core field opens
  pre-filled where a plausible candidate exists and reads as unmapped where none does.
* **FR-WIZ-006** — `setup-wizard` · `two-stage-matching-with-a-strict-threshold`: in full, and the
  type filter runs before any similarity is computed. The threshold's **numeric value** is not
  stated by this change, for the reason the requirement's own Open Questions record: the functional
  gives no number, and the outcome — below it a field is left unmapped and a mediocre suggestion is
  never made — is what the acceptance test can check, while a number would be asserted here and
  tested by nobody.
* **FR-WIZ-007** — `setup-wizard` · `no-mapping-is-mandatory`: in full. The wizard can be finished
  with everything, one field or nothing mapped, and the summary describes the nothing-mapped case
  in plain language.
* **FR-WIZ-008** — `setup-wizard` · `plain-language-summary-and-first-document-offer`: in full. The
  summary names the mapped and the unmapped fields, states the empty-record case as *only the
  document will be attached, with no data*, and the final screen's offer opens capture for a
  document of any kind. The capture itself is `capture-intake`'s; this screen only offers it.
* **FR-DST-006** — `destinations-mapping` · `per-field-absent-setting`: **the setting half** — each
  mapped field carries the choice between leaving the Ninox field empty, which is the default, and
  writing zero, and the setting is stored as a property of the destination field and never of the
  canonical model. **The principle** the setting implements is `validation-confidence`'
  `absent-is-not-zero` (FR-VAL-012): a value not printed is never treated as a zero, and which of
  the two applies is the destination's, not the document's. The solver that consumes the setting is
  `implement-validation-and-extraction-core`'; nothing is hardcoded on either side.
* **FR-DST-008** — `destinations-mapping` · `configurable-ninox-host`: **the validation half** — the
  host is a field of the destination's advanced setup, defaults to `api.ninox.com`, is editable and
  is validated at the token step exactly as the token is, so a private-cloud customer enters their
  host and an unreachable one is reported early. The adapter half is `implement-ninox-client`'
  (the host is a constructor parameter, never a compiled constant). GAP-006 records that the
  private-cloud segment is not re-verified; the behaviour is specified and testable, that
  verification is not done.
* **FR-CFG-004** — `local-config-privacy` · `token-storage-in-the-platform-keystore`: **the storage
  half** — the token the step accepted is written to the Android Keystore and to nowhere else: not
  to the writable data containers, not to a log line and not to any widget state that outlives the
  step. Everything else the requirement names — a backup that yields nothing in plaintext, and
  biometric protection deferred rather than required — follows from storing it there and is the
  requirement's own acceptance. The export that must never carry the token is R1's
  (`configuration-export-and-import`), and the clearing action is R1's too.

## Gaps and decisions this change acts on

* **GAP-005** (open, `NO BLOQUEANTE`) — a choice field written with text outside its option list is
  unverified in every test so far. It is out of the MVP **by construction** (plan §4.5: the MVP maps
  no `choice` field, so the risk is never met), and this change's picker offers a choice field's
  existing options only where such a field appears. The gap stays open against R1.
* **GAP-006** (open, `NO BLOQUEANTE`) — the private-cloud host has not been re-verified against a
  private instance, so `configurable-ninox-host` cannot be considered closed for that segment. This
  change implements and tests the behaviour; the verification on a private instance is not done, and
  the product owner decided on 2026-09-25 to ask the Ninox community after the MVP.
* **GAP-022** (closed 2026-09-25, DEC-005) — formula fields never appear in the app, and read-only
  is diagnosed rather than anticipated. The spike measured that `.../tables` **omits** formula
  fields (727 of 2,143, per table, no exception) and that `.../schema` marks them with `fn`, and
  that **no read-only marker exists at all**. This change builds the picker on `.../tables`, which
  is plan §6.1's design recommendation for exactly that reason — it is compact, it is the endpoint
  the classic API was chosen for, and its omission already satisfies the rule. `.../schema` is
  ~1,5 MB of the workspace's internal serialisation, is needed only in R1 for the formula-total
  contrast, and its instability is GAP-025.
* **GAP-025** (open, `NO BLOQUEANTE`) — the full database schema is not a stable contract. The MVP
  does not need it if the picker is built on `.../tables`, which is what this change does; the gap
  reopens when R1 designs `formula-totals-used-as-post-write-contrast`, with a mandatory degradation
  if `fn` disappears.
* **DEC-005** (product decisions register) — the rule this change's mapping step is built on, and
  the reason the picker needs no filter of its own. What the endpoint is, is a design matter
  (plan §6.1), settled here in favour of `.../tables` for the reasons above.
* **D-10** (standing approval, plan v0.1 §6.3 / v0.2 §7.1) — writes to the test base are permitted
  bounded to that team, that database, one disposable table and deletes of the records the test
  created. **No step of this change writes.** Any live call — the demo run included — is T1.9's,
  under D-10 and the product owner's approval of `--allow-ninox-token`, and the wizard's tests do
  not make it.

## Deferred

Design and tasks are the orchestrator's; the boundary below is stated so the next two Ninox changes
do not have to renegotiate it.

* **T1.11 — the send pipeline** (`implement-send-pipeline`, plan §8.3 change 6, W2): the send
  itself, staged create → attach → read-back, the retry matrix's state transitions, the
  reconciliation of an uncertain create, the deep link, and the foreground queue. It consumes this
  change's destination — team, database, table, field mapping by identifier, host — and the port's
  payload shape; the HTTP 500 that reports an unwritable mapped field as a mapping error is its,
  and so is the formula-total contrast that R1 needs `.../schema` for.
* **T2.2 — the review screen** (`implement-review-history-duplicates`, Mobile, W3): the destination
  bar, the daily confirmation, and how the six fields this change's summary names are presented.
  This change names the same six fields in plain language and defines nothing about how review
  draws them.
* **R1** — the configuration export and import that must never carry the token
  (`configuration-export-and-import`, FR-CFG-001), device migration (FR-CFG-002), the clearing
  action that genuinely empties everything (`local-data-clearing`, FR-CFG-003), several destinations
  with a switching bar (FR-DST-001's interface half), choice-field mapping (FR-DST-007, GAP-005),
  per-slot tax mapping (FR-VAL-011's mapping half), the formula-total contrast (FR-DST-005) and the
  German interface (`interface-languages`). The wizard's five screens are built once and reused by
  all of them; a destination is edited later through the same step sequence, which is why the steps
  are independent of first-run state rather than wired to it.
* **The mapping's persistence shape beyond the destination tuple** — identifiers rather than names
  (FR-DST-003, `destinations-store-identifiers-not-names`) is a property of the destination this
  change writes, and the name resolution at send time from a schema cached when the app opens is
  the send pipeline's.

## Impact

`app/lib/features/wizard/` (screens, the field-matching logic, the wizard's own state) and its
widget tests in `app/test/features/wizard/`; the keystore write goes through the platform plugin the
app already depends on, with no new permission. `packages/` change: this change consumes
`ninox_client`'s port and `paperdrop_core`'s value types and adds no dependency to either — the
synonym dictionary the matching consults is `countries-languages`', already published as data, and
the wizard adds no term of its own. No living spec changes; no functional change; no new decision
is taken, so nothing is recorded in `openspec/product-decisions.md`. `openspec validate
implement-setup-wizard --strict` passes with zero deltas.

**Every test runs against the port with fixtures.** The port's own contract tests are
`implement-ninox-client`'; here the wizard's steps, the auto-omit rule, the two-stage matching, the
threshold's outcome, the summary's plain language and the absent setting are all proven on fixtures
and on synthetic tables — no test reaches Ninox, so no test needs a token, and CI runs them. Any
live call is T1.9's, under D-10 and the product owner's approval; the demo target of plan §9's M1 —
**the wizard reading the user's real teams, databases, tables and fields** — is that run, on the
product owner's machine, and it is not a test in this change.

**No step uses `NINOX_DB_ID`** (`AGENTS.md` §1.4): the team and database are chosen from the lists
the port returns and are stored in the destination, never read from the environment, and the test
base's identifiers appear in no fixture of this change.
