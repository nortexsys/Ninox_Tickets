# Negative release checklist

Task **T2.4** of plan v0.2 §9 (`QA — negative release checklist automated`), implementing the
acceptance convention of **Funcional §10.6**:

> Every non-goal of §1.2 has a negative test in the release checklist: no backend call, no schema
> mutation, no credential beyond the token, no unmapped write, no telemetry artefact, no
> mail-body byte.

One file per non-goal, one named test per claim, each test naming the non-goal **and** the
requirement it protects. Nothing here is a device test and nothing here reaches Ninox: the
checklist is host Dart, it reads sources and drives fakes, and its only "network" is an
`HttpOverrides` that refuses every connection (and says so).

## How to run it

From `app/` (the resolution that has `flutter_test`, `http`, `paperdrop` and `ninox_client`):

```
flutter test ../validation/release_checklist
```

`dart analyze` from the repository root also reads these files; `validation/analysis_options.yaml`
switches off one lint (`depend_on_referenced_packages`) with the reason written in that file, since
the checklist is not a workspace package and declares no dependencies of its own.

CI runs the same command as a step of the `test` job in `.github/workflows/ci.yml`, so a release
cannot be read against a checklist that no longer runs.

## §10.6 row → test

| §1.2 non-goal | Requirement it protects | File, and the test that proves it |
| --- | --- | --- |
| *no backend call* — "never runs a backend service"; "no document … leaves the device except toward the user's own Ninox database" | NFR-PRV-001, NFR-PRF-002, ADR-002, ADR-017 | `no_backend_call_test.dart`: **one network client and no other**; **every host name is a vendor address with a reason**; **a whole send opens no connection**; **a whole extraction opens no connection**; **the guard sees the one call the adapter makes, and it goes to the configured host** |
| *no schema mutation* — "never creates, renames or deletes fields or tables"; "never deletes or modifies a record it did not create" | BR-16, §2.4 contract 6, DEC-005 / GAP-022 | `no_schema_mutation_test.dart`: **the port declares the nine record-and-read calls and nothing else**; **driving every call produces exactly nine requests, none to a schema path**; **no shipped source names a schema-mutating call or verb**; **the scan catches a planted mutating verb** |
| *no credential beyond the token* — "never requests, stores or transmits a Ninox username or password" | BR-19, NFR-SEC-001, NFR-SEC-003, ADR-018 | `no_credential_test.dart`: **no shipped source asks for a password or a second secret**; **the platform keystore is the only place a secret is stored, and it removes nothing else**; **the configuration file carries no credential**; **the forbidden environment variable is named nowhere in the product** |
| *no unmapped write* — one record per document, header only, in the shape the user mapped | BR-15, BR-22, ADR-004, ADR-013, DEC-005 / GAP-022 | `no_unmapped_write_test.dart`: **a destination with no mapping sends no field key and still carries its document**; **only the mapped names travel, and no marker field is added**; **a refused write is retried with the same payload**; **a formula field is never offered: one schema listing and no second endpoint** |
| *no telemetry artefact* — "never collects telemetry in a public build" | NFR-PRV-006, ADR-012, NFR-PRV-002, NFR-PRV-003 | `no_telemetry_test.dart`: **no declared or resolved dependency is an analytics, crash-reporting or advertising SDK**; **the shipped manifest asks for INTERNET and declares no analytics or advertising component**; **no log line can carry a document value**; **the scan catches a planted analytics dependency** |
| *no mail-body byte* — "never reads the body of a `.msg` / `.eml` message, only the document attachment it carries" | `product-invariants/never-read-message-body`, FR-CAP-006, FR-CAP-001 | `no_mail_body_test.dart`: **a share of a body and one attachment hands over the attachment alone**; **a share that carries only text produces no document**; **an audio or video attachment is not a document**; **a mail container is refused before any of it is stored**; **no shipped source parses a mail container**; **the scan catches a planted container parser** |

`checklist_support.dart` holds what the six files share: where the shipped code is
(`repoRoot`, `shippedSources`, `pubspecFiles`), the lexical scans over
`app/test/tool/source_scan.dart`'s comment masking, the two allowlist helpers
(`unauthorised` for a finding nobody authorised, `unmatchedEntries` for an entry that no longer
matches anything), and `RecordingHttpOverrides`, the guard that records and refuses every
connection.

## The allowlists, and why each entry is a claim

An allowlist here is not a silenced file: an entry is `path|text → reason`, it must match
something, and the day it stops matching the test fails. The four lists, all small:

* **network clients** (2 entries): the classic adapter of ADR-003 and the composition root that
  builds its client. No other file of the product may hold one.
* **host names** (4 entries): `api.ninox.com` (the ADR-017 default API host), `next.ninox.com`
  (the deep link's web host, opened by a browser), `admin.ninox.com` (the vendor's token page,
  handed to the platform's browser) and the token step's placeholder text.
* **credentials** (2 entries): the two copies — catalogue and generated — of the instruction that
  tells the user the app asks for no user name and no password. They state the rule; they are not
  a field.
* **schema mutation, telemetry, mail containers**: empty. Any finding there is a failure.

## What this checklist does not cover

* **Blocked requirements (§11.5).** None of the five — FR-EXT-004, FR-EXT-005, FR-EXT-015,
  NFR-SIZ-001, UC-14 — is a §10.6 row: each is about the reading engine or the PDF library's size,
  not about one of the six non-goals. So this checklist carries no `skip: 'ADR-0xx'`; the design's
  sentence about blocked tests applies to their own capabilities' acceptance tests, which are
  written and skipped where those requirements live.
* **Measured facts.** §10.4's protocol — observed sessions and a benchmark run — is a release
  procedure, not a test, and no file here measures time, taps or accuracy.
* **A device.** Nothing here installs, scans, recognises or uploads. The mail-container half of
  FR-CAP-006/FR-CAP-007 (reading the attachment *out of* a `.msg`/`.eml`) is R1 and unbuilt; the
  negative — that no body byte is read — is proved on the path that exists (share-in) and by the
  intake refusing a container outright.
* **Types.** The scans read names, literals and declarations. Each test says in its own doc comment
  where that stops.

## Findings

No production code was changed by this change: it is tests only (`skip_specs: true`, QA lane).
The checklist is green on the tree it was written against. Three observations were recorded for the
orchestrator, none of them a violation of a §10.6 row:

1. `SendRequest.toString()` prints the document's **file name** next to the field count
   (`packages/ninox_client/lib/src/send/send_request.dart`). It prints no field *value*, which is
   what the log rule is about, so the group-5 test passes; whether a file name counts as a document
   value is a decision for the orchestrator, not for this checklist.
2. `app/lib/l10n/` holds an English catalogue only. NFR-I18N-001 asks for English **and** German;
   when `app_de.arb` arrives, the group-3 scan will find `Passwort`/`Benutzername` in the same
   instruction and will need one allowlist entry with the same reason as the English ones. That is
   the check working, not a defect of it.
3. The shipped code writes no log line at all today. The group-5 test states that as the reason its
   "no log line can carry a document value" assertion holds; a lane that adds a log line will have
   to justify it there.
