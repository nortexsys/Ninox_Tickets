# Tasks: implement-history-retry-duplicates

## 1. Mobile lane

- [ ] 1.1 `RetentionPolicy` + wiring after `Sent` and on load; tests for the three `file-retention` scenarios (design §1).
- [ ] 1.2 `DuplicateChecker` and `markDuplicate`; one test per `duplicate-criteria` scenario (design §2).
- [ ] 1.3 `RetryService` state→call mapping; correction targets `ninoxRecordId`, refuses without it (design §3).
- [ ] 1.4 Uncertainty trace survives a send with nothing mapped (`history-is-the-uncertainty-trace`).
- [ ] 1.5 `SendQueue.drain` with injected `Connectivity`; ordering, single-flight, stop on `Uncertain` (design §4).
- [ ] 1.6 Lane report; no device run claimed.

## 2. Orchestrator and product owner

- [ ] 2.1 Review report and diff; run the checks of design §5.
- [ ] 2.2 PO approves; merge `--no-ff`.
