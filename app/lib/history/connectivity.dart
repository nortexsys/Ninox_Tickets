/// Whether a request can leave the device, as the queue observes it.
///
/// Requirement served: the queued half of `capture-intake/capture-without-connectivity` (FR-CAP-009)
/// — a save performed offline queues the send, and the send happens once connectivity returns,
/// without the user re-entering the document. Design §4 of `implement-history-retry-duplicates`: the
/// drain takes an injected `Connectivity` port.
///
/// **Why a port and not a plugin.** Real connectivity detection on a device is not this change: the
/// drain is proved on the host with a fake, and the platform plugin that feeds it belongs to the
/// screen that owns the app lifecycle. A port also keeps the decision honest — the queue asks *may a
/// request leave now*, which is the only question a send depends on, and not what kind of link the
/// device has.
///
/// **Nothing here is a background service.** A subscription to [changes] lives while the app is in
/// the foreground; there is no isolate and no `workmanager` (design §4).
library;

/// What the queue can learn about connectivity.
abstract interface class Connectivity {
  /// Whether a request could leave the device now.
  ///
  /// Read before the drain starts and again before each entry, which is how a loss of connectivity
  /// stops a drain that is already running: the pipeline's own `Queued` outcome says the same thing
  /// about a send it attempted, and the two together cannot be fooled by a stale answer.
  Future<bool> isOnline();

  /// Each change of connectivity, as the platform reports it: `true` when a connection is back.
  ///
  /// It is a broadcast-shaped view of the platform's own reporting and carries no history: a
  /// listener that attaches late learns the next change, which is why the queue also drains on an
  /// explicit call (`app resume`) rather than on the stream alone.
  Stream<bool> get changes;
}
