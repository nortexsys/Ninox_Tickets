import 'package:paperdrop_core/paperdrop_core.dart';
import 'package:pdfrx/pdfrx.dart';

import 'pdf_text_source.dart';

/// The PDF text layer through **PDFium**, the engine Chrome renders PDFs with,
/// behind the Flutter binding `pdfrx` (`close-adr-011-pdf-text-route`, design §3
/// and §5; ADR-011 closed in favour of this candidate on 2026-10-07).
///
/// **The segmentation is the plugin's.** A page's structured text comes from
/// `PdfPage.loadStructuredText`, whose `fragments` are PDFium's own grouping:
/// `PdfTextFormatter` cuts a line into word runs, keeps a run of whitespace as a
/// fragment of its own and marks a line break as a fragment too. A word here is
/// a non-whitespace fragment, in the order the plugin produced it, none merged
/// and none split (design §2). Whitespace and line-break fragments are
/// separators, not words, and dropping them merges nothing.
///
/// **Coordinates.** PDFium and the plugin work in PDF page coordinates: origin
/// at the page's **bottom-left**, y growing upwards, page size in points
/// (1/72 inch). Core's contract is the opposite on both counts — integer
/// thousandths of a point, origin at the **top-left** — so the conversion here
/// is the only place the two meet: `top = (height - rect.top) * 1000` rounds to
/// Core's top, `bottom = (height - rect.bottom) * 1000` to its bottom, and the
/// x values are rounded as they are. Nothing else in the application converts.
///
/// **Read-only.** `PdfDocument.openFile` opens the file for reading and the
/// document is disposed without being written back; nothing here saves,
/// re-flattens or re-compresses (ADR-015), and the source file stays
/// byte-for-byte what it was.
class PdfrxTextSource implements PdfTextSource {
  /// Creates the source.
  ///
  /// [onPageRead] is called once per page, in page order, with the time that
  /// page's extraction took. The port does not carry timing: the evaluation
  /// harness needs it because design §2's JSON reports milliseconds per page,
  /// and only the reader knows where one page's work ends and the next begins.
  /// Nothing in the application passes it.
  const PdfrxTextSource({this.onPageRead});

  /// Called with each page's extraction time, in page order.
  final void Function(Duration elapsed)? onPageRead;

  /// The library and the version this adapter resolves, in design §2's `tool`
  /// format.
  ///
  /// It is kept in step with `pdfrx` in `app/pubspec.yaml`, and the evaluation
  /// harness writes it into every JSON so that the numbers in the review name
  /// what ran. Nothing in the application reads it.
  static const String toolName = 'pdfrx 2.6.5';

  @override
  Future<List<TextPage>> read(String path) async {
    // Sets up the plugin's asset and cache access and loads the native engine.
    // It is a no-op after the first call, so a caller does not have to know it
    // is needed.
    await pdfrxFlutterInitialize();

    final PdfDocument document;
    try {
      document = await PdfDocument.openFile(path);
    } catch (error) {
      throw PdfTextReadFailure('the document could not be opened', error);
    }

    try {
      final List<TextPage> pages = <TextPage>[];
      for (final PdfPage page in document.pages) {
        final Stopwatch stopwatch = Stopwatch()..start();
        final PdfPageText text = await page.loadStructuredText();
        stopwatch.stop();
        onPageRead?.call(stopwatch.elapsed);
        pages.add(
          textPageFromPdfrx(
            index: page.pageNumber - 1,
            width: page.width,
            height: page.height,
            text: text,
          ),
        );
      }
      return List<TextPage>.unmodifiable(pages);
    } finally {
      await document.dispose();
    }
  }
}

/// One page of `pdfrx` structured text, as Core's [TextPage].
///
/// It is public and pure so that the conversion is unit tested without a
/// device: `PdfPageText`, `PdfPageTextFragment` and `PdfRect` are plain
/// constructible types, so a test hands this function the very shape the plugin
/// produces and reads back Core's units.
///
/// [index] is zero-based. [width] and [height] are the page's size in points,
/// which the plugin reports on the page and not on its text; they become the
/// page's size in milli-points, and [height] is what turns the plugin's
/// bottom-up y into Core's top-down one.
///
/// [TextPage.hasTextLayer] is not set here: it is derived from the words, so a
/// page with no word is a page without a text layer, which is the fall-through
/// signal the route selector reads.
TextPage textPageFromPdfrx({
  required int index,
  required double width,
  required double height,
  required PdfPageText text,
}) {
  final List<PositionedWord> words = <PositionedWord>[];
  for (final PdfPageTextFragment fragment in text.fragments) {
    if (fragment.text.trim().isEmpty) {
      // A run of spaces or a line break: the plugin emits both as fragments of
      // their own, and neither is a word.
      continue;
    }
    final PdfRect bounds = fragment.bounds;
    // `PdfRect` guarantees left <= right and top >= bottom, and rounding keeps
    // that order, so `PositionedWord`'s own invariants hold by construction.
    // Its text invariant is the plugin's business too: `PdfTextFormatter` cuts
    // a line on whitespace, so a fragment is one token; a fragment that carried
    // whitespace would be rejected by `PositionedWord` rather than split here,
    // because splitting it would be this adapter segmenting words and design §2
    // forbids that.
    words.add(
      PositionedWord(
        fragment.text,
        _milli(bounds.left),
        _milli(bounds.right),
        _milli(height - bounds.top),
        _milli(height - bounds.bottom),
      ),
    );
  }
  return TextPage(index, _milli(width), _milli(height), words);
}

/// Points to Core's integer thousandths of a point.
int _milli(double points) => (points * 1000).round();
