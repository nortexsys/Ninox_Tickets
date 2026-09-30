import 'package:paperdrop/adapters/intake/incoming_document.dart';
import 'package:paperdrop/intake/document_intake.dart';
import 'package:paperdrop/intake/intake_failure.dart';
import 'package:paperdrop/intake/intake_result.dart';

/// What one path did with one document (design §3).
sealed class CaptureOutcome {
  const CaptureOutcome();
}

/// The document was stored; its [IntakeResult] is what the intake route shows.
class CaptureStored extends CaptureOutcome {
  const CaptureStored(this.result);

  final IntakeResult result;
}

/// The user closed the picker (or the scanner) without choosing anything. Not
/// an error, and not a message: the capture screen simply stays as it was.
class CaptureCancelled extends CaptureOutcome {
  const CaptureCancelled();
}

/// Nothing was stored, and the user is told why, with a string from the ARB.
class CaptureRefused extends CaptureOutcome {
  const CaptureRefused(this.failure);

  final IntakeFailure failure;
}

/// Every path of T1.13 into the one pipeline of FR-CAP-001.
///
/// The three paths converge here and are indistinguishable afterwards: the same
/// store, the same result, the same route. The fourth path of the requirement —
/// `.msg`/`.eml` — is R1 (plan v0.2 §4.1).
class CaptureController {
  CaptureController({
    required this.intake,
    required this.picker,
    required this.shareIn,
  });

  final DocumentIntake intake;
  final FilePickerSource picker;
  final ShareInSource shareIn;

  /// The file picker path.
  Future<CaptureOutcome> chooseFile() async {
    try {
      final IncomingDocument? document = await picker.pick();
      if (document == null) {
        return const CaptureCancelled();
      }
      return await store(document);
    } on IntakeFailure catch (failure) {
      return CaptureRefused(failure);
    } on Error {
      rethrow;
    } catch (_) {
      return const CaptureRefused(
        IntakeFailure(IntakeFailureCode.intakeFailed),
      );
    }
  }

  /// The share-in path, as a stream of outcomes: a share can arrive at any time,
  /// including as the reason the application started.
  Stream<CaptureOutcome> sharedDocuments() async* {
    try {
      await for (final List<IncomingDocument> documents
          in shareIn.documents()) {
        if (documents.isEmpty) {
          yield const CaptureRefused(
            IntakeFailure(IntakeFailureCode.noDocumentShared),
          );
          continue;
        }
        if (documents.length > 1) {
          // Nothing is stored: several files shared at once are refused in the
          // MVP (product owner, 2026-09-30), and taking the first one silently
          // would be the wrong reading of "one document at a time".
          yield const CaptureRefused(
            IntakeFailure(IntakeFailureCode.severalFilesShared),
          );
          continue;
        }
        yield await store(documents.single);
      }
    } on IntakeFailure catch (failure) {
      yield CaptureRefused(failure);
    } on Error {
      rethrow;
    } catch (_) {
      yield const CaptureRefused(IntakeFailure(IntakeFailureCode.intakeFailed));
    }
  }

  /// Stores one incoming document and says what happened.
  Future<CaptureOutcome> store(IncomingDocument document) async {
    try {
      return CaptureStored(
        await intake.intake(
          document.source,
          document.bytes,
          filename: document.filename,
          mediaType: document.mediaType,
        ),
      );
    } on IntakeFailure catch (failure) {
      return CaptureRefused(failure);
    } on Error {
      rethrow;
    } catch (_) {
      return const CaptureRefused(
        IntakeFailure(IntakeFailureCode.intakeFailed),
      );
    }
  }
}
