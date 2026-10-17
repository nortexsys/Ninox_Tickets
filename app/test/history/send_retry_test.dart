/// Retry and correction: which pipeline call a state earns, what survives a send, and the update
/// that never becomes a second record (`document-history/correction-and-re-send` FR-HIS-003,
/// `document-history/document-states` FR-HIS-002, `document-history/history-is-the-uncertainty-trace`
/// FR-HIS-005; design §3 of `implement-history-retry-duplicates`).
///
/// **Nothing is sent anywhere.** The sender is a fake that records which call it was asked for, and
/// the port records an update and refuses every other call with an `UnimplementedError`: a create
/// reached by a correction would make a test fail rather than write to a database.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ninox_client/ninox_client.dart';
import 'package:paperdrop/history/history_entry.dart';
import 'package:paperdrop/history/history_store.dart';
import 'package:paperdrop/history/retention_policy.dart';
import 'package:paperdrop/history/send_retry.dart';
import 'package:paperdrop_core/paperdrop_core.dart';
import 'package:path/path.dart' as p;

import 'history_fixtures.dart';
import 'send_fakes.dart';

void main() {
  late Directory root;
  late FileHistoryStore store;
  late FakeSender sender;
  late RecordingPort port;

  setUp(() {
    root = Directory.systemTemp.createTempSync('paperdrop-retry-test');
    store = FileHistoryStore(root);
    sender = FakeSender();
    port = RecordingPort();
  });

  tearDown(() {
    if (root.existsSync()) {
      root.deleteSync(recursive: true);
    }
  });

  /// The service under test, over the store, a sender, a port and the test's request builder.
  RetryService serviceWith({FakeSender? withSender}) => RetryService(
    store: store,
    sender: withSender ?? sender,
    port: port,
    requestFor: requestOf,
  );

  /// The stored document file, as `DocumentIntake` leaves it.
  File originalOf(String docId) => File(
    p.join(root.path, docId, '${FileHistoryStore.originalFilePrefix}pdf'),
  );

  group('the state decides the call (design §3)', () {
    test('a `queued` entry is sent: nothing was ever created', () async {
      final HistoryEntry queued = anEntry(
        docId: aDocId(1),
        state: DocumentState.queued,
      );
      await store.create(queued);
      originalOf(queued.docId).writeAsBytesSync(<int>[1, 2, 3]);

      final RetryResult result = await serviceWith().retry(queued.docId);

      expect(sender.calls, <String>['send:${queued.docId}']);
      expect(result.outcome, isA<Sent>());
      expect(result.entry.state, DocumentState.sent);
      expect(result.entry.ninoxRecordId, const RecordId('record-1'));
      expect(await store.get(queued.docId), result.entry);
      expect(
        originalOf(queued.docId).existsSync(),
        isFalse,
        reason: 'a confirmed send releases the local file (`file-retention`)',
      );
    });

    test('a `failed` entry with no record id creates through `send`', () async {
      final HistoryEntry failed = anEntry(
        docId: aDocId(2),
        state: DocumentState.failed,
        failureReason: 'server',
      );
      await store.create(failed);

      final RetryResult result = await serviceWith().retry(failed.docId);

      expect(sender.calls, <String>['send:${failed.docId}']);
      expect(result.entry.state, DocumentState.sent);
      expect(
        result.entry.revision,
        failed.revision + 3,
        reason: 'failed -> reviewing -> sending, and then the send itself',
      );
      expect(
        result.entry.failureReason,
        isNull,
        reason: 'a reason belongs to the attempt that produced it',
      );
    });

    test(
      '[ninox-send/the-retry-matrix] a failed attachment retries alone',
      () async {
        final HistoryEntry failed = anEntry(
          docId: aDocId(3),
          state: DocumentState.failed,
          ninoxRecordId: const RecordId('record-9'),
          failureReason: 'attachment_incomplete',
        );
        await store.create(failed);

        await serviceWith().retry(failed.docId);

        expect(sender.calls, <String>['resume:${failed.docId}:record-9']);
        expect(
          port.calls,
          isEmpty,
          reason: 'no update and no create was needed',
        );
      },
    );

    test('[capture-intake/capture-without-connectivity] the offline save is queued, '
        'not lost', () async {
      final HistoryEntry queued = anEntry(
        docId: aDocId(4),
        state: DocumentState.queued,
      );
      await store.create(queued);

      expect((await store.get(queued.docId)).state, DocumentState.queued);

      final RetryResult result = await serviceWith().retry(queued.docId);

      expect(result.entry.state, DocumentState.sent);
      expect(sender.calls, hasLength(1));
    });

    test(
      'an `uncertain` entry with a record id resumes, and is never re-created',
      () async {
        final HistoryEntry uncertain = anEntry(
          docId: aDocId(5),
          state: DocumentState.uncertain,
          ninoxRecordId: const RecordId('record-5'),
        );
        await store.create(uncertain);

        final RetryResult result = await serviceWith().retry(uncertain.docId);

        expect(sender.calls, <String>['resume:${uncertain.docId}:record-5']);
        expect(result.entry.state, DocumentState.sent);
      },
    );

    test('[document-history/document-states] a lost create response is uncertain, not '
        'failed, and is never blindly retried', () async {
      final HistoryEntry uncertain = anEntry(
        docId: aDocId(6),
        state: DocumentState.uncertain,
      );
      await store.create(uncertain);

      await expectLater(
        () => serviceWith().retry(uncertain.docId),
        throwsA(
          isA<RetryRefusal>().having(
            (RetryRefusal refusal) => refusal.code,
            'code',
            RetryRefusalCode.uncertainNeedsDecision,
          ),
        ),
      );
      expect(sender.calls, isEmpty);
      expect(
        (await store.get(uncertain.docId)).state,
        DocumentState.uncertain,
        reason: 'a refusal changes nothing on disk',
      );
    });

    test(
      'every other state is refused as not retryable, and nothing is called',
      () async {
        for (final DocumentState state in <DocumentState>[
          DocumentState.pending,
          DocumentState.extracting,
          DocumentState.reviewing,
          DocumentState.sending,
          DocumentState.sent,
        ]) {
          final HistoryEntry entry = anEntry(
            docId: aDocId(10 + state.index),
            state: state,
          );
          await store.create(entry);

          await expectLater(
            () => serviceWith().retry(entry.docId),
            throwsA(
              isA<RetryRefusal>().having(
                (RetryRefusal refusal) => refusal.code,
                'code',
                RetryRefusalCode.notRetryable,
              ),
            ),
            reason: '${state.name} has no retry',
          );
          expect((await store.get(entry.docId)).revision, entry.revision);
        }
        expect(sender.calls, isEmpty);
      },
    );

    test(
      'a document with no entry is a store failure, not a refusal',
      () async {
        await expectLater(
          () => serviceWith().retry(aDocId(20)),
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
  });

  group('the outcome decides the state and the reason', () {
    Future<HistoryEntry> sendAndStore(
      SendOutcome outcome, {
      String? documentHash,
      String? docId,
    }) async {
      final HistoryEntry queued = anEntry(
        docId: docId ?? aDocId(21),
        state: DocumentState.queued,
        documentHash: documentHash,
      );
      await store.create(queued);
      originalOf(queued.docId).writeAsBytesSync(<int>[1, 2, 3]);
      final RetryService service = serviceWith(
        withSender: FakeSender(
          answer: (SendRequest request, RecordId? recordId) => outcome,
        ),
      );
      final RetryResult result = await service.retry(queued.docId);
      expect(result.outcome, same(outcome));
      return result.entry;
    }

    test(
      'a queued outcome leaves the entry `queued` and keeps its file',
      () async {
        final HistoryEntry entry = await sendAndStore(const Queued());

        expect(entry.state, DocumentState.queued);
        expect(entry.failureReason, isNull, reason: 'waiting is not failing');
        expect(originalOf(entry.docId).existsSync(), isTrue);
      },
    );

    test(
      'an uncertain outcome leaves the entry `uncertain` and says nothing else',
      () async {
        final HistoryEntry entry = await sendAndStore(
          const Uncertain(candidates: <NinoxRecord>[]),
        );

        expect(entry.state, DocumentState.uncertain);
        expect(entry.failureReason, isNull);
        expect(originalOf(entry.docId).existsSync(), isTrue);
      },
    );

    test('an incomplete outcome is `failed` with its record id and `attachment_incomplete`: '
        'never done, and resumable', () async {
      final HistoryEntry entry = await sendAndStore(
        const Incomplete(
          recordId: RecordId('record-7'),
          reason:
              'the document could not be attached within the bounded attempts',
        ),
      );

      expect(entry.state, DocumentState.failed);
      expect(
        entry.ninoxRecordId,
        const RecordId('record-7'),
        reason: 'kept, so the next retry resumes instead of creating',
      );
      expect(entry.failureReason, 'attachment_incomplete');
      expect(originalOf(entry.docId).existsSync(), isTrue);

      // And that is exactly what the next retry does: it resumes the attachment against the record
      // that already exists, and does not create a second one.
      await serviceWith().retry(entry.docId);
      expect(sender.calls, <String>['resume:${entry.docId}:record-7']);
    });

    test('a terminal failure is `failed` with the pipeline\'s own kind as its code', () async {
      final Map<SendFailureKind, String> expected = <SendFailureKind, String>{
        SendFailureKind.auth: 'auth',
        SendFailureKind.destinationGone: 'destination_gone',
        SendFailureKind.mapping: 'mapping',
        SendFailureKind.server: 'server',
      };
      for (final MapEntry<SendFailureKind, String> entry in expected.entries) {
        final HistoryEntry failed = await sendAndStore(
          Failed(kind: entry.key, failure: const Unauthorized()),
          documentHash: aDocumentHash('failure-${entry.key.name}'),
          docId: aDocId(30 + entry.key.index),
        );

        expect(failed.state, DocumentState.failed);
        expect(failed.failureReason, entry.value);
        expect(failed.ninoxRecordId, isNull);
        expect(originalOf(failed.docId).existsSync(), isTrue);
      }
    });
  });

  test('[document-history/history-is-the-uncertainty-trace] confidence survives the send '
      'with nothing mapped', () async {
    // The destination of the fixture is a table with no field mapped at all, and the entry knows
    // its values and its confidence. What the send does must not touch either.
    final CanonicalDocument values = aCanonicalDocument(seed: 'trace');
    final HistoryEntry queued = anEntry(
      docId: aDocId(31),
      state: DocumentState.queued,
      values: values,
      confidence: ConfidenceState.amber,
    );
    await store.create(queued);

    final RetryResult result = await serviceWith().retry(queued.docId);

    expect(result.entry.state, DocumentState.sent);
    expect(result.entry.values, values);
    expect(result.entry.confidence, ConfidenceState.amber);
    expect(
      result.entry.values!.docDate,
      isA<Present<CalendarDate>>(),
      reason: 'the provenance of every value is still there',
    );

    final HistoryEntry stored = await store.get(queued.docId);
    expect(stored.values, values);
    expect(stored.confidence, ConfidenceState.amber);
    expect(stored, result.entry);
  });

  test('[document-history/history-is-the-uncertainty-trace] history is not treated as '
      'disposable', () async {
    // A completed send releases the document file (`file-retention`) and keeps the entry, because
    // the entry is the only record of how sure the app was.
    final HistoryEntry queued = anEntry(
      docId: aDocId(32),
      state: DocumentState.queued,
      values: aCanonicalDocument(seed: 'disposable'),
      confidence: ConfidenceState.amber,
    );
    await store.create(queued);
    originalOf(queued.docId).writeAsBytesSync(<int>[1, 2, 3]);

    final RetryResult result = await serviceWith().retry(queued.docId);

    expect(await store.get(queued.docId), result.entry);
    expect((await store.list()).entries, hasLength(1));
    expect(originalOf(queued.docId).existsSync(), isFalse);
  });

  test('the request is built for the entry that is being sent, and the payload is the '
      'caller\'s own', () async {
    final HistoryEntry queued = anEntry(
      docId: aDocId(41),
      state: DocumentState.queued,
    );
    await store.create(queued);

    await serviceWith().retry(queued.docId);

    expect(sender.requests.single.docId, queued.docId);
    expect(sender.requests.single.ref, queued.destination);
    expect(sender.requests.single.fieldsByName, <String, Object?>{
      'Total': 1999,
    });
  });

  group('correction', () {
    test('[document-history/correction-and-re-send] a correction updates rather than '
        'duplicates', () async {
      final HistoryEntry sent = anEntry(
        docId: aDocId(51),
        state: DocumentState.sent,
        ninoxRecordId: const RecordId('record-51'),
      );
      await store.create(sent);

      await serviceWith().correct(sent.docId, <String, Object?>{'Total': 2599});

      expect(port.calls, <String>['updateRecord']);
      expect(port.updates.single.recordId, const RecordId('record-51'));
      expect(port.updates.single.ref, sent.destination);
      expect(port.updates.single.fields, <String, Object?>{'Total': 2599});
    });

    test('[document-history/correction-and-re-send] the correction reaches the record it '
        'came from', () async {
      final HistoryEntry first = anEntry(
        docId: aDocId(52),
        state: DocumentState.sent,
        ninoxRecordId: const RecordId('record-52'),
      );
      final HistoryEntry second = anEntry(
        docId: aDocId(53),
        state: DocumentState.sent,
        ninoxRecordId: const RecordId('record-53'),
      );
      await store.create(first);
      await store.create(second);

      await serviceWith().correct(first.docId, <String, Object?>{'Total': 1});

      expect(port.updates, hasLength(1));
      expect(port.updates.single.recordId, const RecordId('record-52'));
    });

    test('a correction without a record identifier is refused and nothing is sent: an '
        'update, never a create', () async {
      final HistoryEntry failed = anEntry(
        docId: aDocId(54),
        state: DocumentState.failed,
      );
      await store.create(failed);

      await expectLater(
        () =>
            serviceWith().correct(failed.docId, <String, Object?>{'Total': 1}),
        throwsA(
          isA<RetryRefusal>().having(
            (RetryRefusal refusal) => refusal.code,
            'code',
            RetryRefusalCode.noRecordId,
          ),
        ),
      );
      expect(port.calls, isEmpty);
    });

    test(
      'an update the port refuses travels to the caller, unchanged',
      () async {
        final HistoryEntry sent = anEntry(
          docId: aDocId(55),
          state: DocumentState.sent,
          ninoxRecordId: const RecordId('record-55'),
        );
        await store.create(sent);
        port.failure = const ServerError(500);

        await expectLater(
          () =>
              serviceWith().correct(sent.docId, <String, Object?>{'Total': 1}),
          throwsA(isA<ServerError>()),
        );
      },
    );
  });

  test(
    'the service defaults to the retention policy of its own store',
    () async {
      final HistoryEntry sent = anEntry(
        docId: aDocId(61),
        state: DocumentState.sent,
      );
      await store.create(sent);
      final RetryService service = serviceWith();
      expect(service.retention.store, same(store));
      expect(await service.retention.apply(sent), RetentionOutcome.released);
    },
  );
}
