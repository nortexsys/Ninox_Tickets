# Tasks: fix-text-pdf-extraction-yield

## 1. Core lane

- [x] 1.1 Fixtures from the evidence and one failing test per absent field (`gross_total`, `supplier_name`, `doc_number`), each naming the stage that drops it.
- [x] 1.2 Fix each cause inside the existing requirements; the tip case and the arithmetic gate keep their rules.
- [x] 1.3 Report: per cause, the stage, the fix, and anything the specs do not decide.

## 2. Orchestrator and product owner

- [ ] 2.1 Review the diff and the report; run the checks of design §3.
- [ ] 2.2 Re-run the extraction harness on the S22; compare yield with 2026-10-18.
- [ ] 2.3 PO approves; merge `--no-ff`.
