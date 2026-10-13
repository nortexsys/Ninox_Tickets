/// The local history store: one JSON file per document (design §5.1).
///
/// Requirement served: FR-HIS-001 and FR-HIS-002 (`document-history`) for what an entry is and
/// which state it holds, and FR-HIS-004 (`file-retention`) for the part of retention a store
/// can do — release the document file of a confirmed send, and refuse for everything else. The
/// store is local-only (ADR-009); nothing here opens a connection.
///
/// **Where an entry lives.** `<root>/<docId>/entry.json`, next to the `original.<ext>` that
/// `DocumentIntake` already put in `<root>/<docId>/`: a document's entry, its stored file and
/// its thumbnail are one folder, and `<root>` is the folder `DocumentIntake.originalsFolder`
/// names. `entry.json` is the only file this store owns; it reads no other file and writes none.
///
/// **A write is atomic.** It goes to `entry.json.tmp`, is flushed, and is renamed over
/// `entry.json`: a reader sees the entry before the write or the entry after it, never half of
/// either, and a crash between the two leaves the previous entry in place. A `.tmp` left by such
/// a crash is ignored on read — only `entry.json` is read — and removed by the next write.
///
/// **No clock and no timer.** Retention follows the state: [HistoryStore.deleteOriginal]
/// releases the file of an entry in `sent` and refuses every other state, and nothing in this
/// file deletes anything because time passed (`file-retention` · *retention follows the state,
/// not a timer*).
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'history_entry.dart';

/// What a history store refuses to do (design §5.1).
///
/// Every value is a refusal, and a code carries no user-facing text: a screen translates it, as
/// `features/capture/capture_messages.dart` translates the intake's codes (NFR-I18N-001). The
/// code reaches a screen as a string from the ARB file and never as this name.
enum HistoryStoreFailureCode {
  /// The document has no entry.
  notFound,

  /// The document already has an entry: a create never overwrites one.
  alreadyExists,

  /// The stored file is not an entry this app wrote. Reported *for that entry*: `list()`
  /// reports it and goes on with the other documents (design §5.1).
  unreadable,

  /// The offered entry is not newer than the stored one. Nothing was written.
  staleRevision,

  /// The stored document file is retained, because an unresolved item keeps its file
  /// (`file-retention` · *an unresolved item keeps its file*).
  originalRetained,

  /// The device's file system refused the operation.
  ioFailed,
}

/// A refusal of the history store. Thrown by `FileHistoryStore`, never shown as it is.
class HistoryStoreFailure implements Exception {
  /// Creates a refusal of [code], about [docId] when one document is concerned.
  const HistoryStoreFailure(this.code, {this.docId, this.detail});

  /// What was refused, as a code the screens translate.
  final HistoryStoreFailureCode code;

  /// The document the refusal is about. Content-free: the identifier is random and derived from
  /// nothing (design §3).
  final String? docId;

  /// Diagnostic only — the state, a revision number, an error class. It is never user-facing,
  /// and it must never carry document content: no amount, no extracted value, no file name. The
  /// identifier in [docId] is the only thing about a document that may appear here.
  final String? detail;

  @override
  String toString() =>
      'HistoryStoreFailure(${code.name}'
      '${docId == null ? '' : ', $docId'}'
      '${detail == null ? '' : ', $detail'})';
}

/// What [HistoryStore.list] found.
final class HistoryListing {
  /// Builds a listing from the entries that could be read and the documents that could not.
  const HistoryListing({required this.entries, required this.unreadable});

  /// Every entry that could be read, newest first: [HistoryEntry.createdAt] descending, and by
  /// [HistoryEntry.docId] ascending when two documents share an instant, so that the order is
  /// the same on every read.
  final List<HistoryEntry> entries;

  /// The documents whose `entry.json` could not be read, by identifier. They are reported and
  /// never dropped: an entry that vanished quietly would be a document the user could no longer
  /// account for.
  final List<UnreadableEntry> unreadable;

  /// Whether every stored entry could be read.
  bool get isComplete => unreadable.isEmpty;

  @override
  String toString() =>
      'HistoryListing(${entries.length} entries, '
      '${unreadable.length} unreadable)';
}

/// One document whose entry could not be read, and why.
final class UnreadableEntry {
  /// Binds a document identifier to the failure reading its entry produced.
  const UnreadableEntry({required this.docId, required this.failure});

  /// The identifier of the document whose entry could not be read.
  final String docId;

  /// Why it could not be read: `unreadable` for a file that is not an entry this app wrote,
  /// `ioFailed` for a file system that refused to hand it over.
  final HistoryStoreFailure failure;

