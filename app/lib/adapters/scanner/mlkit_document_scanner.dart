import 'dart:io';

import 'package:flutter/services.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart'
    as mlkit;
import 'package:paperdrop/adapters/intake/incoming_document.dart';
import 'package:paperdrop/adapters/scanner/document_scanner.dart';
import 'package:paperdrop/intake/intake_failure.dart';
import 'package:paperdrop/intake/intake_result.dart';

/// The platform's document scanner on Android: ML Kit Document Scanner
/// (FR-CAP-002, ADR-006, design §3).
///
/// In **PDF mode**, multi-page allowed and gallery import off: the scanner's own
/// PDF is the document — cropped, deskewed, enhanced and assembled by the
/// platform — and the application hands it to the store unchanged. No page is
/// re-encoded here, nothing is re-rendered, and no perspective correction or
/// binarisation routine exists in this application: a test proves there is none
/// in `app/lib/`.
class MlKitDocumentScanner implements DocumentScanner {
  const MlKitDocumentScanner();

  /// The page limit of one scan session.
  ///
  /// ML Kit requires a value of at least 1 and offers no "unlimited": the
  /// plugin's own default is 1 page, which would make FR-CAP-003 impossible
  /// (several pages are one expense). No requirement and no design states a page
  /// cap for the MVP, so this constant is not one — it is the platform
  /// parameter, set high enough that no document the MVP is aimed at reaches
  /// it, and the platform itself bounds the rest by memory and storage.
  static const int pageLimit = 100;

  /// The code ML Kit's scanner uses when the user leaves it without scanning.
  ///
  /// The platform answers a cancellation with an error rather than an empty
  /// result, so the only way to tell "the user changed their mind" from "the
  /// scan failed" is this code. It is matched here once, and nowhere else.
  static const String _cancelledCode = 'DocumentScanner';
  static const String _cancelledMessage = 'Operation cancelled';

  @override
  Future<IncomingDocument?> scan() async {
    final mlkit.DocumentScanner scanner = mlkit.DocumentScanner(
      options: mlkit.DocumentScannerOptions(
        documentFormats: const <mlkit.DocumentFormat>{mlkit.DocumentFormat.pdf},
        pageLimit: pageLimit,
        mode: mlkit.ScannerMode.full,
        isGalleryImport: false,
      ),
    );
    try {
      final mlkit.DocumentScanningResult result = await scanner.scanDocument();
      final mlkit.DocumentScanningResultPdf? pdf = result.pdf;
      if (pdf == null) {
        // The scanner answered with images only. Assembling a PDF here would be
        // the app doing what the platform does, and would re-encode every page:
        // it is a failure to report, not a reason to improvise.
        throw const IntakeFailure(IntakeFailureCode.scannerProducedNoPdf);
      }
      return IncomingDocument(
        source: IntakeSource.scanner,
        bytes: File(pdf.uri).openRead(),
        mediaType: 'application/pdf',
      );
    } on PlatformException catch (exception) {
      if (exception.code == _cancelledCode &&
          exception.message == _cancelledMessage) {
        return null;
      }
      throw const IntakeFailure(IntakeFailureCode.intakeFailed);
    } on Error {
      rethrow;
    } catch (_) {
      throw const IntakeFailure(IntakeFailureCode.intakeFailed);
    } finally {
      await scanner.close();
    }
  }
}
