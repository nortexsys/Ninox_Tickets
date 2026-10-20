# Tasks: fix-ci-pdfium-runner

## 1. QA lane

- [ ] 1.1 Read the pinned pdfrx source/README and the Flutter 3.47.5 behaviour (design §2); report what the runner is missing, with quotes.
- [ ] 1.2 Change `.github/workflows/ci.yml` (and only that, design §2) so the runner has PDFium before "Test app with coverage".
- [ ] 1.3 Check on Windows: YAML parses; `flutter test test/adapters/ocr/pdfrx_page_rasterizer_test.dart` and the full `app` suite pass; privacy scripts 0 findings.
- [ ] 1.4 Report: the choice (a/b/c), the evidence for it, the fallback if it fails on Linux, and that the Linux result is unproven.

## 2. Orchestrator

- [ ] 2.1 Review the diff and the report.
- [ ] 2.2 After the PO approves a push, run CI on GitHub and read the result; if it fails, iterate with the fallback (a new push needs the PO again).
- [ ] 2.3 PO approves; merge `--no-ff`; archive.