  @override
  String toString() => 'UnreadableEntry($docId, ${failure.code.name})';
}

/// Where a document's history entry is kept (design §5.1).
abstract interface class HistoryStore {
  /// Stores [entry] as the first entry of its document.
  ///
  /// Refuses with [HistoryStoreFailureCode.alreadyExists] when the document already has an
  /// entry: a create that overwrote one would replace the history of a document that exists.
  Future<void> create(HistoryEntry entry);

  /// The entry of [docId].
  ///
  /// Throws a [HistoryStoreFailure] with [HistoryStoreFailureCode.notFound] when there is none,
  /// [HistoryStoreFailureCode.unreadable] when the stored file is not an entry this app wrote,
  /// and [HistoryStoreFailureCode.ioFailed] when the file cannot be read.
  Future<HistoryEntry> get(String docId);

  /// Replaces the stored entry of [docId] with [entry].
  ///
  /// Refuses with [HistoryStoreFailureCode.staleRevision] — and writes nothing — when [entry] is
  /// not newer than what is stored. The revision is what stops a screen that has been open since
  /// before a change from writing its older state over the newer one.
  Future<void> update(String docId, HistoryEntry entry);

  /// Every entry, newest first, and the documents whose entry could not be read.
  ///
  /// Never throws because one entry is bad: a corrupt `entry.json` is reported as a failure *for
  /// that entry* and the rest of the history is returned (design §5.1).
  Future<HistoryListing> list();

  /// Removes the stored document file of [docId], leaving `entry.json` and the thumbnail.
  ///
  /// Refuses with [HistoryStoreFailureCode.originalRetained] unless the entry is `sent`
  /// (FR-HIS-004): the document is in Ninox by then, and until then it is the only copy.
  Future<void> deleteOriginal(String docId);
}

/// The file-backed store: `<root>/<docId>/entry.json`, written through a temporary file.
///
/// The root is a [Directory] the caller resolves — on the device, the app documents directory
/// joined with `DocumentIntake.originalsFolder` — so a test writes into a directory it owns and
/// no test needs a device (design §1).
final class FileHistoryStore implements HistoryStore {
  /// Builds the store over the folder the document folders live in.
  const FileHistoryStore(this.root);

  /// The folder that holds one folder per document.
  final Directory root;

  /// The one file of a document's folder that this store owns.
  static const String entryFileName = 'entry.json';

  /// The file a write goes through before it is renamed over [entryFileName].
  static const String temporaryFileName = 'entry.json.tmp';

  /// The name `DocumentIntake` gave the stored document (design §3), which retention removes.
  static const String originalFilePrefix = 'original.';

  @override
  Future<void> create(HistoryEntry entry) async {
    try {
      if (await _entryFile(entry.docId).exists()) {
        throw HistoryStoreFailure(
          HistoryStoreFailureCode.alreadyExists,
          docId: entry.docId,
        );
      }
      await _folder(entry.docId).create(recursive: true);
      await _write(entry);
    } on IOException catch (error) {
      throw _ioFailure(entry.docId, error);
    }
  }

  @override
  Future<HistoryEntry> get(String docId) async {
    final File file = _entryFile(docId);
    final String text;
    try {
      if (!await file.exists()) {
        throw HistoryStoreFailure(
          HistoryStoreFailureCode.notFound,
          docId: docId,
        );
      }
      text = await file.readAsString();
    } on HistoryStoreFailure {
      rethrow;
    } on IOException catch (error) {
      throw _ioFailure(docId, error);
    }
    return _decode(text, docId);
  }

  @override
  Future<void> update(String docId, HistoryEntry entry) async {
    if (entry.docId != docId) {
      throw ArgumentError.value(
        entry.docId,
        'entry',
        'is not the entry of `$docId`',
      );
    }
    // The stored entry is read first, and its revision is the one the offered
    // entry has to beat: a write from a copy that has been overtaken refuses
    // instead of replacing a newer state.
    final HistoryEntry stored = await get(docId);
    if (entry.revision <= stored.revision) {
      throw HistoryStoreFailure(
        HistoryStoreFailureCode.staleRevision,
        docId: docId,
        detail: 'stored revision ${stored.revision}, offered ${entry.revision}',
      );
    }
    try {
      await _write(entry);
    } on IOException catch (error) {
      throw _ioFailure(docId, error);
    }
  }

