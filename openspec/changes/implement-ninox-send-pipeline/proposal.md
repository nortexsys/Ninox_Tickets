# Change: implement-ninox-send-pipeline

## Why

The demo of M1 is a send with a read-back, and it is the one piece of the loop that does not exist:
the port (T1.8) has the primitives (`createRecord`, `uploadFile`, `listFiles`, `readRecord`,
`listRecords`, `updateRecord`) but nothing sequences them. Sequencing is where the expensive
failures live: a create whose response is lost is retried into a duplicate, a 500 is read as an
outage, and a record created without its document is reported as done. `ninox-send` states all of
that as requirements; this change implements them.

## What Changes

An **implementation-only change** (`skip_specs: true`). No requirement is added, modified or
removed. Owner: Ninox lane. Code goes in `packages/ninox_client/lib/src/send/` and is exported
from `ninox_client.dart`; Flutter-facing glue, if any, goes in `app/lib/features/send/`.

* **T1.11 — `SendPipeline`**: create → attach → read back (FR-SND-001..003), the retry matrix
  (FR-SND-004), reconciliation of an uncertain create (FR-SND-005), the deep link (FR-SND-006).
* The pipeline is **pure Dart over `NinoxPort`**, with an injected clock, an injected sleeper and a
  `SendJournal` interface it reports state transitions to. T1.14 (the local store) implements
  `SendJournal` later; this change ships an in-memory implementation for tests. So T1.11 does not
  wait for T1.14.

## Out of scope

* The local store and the nine-state machine (T1.14); the pipeline only emits transitions.
* Connectivity detection and the offline queue's trigger (Mobile): the pipeline receives a
  no-connectivity failure and returns `Queued`.
* Any write to Ninox from tests: all tests run on a fake port. A live run needs the PO's approval
  and is a separate orchestrator task (tasks 2.3).
