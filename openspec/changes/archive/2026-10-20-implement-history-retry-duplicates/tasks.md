# Tasks: implement-history-retry-duplicates

## 1. Mobile lane

- [x] 1.1 `RetentionPolicy` + wiring after `Sent` and on load; tests for the three `file-retention` scenarios (design §1). (done: da673c7)
- [x] 1.2 `DuplicateChecker` and `markDuplicate`; one test per `duplicate-criteria` scenario (design §2). (done: da673c7)
- [x] 1.3 `RetryService` state→call mapping; correction targets `ninoxRecordId`, refuses without it (design §3). (done: da673c7)
- [x] 1.4 Uncertainty trace survives a send with nothing mapped (`history-is-the-uncertainty-trace`). (done: da673c7)
- [x] 1.5 `SendQueue.drain` with injected `Connectivity`; ordering, single-flight, stop on `Uncertain` (design §4). (done: da673c7)
- [x] 1.6 Lane report; no device run claimed. (done: da673c7)

## 2. Orchestrator and product owner

- [x] 2.1 Review report and diff; run the checks of design §5. (done: da673c7)
- [x] 2.2 PO approves; merge `--no-ff`. (done: da673c7)
