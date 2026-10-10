/// One document's local history entry, and the eight states it is stored in (design §5.2, §5.3).
///
/// Requirement served: FR-HIS-001 (`document-history/content-of-a-history-entry`) — every
/// capture produces an entry holding the thumbnail, the extracted values with their
/// provenance, the destination, the state, the confidence, the document hash and the Ninox
/// record identifier once sent — and FR-HIS-002 (`document-history/document-states`) — exactly
/// one state of eight, whose transitions `document_machine.dart` owns.
///
/// **The store reads the contract, it does not author it (BR-09).** Every value
/// `paperdrop_core` owns is written and read through that package's own JSON: the extracted
/// values are the core's canonical document, under the core's own keys, and the confidence is
/// the core's [ConfidenceState]. Nothing here can hold a value the core cannot round-trip,
/// because nothing here writes a value of its own.
///
/// **A code, never a message.** [HistoryEntry.failureReason] is a code, and one that is not a
/// code is refused (design §5.2); every [FormatException] this file throws names a field or a
/// state, never a document's content.
library;

import 'package:ninox_client/ninox_client.dart' show RecordId, TableRef;
import 'package:paperdrop_core/paperdrop_core.dart'
    show CanonicalDocument, ConfidenceState;

/// The eight states a history entry is stored in, in the order design §5.3 lists them.
///
/// **What is not here.** The functional's finer steps are not stored states (§5.3):
/// `capturing` and `ingested` are [pending], `attaching` and `reading-back` are [sending],
/// `reconciling` is [uncertain], and discarding deletes the entry and its folder instead of
/// moving it. `duplicate-flagged` is not a ninth value either: DEC-016 (product owner,
/// 2026-10-10) makes it the separate flag [HistoryEntry.duplicateFlagged], because a duplicate
/// is a property a document has in any state rather than a situation of its own.
enum DocumentState {
  /// Captured and stored, before extraction has run.
  pending,

  /// Saved with no connectivity: waiting, not failed (`document-states` · *an offline save is
  /// queued, not failed*).
  queued,

  /// Extraction is running.
  extracting,

  /// Extraction is done and the user is reviewing the document.
  reviewing,

  /// The send pipeline has it: attaching and reading back are this state's finer steps.
  sending,

  /// A create whose response was lost. Reconcile or ask — never a blind retry, and never
  /// collapsed into [failed] or into [sent] (`document-states` · *a lost create response is
  /// uncertain, not failed*).
  uncertain,

  /// Confirmed in Ninox: the entry stays in history and the local document file is released
  /// (FR-HIS-004).
  sent,

  /// Known to have failed. The file is retained, and the entry can be corrected and re-sent.
  failed;

  /// The stored name: the enum's own name, which is also what `entry.json` carries.
  String toJson() => name;

  /// The state with this stored name, or a [FormatException].
  ///
  /// The names this refuses are the ones design §5.3 keeps out of the store: the functional's
  /// finer steps (`capturing`, `ingested`, `attaching`, `reading_back`, `reconciling`,
  /// `discarded`) and DEC-016's `duplicate_flagged`, which is a flag and not a state.
  static DocumentState fromJson(Object? json) {
    if (json is! String) {
      throw const FormatException('a document state must be a string');
    }
    for (final DocumentState state in values) {
      if (state.name == json) {
        return state;
      }
    }
    throw FormatException(
      'unknown document state `$json`; the eight stored states are '
      '${values.map((DocumentState state) => state.name).join(', ')}',
    );
  }
}

/// One document's history entry: every item of FR-HIS-001 and the one state it holds.
///
/// Immutable and compared by value, so a state is read from an entry and never assigned to it:
/// the only way to another state is `transition()` in `document_machine.dart`, which applies
/// design §5.3's table and bumps [revision].
///
/// **What a change costs.** [revision] is the entry's own counter: every change produces one
/// higher (design §5.1), and `FileHistoryStore.update` refuses an entry that is not newer than
/// what is stored. That is what makes a write from a copy that has been overtaken fail instead
/// of silently replacing a newer state.
final class HistoryEntry {
  /// Builds an entry, refusing one that could not be true.
  ///
  /// [createdAt] is carried in UTC, so that a stored instant is unambiguous and equal to itself
  /// after a round trip. The refusals are the invariants of the design: [docId] and
  /// [documentHash] are in the shape the intake produces, [revision] starts at 1, a
  /// [failureReason] is a code, and a [sent][DocumentState.sent] entry carries a record
  /// identifier.
  HistoryEntry({
    required this.docId,
    required this.revision,
    required DateTime createdAt,
    required this.state,
    required this.documentHash,
    required this.destination,
    this.duplicateFlagged = false,
    this.thumbnailPath,
    this.values,
    this.confidence,
    this.ninoxRecordId,
    this.failureReason,
  }) : createdAt = createdAt.toUtc() {
    _checkInvariants();
  }

