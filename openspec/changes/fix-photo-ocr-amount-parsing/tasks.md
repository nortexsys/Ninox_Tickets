# Tasks: fix-photo-ocr-amount-parsing

## 1. Core lane

- [ ] 1.1 Synthetic OCR-shaped cases of design §1 as failing tests, each naming its stage via the trace.
- [ ] 1.2 Fix amount parsing and binding for those cases without lowering any trust rule (design §2).
- [ ] 1.3 Fix date parsing for the OCR forms of design §1.
- [ ] 1.4 Trace covers every absent or capped field; test for it (design §3).
- [ ] 1.5 Report: per case the stage, the fix, and anything the specs do not decide.

## 2. Orchestrator and product owner

- [ ] 2.1 Review, run the checks; re-measure the 19 photographs on the host (counts only).
- [ ] 2.2 PO approves; merge `--no-ff`; re-run the harness on the S22 when the phone is available.
