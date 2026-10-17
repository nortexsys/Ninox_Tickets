/// The foreground queue: the `queued` entries, oldest first, one at a time, stopping at an uncertain
/// entry or at connectivity loss (`capture-intake/capture-without-connectivity` FR-CAP-009, the
/// queued half of `document-history/document-states`; design §4 of
/// `implement-history-retry-duplicates`).
///
/// The connectivity port is a fake a test drives, so a tunnel is one line: nothing here waits, and
/// nothing here reaches a device.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ninox_client/ninox_client.dart';
import 'package:paperdrop/history/history_entry.dart';
import 'package:paperdrop/history/history_store.dart';
import 'package:paperdrop/history/send_queue.dart';
import 'package:paperdrop/history/send_retry.dart';
import 'package:path/path.dart' as p;

import 'history_fixtures.dart';
import 'send_fakes.dart';

void main() {
  late Directory root;
  late FileHistoryStore store;
  late FakeConnectivity connectivity;
  late RecordingPort port;

  setUp(() {
    root = Directory.systemTemp.createTempSync('paperdrop-queue-test');
    store = FileHistoryStore(root);
    connectivity = FakeConnectivity();
    port = RecordingPort();
  });

  tearDown(() async {
    await connectivity.close();
    if (root.existsSync()) {
      root.deleteSync(recursive: true);
    }
  });

  /// The queue under test, over a sender that answers as the fake is scripted.
  SendQueue queueWith(FakeSender sender) => SendQueue(
    store: store,
    retry: RetryService(
      store: store,
      sender: sender,
      port: port,
      requestFor: requestOf,
    ),
    connectivity: connectivity,
  );

  /// A stored `queued` entry, with the document file the intake would have left.
  Future<HistoryEntry> aQueuedEntry({
    required int seed,
    required DateTime createdAt,
    DocumentState state = DocumentState.queued,
  }) async {
    final HistoryEntry entry = anEntry(
      docId: aDocId(seed),
      state: state,
      createdAt: createdAt,
    );
    await store.create(entry);
    File(
      p.join(
        root.path,
        entry.docId,
        '${FileHistoryStore.originalFilePrefix}pdf',
      ),
    ).writeAsBytesSync(<int>[1, 2, 3]);
    return entry;
  }

  test('the queue is drained oldest first, one entry at a time', () async {
    final HistoryEntry newest = await aQueuedEntry(
      seed: 3,
      createdAt: DateTime.utc(2026, 10, 3),
    );
    final HistoryEntry oldest = await aQueuedEntry(
      seed: 1,
      createdAt: DateTime.utc(2026, 10, 1),
    );
    final HistoryEntry middle = await aQueuedEntry(
      seed: 2,
      createdAt: DateTime.utc(2026, 10, 2),
    );
    final FakeSender sender = FakeSender();
    final SendQueue queue = queueWith(sender);

    final QueueDrain? drain = await queue.drain();

    expect(drain, isNotNull);
    expect(sender.calls, <String>[
      'send:${oldest.docId}',
      'send:${middle.docId}',
      'send:${newest.docId}',
    ]);
    expect(drain!.stop, DrainStop.drained);
    expect(
      drain.results.map((RetryResult result) => result.entry.docId),
      <String>[oldest.docId, middle.docId, newest.docId],
    );
    for (final HistoryEntry entry in <HistoryEntry>[oldest, middle, newest]) {
      expect((await store.get(entry.docId)).state, DocumentState.sent);
    }
  });

  test('two entries of one instant keep the history\'s own order', () async {
    final DateTime instant = DateTime.utc(2026, 10, 5);
    final HistoryEntry low = await aQueuedEntry(seed: 1, createdAt: instant);
    final HistoryEntry high = await aQueuedEntry(seed: 2, createdAt: instant);
    final FakeSender sender = FakeSender();

    await queueWith(sender).drain();

    expect(sender.calls, <String>['send:${low.docId}', 'send:${high.docId}']);
  });

  test('only `queued` entries are attempted', () async {
    final HistoryEntry queued = await aQueuedEntry(
      seed: 11,
      createdAt: DateTime.utc(2026, 10, 1),
    );
    await aQueuedEntry(
      seed: 12,
      createdAt: DateTime.utc(2026, 10, 1),
      state: DocumentState.failed,
    );
    await aQueuedEntry(
      seed: 13,
      createdAt: DateTime.utc(2026, 10, 1),
      state: DocumentState.sent,
    );
    final FakeSender sender = FakeSender();

    final QueueDrain? drain = await queueWith(sender).drain();

    expect(sender.calls, <String>['send:${queued.docId}']);
    expect(drain!.results, hasLength(1));
  });

  test('a reentrant drain is ignored while one is running', () async {
    final Completer<void> gate = Completer<void>();
    final FakeSender sender = FakeSender(
      answer: (SendRequest request, RecordId? recordId) {
        // The first entry's answer waits, so the second call of `drain()` arrives mid-drain.
        if (!gate.isCompleted) {
          gate.complete();
        }
        return aSent();
      },
    );
    await aQueuedEntry(seed: 21, createdAt: DateTime.utc(2026, 10, 1));
    await aQueuedEntry(seed: 22, createdAt: DateTime.utc(2026, 10, 2));
    final SendQueue queue = queueWith(sender);

    final Future<QueueDrain?> first = queue.drain();
    final QueueDrain? second = await queue.drain();
    final QueueDrain? firstDrain = await first;

    expect(second, isNull, reason: 'reentrant calls are ignored (design §4)');
    expect(firstDrain!.results, hasLength(2));
    expect(sender.calls, hasLength(2), reason: 'each entry was sent once');
  });

  test('the drain stops at the first uncertain entry and attempts nothing behind it', () async {
    final HistoryEntry first = await aQueuedEntry(
      seed: 31,
      createdAt: DateTime.utc(2026, 10, 1),
    );
    final HistoryEntry second = await aQueuedEntry(
      seed: 32,
      createdAt: DateTime.utc(2026, 10, 2),
    );
    final FakeSender sender = FakeSender(
      answer: (SendRequest request, RecordId? recordId) =>
          const Uncertain(candidates: <NinoxRecord>[]),
    );

    final QueueDrain drain = (await queueWith(sender).drain())!;

    expect(drain.stop, DrainStop.uncertain);
    expect(sender.calls, <String>['send:${first.docId}']);
    expect((await store.get(first.docId)).state, DocumentState.uncertain);
    expect(
      (await store.get(second.docId)).state,
      DocumentState.queued,
      reason: 'it waits for the next drain',
    );
  });

  test('nothing is attempted while there is no connectivity', () async {
    await aQueuedEntry(seed: 41, createdAt: DateTime.utc(2026, 10, 1));
    connectivity.report(online: false);
    final FakeSender sender = FakeSender();

    final QueueDrain drain = (await queueWith(sender).drain())!;

    expect(drain.stop, DrainStop.connectivityLost);
    expect(drain.results, isEmpty);
    expect(sender.calls, isEmpty);
  });

  test('a connection that goes away mid-drain stops it, and the rest stays queued', () async {
    final HistoryEntry first = await aQueuedEntry(
      seed: 51,
      createdAt: DateTime.utc(2026, 10, 1),
    );
    final HistoryEntry second = await aQueuedEntry(
      seed: 52,
      createdAt: DateTime.utc(2026, 10, 2),
    );
    final FakeSender sender = FakeSender(
      answer: (SendRequest request, RecordId? recordId) {
        // The send of the first entry is the last thing the connection manages.
        connectivity.report(online: false);
        return aSent();
      },
    );

    final QueueDrain drain = (await queueWith(sender).drain())!;

    expect(drain.stop, DrainStop.connectivityLost);
    expect(drain.results, hasLength(1));
    expect(sender.calls, <String>['send:${first.docId}']);
    expect((await store.get(second.docId)).state, DocumentState.queued);
  });

  test(
    'a send the pipeline queues stops the drain: nothing left the device',
    () async {
      await aQueuedEntry(seed: 53, createdAt: DateTime.utc(2026, 10, 1));
      final HistoryEntry second = await aQueuedEntry(
        seed: 54,
        createdAt: DateTime.utc(2026, 10, 2),
      );
      // The connectivity port still believes there is a connection; the pipeline, which tried, says
      // there is not.
      final FakeSender sender = FakeSender(
        answer: (SendRequest request, RecordId? recordId) => const Queued(),
      );

      final QueueDrain drain = (await queueWith(sender).drain())!;

      expect(drain.stop, DrainStop.connectivityLost);
      expect(sender.calls, hasLength(1));
      expect((await store.get(second.docId)).state, DocumentState.queued);
    },
  );

  test(
    'a failed entry does not stop the drain: it is no longer queued',
    () async {
      final HistoryEntry first = await aQueuedEntry(
        seed: 55,
        createdAt: DateTime.utc(2026, 10, 1),
      );
      final HistoryEntry second = await aQueuedEntry(
        seed: 56,
        createdAt: DateTime.utc(2026, 10, 2),
      );
      final FakeSender sender = FakeSender(
        answer: (SendRequest request, RecordId? recordId) =>
            request.docId == first.docId
            ? Failed(
                kind: SendFailureKind.server,
                failure: const ServerError(503),
              )
            : aSent(),
      );

      final QueueDrain drain = (await queueWith(sender).drain())!;

      expect(drain.stop, DrainStop.drained);
      expect(sender.calls, hasLength(2));
      expect((await store.get(first.docId)).state, DocumentState.failed);
      expect((await store.get(second.docId)).state, DocumentState.sent);
    },
  );

  test('[capture-intake/capture-without-connectivity] the offline save is queued, not '
      'lost', () async {
    final HistoryEntry queued = await aQueuedEntry(
      seed: 61,
      createdAt: DateTime.utc(2026, 10, 1),
    );
    connectivity.report(online: false);
    final FakeSender sender = FakeSender();
    final SendQueue queue = queueWith(sender);
    queue.listen();

    // Offline: the report of a lost connection drains nothing.
    connectivity.report(online: false);
    await _settle();
    expect(sender.calls, isEmpty);

    // And back: the report is the trigger, and the entry is sent without being re-entered.
    connectivity.report(online: true);
    await _settle();

    expect(sender.calls, <String>['send:${queued.docId}']);
    expect((await store.get(queued.docId)).state, DocumentState.sent);

    await queue.dispose();
  });

  test(
    'a drain the subscription started is not reported as an unhandled error',
    () async {
      await aQueuedEntry(seed: 71, createdAt: DateTime.utc(2026, 10, 1));
      final FakeSender sender = FakeSender(
        answer: (SendRequest request, RecordId? recordId) =>
            throw StateError('the sender itself failed'),
      );
      final SendQueue queue = queueWith(sender);
      queue.listen();

      connectivity.report(online: true);
      await _settle();

      // A failure of the caller's own code is not classified into a state by the pipeline, and the
      // queue has no screen of its own to report it to: the entry is not `sent`, nothing was thrown
      // into the zone by the subscription, and the next drain tries again.
      expect((await store.get(aDocId(71))).state, isNot(DocumentState.sent));
      await queue.dispose();
    },
  );

  test(
    'dispose ends the subscription, and a second listen adds none',
    () async {
      final HistoryEntry queued = await aQueuedEntry(
        seed: 81,
        createdAt: DateTime.utc(2026, 10, 1),
      );
      final FakeSender sender = FakeSender();
      final SendQueue queue = queueWith(sender);
      queue.listen();
      queue.listen();

      await queue.dispose();
      connectivity.report(online: true);
      await _settle();
      expect(sender.calls, isEmpty, reason: 'nothing is listening any more');

      queue.listen();
      connectivity.report(online: true);
      await _settle();
      expect(sender.calls, <String>['send:${queued.docId}']);
      await queue.dispose();
    },
  );
}

/// Lets a drain the subscription started run to its end.
///
/// A drain reaches the store, and the store is `dart:io` work: the turns are real waits, because a
/// bare `Future.microtask` would let the stream event through and none of the file work that follows
/// it.
Future<void> _settle() async {
  for (int turn = 0; turn < 20; turn++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}
