# Tasks: verify-live-send-pipeline

## 1. Ninox lane

- [ ] 1.1 `test/live/send_pipeline_live_test.dart`: guard, literals, target resolution, caps, cleanup (design §1).
- [ ] 1.2 Payload builder from the resolved `EF` schema; formula fields skipped (design §2.1).
- [ ] 1.3 `SendPipeline.send` happy path with read-back assertions (design §2.2).
- [ ] 1.4 Fixture re-recording helper, structure only (design §3).
- [ ] 1.5 Lane report: no token, no call made, no measured result claimed.

## 2. Orchestrator and product owner

- [ ] 2.1 Review the diff; run the checks of design §4.
- [ ] 2.2 PO approves the **exact** payload shape and caps shown by the test before the run.
- [ ] 2.3 Orchestrator runs the live test; reads results by counts only.
- [ ] 2.4 Re-record fixtures; update the status file and the gaps register.
