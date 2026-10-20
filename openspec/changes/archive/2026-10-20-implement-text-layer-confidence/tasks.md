# Tasks: implement-text-layer-confidence

## 1. Core lane

- [x] 1.1 Route test: all passes `pdf-text` → text-layer reading; `pdf-mixed` and OCR routes do not qualify (design §1). (done: 5aac3c7)
- [x] 1.2 `_finalizeConfidence` rule for a `Single` with a holding, checkable, non-derived identity (design §1–2). (done: 5aac3c7)
- [x] 1.3 One test per scenario of the amended requirements (design §3); update only the text-layer cases of old tests, listing each. (done: 5aac3c7)
- [x] 1.4 Lane report: checks of design §4 with their output; no device claim. (done: 5aac3c7)

## 2. Orchestrator and product owner

- [x] 2.1 Review report and diff; re-run Core, `ninox_client` and app tests on the merged tree. (done: 5aac3c7)
- [x] 2.2 PO approves; merge `--no-ff`. (done: 5aac3c7)
