import 'dart:convert';

import 'package:paperdrop/adapters/ocr/ocr_text_source.dart';
import 'package:paperdrop_core/paperdrop_core.dart';

import 'ocr_pass_agreement.dart';

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
///
/// **This file holds the document's words**, which is what T2.5 compares them
/// with. The numbers the product owner reads are `ocrEvalSummaryJson`'s, and
/// that file holds no word at all
/// (`implement-photo-passes`, design §5).
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

/// The one file the harness writes per document that holds **numbers and pass
/// ids only** (`implement-photo-passes`, design §5 and task 1.6).
///
/// **What it is for.** The product owner reads the numbers of a device run:
/// how many words each pass of a photograph read, how many of those words two
/// passes agree on, how long each pass took, and whether the passes of one
/// document reported the same page sizes — the invariant of design §4. Which
/// passes are worth keeping is T2.5's decision and the PO's, and this file
/// applies **no threshold**: it reports a share and does not say whether it is
/// good.
///
/// **What it does not hold.** Not one word of any document: the shares are
/// counts, the pass ids are the list's, and a dropped pass is named by its id
/// and counted. That is the point of a second file beside the detailed one —
/// the detailed JSON holds the document's words for T2.5 to compare, and this
/// one can be read, pasted into a report or sent by mail without carrying a
/// supplier's name.
String ocrEvalSummaryJson({
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
  // 0 when the file was read and left as it was (ADR-015), 1 when reading it
  // changed it. A number, and not a sentence, so that nothing here is prose.
  'sha256_changed': sha256Before == sha256After ? 0 : 1,
  'passes': <Map<String, Object?>>[
    for (final OcrPass pass in passes)
      <String, Object?>{
        'pass_id': pass.passId,
        'ms': msPerPass[pass.passId] ?? -1,
        'words': wordsInPass(pass),
        'pages': <Map<String, Object?>>[
          for (final TextPage page in pass.pages)
            <String, Object?>{
              'index': page.index,
              'width': _points(page.width),
              'height': _points(page.height),
              'words': normalisedWordsOf(page).length,
            },
        ],
      },
  ],
  'agreement': <Map<String, Object?>>[
    for (final OcrPassAgreement agreement in passAgreements(passes))
      <String, Object?>{
        'first_pass_id': agreement.firstPassId,
        'second_pass_id': agreement.secondPassId,
        'first_words': agreement.firstWords,
        'second_words': agreement.secondWords,
        'shared_words': agreement.sharedWords,
        'share': agreement.share,
      },
  ],
  // The invariant of design §4 as a number: 1 when every pass of this document
  // reported the same page sizes, more when they disagree, 0 when no pass read
  // anything.
  'distinct_page_sizes': distinctPageSizes(passes),
  'dropped_pass_ids': <String>[
    for (final OcrDroppedPass dropped in droppedPasses) dropped.passId,
  ],
});

/// The file the summary of a document is written under.
String ocrEvalSummaryFileName({required String docId}) =>
    '$docId.mlkit-ocr-summary.json';

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
