/// Retention: what happens to a document's file once its send is confirmed, and what does not happen
/// while it is unresolved (`document-history/file-retention`, FR-HIS-004; design §1 of
/// `implement-history-retry-duplicates`).
///
/// **Real files in a folder the test owns.** The policy is a decision over a state; the file it
/// releases is the store's, so the round trip is the one the device performs and no test needs one.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:paperdrop/history/history_entry.dart';
import 'package:paperdrop/history/history_store.dart';
import 'package:paperdrop/history/retention_policy.dart';
import 'package:path/path.dart' as p;

import 'history_fixtures.dart';

void main() {
  late Directory root;
  late FileHistoryStore store;
  late RetentionPolicy policy;

  setUp(() {
    root = Directory.systemTemp.createTempSync('paperdrop-retention-test');
    store = FileHistoryStore(root);
    policy = RetentionPolicy(store);
  });

  tearDown(() {
    if (root.existsSync()) {
      root.deleteSync(recursive: true);
    }
  });

  /// The document's folder, the one `DocumentIntake` creates and the store shares.
  Directory folderOf(String docId) => Directory(p.join(root.path, docId));

  /// The stored document file, as `DocumentIntake` leaves it (design §3 of the store's change).
  File originalOf(String docId) => File(
    p.join(folderOf(docId).path, '${FileHistoryStore.originalFilePrefix}pdf'),
  );

  /// The thumbnail a history detail shows once the document itself is in Ninox.
  File thumbnailOf(String docId) =>
      File(p.join(folderOf(docId).path, 'thumbnail.png'));

  /// Stores [entry] with a document file and a thumbnail beside it.
  Future<void> storeWithFiles(HistoryEntry entry) async {
    await store.create(entry);
    originalOf(entry.docId).writeAsBytesSync(<int>[1, 2, 3]);
    thumbnailOf(entry.docId).writeAsBytesSync(<int>[4, 5, 6]);
  }

  test('[document-history/file-retention] a confirmed send releases the local file', () async {
    final HistoryEntry sent = anEntry(
      docId: aDocId(1),
      state: DocumentState.sent,
    );
    await storeWithFiles(sent);

    expect(await policy.apply(sent), RetentionOutcome.released);

    expect(
      originalOf(sent.docId).existsSync(),
      isFalse,
      reason: 'the document is in Ninox by then',
    );
    expect(
      thumbnailOf(sent.docId).existsSync(),
      isTrue,
      reason: 'the thumbnail remains',
    );
    expect(
      await store.get(sent.docId),
      sent,
      reason: 'the entry itself stays in history',
    );
  });

  test('[document-history/file-retention] an unresolved item keeps its file, in every '
      'state that is not `sent`', () async {
    // `failed` is the spec's scenario; the same is true of every other state, because until the
    // send is confirmed the file is the only copy.
    for (final DocumentState state in DocumentState.values) {
      if (state == DocumentState.sent) {
        continue;
      }
      final HistoryEntry entry = anEntry(
        docId: aDocId(state.index + 1),
        state: state,
      );
      await storeWithFiles(entry);

      expect(
        await policy.apply(entry),
        RetentionOutcome.retained,
        reason: '${state.name} is not a confirmed send',
      );
      expect(
        originalOf(entry.docId).existsSync(),
        isTrue,
        reason: '${state.name} keeps the only copy of the document',
      );
    }
  });

  test('[document-history/file-retention] retention follows the state, not a timer', () async {
    // Pending since long before this change: nothing has expired it, and evaluating retention does
    // not.
    final HistoryEntry old = anEntry(
      docId: aDocId(11),
      state: DocumentState.reviewing,
      createdAt: DateTime.utc(2019, 1, 2, 3),
    );
    await storeWithFiles(old);

    expect(await policy.apply(old), RetentionOutcome.retained);
    expect(
      originalOf(old.docId).existsSync(),
      isTrue,
      reason: 'an unresolved item keeps its file, however old it is',
    );

    // And the mirror of it: an entry confirmed a moment ago is released, because nothing in the
    // policy waits for time to pass either.
    final HistoryEntry fresh = anEntry(
      docId: aDocId(12),
      state: DocumentState.sent,
      createdAt: DateTime.now().toUtc(),
    );
    await storeWithFiles(fresh);

    expect(await policy.apply(fresh), RetentionOutcome.released);
    expect(originalOf(fresh.docId).existsSync(), isFalse);
  });

  test('a crash between `sent` and the delete is repaired when the entry is loaded '
      '(design §1)', () async {
    final HistoryEntry sent = anEntry(
      docId: aDocId(21),
      state: DocumentState.sent,
    );
    await storeWithFiles(sent);

    // The entry was written `sent` and the process died before the file was released: that is
    // exactly the state the load path repairs.
    expect(await policy.applyToStored(sent.docId), RetentionOutcome.released);
    expect(originalOf(sent.docId).existsSync(), isFalse);
  });

  test('applying retention twice is not an error, and the second call is a release '
      'over a file that is already gone', () async {
    final HistoryEntry sent = anEntry(
      docId: aDocId(31),
      state: DocumentState.sent,
    );
    await storeWithFiles(sent);

    expect(await policy.apply(sent), RetentionOutcome.released);
    expect(await policy.apply(sent), RetentionOutcome.released);
  });

  test('an entry that is no longer `sent` keeps its file, because the document is not '
      'in Ninox after all', () async {
    // The entry a caller holds says `sent`, the stored one says `failed`: the store re-reads and
    // refuses, and the file must stay — that refusal is a retention, not a failure.
    final HistoryEntry failed = anEntry(
      docId: aDocId(41),
      state: DocumentState.failed,
    );
    await storeWithFiles(failed);
    final HistoryEntry stale = anEntry(
      docId: failed.docId,
      state: DocumentState.sent,
      revision: failed.revision + 1,
    );

    expect(await policy.apply(stale), RetentionOutcome.retained);
    expect(originalOf(failed.docId).existsSync(), isTrue);
  });

  test(
    'a document with no entry is a store failure, not a retention',
    () async {
      expect(
        () => policy.applyToStored(aDocId(51)),
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
