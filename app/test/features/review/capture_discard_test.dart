import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:paperdrop/features/review/capture_discard.dart';
import 'package:paperdrop/history/history_entry.dart';
import 'package:paperdrop/history/history_store.dart';
import 'package:path/path.dart' as p;

import '../../history/history_fixtures.dart';
import 'review_fixtures.dart';

/// Discarding a document: the whole folder, and nothing above it (FR-REV-011, design §5).
///
/// The folder is what `FileHistoryStore` and `DocumentIntake` share — `entry.json`, the stored
/// original and the thumbnail — so deleting it is what leaves *no history entry* behind: `list()`
/// reports the documents whose folders it finds.
void main() {
  late Directory root;
  late FileHistoryStore store;
  late FileCaptureDiscard discard;

  setUp(() {
    root = aTempRoot();
    store = FileHistoryStore(root);
    discard = FileCaptureDiscard(root);
  });

  test(
    'the discard deletes the entry, the original and the thumbnail',
    () async {
      final HistoryEntry entry = aReviewingEntry();
      await store.create(entry);
      File(p.join(root.path, entry.docId, 'original.pdf'))
          .writeAsStringSync('%PDF-1.7');
      File(p.join(root.path, entry.docId, 'thumbnail.png'))
          .writeAsStringSync('x');
      expect((await store.list()).entries, hasLength(1));

      await discard.deleteCapture(entry.docId);

      expect(Directory(p.join(root.path, entry.docId)).existsSync(), isFalse);
      expect((await store.list()).entries, isEmpty);
    },
  );

  test('the other documents of the history are left alone', () async {
    final HistoryEntry kept = aReviewingEntry(docId: aDocId(1));
    final HistoryEntry discarded = aReviewingEntry(docId: aDocId(2));
    await store.create(kept);
    await store.create(discarded);

    await discard.deleteCapture(discarded.docId);

    expect((await store.list()).entries, <HistoryEntry>[kept]);
  });

  test('a capture that is already gone is not a failure', () async {
    await discard.deleteCapture(aDocId(3));

    expect(Directory(p.join(root.path, aDocId(3))).existsSync(), isFalse);
  });

  test('an identifier that is not one is refused', () async {
    for (final String docId in <String>[
      '..',
      '../escape',
      'ABCDEF',
      '',
      '${aDocId()}/..',
    ]) {
      await expectLater(
        discard.deleteCapture(docId),
        throwsA(isA<ArgumentError>()),
        reason: docId,
      );
    }
  });
}
