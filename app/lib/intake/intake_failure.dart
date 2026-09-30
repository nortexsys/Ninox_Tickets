/// Why a document was not accepted.
///
/// Every value here is a *refusal*, and every one of them is shown to the user
/// as a string from the ARB file (NFR-I18N-001): the mapping from code to text
/// lives in `features/capture/capture_messages.dart`. The code itself carries no
/// user-facing text, so that no string reaches a screen without passing through
/// the resources.
enum IntakeFailureCode {
  /// The document is not one of [IntakeResult.supportedMediaTypes] (design §3).
  unsupportedMediaType,

  /// Several files arrived in one share. Refused in the MVP (product owner,
  /// 2026-09-30): nothing is stored and the user is asked for one document.
  severalFilesShared,

  /// A share arrived carrying no file at all.
  noDocumentShared,

  /// The platform scanner answered without a PDF. The app assembles no PDF of
  /// its own, so this is a failure and not a reason to improvise (design §3).
  scannerProducedNoPdf,

  /// The copy, the digest or the storage failed. Nothing is kept: a half-written
  /// document is worse than none, because it is one the app would later claim
  /// to have.
  intakeFailed,
}

/// A refused document. Thrown by `DocumentIntake` and the capture pipeline,
/// never shown as it is.
class IntakeFailure implements Exception {
  const IntakeFailure(this.code, {this.detail});

  /// What went wrong, as a code the screens translate.
  final IntakeFailureCode code;

  /// Diagnostic only — a media type, an extension, an error class. It is never
  /// user-facing, and it must never carry document content or a file name:
  /// `DocumentIntake` does not record names, and this field must not become the
  /// place where one leaks into a log line.
  final String? detail;

  @override
  String toString() =>
      'IntakeFailure(${code.name}${detail == null ? '' : ', $detail'})';
}
