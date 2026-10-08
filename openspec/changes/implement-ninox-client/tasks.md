# Tasks: implement-ninox-client

Plan v0.2 M1, Ninox lane. A task is done when its check passes, not when its files exist. Every check
is run from the repository root on Flutter 3.47.5 / Dart 3.13.4:
`dart analyze --fatal-infos packages/ninox_client`, `dart format --set-exit-if-changed packages/ninox_client`,
`dart test packages/ninox_client`, `python .github/scripts/no_ninox_db_id.py`,
`python .github/scripts/privacy_check.py`.

## 1. Ninox — first dispatch: port and classic adapter, no token (T1.8)

- [x] 1.1 **Endpoint and credentials** (design §2). *Done when* every accepted and rejected form of
      design §2 has a test, `api.ninox.com` appears once in `lib/`, and `NinoxCredentials.toString()`
      does not contain the token.
- [x] 1.2 **Model, port and failures** (design §3–§4): `TableRef`, the value types, `NinoxPort`,
      `NinoxFailure` and its subtypes, JSON parsing of each response shape. *Done when* each type
      parses its fixture and rejects a malformed body with `UnexpectedResponse`.
- [x] 1.3 **Classic adapter — reads** (`listTeams`, `listDatabases`, `listTables`, `readRecord`,
      `listFiles`, `listRecords`) with fixtures and contract tests (design §5). *Done when* each call's
      method, path, query and headers are asserted, and a private-host test proves no request goes to
      `api.ninox.com` (tag `[destinations-mapping/configurable-ninox-host] a private-cloud customer
      needs no fork` only if the scenario is proved whole at this layer; otherwise untagged).
- [x] 1.4 **Classic adapter — writes against `MockClient` only** (`createRecord`, `updateRecord`, `uploadFile`).
      *Done when* the body shape, the empty-mapping case, the merge body of `updateRecord` (only the
      given fields), and byte-for-byte multipart upload are
      asserted, and no test can reach the network (the adapter is always built with a `MockClient`).
- [x] 1.5 **Failure mapping and token hygiene** (design §1, §4). *Done when* every status of design §4
      maps to its failure, a timeout on create yields `CreateOutcomeUncertain`, no non-`NinoxFailure`
      exception escapes a port method, and a test stringifies every failure and the credentials and
      finds no token.
- [x] 1.6 **GAP-023 check written, not run** (design §5): the `live`-tagged GET-only test, excluded by
      default via `dart_test.yaml`, skipping without `NINOX_API_KEY`. *Done when* `dart test
      packages/ninox_client` runs green without it, and `dart test --run-skipped -t live` is **not**
      executed by the lane.
- [x] 1.7 **Public API** exported from `lib/ninox_client.dart`, dartdoc on every public member; the
      lane report lists it for the orchestrator's review.

## 2. Ninox — second dispatch: live tests (T1.9)

Detailed in design §6 before dispatch; needs the product owner's approval of `--allow-ninox-token`.

- [ ] 2.1 Re-record the fixtures against the test base, GET only; diff against §1's.
- [x] 2.2 Run the GAP-023 check; record the result in `openspec/gaps-register.md` (through Spec).
      Done 2026-10-07 by the orchestrator with the PO's approval, GET only, on the disposable table
      `Paperdrop_test` of `JI-PRUEBAS-CLAUDE`; GAP-023 closed.
- [x] 2.3 Write tests within D-10's bounds; attachment size and timing from Spain (GAP-004).
      Done 2026-10-08: `test/live/write_limits_test.dart`, run twice with the PO's approval on `Paperdrop_test`
      (`EF`); second run green, table left as found. Results in `docs/Plan/status/2026-10-08.md`.

## 3. QA

- [ ] 3.1 Review the contract tests against ADR-004 and the `ninox` skill: every rule of ADR-004's
      table that this layer can prove is proved; report any that is not.

## 4. Orchestrator

- [x] 4.1 Review the lane's report and diff; run the checks at the top of this file; present the
      public API to the product owner.
- [x] 4.2 Merge `change/implement-ninox-client` with `--no-ff` after the product owner approves.
