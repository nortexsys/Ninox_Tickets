/// The local history store: one file per document, atomic writes, strict reads and retention
/// (FR-HIS-001, FR-HIS-002, FR-HIS-004; design §5.1, §5.5).
///
/// **Real files in a directory the test owns**, so the round trip is the one the device
/// performs: the store is handed a `Directory` and no test here needs a device.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:paperdrop/history/document_machine.dart';
import 'package:paperdrop/history/history_entry.dart';
import 'package:paperdrop/history/history_store.dart';
import 'package:paperdrop_core/paperdrop_core.dart';
import 'package:path/path.dart' as p;

import 'history_fixtures.dart';

void main() {
  late Directory root;
  late FileHistoryStore store;

  setUp(() {
    root = Directory.systemTemp.createTempSync('paperdrop-history-test');
    store = FileHistoryStore(root);
  });

  tearDown(() {
    if (root.existsSync()) {
      root.deleteSync(recursive: true);
    }
  });

  /// The document's folder, the one `DocumentIntake` creates and this store shares.
  Directory folderOf(String docId) => Directory(p.join(root.path, docId));

  /// The entry, where design §5.1 puts it.
  File entryFileOf(String docId) =>
      File(p.join(folderOf(docId).path, FileHistoryStore.entryFileName));

  /// The temporary file a write goes through.
  File temporaryFileOf(String docId) =>
      File(p.join(folderOf(docId).path, FileHistoryStore.temporaryFileName));

  /// A stored document, as `DocumentIntake` leaves it (design §3).
  File originalOf(String docId) => File(
    p.join(folderOf(docId).path, '${FileHistoryStore.originalFilePrefix}pdf'),
  );

  test('an entry is stored as <root>/<docId>/entry.json', () async {
    final HistoryEntry entry = anEntry(docId: aDocId(7));

    await store.create(entry);

    expect(entryFileOf(entry.docId).existsSync(), isTrue);
    expect(
      p.relative(entryFileOf(entry.docId).path, from: root.path),
      p.join(entry.docId, FileHistoryStore.entryFileName),
    );
    expect(await store.get(entry.docId), entry);
    // Nothing of the document's own folder was touched: the stored original is
    // the intake's file, and this store only adds its own.
    originalOf(entry.docId).writeAsBytesSync(<int>[1, 2, 3]);
    await store.update(
      entry.docId,
      transition(entry, DocumentState.extracting),
    );
    expect(originalOf(entry.docId).readAsBytesSync(), <int>[1, 2, 3]);
  });

  test('every state is readable from the store, with the values it carried', () async {
    // The design's "all eight stored values readable", and the round trip with
    // money and provenance through a real file rather than through toJson alone.
    for (final DocumentState state in DocumentState.values) {
      final String docId = aDocId(state.index + 1);
      final HistoryEntry entry = anEntry(
        docId: docId,
        state: state,
        confidence: ConfidenceState.amber,
        values: aCanonicalDocument(),
        thumbnailPath: 'thumbs/${state.name}.jpg',
      );

      await store.create(entry);

      final HistoryEntry read = await store.get(docId);
      expect(read.state, state);
      expect(read, entry);
      expect(read.values?.grossTotal, entry.values?.grossTotal);
      expect(
        utf8.decode(entryFileOf(docId).readAsBytesSync()),
        contains('{"minor":1999,"currency":"EUR"}'),
      );
      expect(
        entryFileOf(docId).readAsStringSync(),
        contains('"provenance":"read"'),
      );
    }
  });

  test(
    'list returns the entries newest first and skips what is not one',
    () async {
      final HistoryEntry older = anEntry(
        docId: aDocId(1),
        createdAt: DateTime.utc(2026, 10, 1),
      );
      final HistoryEntry newer = anEntry(
        docId: aDocId(2),
        createdAt: DateTime.utc(2026, 10, 9),
      );
      final HistoryEntry sameInstant = anEntry(
        docId: aDocId(3),
        createdAt: DateTime.utc(2026, 10, 9),
      );
      await store.create(older);
      await store.create(newer);
      await store.create(sameInstant);

      // A document folder with no entry yet — the window between the intake and
      // the entry — is not a failure and not an entry.
      folderOf(aDocId(4)).createSync(recursive: true);
      originalOf(aDocId(4)).writeAsBytesSync(<int>[4]);
      // Nor is a file where a folder belongs.
      File(p.join(root.path, 'notes.txt')).writeAsStringSync('nothing');

      final HistoryListing listing = await store.list();

      expect(listing.entries, <HistoryEntry>[newer, sameInstant, older]);
      expect(listing.unreadable, isEmpty);
      expect(listing.isComplete, isTrue);
    },
  );

  test('a device that has captured nothing has no entries', () async {
    final HistoryListing listing = await FileHistoryStore(
      Directory(p.join(root.path, 'not-created-yet')),
    ).list();

    expect(listing.entries, isEmpty);
    expect(listing.unreadable, isEmpty);
  });

  test('create refuses a second entry for one document', () async {
    final HistoryEntry entry = anEntry(docId: aDocId(5));
    await store.create(entry);

    final HistoryEntry other = anEntry(docId: aDocId(5), revision: 2);

    await expectLater(
      store.create(other),
      throwsA(
        isA<HistoryStoreFailure>().having(
          (HistoryStoreFailure failure) => failure.code,
          'code',
          HistoryStoreFailureCode.alreadyExists,
        ),
      ),
    );
    expect(await store.get(entry.docId), entry);
  });

  test('update writes a newer entry and refuses a stale revision', () async {
    final HistoryEntry created = anEntry(docId: aDocId(6));
    await store.create(created);

    final HistoryEntry extracting = transition(
      created,
      DocumentState.extracting,
    );
    await store.update(created.docId, extracting);
    expect(await store.get(created.docId), extracting);

    // A copy that has been overtaken: same revision as what is stored, and again
    // with an older one. Neither is written.
    final List<int> before = entryFileOf(created.docId).readAsBytesSync();
    for (final HistoryEntry stale in <HistoryEntry>[
      anEntry(
        docId: created.docId,
        revision: extracting.revision,
        state: DocumentState.pending,
      ),
      anEntry(docId: created.docId, state: DocumentState.pending),
    ]) {
      await expectLater(
        store.update(created.docId, stale),
        throwsA(
          isA<HistoryStoreFailure>().having(
            (HistoryStoreFailure failure) => failure.code,
            'code',
            HistoryStoreFailureCode.staleRevision,
          ),
        ),
      );
    }
    expect(entryFileOf(created.docId).readAsBytesSync(), before);
    expect(await store.get(created.docId), extracting);
  });

  test('update on a document with no entry is notFound, and a foreign document '
      'is a mistake', () async {
    await expectLater(
      store.update(aDocId(8), anEntry(docId: aDocId(8))),
      throwsA(
        isA<HistoryStoreFailure>().having(
          (HistoryStoreFailure failure) => failure.code,
          'code',
          HistoryStoreFailureCode.notFound,
        ),
      ),
    );
    await store.create(anEntry(docId: aDocId(9)));

    expect(
      () => store.update(aDocId(9), anEntry(docId: aDocId(10), revision: 2)),
      throwsArgumentError,
    );
  });

  test('a refused transition changes nothing on disk', () async {
    // Design §5.3: an illegal transition throws and changes nothing. The entry
    // is immutable and no store call happens, so the file is byte for byte what
    // it was.
    final HistoryEntry created = anEntry(docId: aDocId(11));
    await store.create(created);
    final List<int> before = entryFileOf(created.docId).readAsBytesSync();
    final DateTime written = entryFileOf(created.docId).lastModifiedSync();

    expect(() => transition(created, DocumentState.sent), throwsStateError);
    expect(
      () => transition(created, DocumentState.reviewing),
      throwsStateError,
    );

    expect(entryFileOf(created.docId).readAsBytesSync(), before);
    expect(entryFileOf(created.docId).lastModifiedSync(), written);
    expect(await store.get(created.docId), created);
  });

  test('a kill between the temporary write and the rename leaves the previous '
      'entry intact', () async {
    final HistoryEntry created = anEntry(docId: aDocId(12));
    await store.create(created);

    // What a crash between the flush and the rename leaves: a temporary file
    // holding the newer entry, and the entry itself untouched.
    final HistoryEntry newer = transition(created, DocumentState.extracting);
    temporaryFileOf(created.docId)
        .writeAsStringSync(jsonEncode(newer.toJson()), flush: true);

    expect(await store.get(created.docId), created);
    final HistoryListing listing = await store.list();
    expect(listing.entries, <HistoryEntry>[created]);
    expect(listing.unreadable, isEmpty);

    // The next write removes it, and what it wrote is the entry.
    await store.update(created.docId, newer);
    expect(temporaryFileOf(created.docId).existsSync(), isFalse);
    expect(await store.get(created.docId), newer);
  });

  test('a temporary file with no entry is not an entry', () async {
    // The document's folder exists with half an attempt in it and no entry: the
    // temporary file is ignored on read, and there is nothing to be wrong about.
    final String docId = aDocId(13);
    folderOf(docId).createSync(recursive: true);
    temporaryFileOf(docId)
        .writeAsStringSync(jsonEncode(anEntry(docId: docId).toJson()));

    final HistoryListing listing = await store.list();
    expect(listing.entries, isEmpty);
    expect(listing.unreadable, isEmpty);
    await expectLater(
      store.get(docId),
      throwsA(
        isA<HistoryStoreFailure>().having(
          (HistoryStoreFailure failure) => failure.code,
          'code',
          HistoryStoreFailureCode.notFound,
        ),
      ),
    );
  });

  test(
    'a corrupt entry is reported for that entry and does not break the list',
    () async {
      final HistoryEntry good = anEntry(docId: aDocId(14));
      final String corrupt = aDocId(15);
      final String foreign = aDocId(16);
      await store.create(good);
      folderOf(corrupt).createSync(recursive: true);
      entryFileOf(corrupt).writeAsStringSync('{"docId": ');
      // A folder that names one document while the entry inside names another: the
      // file was moved or written by something else, and neither is reported as the
      // entry of that document.
      folderOf(foreign).createSync(recursive: true);
      entryFileOf(foreign)
          .writeAsStringSync(jsonEncode(anEntry(docId: aDocId(17)).toJson()));

      final HistoryListing listing = await store.list();

      expect(listing.entries, <HistoryEntry>[good]);
      expect(
        listing.unreadable.map((UnreadableEntry entry) => entry.docId),
        <String>[corrupt, foreign],
      );
      expect(
        listing.unreadable
            .map((UnreadableEntry entry) => entry.failure.code)
            .toSet(),
        <HistoryStoreFailureCode>{HistoryStoreFailureCode.unreadable},
      );
      expect(listing.isComplete, isFalse);

      await expectLater(
        store.get(corrupt),
        throwsA(
          isA<HistoryStoreFailure>().having(
            (HistoryStoreFailure failure) => failure.code,
            'code',
            HistoryStoreFailureCode.unreadable,
          ),
        ),
      );
      // The good entry is still readable: one bad file is one bad entry.
      expect(await store.get(good.docId), good);
    },
  );

  test('[document-history/file-retention] a confirmed send releases the local '
      'file', () async {
    // GIVEN an entry in the sent state WHEN the local store is inspected THEN
    // the document file is gone AND the thumbnail remains.
    final String docId = aDocId(18);
    final HistoryEntry sent = anEntry(
      docId: docId,
      state: DocumentState.sent,
      thumbnailPath: p.join(folderOf(docId).path, 'thumbnail.jpg'),
    );
    await store.create(sent);
    originalOf(docId).writeAsBytesSync(<int>[1, 2, 3]);
    File(sent.thumbnailPath!).writeAsBytesSync(<int>[9]);

    await store.deleteOriginal(docId);

    expect(originalOf(docId).existsSync(), isFalse);
    expect(File(sent.thumbnailPath!).existsSync(), isTrue);
    expect(entryFileOf(docId).existsSync(), isTrue);
  });

  test(
    '[document-history/file-retention] an unresolved item keeps its file',
    () async {
      // GIVEN an entry in any unresolved state WHEN retention is evaluated THEN
      // its local file is still available: only a confirmed send releases it.
      for (final DocumentState state in DocumentState.values) {
        if (state == DocumentState.sent) {
          continue;
        }
        final String docId = aDocId(20 + state.index);
        await store.create(anEntry(docId: docId, state: state));
        originalOf(docId).writeAsBytesSync(<int>[1, 2, 3]);

        await expectLater(
          store.deleteOriginal(docId),
          throwsA(
            isA<HistoryStoreFailure>().having(
              (HistoryStoreFailure failure) => failure.code,
              'code',
              HistoryStoreFailureCode.originalRetained,
            ),
          ),
        );
        expect(
          originalOf(docId).existsSync(),
          isTrue,
          reason: '${state.name} keeps its file',
        );
      }
    },
  );

  test('[document-history/file-retention] retention follows the state, not a '
      'timer', () async {
    // GIVEN an entry that has been pending for a long time WHEN retention is
    // evaluated THEN its file is retained because the item is unresolved AND no
    // elapsed time alone has deleted it.
    final String docId = aDocId(40);
    await store.create(
      anEntry(docId: docId, createdAt: DateTime.utc(2019, 1, 1)),
    );
    originalOf(docId).writeAsBytesSync(<int>[1, 2, 3]);
    // The stored file is old too, so that nothing could be measuring how long
    // the document has waited: no clock is read anywhere in the store.
    originalOf(docId).setLastModifiedSync(DateTime.utc(2019, 1, 1));

    await store.get(docId);
    await store.list();
    await store.update(
      docId,
      transition(await store.get(docId), DocumentState.extracting),
    );

    expect(originalOf(docId).existsSync(), isTrue);
    await expectLater(
      store.deleteOriginal(docId),
      throwsA(isA<HistoryStoreFailure>()),
    );
    expect(originalOf(docId).existsSync(), isTrue);
  });

  test('[document-history/history-is-the-uncertainty-trace] history is not '
      'treated as disposable', () async {
    // GIVEN a completed send WHEN the entry is considered for removal THEN it is
    // retained, because it is the only record of how sure the app was: releasing
    // the document file leaves the entry and its values where they were.
    final String docId = aDocId(41);
    final HistoryEntry sent = anEntry(
      docId: docId,
      state: DocumentState.sent,
      values: aCanonicalDocument(),
      confidence: ConfidenceState.amber,
    );
    await store.create(sent);
    originalOf(docId).writeAsBytesSync(<int>[1, 2, 3]);

    await store.deleteOriginal(docId);

    final HistoryEntry read = await store.get(docId);
    expect(read, sent);
    expect(read.confidence, ConfidenceState.amber);
    expect(read.values?.grossTotal, sent.values?.grossTotal);
    expect(
      (await store.list()).entries.map((HistoryEntry entry) => entry.docId),
      <String>[docId],
    );
  });

  test(
    'releasing a file twice is not an error, and a missing entry is',
    () async {
      final String docId = aDocId(42);
      await store.create(anEntry(docId: docId, state: DocumentState.sent));
      originalOf(docId).writeAsBytesSync(<int>[1, 2, 3]);

      await store.deleteOriginal(docId);
      // The postcondition is what matters: the document file is gone.
      await store.deleteOriginal(docId);
      expect(originalOf(docId).existsSync(), isFalse);

      final String unknown = aDocId(43);
      await expectLater(
        store.deleteOriginal(unknown),
        throwsA(
          isA<HistoryStoreFailure>().having(
            (HistoryStoreFailure failure) => failure.code,
            'code',
            HistoryStoreFailureCode.notFound,
          ),
        ),
      );
    },
  );
}
