import 'package:paperdrop/intake/intake_result.dart';

/// A document a platform service has just handed to the application, before it
/// is stored (design §3).
///
/// The bytes are a stream and not a list: a document is copied through, never
/// held in memory, so that a large attachment behaves like a small one.
class IncomingDocument {
  const IncomingDocument({
    required this.source,
    required this.bytes,
    this.mediaType,
    this.filename,
  });

  /// The path this document arrived by.
  final IntakeSource source;

  /// The document itself.
  final Stream<List<int>> bytes;

  /// What the source declared, if it declared anything. `DocumentIntake`
  /// resolves the accepted type; this value never decides it alone.
  final String? mediaType;

  /// The name the document arrived under, used **only** to resolve a media type
  /// when the source declared none. It never reaches the stored path or the
  /// result of the intake: a file name can carry an invoice number or a person's
  /// name (design §3).
  final String? filename;
}

/// The device's file picker — one of the paths of FR-CAP-001.
abstract interface class FilePickerSource {
  /// The document the user chose, or null when they cancelled.
  ///
  /// Throws [IntakeFailure] when the picker itself cannot answer.
  Future<IncomingDocument?> pick();
}

/// Documents handed over by another application — the Android half of
/// FR-CAP-008, which needs no separate component on Android.
abstract interface class ShareInSource {
  /// The documents shared while the app is running, and the one that started it.
  ///
  /// A share carries a list because `ACTION_SEND_MULTIPLE` exists: several files
  /// shared at once are refused in the MVP (product owner, 2026-09-30), and the
  /// refusal is only possible if the list is not flattened away.
  Stream<List<IncomingDocument>> documents();
}