  @override
  Future<HistoryListing> list() async {
    if (!await root.exists()) {
      // A device that has captured nothing: no folder, no entry, no failure.
      return const HistoryListing(
        entries: <HistoryEntry>[],
        unreadable: <UnreadableEntry>[],
      );
    }

    final List<FileSystemEntity> children;
    try {
      children = await root.list().toList();
    } on IOException catch (error) {
      throw _ioFailure(null, error);
    }

    final List<HistoryEntry> entries = <HistoryEntry>[];
    final List<UnreadableEntry> unreadable = <UnreadableEntry>[];
    for (final FileSystemEntity child in children) {
      if (child is! Directory) {
        continue;
      }
      final String docId = p.basename(child.path);
      try {
        final File file = File(p.join(child.path, entryFileName));
        if (!await file.exists()) {
          // A document folder with no entry yet — the window between the intake
          // and the entry — is not a failure: there is no entry to be wrong.
          // The `.tmp` a crash left is not read here either, for the same
          // reason it is not read by `get`.
          continue;
        }
        final HistoryEntry entry = _decode(await file.readAsString(), docId);
        if (entry.docId != docId) {
          throw HistoryStoreFailure(
            HistoryStoreFailureCode.unreadable,
            docId: docId,
            detail: 'the folder and the entry name different documents',
          );
        }
        entries.add(entry);
      } on HistoryStoreFailure catch (failure) {
        unreadable.add(UnreadableEntry(docId: docId, failure: failure));
      } on IOException catch (error) {
        unreadable.add(
          UnreadableEntry(docId: docId, failure: _ioFailure(docId, error)),
        );
      }
    }

    entries.sort((HistoryEntry a, HistoryEntry b) {
      final int byTime = b.createdAt.compareTo(a.createdAt);
      return byTime != 0 ? byTime : a.docId.compareTo(b.docId);
    });
    unreadable.sort(
      (UnreadableEntry a, UnreadableEntry b) => a.docId.compareTo(b.docId),
    );

    return HistoryListing(
      entries: List<HistoryEntry>.unmodifiable(entries),
      unreadable: List<UnreadableEntry>.unmodifiable(unreadable),
    );
  }

  @override
  Future<void> deleteOriginal(String docId) async {
    final HistoryEntry entry = await get(docId);
    if (entry.state != DocumentState.sent) {
      throw HistoryStoreFailure(
        HistoryStoreFailureCode.originalRetained,
        docId: docId,
        detail: 'the entry is ${entry.state.name}',
      );
    }
    try {
      await for (final FileSystemEntity child in _folder(docId).list()) {
        final String name = p.basename(child.path);
        if (child is File && name.startsWith(originalFilePrefix)) {
          await child.delete();
        }
      }
    } on IOException catch (error) {
      throw _ioFailure(docId, error);
    }
  }

  /// The folder of one document, which `DocumentIntake` created and this store shares.
  Directory _folder(String docId) => Directory(p.join(root.path, docId));

  /// The document's entry, the only file this store reads and writes.
  File _entryFile(String docId) =>
      File(p.join(_folder(docId).path, entryFileName));

  /// The file a write goes through, and the one a crash may leave behind.
  File _temporaryFile(String docId) =>
      File(p.join(_folder(docId).path, temporaryFileName));

  /// Writes [entry] atomically: the temporary file, flushed, renamed over the entry.
  Future<void> _write(HistoryEntry entry) async {
    final File temporary = _temporaryFile(entry.docId);
    if (await temporary.exists()) {
      // A `.tmp` left by a crash is removed by the next write (design §5.1):
      // what it holds is half of an attempt that never became the entry.
      await temporary.delete();
    }
    // Flushed before the rename: renaming a file whose bytes are not on the
    // device would leave the entry's name pointing at content nothing wrote.
    await temporary.writeAsString(jsonEncode(entry.toJson()), flush: true);
    await temporary.rename(_entryFile(entry.docId).path);
  }

  /// [text] as an entry, or one entry's failure.
  HistoryEntry _decode(String text, String docId) {
    try {
      return HistoryEntry.fromJson(jsonDecode(text));
    } on FormatException catch (error) {
      // Neither `jsonDecode` nor `HistoryEntry.fromJson` reports document
      // content in its message: a field name, a state name, a type.
      throw HistoryStoreFailure(
        HistoryStoreFailureCode.unreadable,
        docId: docId,
        detail: error.message,
      );
    }
  }

  /// The failure a file system error becomes, with the error's class and never its message —
  /// a message could carry a path, and this is not the place for one.
  HistoryStoreFailure _ioFailure(String? docId, Object error) =>
      HistoryStoreFailure(
        HistoryStoreFailureCode.ioFailed,
        docId: docId,
        detail: '${error.runtimeType}',
      );

  @override
  String toString() => 'FileHistoryStore(${root.path})';
}
