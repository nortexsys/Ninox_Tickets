/// The foreground queue: the `queued` entries, sent one at a time when connectivity returns.
///
/// Requirement served: `capture-intake/capture-without-connectivity` (FR-CAP-009) — a save performed
/// with no connectivity is queued, not lost, and is sent once connectivity returns without the user
/// re-entering the document — and the part of `document-history/document-states` that says an
/// offline save reads `queued` and not `failed` (FR-HIS-002). Design §4 of
/// `implement-history-retry-duplicates` settles the order, the single flight and where it stops.
///
/// **Foreground, one at a time, oldest first.** A drain reads the history, takes the entries in
/// `queued`, oldest first, and hands them to [RetryService] one after another. Nothing runs in
/// parallel: two sends of one document would create two records, and two drains of one queue would
/// send the same entry twice.
///
/// **It stops at two things and only two** (design §4): an entry that came back `Uncertain` — the
/// app does not guess, so nothing behind it is attempted (`document-states` · *a lost create response
/// is uncertain, not failed*) — and a loss of connectivity, which is how a queue with a hundred
/// waiting entries behaves when the train enters a tunnel. A `Failed` outcome is **not** a stop: that
/// document is `failed` now and not `queued`, and the next entry has nothing to do with it.
///
/// **No background service** (design §4): there is no isolate, no `workmanager` and no alarm. What
/// there is, is a subscription the app makes while it is in the foreground — [listen] — and an
/// explicit [drain] for the call the app makes when it returns to the foreground.
library;

import 'dart:async';

import 'package:ninox_client/ninox_client.dart'
    show Queued, SendOutcome, Uncertain;

import 'connectivity.dart';
import 'history_entry.dart';
import 'history_store.dart';
import 'send_retry.dart';

/// Why a drain stopped.
enum DrainStop {
  /// Every `queued` entry was attempted; there is nothing left to send.
  drained,

  /// Nothing left the device, or the connection went away mid-drain: the rest of the queue waits for
  /// the next report of connectivity.
  connectivityLost,

  /// An entry came back [Uncertain]: the user resolves it, and nothing behind it is attempted.
  uncertain,
}

/// What one drain did, in the order it did it.
final class QueueDrain {
  /// Binds the results of the entries attempted to the reason the drain stopped.
  const QueueDrain({required this.results, required this.stop});

  /// One result per entry attempted, oldest first. An entry that was not attempted is not here.
  final List<RetryResult> results;

  /// Why the drain stopped: nothing left, connectivity gone, or an uncertain entry.
  final DrainStop stop;

  @override
  String toString() =>
      'QueueDrain(${results.length} attempted, stop: ${stop.name})';
}

/// Sends the `queued` entries of the local history, oldest first, one at a time.
///
/// Built over the store the queue is read from, the [RetryService] that performs each send — which
/// is where the state machine, the pipeline and retention live — and the [Connectivity] port that
/// says whether a request may leave.
///
/// **Single flight.** A [drain] that starts while one is running returns `null` and does nothing:
/// reentrant calls are ignored (design §4) rather than queued behind each other, because a second
/// drain would send nothing the first is not already sending, and a send in flight cannot be
/// cancelled by asking again.
final class SendQueue {
  /// Builds the queue over the store, the retry service and the connectivity port.
  SendQueue({
    required this.store,
    required this.retry,
    required this.connectivity,
  });

  /// Where the `queued` entries are read from.
  final HistoryStore store;

  /// How each entry is sent again.
  final RetryService retry;

  /// Whether a request may leave the device.
  final Connectivity connectivity;

  /// The drain in flight, or `null` when there is none. What makes a second call a no-op.
  Future<QueueDrain>? _running;

  /// The subscription [listen] made, so that [dispose] can end it.
  StreamSubscription<bool>? _subscription;

  /// Drains the queue, or answers `null` when one is already running.
  ///
  /// The order is **oldest first**: `createdAt` ascending, and by `docId` ascending when two
  /// documents share an instant, so that the order is the one the user would recognise and the same
  /// on every drain. The entry's state is re-read by [RetryService.retry], so an entry that stopped
  /// being `queued` since the listing was read is not sent twice.
  Future<QueueDrain?> drain() async {
    if (_running != null) {
      return null;
    }
    final Future<QueueDrain> running = _drain();
    _running = running;
    try {
      return await running;
    } finally {
      _running = null;
    }
  }

  /// Starts draining whenever the device is reported back online.
  ///
  /// Called once, while the app is in the foreground: a second call adds no second subscription. A
  /// drain this starts and that fails is not reported anywhere — the queue has no screen of its own —
  /// and the next connectivity report or the next [drain] from the app's resume handling is what
  /// notices; the entries it did not reach are still `queued`.
  void listen() {
    _subscription ??= connectivity.changes.listen((bool online) {
      if (online) {
        // The drain is not awaited here: this is a stream callback, and the answer belongs to
        // whoever calls `drain()` themselves.
        unawaited(drain().then((QueueDrain? _) {}).catchError((Object _) {}));
      }
    });
  }

  /// Ends the subscription [listen] made, and does nothing when there is none.
  ///
  /// The drain in flight, if any, is not cancelled: a send cannot be un-sent by ceasing to listen,
  /// and its outcome is written by the pipeline and the store either way.
  Future<void> dispose() async {
    final StreamSubscription<bool>? subscription = _subscription;
    _subscription = null;
    await subscription?.cancel();
  }

  /// The drain itself, behind the single-flight guard of [drain].
  Future<QueueDrain> _drain() async {
    if (!await connectivity.isOnline()) {
      return const QueueDrain(
        results: <RetryResult>[],
        stop: DrainStop.connectivityLost,
      );
    }

    final HistoryListing listing = await store.list();
    // `list()` answers newest first and a queue is oldest first, so the order is sorted again rather
    // than reversed: reversing would reverse the tie-break on the document identifier too, and the
    // order of two documents of one instant would then be the opposite of the history's.
    final List<HistoryEntry> queued =
        listing.entries
            .where((HistoryEntry entry) => entry.state == DocumentState.queued)
            .toList(growable: false)
          ..sort((HistoryEntry a, HistoryEntry b) {
            final int byTime = a.createdAt.compareTo(b.createdAt);
            return byTime != 0 ? byTime : a.docId.compareTo(b.docId);
          });

    final List<RetryResult> results = <RetryResult>[];
    for (final HistoryEntry entry in queued) {
      if (!await connectivity.isOnline()) {
        return QueueDrain(
          results: List<RetryResult>.unmodifiable(results),
          stop: DrainStop.connectivityLost,
        );
      }
      final RetryResult result = await retry.retry(entry.docId);
      results.add(result);
      final SendOutcome outcome = result.outcome;
      if (outcome is Uncertain) {
        return QueueDrain(
          results: List<RetryResult>.unmodifiable(results),
          stop: DrainStop.uncertain,
        );
      }
      if (outcome is Queued) {
        // The pipeline says nothing left the device: that is connectivity loss as this queue can
        // observe it, and the rest of the queue waits for the next report.
        return QueueDrain(
          results: List<RetryResult>.unmodifiable(results),
          stop: DrainStop.connectivityLost,
        );
      }
    }

    return QueueDrain(
      results: List<RetryResult>.unmodifiable(results),
      stop: DrainStop.drained,
    );
  }

  @override
  String toString() => 'SendQueue(${store.runtimeType})';
}
