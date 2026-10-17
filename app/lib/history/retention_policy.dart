/// What the local store does with a document's file, decided by the entry's state alone.
///
/// Requirement served: FR-HIS-004 (`document-history/file-retention`) — local document images are
/// deleted once a send is confirmed, since the document is in Ninox by then, and are retained while
/// an item is pending or failed. Design §1 of `implement-history-retry-duplicates`: the policy is a
/// function of the **state only**.
///
/// **A function of the state, not of a clock.** Nothing here reads the time, remembers when it last
/// ran or expires anything: a document captured a year ago whose send never completed still has its
/// file (`file-retention` · *retention follows the state, not a timer*), and a document confirmed a
/// second ago does not.
///
/// **Two calls, one decision.** [apply] is the decision over an entry a caller already holds — the
/// path that follows a `Sent` outcome; [applyToStored] re-reads the entry first and is the path that
/// repairs a crash between `sent` and the delete, because an entry that was written `sent` and never
/// released is released the next time it is loaded.
///
/// **Idempotent.** Deleting an absent file is not an error: the store's [HistoryStore.deleteOriginal]
/// looks for the document's files and finds none, which is the state a second call leaves. A crash
/// cannot therefore leave a document that can never be released.
library;

import 'history_entry.dart';
import 'history_store.dart';

/// What one application of the policy did to a document's file.
enum RetentionOutcome {
  /// The entry is `sent`: the stored document file was released, and the thumbnail and the entry
  /// were left where they are (`file-retention` · *a confirmed send releases the local file*).
  released,

  /// The entry is in any other state: the file is still the only copy, so it stays
  /// (`file-retention` · *an unresolved item keeps its file*).
  retained,
}

/// Releases the stored document file of a confirmed send, and keeps every other state's.
///
/// It is built over the store rather than over a folder, so the one rule about *which* file is the
/// document's lives in [HistoryStore.deleteOriginal] and is not restated here: this class only
/// decides whether to call it.
final class RetentionPolicy {
  /// Binds the policy to the store whose files it releases.
  const RetentionPolicy(this.store);

  /// Where the entries and their document files are.
  final HistoryStore store;

  /// Applies retention to [entry], as it is in hand.
  ///
  /// [DocumentState.sent] releases the document file through the store and answers
  /// [RetentionOutcome.released]; every other state answers [RetentionOutcome.retained] and touches
  /// nothing. The thumbnail is never deleted: it is what a history detail shows once the document
  /// itself is in Ninox.
  ///
  /// **A state that changed under the call is a retention, not a failure.** The store decides
  /// whether to release by reading the stored entry again; when that read finds another state, the
  /// file must be kept — the document is not in Ninox after all — so the store's
  /// [HistoryStoreFailureCode.originalRetained] is the right answer and not an error. Every other
  /// store failure is a file system refusing and travels to the caller.
  Future<RetentionOutcome> apply(HistoryEntry entry) async {
    if (entry.state != DocumentState.sent) {
      return RetentionOutcome.retained;
    }
    try {
      await store.deleteOriginal(entry.docId);
    } on HistoryStoreFailure catch (failure) {
      if (failure.code == HistoryStoreFailureCode.originalRetained) {
        return RetentionOutcome.retained;
      }
      rethrow;
    }
    return RetentionOutcome.released;
  }

  /// Applies retention to [docId] as it is **stored**: the load path of design §1.
  ///
  /// Reading first is the whole point: an entry found `sent` whose file is still there is a send
  /// that was confirmed and whose process died before the delete, and this call repairs it. Throws
  /// what [HistoryStore.get] throws for a document that has no entry or whose entry cannot be read.
  Future<RetentionOutcome> applyToStored(String docId) async =>
      apply(await store.get(docId));

  @override
  String toString() => 'RetentionPolicy(${store.runtimeType})';
}
