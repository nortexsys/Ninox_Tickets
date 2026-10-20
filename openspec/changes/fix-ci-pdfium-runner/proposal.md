# Change: fix-ci-pdfium-runner

CI on `main` has been red since 2026-10-17: the step "Test app with coverage" fails 4 tests, all in
`app/test/adapters/ocr/pdfrx_page_rasterizer_test.dart`. Run 39434943081 (commit `6f59b7a`) says:

```
Failed to load PDFium module: Tried to load the default PDFium module
".../flutter/bin/cache/artifacts/engine/linux-x64/lib/libpdfium.so" but it failed: cannot open shared
object file: No such file or directory. Then tried to load the bundled native asset, but that also
failed: Exception: Native assets file not found.
```

The Linux runner has no PDFium native library. The tests pass on the PO's Windows machine. 548 other
tests pass; `analyze`, `format` and `python-checks` are green. Decision of the PO (2026-10-20): **give the
runner PDFium; do not skip the tests** (option 1).

Implementation-only (`skip_specs: true`). QA lane (it owns `.github/**` and tests). No product code
under `app/lib` or `packages/` changes.
