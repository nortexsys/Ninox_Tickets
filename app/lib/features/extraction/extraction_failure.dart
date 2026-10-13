/// The one failure the extraction route reports, whichever port produced it.
///
/// Requirement served: `extraction-pipeline` · `invoice-route-priority` (FR-EXT-002) —
/// the route stops at the first method that can read the document, so a document no
/// method could read is a failure of the *route* and not of the port that noticed it.
/// `PdfTextReadFailure` (`adapters/pdf_text/`) and `OcrFailure` (`adapters/ocr/`) are
/// two ends of one pipeline: `ExtractionRouter` catches both and hands its caller one
/// type (design §2).
///
/// **No document content.** [ExtractionFailure.cause] is the failure the port raised,
/// kept for a debugger and never printed — a reason that carried a value of the document
/// would otherwise reach a log line through it. `toString` names the code and nothing
/// else, and the wording a user reads is T2.2's, from the ARB (NFR-I18N-001).
library;

/// Why the extraction route could not read a document (design §2).
///
/// Every value is a refusal, and every one of them is shown to the user as a string from
/// the ARB file: the mapping from code to text belongs with the screen (T2.2), as
/// `features/capture/capture_messages.dart` does it for the intake's codes.
///
/// [code] is the wire form — lowercase, digits and underscores — which is the shape
/// `HistoryEntry.failureReason` accepts: the same code a `failed` entry stores is the one
/// this enum names, so no second vocabulary is invented for the store.
enum ExtractionFailureCode {
  /// The PDF could not be opened or read at all, so not one page could be asked whether
  /// it has a text layer (`PdfTextReadFailure`). A page that merely holds no word is not
  /// this: that is an answer, and the route falls through to OCR.
  textLayerUnreadable('text_layer_unreadable'),

  /// The pages could not be rendered and recognised, or the route's recognition produced
  /// no pass at all (`OcrFailure`). A pass that was dropped is not this: the list may be
  /// shorter than the pass list, and one pass alone is legal.
  recognitionUnreadable('recognition_unreadable');

  /// Creates a code with its stored [code].
  const ExtractionFailureCode(this.code);

  /// The code as it is stored and compared: `text_layer_unreadable`.
  final String code;

  @override
  String toString() => code;
}

/// A document the extraction route could not read.
///
/// Thrown by `ExtractionRouter`, caught by `ExtractionService`, which moves the entry to
/// `failed` and gives it [code]. It carries no document content: [code] is a vocabulary
/// word and [cause] is diagnostic only.
///
/// **Why the cause is not printed.** The adapters' own failures carry the reason *and*
/// the exception the library raised, and a `FileSystemException` carries a path.
/// `toString` therefore reports the code alone; a debugger can still read [cause].
final class ExtractionFailure implements Exception {
  /// Creates a failure of [code], about the failure [cause] a port raised when there was
  /// one.
  const ExtractionFailure(this.code, {this.cause});

  /// What could not be read, as a code the screens translate.
  final ExtractionFailureCode code;

  /// The `PdfTextReadFailure` or `OcrFailure` behind this one, or `null` when a port
  /// answered with no pass at all. Diagnostic only: never user-facing, never printed.
  final Object? cause;

  @override
  String toString() => 'ExtractionFailure(${code.code})';
}
