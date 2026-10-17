# Change: verify-live-send-pipeline

## Why

`SendPipeline` (T1.11) is merged and proven against `FakeNinoxPort` only. The M1 demo is "send with
read-back", and nothing has yet shown it against a real Ninox. The PO approved the live run on
2026-10-17 (table `EF`, test base `jd1m8n8l4j7i`, invented values, synthetic PDF).

## What Changes

An **implementation-only change** (`skip_specs: true`). Owner: Ninox lane. Adds one opt-in live test
under `packages/ninox_client/test/live/` that drives `SendPipeline.send` through the real
`ClassicAdapter`, plus re-recording of the `create-response` and `error-500` fixtures (structure
only, no live value copied).

## Out of scope

* Any table other than `EF`; any read of `EF`'s existing records beyond recording their ids.
* Product code changes. If the run exposes a pipeline defect, it is reported, not fixed here.
* The `uncertain` and reconciliation paths (they need injected failures; the fake covers them).