  /// Reads an entry out of what [toJson] wrote, or a [FormatException].
  ///
  /// **Strictly.** A file this app wrote is read as strictly as it was written — the wizard's
  /// store takes the same position — because reading a corrupt entry as *no entry* would
  /// silently throw the user's document away. `FileHistoryStore` turns the [FormatException]
  /// into one entry's failure, never into an exception out of `list()` (design §5.1).
  factory HistoryEntry.fromJson(Object? json) {
    final Map<String, Object?> object = _objectOf(json, what: 'an entry');
    try {
      return HistoryEntry(
        docId: _stringOf(object, 'docId', what: 'an entry'),
        revision: _intOf(object, 'revision', what: 'an entry'),
        createdAt: DateTime.parse(
          _stringOf(object, 'createdAt', what: 'an entry'),
        ),
        state: DocumentState.fromJson(object['state']),
        duplicateFlagged: _boolOf(object, 'duplicateFlagged', what: 'an entry'),
        documentHash: _stringOf(object, 'documentHash', what: 'an entry'),
        thumbnailPath: _optionalStringOf(
          object,
          'thumbnailPath',
          what: 'an entry',
        ),
        destination: _tableRefOf(object['destination']),
        values: _canonicalDocumentOf(object['values']),
        confidence: object['confidence'] == null
            ? null
            : ConfidenceState.fromJson(object['confidence']),
        ninoxRecordId: _recordIdOf(object['ninoxRecordId']),
        failureReason: _optionalStringOf(
          object,
          'failureReason',
          what: 'an entry',
        ),
      );
    } on ArgumentError catch (error) {
      // The constructor refuses a value that could not be true. In a file, that
      // is corruption and not a programming mistake, so it is reported as one.
      throw FormatException('an entry: ${error.message}');
    }
  }

  /// The identifier `DocumentIntake` assigned: 128 random bits, hex encoded.
  ///
  /// Content-free, derived from nothing, and — because it names the document's folder — kept to
  /// hex digits by the constructor: an identifier that could carry a separator could be a path
  /// out of the document folder.
  final String docId;

  /// How many changes this entry has had, starting at 1 for a created entry.
  ///
  /// The store's optimistic-concurrency value (design §5.1): `update` refuses an entry whose
  /// revision is not newer than the stored one.
  final int revision;

  /// When the entry was created, in UTC.
  final DateTime createdAt;

  /// The one state the entry holds.
  final DocumentState state;

  /// Whether the duplicate check flagged this document (DEC-016: a property, not a state).
  ///
  /// It can be set in any state and never blocks a transition (design §5.3). The criteria
  /// themselves are `document-history`'s and are checked read-side against the store; this flag
  /// is only where the answer is kept.
  final bool duplicateFlagged;

  /// The SHA-256 of the document as stored, lowercase hex, from `DocumentIntake` (FR-CAP-005).
  ///
  /// It is the substance of the duplicate check's hash criterion. It is not the canonical
  /// document's `sourceHash`: that one is extraction's, and the two are compared by whoever
  /// needs to, not by this store.
  final String documentHash;

  /// Where the thumbnail is, or `null` until one exists.
  ///
  /// The path is the app's own — a thumbnail is rendered from the stored original, so it
  /// carries no file name the user's document came with (design §3) — and it is read as it was
  /// written: nothing here deletes or moves a thumbnail, which is what `file-retention` requires
  /// to remain after the document file is released.
  final String? thumbnailPath;

  /// The destination the document goes to: the three identifiers and nothing else (design §5.2).
  ///
  /// The field mapping is not here. A destination's mapping belongs to the configuration and is
  /// resolved at send time; an entry that carried a second copy could disagree with it.
  final TableRef destination;

