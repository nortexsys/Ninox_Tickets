import 'dart:convert';

import 'package:paperdrop/adapters/pdf_text/pdf_text_candidate.dart';

/// Design §2's JSON — the one file the harness writes per document and
/// candidate, in the schema of the reference extraction, so that the comparison
/// reads three files of one shape.
///
/// **Why it lives here and not in `app/lib/`.** It is the evaluation's own
/// output format and not a shape the application produces: nothing in `app/lib/`
/// writes it, and when the decision of Tue 6 Oct is taken what stays is the
/// numbers in the review file (design §5). The harness that calls it is
/// `app/integration_test/pdf_text_eval_test.dart`, and the comparison script
/// that reads it is QA's.
///
/// Every number is in design §2's units: PDF points, origin at the page's
/// top-left corner, `ms_per_page` in wall-clock milliseconds per page in page
/// order. The writer takes the pieces and decides nothing: the tool string is
/// the candidate's own, and the two hashes are taken around the read by the
/// caller.
String evalDocumentJson({
  required String docId,
  required String tool,
  required String sha256Before,
  required String sha256After,
  required List<int> msPerPage,
  required List<CandidatePage> pages,
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

Map<String, Object?> _pageJson(CandidatePage page) => <String, Object?>{
  'index': page.index,
  'width': page.width,
  'height': page.height,
  'words': page.words.map(_wordJson).toList(growable: false),
};

Map<String, Object?> _wordJson(CandidateWord word) => <String, Object?>{
  'text': word.text,
  'x0': word.x0,
  'x1': word.x1,
  'top': word.top,
  'bottom': word.bottom,
};
