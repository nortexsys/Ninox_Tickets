# Tasks: verify-live-send-pipeline

## 1. Ninox lane

- [x] 1.1 `test/live/send_pipeline_live_test.dart`: guard, literals, target resolution, caps, cleanup (design §1). (done: 28cc62b)
- [x] 1.2 Payload builder from the resolved `EF` schema; formula fields skipped (design §2.1). (done: 28cc62b)
- [x] 1.3 `SendPipeline.send` happy path with read-back assertions (design §2.2). (done: 28cc62b)
- [x] 1.4 Fixture re-recording helper, structure only (design §3). (done: 28cc62b)
- [x] 1.5 Lane report: no token, no call made, no measured result claimed. (done: 28cc62b)

## 2. Orchestrator and product owner

- [x] 2.1 Review the diff; run the checks of design §4. (done: 28cc62b)
- [x] 2.2 PO approves the **exact** payload shape and caps shown by the test before the run. (done: docs/Plan/diario/2026-10-17.md, live send on EF passed)
- [x] 2.3 Orchestrator runs the live test; reads results by counts only. (done: docs/Plan/diario/2026-10-17.md, live send on EF passed)
- [ ] 2.4 Re-record fixtures; update the status file and the gaps register.