  /// The extracted values with their provenance, or `null` until extraction has run.
  ///
  /// The core's canonical document, read and written only through the core's own JSON — so every
  /// amount is an integer in minor units, every rate is basis points and every value carries one
  /// of the four provenance tags by wire name (BR-09, FR-EXT-011).
  final CanonicalDocument? values;

  /// The document's confidence, or `null` until validation has run.
  ///
  /// The core's own states, which is what history shows when nothing was mapped: it is the only
  /// place a past document's confidence can be inspected after the fact
  /// (`history-is-the-uncertainty-trace`).
  final ConfidenceState? confidence;

  /// The Ninox record's identifier, or `null` until a create has been confirmed.
  ///
  /// Set when the create is confirmed and kept from then on — through [DocumentState.sent], and
  /// also through `sent -> reviewing -> sending` on a correction, because it is what makes the
  /// correction an update of that record instead of a second one (FR-HIS-003).
  final RecordId? ninoxRecordId;

  /// Why the document's last attempt failed, as a code, or `null`.
  ///
  /// A code and never a message: a reason that is not `[a-z][a-z0-9_]{0,63}` is refused by the
  /// constructor, so no amount, currency or other value of a document can travel in this field.
  /// The codes are the send pipeline's vocabulary — `attachment_incomplete` is one, from design
  /// §5.4 — and this store neither invents nor interprets them.
  final String? failureReason;

  /// The stored form (design §5.2): every item of the entry, and nothing else.
  ///
  /// The envelope's keys are the design's field names; `destination` holds the three identifiers
  /// as plain ids, and `values` and `confidence` are the core's JSON, never re-keyed here. A
  /// field that is not set yet is written as `null` rather than left out, so the file's shape
  /// does not change as a document moves through the machine.
  Map<String, Object?> toJson() => <String, Object?>{
    'docId': docId,
    'revision': revision,
    'createdAt': createdAt.toIso8601String(),
    'state': state.toJson(),
    'duplicateFlagged': duplicateFlagged,
    'documentHash': documentHash,
    'thumbnailPath': thumbnailPath,
    'destination': <String, Object?>{
      'team': destination.teamId,
      'database': destination.databaseId,
      'table': destination.tableId,
    },
    'values': values?.toJson(),
    'confidence': confidence?.toJson(),
    'ninoxRecordId': ninoxRecordId?.value,
    'failureReason': failureReason,
  };

  /// The entry's own invariants — the ones that must hold of every entry, from the constructor
  /// and from a file alike.
  void _checkInvariants() {
    if (!_docIdPattern.hasMatch(docId)) {
      throw ArgumentError.value(
        docId,
        'docId',
        'must be the 32 hex digits DocumentIntake assigns: the identifier also '
            'names the document folder',
      );
    }
    if (revision < 1) {
      throw ArgumentError.value(
        revision,
        'revision',
        'must be 1 or more: a created entry has revision 1 and every change '
            'adds one',
      );
    }
    if (!_documentHashPattern.hasMatch(documentHash)) {
      throw ArgumentError.value(
        documentHash,
        'documentHash',
        'must be a SHA-256 in lowercase hex, as DocumentIntake computes it',
      );
    }
    if (thumbnailPath != null && thumbnailPath!.isEmpty) {
      throw ArgumentError.value(
        thumbnailPath,
        'thumbnailPath',
        'must be a path or null, not an empty string',
      );
    }
    if (ninoxRecordId != null && ninoxRecordId!.value.isEmpty) {
      throw ArgumentError.value(
        ninoxRecordId,
        'ninoxRecordId',
        'must be an identifier or null, not an empty string',
      );
    }
    if (failureReason != null && !_codePattern.hasMatch(failureReason!)) {
      throw ArgumentError.value(
        failureReason,
        'failureReason',
        'must be a code — lowercase, digits and underscores — and never a '
            'message that carries a value',
      );
    }
    if (state == DocumentState.sent && ninoxRecordId == null) {
      throw ArgumentError(
        'a sent entry must carry the record identifier of the create it was '
        'confirmed by (`document-states` · *a completed send carries its record '
        'identifier*)',
      );
    }
  }

  /// Value equality on every item of the entry.
  @override
  bool operator ==(Object other) =>
      other is HistoryEntry &&
      other.docId == docId &&
      other.revision == revision &&
      other.createdAt == createdAt &&
      other.state == state &&
      other.duplicateFlagged == duplicateFlagged &&
      other.documentHash == documentHash &&
      other.thumbnailPath == thumbnailPath &&
      other.destination == destination &&
      other.values == values &&
      other.confidence == confidence &&
      other.ninoxRecordId == ninoxRecordId &&
      other.failureReason == failureReason;

