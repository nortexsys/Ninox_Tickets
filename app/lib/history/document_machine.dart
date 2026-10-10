/// The document state machine of Funcional §6.2.3, as design §5.3 stores it.
///
/// Requirement served: FR-HIS-002 (`document-history/document-states`) — an entry carries
/// exactly one of the eight stored states, and its transitions are the functional's. This file
/// is the only place a state changes: [HistoryEntry] is immutable, and [transition] applies
/// [allowedTransitions] and the invariants that go with each state.
///
/// **What the drivers map onto it (design §5.3).** The functional's finer steps are not stored
/// states: `capturing` and `ingested` are `pending`, `attaching` and `reading-back` are
/// `sending`, `reconciling` is `uncertain`, and discarding deletes the entry and its folder
/// rather than moving it. The send pipeline's own step vocabulary meets this machine only in
/// the adapter of `app/lib/features/send/` (design §5.4), which is the Ninox lane's file:
/// nothing here imports it, and no transition is written to suit it.
///
/// **Two states that are not one.** `queued` is waiting and `uncertain` is genuinely unknown:
/// neither is `failed`, neither is reachable from `failed`, and collapsing them is how a create
/// whose response was lost gets retried and duplicated (`document-history` · *a lost create
/// response is uncertain, not failed*).
library;

import 'package:ninox_client/ninox_client.dart' show RecordId, TableRef;
import 'package:paperdrop_core/paperdrop_core.dart'
    show CanonicalDocument, ConfidenceState;

import 'history_entry.dart';

/// Every transition the machine allows, and no other (design §5.3).
///
/// A state with no entry here has no transition out of it: `sent` and `failed` both have one,
/// because a correction returns the document to `reviewing` (FR-HIS-003), and `reviewing` is
/// where the user can save, send or discard. Discarding is absent on purpose: it deletes the
/// entry and its folder instead of moving it to a state.
const Map<DocumentState, Set<DocumentState>> allowedTransitions =
    <DocumentState, Set<DocumentState>>{
      DocumentState.pending: <DocumentState>{
        DocumentState.extracting,
        DocumentState.failed,
      },
      DocumentState.extracting: <DocumentState>{
        DocumentState.reviewing,
        DocumentState.failed,
      },
      DocumentState.reviewing: <DocumentState>{
        DocumentState.queued,
        DocumentState.sending,
      },
      DocumentState.queued: <DocumentState>{DocumentState.sending},
      DocumentState.sending: <DocumentState>{
        DocumentState.sent,
        DocumentState.uncertain,
        DocumentState.failed,
        DocumentState.queued,
      },
      DocumentState.uncertain: <DocumentState>{
        DocumentState.sending,
        DocumentState.sent,
        DocumentState.failed,
      },
      DocumentState.failed: <DocumentState>{DocumentState.reviewing},
      DocumentState.sent: <DocumentState>{DocumentState.reviewing},
    };

/// Whether a document in [from] may move to [to].
bool isAllowedTransition(DocumentState from, DocumentState to) =>
    allowedTransitions[from]?.contains(to) ?? false;

/// [entry] moved to [to], with whatever the caller attaches by it, or a refusal.
///
/// **The table decides.** A pair [allowedTransitions] does not allow throws a [StateError]
/// naming both states (`pending -> sent`), and nothing is changed anywhere: an entry is
/// immutable and this store touches no file, so a refused transition leaves the disk as it was.
///
/// **Every argument is optional.** One that is `null` leaves the entry's own value in place —
/// `values`, `confidence`, `thumbnailPath`, `destination`, `ninoxRecordId` and
/// `duplicateFlagged` are each attached once by the stage that produces them and then travel
/// with the document. The one exception is [failureReason]: a reason belongs to the attempt that
/// produced it and not to the document, so a transition that is not given one produces an entry
/// without one, and a stale reason cannot outlive its attempt.
///
/// [duplicateFlagged] may be given in any state and never blocks a transition (design §5.3,
/// DEC-016): a duplicate is flagged *alongside* the state the document is in.
///
/// The result's [HistoryEntry.revision] is one higher than [entry]'s, which is what makes the
/// write that follows able to refuse a copy that has been overtaken (design §5.1).
HistoryEntry transition(
  HistoryEntry entry,
  DocumentState to, {
  TableRef? destination,
  String? thumbnailPath,
  CanonicalDocument? values,
  ConfidenceState? confidence,
  RecordId? ninoxRecordId,
  String? failureReason,
  bool? duplicateFlagged,
}) {
  final Set<DocumentState> allowed =
      allowedTransitions[entry.state] ?? const <DocumentState>{};
  if (!allowed.contains(to)) {
    final String expected = allowed.isEmpty
        ? 'no transition'
        : allowed.map((DocumentState state) => state.name).join(', ');
    throw StateError(
      'illegal document transition ${entry.state.name} -> ${to.name}; '
      '${entry.state.name} allows $expected',
    );
  }

  final RecordId? recordId = ninoxRecordId ?? entry.ninoxRecordId;
  if (to == DocumentState.sent && recordId == null) {
    // `sent` requires it (design §5.3): an entry in `sent` without the
    // identifier of its record could not be corrected, and would look like a
    // document nobody could find again.
    throw ArgumentError(
      'a transition to sent must carry the record identifier the create was '
      'confirmed with: ${entry.state.name} -> sent would leave the entry '
      'without one',
    );
  }

  return HistoryEntry(
    docId: entry.docId,
    revision: entry.revision + 1,
    createdAt: entry.createdAt,
    state: to,
    documentHash: entry.documentHash,
    destination: destination ?? entry.destination,
    duplicateFlagged: duplicateFlagged ?? entry.duplicateFlagged,
    thumbnailPath: thumbnailPath ?? entry.thumbnailPath,
    values: values ?? entry.values,
    confidence: confidence ?? entry.confidence,
    ninoxRecordId: recordId,
    failureReason: failureReason,
  );
}
