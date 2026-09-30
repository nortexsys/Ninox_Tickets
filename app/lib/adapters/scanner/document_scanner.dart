import 'package:paperdrop/adapters/intake/incoming_document.dart';

/// The platform's document scanner (FR-CAP-002, design §3).
///
/// The interface is what keeps the application free of the platform's SDK: the
/// screens and the pipeline know only that a scan produces a document or
/// nothing.
///
/// The implementation **never** presents a raw camera view and the app adds no
/// processing of its own: edge detection, perspective correction, contrast
/// enhancement and multi-page chaining come from the platform, and the
/// prototype's pre-processing stage is not ported.
abstract interface class DocumentScanner {
  /// Scans a document and returns it, or null when the user cancelled.
  ///
  /// Throws [IntakeFailure] with `scannerProducedNoPdf` when the platform
  /// answered without a PDF — the app assembles no PDF itself — and with
  /// `intakeFailed` when the scan failed.
  Future<IncomingDocument?> scan();
}
