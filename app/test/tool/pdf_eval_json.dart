import 'dart:convert';

import 'package:paperdrop_core/paperdrop_core.dart';

/// Design §2's JSON — the one file the harness writes per document and
/// candidate, in the schema of the reference extraction, so that the comparison
/// reads files of one shape.
///
/// **Why it lives here and not in `app/lib/`.** It is the evaluation's own
/// output format and not a shape the application produces: nothing in `app/lib/`
/// writes it, and when the decision of 2026-10-07 is in force what stays is the
/// numbers in the review file (design §5). The harness that calls it is
/// `app/integration_test/pdf_text_eval_test.dart`, and the comparison script
/// that reads it is QA's.
///
/// **Units.** The schema is in PDF points with a top-left origin, which is what
/// the reference extraction speaks. Core holds integer thousandths of a point,
/// so this writer divides by a thousand — the exact inverse of the adapter's
/// `(points * 1000).round()`, and lossless for the numbers a library reports,
/// which are hundredths of a point at best.
String evalDocumentJson({
  required String docId,
  required String tool,
  required String sha256Before,
  required String sha256After,
  required List<int> msPerPage,
  required List<TextPage> pages,
}) => const JsonEncoder.withIndent('  ').convert(<String, Object?>{
  'doc_id': docId,
  'tool': tool,
  'sha256': sha256Before,
  'sha256_after': sha256After,
  'ms_per_page': msPerPage,
  'pages': pages.map(_pageJson).toList(growable: false),
});

/// The file name the harness writes one document and candidate under, as design
/// §2 spells it: `<doc_id>.<candidate>-words.json`.
///
/// The document is named once here so that the harness and whoever collects the
/// files agree without repeating the pattern, and so that the document's name —
/// which the corpus chose and which can carry a supplier — is never anywhere
/// else in the file.
String evalJsonFileName({
  required String docId,
  required String candidateToken,
}) => '$docId.$candidateToken-words.json';

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

/// Milli-points back to the points design §2's schema reports.
double _points(MilliPoint milli) => milli / 1000;
