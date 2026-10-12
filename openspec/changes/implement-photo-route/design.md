# Design: implement-photo-route

Owner: Mobile lane. Written by the orchestrator, 2026-10-12.

## 1. The port

```dart
abstract interface class OcrTextSource {
  /// Recognises [path] (a PDF of scanned pages, or one image) and returns one OcrPass per pass.
  Future<List<OcrPass>> recognise(String path);
}
class OcrPass { final String passId; final List<TextPage> pages; }
class OcrFailure implements Exception { final String reason; final Object? cause; }
```

* Output units are Core's: integer thousandths of a point, top-left origin. Pixel boxes from the
  engine are converted with the page's size in points (pdfrx page size for a PDF; for a bare image,
  its pixel size taken as points at 72 dpi — stated in the doc comment, not guessed).
* A page that yields no word is a `TextPage` with no words, not a failure. A file that cannot be
  opened or rendered throws `OcrFailure`.
* **Read-only**: the input is hashed before and after in a test; nothing is written back
  (`received-files-are-attached-byte-for-byte`). Render buffers live in the app's cache directory and
  are deleted when the call returns, including on failure.
* Words are the engine's own **elements** (ML Kit `TextElement`), not lines or blocks. No merging,
  sorting or parsing happens in the adapter.

## 2. Engine

`google_mlkit_text_recognition` with the Latin script recognizer (languages in scope are all Latin
script: ES, EN, FR, DE, IT, PT). Two things the lane **measures and reports, not decides**:
bundled vs. Play-services model (release arm64 APK delta, NFR-SIZ-001) and the resolved artefact's
licence (NFR-LIC-001). The lane uses the dependency form the plugin's default gives and records the
other form's size; the PO chooses. The package is pinned exactly, as `google_mlkit_document_scanner`
is.

## 3. Multi-pass strategy

Passes are a **fixed, ordered list**, each with a stable `passId`, so consensus is reproducible:

| passId | Render |
| --- | --- |
| `p1-native` | page rendered at 150 dpi |
| `p2-hi` | page rendered at 200 dpi |
| `p3-lo` | page rendered at 100 dpi |
| `p4-contrast` | 150 dpi, grey-scale with contrast stretch |

Scaling is the only variation that needs no new dependency (pdfrx renders); the contrast pass is
done in pure Dart on the render buffer. The list lives in one constant, is injectable for tests, and
a pass that throws is dropped and recorded (an `OcrPass` list shorter than the constant is legal; one
pass alone is legal and Core treats it as `Single`). **No pass is skipped for speed in M1**; timings
are reported per pass so the PO can decide to trim.

## 4. Testing

* Host side (CI): the engine is behind a small internal interface (`TextRecognizerBackend`), faked
  in tests. Cover: pixel→milli-point conversion with a known box; origin and units; empty page →
  `hasTextLayer == false`; pass list order and ids; a failing pass dropped, others returned; input
  hash unchanged; cache files removed on success and on failure.
* Device (not CI): an integration test `app/integration_test/ocr_eval_test.dart` modelled on
  `pdf_text_eval_test.dart`: reads `OCR_EVAL_DIR`, skipped without it, writes one JSON per document
  with passId, words (pdfplumber schema, points), SHA-256 before/after and ms per pass. Run by the
  orchestrator on the S22; the files are pulled to the private corpus, never committed.
* One synthetic public fixture only: a PDF made by a committed script from invented text; no real
  document's content anywhere in `app/` (AGENTS.md §1.2).

## 5. Output of the change

`OcrTextSource` + `MlKitOcrTextSource`, the four passes, tests green, the device harness, and the
lane report with: APK size delta (bundled / unbundled), licence, and which assertions could only run
on a device. T2.5 consumes the harness output; T2.1 consumes the port.
