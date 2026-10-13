/// The journal a send reports its steps to, and the steps it reports.
///
/// The pipeline **only emits transitions**: the nine states a document's history carries are
/// `document-history`'s (T1.14), and the store that keeps them implements this interface. This
/// change ships [InMemorySendJournal] so the pipeline is testable and so T1.14 has a shape to
/// implement against; it is not the local store.
library;

import '../model.dart';

/// A step of a send, as the pipeline reports it.
///
/// The names are the pipeline's own steps and not the nine states of `document-history`'s machine;
/// the mapping between the two belongs to whoever implements [SendJournal] (T1.14). Each step says
/// which of them it corresponds to, and only [created], [attaching], [attached] and [incomplete]
/// carry a record identifier.
enum SendStep {
  /// A create whose outcome is unknown is being reconciled — the `uncertain` situation.
  uncertain,

  /// Nothing left the device: the connectivity failure arrived before any request did. This is
  /// `document-history`'s `queued`, and it is only reachable while no record exists yet.
  queued,

  /// The pipeline is sending: the create is on its way. This is `document-history`'s `sending`.
  sending,

  /// A record exists and its identifier is in the entry. The attachment is next; the document is
  /// not in it yet.
  created,

  /// The document is being attached to that record.
  attaching,

  /// The upload returned and the read-back is next. The attachment is stored, but nothing has
  /// confirmed it yet.
  attached,

  /// The read-back is complete and the record carries the document: the send is done
  /// (`document-history`'s `sent`).
  sent,

  /// A record exists but the document is not confirmed in it. Nothing is lost: the attachment is
  /// retried alone, and the send is not reported as done until it is.
  incomplete,

  /// The send stopped at a failure the user has to act on (`document-history`'s `failed`).
  failed,
}

/// One transition of one document, as the store keeps it.
final class SendJournalEntry {
  /// Builds an entry.
  const SendJournalEntry({
    required this.docId,
    required this.step,
    this.recordId,
  });

  /// The local document this transition belongs to.
  final String docId;

  /// The step the send reached.
  final SendStep step;

  /// The record the step is about, for the steps that have one.
  final RecordId? recordId;

  @override
  bool operator ==(Object other) =>
      other is SendJournalEntry &&
      other.docId == docId &&
      other.step == step &&
      other.recordId == recordId;

  @override
  int get hashCode => Object.hash(docId, step, recordId);

  @override
  String toString() =>
      'SendJournalEntry($docId, ${step.name}'
      '${recordId == null ? '' : ', ${recordId!.value}'})';
}

/// Where a send reports its transitions.
///
/// The one method is deliberately narrow: the pipeline says **which step** a document reached and
/// **which record** it is about, and decides nothing about the states a history holds. An
/// implementation that cannot write must not throw at the pipeline — a journal that fails takes the
/// send with it, so the store is the caller's responsibility (T1.14).
abstract interface class SendJournal {
  /// Records that the document [docId] reached [step], optionally about a record.
  ///
  /// [recordId] is present on [SendStep.created], [SendStep.attaching], [SendStep.attached],
  /// [SendStep.sent] and [SendStep.incomplete], and absent on the steps that are not about one
  /// record yet.
  Future<void> record(String docId, SendStep step, {RecordId? recordId});
}

/// The journal of a pipeline whose caller keeps no history.
///
/// It exists so that a pipeline can be built without one — in a test that only cares about the
/// outcome, or in a caller that has its own record — rather than to be a policy.
final class NoopSendJournal implements SendJournal {
  /// Builds the journal. There is nothing to configure.
  const NoopSendJournal();

  @override
  Future<void> record(
    String docId,
    SendStep step, {
    RecordId? recordId,
  }) async {}
}

/// The journal this change ships: an in-memory list of the transitions, for tests and for T1.14.
///
/// It keeps every transition in the order it was reported, which is what makes the order of a send
/// assertable without a store. It is **not** the local store: nothing is persisted, nothing survives
/// the process, and no state machine is applied — `document-history`'s nine states are T1.14's.
final class InMemorySendJournal implements SendJournal {
  /// Builds an empty journal.
  InMemorySendJournal();

  /// Every transition reported, oldest first.
  final List<SendJournalEntry> entries = <SendJournalEntry>[];

  @override
  Future<void> record(String docId, SendStep step, {RecordId? recordId}) async {
    entries.add(SendJournalEntry(docId: docId, step: step, recordId: recordId));
  }

  /// The steps of one document, in order — the shape a test asserts on.
  List<SendStep> stepsOf(String docId) => [
    for (final SendJournalEntry entry in entries)
      if (entry.docId == docId) entry.step,
  ];

  @override
  String toString() => 'InMemorySendJournal(${entries.length} entries)';
}
