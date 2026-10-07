/// The port of the invoice route's text layer
/// (`close-adr-011-pdf-text-route`, design §3).
///
/// **What it is.** A PDF, opened for reading, becomes pages of positioned words
/// — Core's `TextPage` and `PositionedWord`, in integer thousandths of a PDF
/// point with a top-left origin. That is the platform-neutral input Core's
/// layout reasoning consumes, and the same input the OCR adapter of the photo
/// route produces (T1.16), so a later engine swap changes this file and not the
/// rule that binds a label to its value.
///
/// **What it is not.** It decides nothing: it segments no words, sorts nothing,
/// parses no amount and binds no label. The only things it fixes are the units,
/// the origin and the read-only rule below.
library;

import 'package:paperdrop_core/paperdrop_core.dart';

/// A source of PDF text layers.
abstract interface class PdfTextSource {
  /// Reads [path] and returns its pages, in page order, from page 0 on.
  ///
  /// **Read-only.** The file is opened for reading and nothing else: no save,
  /// no re-flatten, no re-compress (ADR-015,
  /// `received-files-are-attached-byte-for-byte`). The caller may hash the file
  /// before and after this call and must find the same bytes; the adapter
  /// carries no write path at all.
  ///
  /// A page that yields no word is a page with no word, not a failure: its
  /// [TextPage.hasTextLayer] is false, which is what the route selector's
  /// fall-through to OCR reads (T2.1). A document that cannot be opened or read
  /// at all throws a [PdfTextReadFailure].
  Future<List<TextPage>> read(String path);
}

/// A document the text layer could not be read from.
///
/// It is thrown for a document that cannot be opened, is not a PDF, or is
/// damaged — never for a page that simply holds no word, which is an answer and
/// not a failure. The user-facing wording of it belongs to whoever surfaces the
/// route's failure (T2.1); this type only carries what happened.
class PdfTextReadFailure implements Exception {
  /// Creates a failure with a short [reason] and, when there is one, the
  /// [cause] the library raised.
  const PdfTextReadFailure(this.reason, [this.cause]);

  /// What went wrong, in a few words.
  final String reason;

  /// The exception the library raised, when it raised one.
  final Object? cause;

  @override
  String toString() =>
      'PdfTextReadFailure: $reason${cause == null ? '' : ' ($cause)'}';
}
