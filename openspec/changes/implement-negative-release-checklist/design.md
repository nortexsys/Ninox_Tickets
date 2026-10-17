# Design: implement-negative-release-checklist

One test library, `validation/release_checklist/` (host Dart, runnable with `dart test`/`flutter test`),
with one group per non-goal:

1. **No backend call.** Static scan of all `lib/` and package sources for network clients: the only
   allowed outbound code is `ninox_client` (host from configuration, ADR-017). Plus a runtime test: run
   `SendPipeline` and the extraction service over fakes with an HTTP-intercepting `HttpOverrides` that
   fails on any host other than the configured Ninox host.
2. **No schema mutation.** The `NinoxPort` surface is inspected: no method issues POST/PUT/DELETE to a
   schema or table-definition path; record create/update/file upload only.
3. **No credential beyond the token.** Scan: nothing reads or stores a password, a client secret or a
   second key; the token is stored only through `TokenStore`; `NINOX_DB_ID` is never referenced.
4. **No unmapped write.** A send over a destination with unmapped and formula fields writes only the
   mapped, writable ones (`never-write-an-unmapped-field`).
5. **No telemetry artefact.** `pubspec.yaml` of every package and the Android manifest are scanned for
   analytics/crash/ads SDKs and the `INTERNET`-using extras; logs contain no document values.
6. **No mail-body byte.** The share-intake path only accepts attachments and never reads a body part.

Each test fails with the non-goal name and the requirement id. Blocked ones are `skip: 'ADR-0xx'`.
Checks: `dart format`, `flutter analyze --fatal-infos`, tests green, `privacy_check` 0 findings.
