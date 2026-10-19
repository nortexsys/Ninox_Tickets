# Tasks: add-extraction-stage-trace

## 1. Core lane

- [ ] 1.1 `ExtractionStage`, `ExtractionTrace`, `CollectingTrace`; optional parameter on `extractDocument`, default unchanged.
- [ ] 1.2 Record the stage at every place a field or candidate is lost or lowered (design §2).
- [ ] 1.3 Tests: each stage fires on a synthetic case; no value can reach a trace; existing tests unchanged.
- [ ] 1.4 Report: the list of stages and where each is recorded.

## 2. Orchestrator

- [ ] 2.1 Review; run the checks; run the trace over the private photographs on the host (counts per stage, no values).
- [ ] 2.2 PO approves; merge `--no-ff`; write the next change from the dominant stages.