  /// Hash of every item of the entry.
  @override
  int get hashCode => Object.hashAll(<Object?>[
    docId,
    revision,
    createdAt,
    state,
    duplicateFlagged,
    documentHash,
    thumbnailPath,
    destination,
    values,
    confidence,
    ninoxRecordId,
    failureReason,
  ]);

  /// The entry's state line, and nothing else.
  ///
  /// No extracted value, no amount, no path, no record identifier and no hash: a diagnostic
  /// carries no document content (`local-config-privacy` · *no document content appears in a
  /// diagnostic*), and this is the only text an entry ever produces.
  @override
  String toString() =>
      'HistoryEntry(docId: ${docId.substring(0, 8)}…, revision: $revision, '
      'state: ${state.name}'
      '${duplicateFlagged ? ', duplicate-flagged' : ''}, '
      'values: ${values == null ? 'none' : 'extracted'})';
}

/// `DocumentIntake`'s identifier shape (design §3): 128 bits as lowercase hex.
final RegExp _docIdPattern = RegExp(r'^[0-9a-f]{32}$');

/// A SHA-256 in lowercase hex, the form `DocumentIntake` reports.
final RegExp _documentHashPattern = RegExp(r'^[0-9a-f]{64}$');

/// A failure reason that is a code: a token, not a sentence with a value in it.
final RegExp _codePattern = RegExp(r'^[a-z][a-z0-9_]{0,63}$');

/// One stored object, or a [FormatException].
Map<String, Object?> _objectOf(Object? json, {required String what}) {
  if (json is! Map) {
    throw FormatException('$what: expected a JSON object');
  }
  return <String, Object?>{
    for (final MapEntry<Object?, Object?> entry in json.entries)
      '${entry.key}': entry.value,
  };
}

/// One stored string, or a [FormatException].
String _stringOf(
  Map<String, Object?> json,
  String key, {
  required String what,
}) {
  final Object? value = json[key];
  if (value is! String) {
    throw FormatException('$what: expected a string under `$key`');
  }
  return value;
}

/// One stored string that may be absent, or a [FormatException].
String? _optionalStringOf(
  Map<String, Object?> json,
  String key, {
  required String what,
}) {
  if (!json.containsKey(key) || json[key] == null) {
    return null;
  }
  return _stringOf(json, key, what: what);
}

/// One stored integer, or a [FormatException].
int _intOf(Map<String, Object?> json, String key, {required String what}) {
  final Object? value = json[key];
  if (value is! int) {
    throw FormatException('$what: expected an integer under `$key`');
  }
  return value;
}

/// One stored boolean, or a [FormatException].
bool _boolOf(Map<String, Object?> json, String key, {required String what}) {
  final Object? value = json[key];
  if (value is! bool) {
    throw FormatException('$what: expected a boolean under `$key`');
  }
  return value;
}

/// One stored destination — the three identifiers as plain ids, or a [FormatException].
TableRef _tableRefOf(Object? json) {
  final Map<String, Object?> object = _objectOf(json, what: 'a destination');
  return TableRef(
    teamId: _identifierOf(object, 'team', what: 'a destination'),
    databaseId: _identifierOf(object, 'database', what: 'a destination'),
    tableId: _identifierOf(object, 'table', what: 'a destination'),
  );
}

/// One stored identifier: a non-empty string, or a [FormatException].
String _identifierOf(
  Map<String, Object?> json,
  String key, {
  required String what,
}) {
  final String value = _stringOf(json, key, what: what);
  if (value.isEmpty) {
    throw FormatException('$what: an empty `$key` is not an identifier');
  }
  return value;
}

/// The stored canonical document, or a [FormatException].
CanonicalDocument? _canonicalDocumentOf(Object? json) {
  if (json == null) {
    return null;
  }
  return CanonicalDocument.fromJson(_objectOf(json, what: 'values'));
}

/// The stored record identifier, or a [FormatException].
RecordId? _recordIdOf(Object? json) {
  if (json == null) {
    return null;
  }
  if (json is! String || json.isEmpty) {
    throw const FormatException(
      'a record identifier must be a non-empty string',
    );
  }
  return RecordId(json);
}
