# Tasks: implement-ninox-send-pipeline

Plan v0.2 M1, Ninox lane. A task is done when its check passes (design §6).

## 1. Ninox lane

- [x] 1.1 `FakeNinoxPort` with scripted per-call failures and a call log. *Done when* every test below uses it. (done: 31b6b74)
- [x] 1.2 `SendPipeline.send` happy path: create → upload → read-back; `Sent` carries the read-back (design §2, §5). (done: 31b6b74)
- [x] 1.3 Retry matrix, one test per row (design §3). (done: 31b6b74)
- [x] 1.4 Reconciliation, the four scenarios of `ninox-send` (design §4). (done: 31b6b74)
- [x] 1.5 `resume`, `adopt`, `createAnyway` (design §2). (done: 31b6b74)
- [x] 1.6 `recordLink` and `databaseLink`, zero port calls, degradation. (done: 31b6b74)
- [x] 1.7 Public export, dartdoc, lane report with dependencies (none expected). (done: 31b6b74)

## 2. Orchestrator and product owner

- [x] 2.1 Review the report and diff; run the checks of design §6. (done: 31b6b74)
- [x] 2.2 PO approves; merge `--no-ff`. (done: 31b6b74)
- [ ] 2.3 Live run of the pipeline in the test base `jd1m8n8l4j7i`, table named by the PO — **needs explicit PO approval**. Also covers re-recording the `create-response` and `error-500` fixtures.
- [ ] 2.4 Tell Mobile the pipeline is merged (T1.14 implements `SendJournal`).
