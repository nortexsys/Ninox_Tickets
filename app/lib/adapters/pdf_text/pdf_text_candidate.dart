/// The two candidates of ADR-011, seen by the evaluation harness only
/// (`close-adr-011-pdf-text-route`, design §1–§2, tasks 1.1–1.3).
///
/// **What a candidate is.** One PDF library under evaluation, with the one
/// operation the comparison needs: open a document **for reading** and return,
/// per page, the words *that library* segments, each with a box in PDF points
/// and a top-left origin. Those are the units and the origin of the reference
/// extraction and of design §2's JSON, so nothing is mapped between the three.
///
/// **What this is not.** It is not the port. `PdfTextSource` over
/// `paperdrop_core`'s `TextPage`/`PositionedWord` is design §3's, and it is
/// written after the product owner's decision of Tue 6 Oct (task 4.1), because
/// the evaluation must not wait on Core and the losing candidate leaves with its
/// dependency (design §5). Nothing here decides a value either: the words come
/// back as the library segments them — no merging, no splitting, no reordering
/// (design §2) — and the rule that binds a label to the value nearest it in the
/// visual layout is Core's (design §3).
library;

/// One word as a candidate library segments it.
///
/// The box is in PDF points, origin at the page's top-left corner, exactly as
/// design §2's `words` entries and the reference extraction spell it: `x0` is
/// the left edge, `x1` the right edge, `top` the distance from the top of the
/// page to the top of the box, and `bottom` the distance from the top of the
/// page to the bottom of it. `top` is therefore *smaller* than `bottom`, unlike
/// the bottom-left origin of a PDF's own coordinate system.
class CandidateWord {
  const CandidateWord({
    required this.text,
    required this.x0,
    required this.x1,
    required this.top,
    required this.bottom,
  });

  /// The text of the word, as the library grouped it.
  final String text;

  /// Left edge, in points from the page's left edge.
  final double x0;

  /// Right edge, in points from the page's left edge.
  final double x1;

  /// Top edge, in points from the page's top edge.
  final double top;

  /// Bottom edge, in points from the page's top edge.
  final double bottom;
}

/// One page of one document, as one candidate read it.
///
/// `width` and `height` are the page's size in points, in the same
/// top-left-origin frame as the words, so that a lower-left corner can be
/// computed from either.
class CandidatePage {
  const CandidatePage({
    required this.index,
    required this.width,
    required this.height,
    required this.words,
  });

  /// Zero-based page index; the first page of a document is 0.
  final int index;

  /// Page width in points.
  final double width;

  /// Page height in points.
  final double height;

  /// The words the library found on this page, in the order it produced them.
  ///
  /// Empty is a real answer and not a failure: a page that yields no word is
  /// what T2.1's fall-through to OCR needs to see (design §3), and the harness
  /// records it as a page with no words rather than as an error.
  final List<CandidateWord> words;
}

/// One library under evaluation, behind the operation the comparison uses.
abstract interface class PdfTextCandidate {
  /// The library and the version that was actually resolved, in design §2's
  /// `tool` field format — for example `pdfbox-android 2.0.27.0`.
  ///
  /// It is the version of the artefact the build resolved, not the one this
  /// file was written against: the numbers in the review must name what ran.
  String get tool;

  /// Reads [path] **without writing to it** and returns its pages.
  ///
  /// The file is opened for reading and nothing else: no save, no re-flatten,
  /// no re-compress (ADR-015, `received-files-are-attached-byte-for-byte`).
  /// The harness proves it with a SHA-256 taken before and after this call —
  /// design §1, "whether opening the file ever writes to it" — and never by
  /// inspection.
  ///
  /// Throws [PlatformException] when the platform side fails, and
  /// [PdfTextReplyFormatException] when a channel reply does not have the shape
  /// this evaluation expects.
  Future<List<CandidatePage>> read(String path);
}

/// A channel reply that is not the shape design §2 fixes for it.
///
/// It is a failure of the harness's own boundary rather than of the document,
/// so it is never swallowed: a candidate whose reply cannot be read would
/// otherwise be recorded as a candidate that found no words, which is the one
/// confusion this evaluation must not make.
class PdfTextReplyFormatException implements Exception {
  const PdfTextReplyFormatException(this.reason);

  /// What was wrong with the reply, in words.
  final String reason;

  @override
  String toString() => 'PdfTextReplyFormatException: $reason';
}
