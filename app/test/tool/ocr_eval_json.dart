import 'dart:convert';

import 'package:paperdrop/adapters/ocr/ocr_text_source.dart';
import 'package:paperdrop_core/paperdrop_core.dart';

/// The photo route's harness output (`implement-photo-route`, design §4): one
/// file per document, with every pass the engine produced.
///
/// **Why it lives here and not in `app/lib/`.** It is the evaluation's own
/// output format and not a shape the application produces: nothing in `app/lib/`
/// writes it. The harness that calls it is
/// `app/integration_test/ocr_eval_test.dart`, and whoever compares the passes
/// (T2.5) reads the files it wrote.
///
/// **The word schema is the invoice route's.** `pages` and their `words` are in
/// the schema of the reference extraction, so a file this writer produced can
/// be read by the same comparison that read the invoice route's JSON — and the
/// units are the reference's, PDF points with a top-left origin. Core holds
/// integer thousandths of a point, so the writer divides by a thousand, which
/// is lossless for the numbers a recogniser reports.
///
/// **One file per document, not per pass.** Design §4 asks for `passId` in the
/// document's JSON, and a document is what was read: the passes are an array
/// under `passes`, each with the id the port reported and the milliseconds the
/// pass took, and a pass that was dropped is named under `dropped_passes` with
/// what threw. A document with a pass missing is therefore visible in the file
/// and not only in the log of whoever ran it.
String ocrEvalDocumentJson({
  required String docId,
  required String tool,
  required String sha256Before,
  required String sha256After,
  required List<OcrPass> passes,
  required Map<String, int> msPerPass,
  required List<OcrDroppedPass> droppedPasses,
}) => const JsonEncoder.withIndent('  ').convert(<String, Object?>{
  'doc_id': docId,
  'tool': tool,
  'sha256': sha256Before,
  'sha256_after': sha256After,
  'passes': <Map<String, Object?>>[
    for (final OcrPass pass in passes)
      <String, Object?>{
        'pass_id': pass.passId,
        'ms': msPerPass[pass.passId] ?? -1,
        'pages': pass.pages.map(_pageJson).toList(growable: false),
      },
  ],
  'dropped_passes': <Map<String, Object?>>[
    for (final OcrDroppedPass dropped in droppedPasses)
      <String, Object?>{'pass_id': dropped.passId, 'error': dropped.error},
  ],
});

/// A pass that threw and was left out of the document's result.
class OcrDroppedPass {
  /// Creates a record of a dropped [passId] and what [error] threw.
  const OcrDroppedPass(this.passId, this.error);

  /// The pass that was dropped.
  final String passId;

  /// What threw, in the engine's or the renderer's own words.
  final String error;

  @override
  String toString() => 'OcrDroppedPass($passId: $error)';
}

/// The file the harness writes one document under.
///
/// The document is named once here so that the harness and whoever collects the
/// files agree without repeating the pattern, and so that the document's name —
/// which the corpus chose and which can carry a supplier — is never anywhere
/// else in the file.
String ocrEvalJsonFileName({required String docId}) => '$docId.mlkit-ocr.json';

Map<String, Object?> _pageJson(TextPage page) => <String, Object?>{
  'index': page.index,
  'width': _points(page.width),
  'height': _points(page.height),
  'words': page.words.map(_wordJson).toList(growable: false),
};

Map<String, Object?> _wordJson(PositionedWord word) => <String, Object?>{
  'text': word.text,
  'x0': _points(word.x0),
  'x1': _points(word.x1),
  'top': _points(word.top),
  'bottom': _points(word.bottom),
};

/// Milli-points back to the points design §4's schema reports.
double _points(MilliPoint milli) => milli / 1000;
