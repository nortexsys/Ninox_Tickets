import 'package:pdfrx/pdfrx.dart';

import 'pdf_text_candidate.dart';

/// Candidate B of ADR-011 — **PDFium through `pdfrx`** (`close-adr-011-pdf-text-route`,
/// design §1, task 1.2).
///
/// PDFium is the engine Chrome renders PDFs with, and `pdfrx` is the Flutter
/// binding: one implementation for Android and iOS, which is the only path to R2
/// that is not a second library (proposal, "What Changes").
///
/// **The segmentation is the plugin's.** A page's structured text comes from
/// `PdfPage.loadStructuredText`, whose `fragments` are PDFium's own grouping —
/// `PdfTextFormatter` cuts a line into word runs, keeps a run of whitespace as
/// its own fragment, and marks a line break as a fragment too. A word here is a
/// fragment that is not whitespace: they are read in the order the plugin
/// produced them, none merged and none split (design §2). The plugin's own
/// fragment bounds are the `bounds` of that run.
///
/// **Coordinates.** PDFium and the plugin work in PDF page coordinates: origin
/// at the page's **bottom-left**, y growing upwards, page size in points
/// (1/72 inch). Design §2's schema and the reference extraction want the
/// opposite on both counts, so the y of a box is measured down from the top of
/// the page here, and only here: `top = height - rect.top` and
/// `bottom = height - rect.bottom`, which also swaps which of the two is the
/// smaller number.
///
/// **Read-only.** `PdfDocument.openFile` opens the file for reading and the
/// document is disposed without being written back; nothing in this class saves,
/// re-flattens or re-compresses (ADR-015). The harness proves it with a SHA-256
/// before and after the call (design §1), not by reading this class.
class PdfrxTextCandidate implements PdfTextCandidate {
  const PdfrxTextCandidate();

  /// The library and version this candidate resolves, in design §2's `tool`
  /// format. Kept in step with `pdfrx` in `app/pubspec.yaml`; the PDFium binary
  /// the build downloads is reported beside it in the lane report, not here.
  static const String toolName = 'pdfrx 2.6.5';

  @override
  String get tool => toolName;

  @override
  Future<CandidateDocument> read(String path) async {
    // Sets up the plugin's asset and cache access and loads the native engine.
    // It is a no-op after the first call, so the harness does not have to know
    // it is needed.
    await pdfrxFlutterInitialize();

    final PdfDocument document = await PdfDocument.openFile(path);
    try {
      final List<CandidatePage> pages = <CandidatePage>[];
      final List<int> msPerPage = <int>[];
      for (final PdfPage page in document.pages) {
        // The page's own extraction, timed where the plugin's work happens:
        // the document is already open, so what is measured is the page and not
        // the open or the close (design §1.3).
        final Stopwatch stopwatch = Stopwatch()..start();
        final PdfPageText text = await page.loadStructuredText();
        stopwatch.stop();
        msPerPage.add(stopwatch.elapsedMilliseconds);
        pages.add(
          candidatePageFromPdfrx(
            index: page.pageNumber - 1,
            width: page.width,
            height: page.height,
            text: text,
          ),
        );
      }
      return CandidateDocument(pages: pages, msPerPage: msPerPage);
    } finally {
      await document.dispose();
    }
  }
}

/// One plugin page of structured text, in design §2's shape.
///
/// It is public and pure so that the coordinate conversion and the treatment of
/// whitespace fragments are unit tested without a device — `PdfPageText` and
/// `PdfPageTextFragment` are plain constructible types, so a test can hand this
/// function the very shape the plugin produces.
///
/// [index] is zero-based and [height] is the page's height in points, which the
/// plugin reports on the page and not on its text.
CandidatePage candidatePageFromPdfrx({
  required int index,
  required double width,
  required double height,
  required PdfPageText text,
}) {
  final List<CandidateWord> words = <CandidateWord>[];
  for (final PdfPageTextFragment fragment in text.fragments) {
    // A whitespace fragment is a run of spaces or a line break, which the
    // plugin emits as a fragment of its own. They are separators and not words,
    // and dropping them merges nothing: the word fragments stay exactly as the
    // plugin cut them.
    if (fragment.text.trim().isEmpty) {
      continue;
    }
    final PdfRect bounds = fragment.bounds;
    words.add(
      CandidateWord(
        text: fragment.text,
        x0: bounds.left,
        x1: bounds.right,
        top: height - bounds.top,
        bottom: height - bounds.bottom,
      ),
    );
  }
  return CandidatePage(
    index: index,
    width: width,
    height: height,
    words: List<CandidateWord>.unmodifiable(words),
  );
}
