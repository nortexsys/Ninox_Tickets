# Change: implement-negative-release-checklist

## Why

T2.4 (plan §9, M2): Funcional §10.6 requires every non-goal of §1.2 to have a negative test in the
release checklist: no backend call, no schema mutation, no credential beyond the token, no unmapped
write, no telemetry artefact, no mail-body byte. Some guards exist (`dependency_declaration_test`,
`no_image_processing_test`, `no_ninox_db_id`, `privacy_check`); none is organised as a checklist a
release can be read against.

## What Changes

An **implementation-only change** (`skip_specs: true`), owner QA lane, tests only (`/**/test/**`,
`/validation/**`). One checklist file per row of §10.6, each test named by the non-goal and the
requirement it protects (BR-14 … BR-19, NFR-PRV-*, ADR-002, ADR-012). Host tests; no device, no Ninox call.

## Out of scope

* Production code: a violation found is reported, not fixed by the QA lane.
* Blocked requirements (§11.5): their acceptance tests are written now and skipped with the ADR id.
