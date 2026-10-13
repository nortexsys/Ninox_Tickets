/// The port of the photo route's recognition (`implement-photo-route`,
/// design §1).
///
/// **What it is.** A file — a PDF of scanned pages, or one image — becomes
/// passes of pages of positioned words: Core's `TextPage` and `PositionedWord`,
/// in integer thousandths of a point with a top-left origin. That is the same
/// input the invoice route's text layer produces (`pdfrx_text_source.dart`), so
/// the rule that binds a label to its value is written once and a later engine
/// swap changes this file's implementation and not that rule.
///
/// **What it is not.** It chooses nothing across passes. The same page is read
/// several times under controlled variations and every pass is returned as it
/// came: no merging, no averaging and no maximum. Which reading wins is Core's
/// consensus (T1.5/T2.1), and this layer never sees a field, an amount or a
/// label.
library;

import 'package:paperdrop_core/paperdrop_core.dart';

/// A source of recognised text: the photo route's twin of `PdfTextSource`.
abstract interface class OcrTextSource {
  /// Recognises [path] and returns one [OcrPass] per pass, in the order of the
  /// pass list the source was built with.
  ///
  /// [path] is a PDF of scanned pages, or one image (PNG or JPEG, the image
  /// media types the MVP accepts). A PDF's pages are rendered and read; an
  /// image is read as it is.
  ///
  /// **Read-only.** The file is opened for reading and nothing else: no save,
  /// no re-flatten, no re-compress, no write back (ADR-015,
  /// `received-files-are-attached-byte-for-byte`). The caller may hash the file
  /// before and after this call and must find the same bytes; the adapters
  /// carry no write path to the input at all.
  ///
  /// A page that yields no word is a page with no word, not a failure: its
  /// [TextPage.hasTextLayer] is false, which is what the route selector's
  /// fall-through reads (T2.1). A file that cannot be opened or rendered throws
  /// an [OcrFailure].
  ///
  /// The list may be shorter than the pass list, or hold a single pass: a pass
  /// that fails is dropped and reported, and one pass alone is legal — Core
  /// treats it as a single reading. Every pass that is returned carries the
  /// words of its own rendering, unconverted by anything else.
  Future<List<OcrPass>> recognise(String path);
}

/// One pass's reading of one document.
///
/// The [passId] is what makes a pass reproducible: it names the rendering the
/// words came from (design §3's table), so a later run reads the same pass and
/// consensus compares like with like. It is the engine's answer for that
/// rendering and nothing else — a pass is never merged with another here.
class OcrPass {
  /// Creates a pass with its [passId] and the [pages] it read.
  OcrPass(this.passId, List<TextPage> pages) : pages = List.unmodifiable(pages);

  /// The rendering this pass read, as design §3 names it.
  final String passId;

  /// The document's pages, in page order, from page 0 on.
  final List<TextPage> pages;

  /// A value-only string form naming the pass and its page count.
  @override
  String toString() => 'OcrPass($passId, ${pages.length} pages)';

  /// Value equality on the pass id and its pages.
  @override
  bool operator ==(Object other) {
    if (other is! OcrPass || other.passId != passId) {
      return false;
    }
    if (other.pages.length != pages.length) {
      return false;
    }
    for (var i = 0; i < pages.length; i++) {
      if (other.pages[i] != pages[i]) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(passId, Object.hashAll(pages));
}

/// A document the photo route could not read at all.
///
/// It is thrown for a file that cannot be opened, is not a PDF or an image this
/// route recognises, or cannot be rendered — never for a page that simply holds
/// no word, which is an answer and not a failure. The user-facing wording of it
/// belongs to whoever surfaces the route's failure (T2.1); this type only
/// carries what happened.
class OcrFailure implements Exception {
  /// Creates a failure with a short [reason] and, when there is one, the
  /// [cause] the library raised.
  const OcrFailure(this.reason, [this.cause]);

  /// What went wrong, in a few words.
  final String reason;

  /// The exception the library raised, when it raised one.
  final Object? cause;

  @override
  String toString() => 'OcrFailure: $reason${cause == null ? '' : ' ($cause)'}';
}
