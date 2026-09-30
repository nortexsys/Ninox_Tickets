/// The three paths into the MVP's one pipeline (design §3, FR-CAP-001).
///
/// The fourth path of the requirement — a mail container shared as `.msg` or
/// `.eml` — is R1 (plan v0.2 §4.1) and is absent by cut, not by omission.
enum IntakeSource {
  /// Camera capture through the platform's document scanner (FR-CAP-002).
  scanner,

  /// A file chosen in the device's file picker.
  picker,

  /// A file handed over by another application's share action (FR-CAP-008).
  shareIn,
}

/// What the intake store did with one document, and what proves it
/// (`received-files-are-attached-byte-for-byte`, FR-CAP-005).
///
/// Nothing here carries the file's original name or anything else a source
/// document could be identified by: `docId` is random and content-free, and the
/// stored path is built from it.
class IntakeResult {
  const IntakeResult({
    required this.docId,
    required this.source,
    required this.mediaType,
    required this.byteLength,
    required this.sha256,
    required this.storedPath,
  });

  /// 128 random bits, hex encoded. Assigned by the store, derived from nothing.
  final String docId;

  /// The path the document arrived by.
  final IntakeSource source;

  /// One of [supportedMediaTypes].
  final String mediaType;

  /// The size of the stored copy, which equals the size of the input.
  final int byteLength;

  /// The SHA-256 of the stored copy, lowercase hex, which equals the SHA-256 of
  /// the input. This is what a later duplicate check has something to compare
  /// against (T2.3, `duplicate-criteria`).
  final String sha256;

  /// Where the untouched original lives on the device.
  final String storedPath;

  /// The first 12 hex digits of [sha256], for a screen that has to show
  /// something short (design §2, the intake placeholder).
  String get sha256Prefix => sha256.substring(0, 12);

  /// The media types the MVP accepts (design §3).
  static const Set<String> supportedMediaTypes = <String>{
    'application/pdf',
    'image/jpeg',
    'image/png',
  };

  @override
  bool operator ==(Object other) =>
      other is IntakeResult &&
      other.docId == docId &&
      other.source == source &&
      other.mediaType == mediaType &&
      other.byteLength == byteLength &&
      other.sha256 == sha256 &&
      other.storedPath == storedPath;

  @override
  int get hashCode =>
      Object.hash(docId, source, mediaType, byteLength, sha256, storedPath);

  @override
  String toString() =>
      'IntakeResult(docId: $docId, source: ${source.name}, '
      'mediaType: $mediaType, byteLength: $byteLength, sha256: $sha256Prefix…)';
}
