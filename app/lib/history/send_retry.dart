/// Sending a queued or failed document again, and correcting the one already in Ninox.
///
/// Requirement served: `document-history/correction-and-re-send` (FR-HIS-003) — from a history entry
/// the user can correct values and re-send, and the result is an update of the same record rather
/// than a new one — and the part of `document-history/document-states` that says `queued` is waiting
/// and never `failed` (FR-HIS-002). Design §3 of `implement-history-retry-duplicates` maps the rest.
///
/// **The state decides the call, and nothing else does** (design §3):
///
/// | The entry as stored | What this service does |
/// | --- | --- |
/// | `queued` | `SendPipeline.send` — nothing was ever created |
/// | `failed` without a record id | `SendPipeline.send` — the create never landed |
/// | `failed` with a record id | `SendPipeline.resume` — the record exists, attach to it |
/// | `uncertain` with a record id | `SendPipeline.resume` — continue with the record it names |
/// | `uncertain` without a record id | **refused**: the app does not guess (`RetryRefusalCode.uncertainNeedsDecision`) |
/// | anything else | **refused**: `pending`, `extracting`, `reviewing` and `sending` are not retryable, and `sent` is corrected, not re-sent |
///
/// **A retry never creates a second record.** Every call that could create one goes through
/// `SendPipeline.send`, whose create is reconciled rather than blindly retried
/// (`ninox-send/reconciliation-of-an-uncertain-create`, FR-SND-005); a state that already knows its
/// record goes through `resume`, which touches the attachment and the read-back and nothing else
/// (`ninox-send/the-retry-matrix` · *a failed attachment retries alone*).
///
/// **What survives a send.** The entry is written back with its state, its record identifier and a
/// failure reason, and with `values` and `confidence` **untouched**: they are the uncertainty trace
/// the user has no other way to see once the mapping is optional
/// (`history-is-the-uncertainty-trace`). Nothing here reads a field mapping, builds a payload or
/// writes an unmapped field.
library;

import 'package:ninox_client/ninox_client.dart'
    show
        Failed,
        Incomplete,
        NinoxFailure,
        NinoxPort,
        Queued,
        RecordId,
        SendFailureKind,
        SendOutcome,
        SendPipeline,
        SendRequest,
        Sent,
        Uncertain;

import 'document_machine.dart';
import 'history_entry.dart';
import 'history_store.dart';
import 'retention_policy.dart';

/// The two calls of the send pipeline a retry can make, as this service needs them.
///
/// An interface rather than the pipeline class itself, so that a host test drives the service with a
/// fake (design §5 of the change: "tests use a fake pipeline") and so that what this service may ask
/// of a send is written down: a create-and-attach, or an attach to a record that already exists.
/// [PipelineSender] is the only implementation that touches Ninox, and it is two forwardings.
abstract interface class DocumentSender {
  /// Creates and attaches: the pipeline's own reconciliation decides whether a create is really
  /// needed (`SendPipeline.send`).
  Future<SendOutcome> send(SendRequest request);

  /// Attaches to [recordId] and reads back, without creating anything (`SendPipeline.resume`).
  Future<SendOutcome> resume(SendRequest request, RecordId recordId);
}

/// The real [DocumentSender]: the send pipeline, forwarded to unchanged.
final class PipelineSender implements DocumentSender {
  /// Adapts [pipeline] to the two calls this service makes.
  const PipelineSender(this.pipeline);

  /// The pipeline the send itself belongs to (T1.11).
  final SendPipeline pipeline;

  @override
  Future<SendOutcome> send(SendRequest request) => pipeline.send(request);

  @override
  Future<SendOutcome> resume(SendRequest request, RecordId recordId) =>
      pipeline.resume(request, recordId);

  @override
  String toString() => 'PipelineSender(${pipeline.runtimeType})';
}

/// Builds the request of an entry: its destination, its payload and its document's bytes.
///
/// Injected and not built here, because what a document is *sent as* is not this service's subject:
/// the payload is keyed by the destination's current field names and built from the mapping
/// (`ninox-send/payload-shape`, `destinations-mapping`), and the bytes are the file `DocumentIntake`
/// stored. Both belong to the lane that owns the send's payload; a retry is about **which call** to
/// make with the request, not about what the request says.
typedef SendRequestBuilder = Future<SendRequest> Function(HistoryEntry entry);

/// What a retry refuses to do, as a code a screen translates.
///
/// Every value is a refusal and none of them is a message: the same rule as the store's codes
/// (NFR-I18N-001 — a code reaches a screen as a string from the ARB file).
enum RetryRefusalCode {
  /// The entry's state has no call: `pending`, `extracting`, `reviewing` and `sending` are not
  /// retryable, and a `sent` entry is corrected through [RetryService.correct], never re-sent as a
  /// create.
  notRetryable,

  /// An `uncertain` entry without a record identifier. The create's response was lost, so whether a
  /// record exists is unknown to this device: the app does not guess and does not create a second
  /// record — the user resolves it (`document-states` · *a lost create response is uncertain, not
  /// failed*).
  uncertainNeedsDecision,

  /// A correction of an entry that carries no record identifier. An update needs a record to update,
  /// and this service never turns a correction into a create
  /// (`correction-and-re-send` · *a correction updates rather than duplicates*).
  noRecordId,
}

/// A retry or a correction this service refused, and why.
class RetryRefusal implements Exception {
  /// Creates the refusal of [code], about [docId] when one document is concerned.
  const RetryRefusal(this.code, {this.docId, this.detail});

  /// What was refused, as a code the screens translate.
  final RetryRefusalCode code;

  /// The document the refusal is about: an identifier, which is random and derived from nothing
  /// (design §3 of the store's change).
  final String? docId;

  /// Diagnostic only — a state name. Never document content, never a field value.
  final String? detail;

  @override
  String toString() =>
      'RetryRefusal(${code.name}'
      '${docId == null ? '' : ', $docId'}'
      '${detail == null ? '' : ', $detail'})';
}

/// One retry, as it ended: the entry as it is now stored, and the pipeline's own answer.
///
/// [outcome] is not re-modelled: `Sent`, `Queued`, `Uncertain`, `Incomplete` and `Failed` are the
/// pipeline's (`ninox-send/the-retry-matrix`) and a screen reads the `Uncertain` candidates or a
/// `Failed` kind straight out of it. [entry] is the entry **as written**, so a caller shows the
/// revision the store holds and not a copy that may already be overtaken.
final class RetryResult {
  /// Binds the stored entry to the outcome that produced it.
  const RetryResult({required this.entry, required this.outcome});

  /// The entry after the outcome: `sent` with its record identifier, `queued`, `uncertain`, or
  /// `failed` with a reason code.
  final HistoryEntry entry;

  /// What the pipeline reported, unclassified and untouched.
  final SendOutcome outcome;

  @override
  String toString() =>
      'RetryResult(${entry.docId}, ${entry.state.name}, ${outcome.runtimeType})';
}

/// Re-sends a `queued` or `failed` document, and corrects the one already in Ninox.
///
/// Built over the store the entries live in, the sender that performs a send, the port a correction
/// updates through, and the builder of a request — plus the retention policy, which is applied after
/// a confirmed send so the local document file is released by the outcome and not by a timer
/// (`document-history/file-retention`, design §1 of this change).
///
/// **Every write goes through the state machine.** The entry is read from the store, moved to
/// `sending` by `document_machine.transition` and written *before* the pipeline is called, so a
/// device that dies mid-send leaves a state that says what was happening; the outcome moves it on
/// from there. `failed` reaches `sending` the way design §5.3 says a correction does: `failed` →
/// `reviewing` → `sending`, both transitions chained in memory and written once.
///
/// **Store failures are not send failures.** A [HistoryStoreFailure] — an entry that is gone, a
/// revision that was overtaken, a file system that refused — travels to the caller: it is the store
/// refusing, not the document failing, and the two must not be confused. Only what the pipeline
/// answers decides the document's state.
final class RetryService {
  /// Builds the service over the store, the sender, the port and the request builder.
  ///
  /// [retention] defaults to a [RetentionPolicy] over [store]: the same store releases the file of
  /// the send that just completed, and a test may pass its own to see what was asked of it.
  RetryService({
    required this.store,
    required this.sender,
    required this.port,
    required this.requestFor,
    RetentionPolicy? retention,
  }) : retention = retention ?? RetentionPolicy(store);

  /// Where the entry is read from and written back to.
  final HistoryStore store;

  /// How a document is created and attached, or attached to a record that exists.
  final DocumentSender sender;

  /// Where a correction is written: one `PUT` against the record the entry came from
  /// (`ninox-send/updates-are-merges`, FR-SND-008).
  final NinoxPort port;

  /// How the request of one entry is built. Never called for a refused retry.
  final SendRequestBuilder requestFor;

  /// What happens to the local document file of the state the outcome produced.
  final RetentionPolicy retention;

  /// Re-sends the stored entry of [docId], and answers the entry as it was written.
  ///
  /// The state this starts from is the **stored** one and not a caller's copy, so an entry that has
  /// been overtaken since a screen read it is retried from where it really is (and a write that
  /// would land on a newer revision is refused by the store). A state with no call throws a
  /// [RetryRefusal] and changes nothing: nothing is written, no request is built and no call is
  /// made.
  Future<RetryResult> retry(String docId) async {
    final HistoryEntry stored = await store.get(docId);
    final _RetryPlan plan = _planFor(stored);

    final HistoryEntry sending = plan.toSending(stored);
    await store.update(docId, sending);

    final SendRequest request = await requestFor(sending);
    final SendOutcome outcome = plan.resumeWith == null
        ? await sender.send(request)
        : await sender.resume(request, plan.resumeWith!);

    final HistoryEntry finished = transition(
      sending,
      _stateOf(outcome),
      ninoxRecordId: _recordIdOf(outcome),
      failureReason: _reasonOf(outcome),
    );
    await store.update(docId, finished);
    await retention.apply(finished);

    return RetryResult(entry: finished, outcome: outcome);
  }

  /// Sends [fieldsByName] as an **update** of the record the stored entry of [docId] came from.
  ///
  /// One `PUT` against [HistoryEntry.ninoxRecordId] and nothing else: no create, no listing, no
  /// attachment and no mapped field beyond the ones given (`correction-and-re-send` · *a correction
  /// updates rather than duplicates*). The entry's state is not changed by this call — it is the
  /// screen's to move through the machine, and `sent -> reviewing` on a correction is its table's —
  /// and nothing is written to the store, because a correction changes the record and not the
  /// local entry's state.
  ///
  /// The entry must carry a record identifier. One that does not is refused with
  /// [RetryRefusalCode.noRecordId] and **nothing is sent**: a correction that could not name its
  /// record would have to create one, and a duplicate is exactly what this refuses to produce.
  ///
  /// Throws what the port throws — [NinoxFailure] subtypes — because the classification of a failed
  /// update (a 500 is a mapping error, a 401 asks for the token) is the caller's, and this method
  /// adds no retry of its own: `updateRecord` is safe to send again, and only the caller knows
  /// whether the user still wants to.
  Future<void> correct(String docId, Map<String, Object?> fieldsByName) async {
    final HistoryEntry stored = await store.get(docId);
    final RecordId? recordId = stored.ninoxRecordId;
    if (recordId == null) {
      throw RetryRefusal(
        RetryRefusalCode.noRecordId,
        docId: docId,
        detail: 'the entry is ${stored.state.name} and names no record',
      );
    }
    await port.updateRecord(stored.destination, recordId, fieldsByName);
  }

  /// The call [entry] allows, or the refusal it earns (design §3).
  _RetryPlan _planFor(HistoryEntry entry) {
    final RecordId? recordId = entry.ninoxRecordId;
    return switch (entry.state) {
      // Nothing was ever created: the pipeline creates, and reconciles if the create's response is
      // lost. `queued`, and `failed` without a record, are the same call for the same reason.
      DocumentState.queued => const _RetryPlan(),
      DocumentState.failed =>
        recordId == null
            ? const _RetryPlan()
            // The record exists: resume touches the attachment and the read-back, and creates
            // nothing (`the-retry-matrix` · *a failed attachment retries alone*).
            : _RetryPlan(resumeWith: recordId),
      DocumentState.uncertain =>
        recordId == null
            ? throw RetryRefusal(
                RetryRefusalCode.uncertainNeedsDecision,
                docId: entry.docId,
                detail: 'uncertain with no record id: whether one exists is unknown',
              )
            : _RetryPlan(resumeWith: recordId),
      // A correction returns a `sent` entry to review, and that is a screen's job, not a retry's.
      DocumentState.pending ||
      DocumentState.extracting ||
      DocumentState.reviewing ||
      DocumentState.sending ||
      DocumentState.sent => throw RetryRefusal(
        RetryRefusalCode.notRetryable,
        docId: entry.docId,
        detail: 'the entry is ${entry.state.name}',
      ),
    };
  }

  /// The state [outcome] puts the document in.
  ///
  /// [Incomplete] is `failed` with its record identifier and `attachment_incomplete`: a record
  /// exists without its document, which is not done (`ninox-send/attachment-upload`) and is not
  /// `sent` either. It is `failed` and it keeps the identifier exactly so that the next retry
  /// resumes the attachment instead of creating a second record (design §3).
  DocumentState _stateOf(SendOutcome outcome) => switch (outcome) {
    Sent() => DocumentState.sent,
    Queued() => DocumentState.queued,
    Uncertain() => DocumentState.uncertain,
    Incomplete() => DocumentState.failed,
    Failed() => DocumentState.failed,
  };

  /// The record identifier [outcome] established, if it established one.
  ///
  /// `null` keeps whatever the entry already carried: an outcome that says nothing about a record
  /// must not erase the identifier a previous attempt learned, or the correction that follows would
  /// have nothing to update.
  RecordId? _recordIdOf(SendOutcome outcome) => switch (outcome) {
    Sent(recordId: final RecordId recordId) => recordId,
    Incomplete(recordId: final RecordId recordId) => recordId,
    _ => null,
  };

  /// The failure reason [outcome] stores, or `null` when nothing failed.
  ///
  /// A code from the pipeline's own vocabulary, never a sentence: `attachment_incomplete` for an
  /// incomplete send (design §5.4 of the store's change), and the pipeline's [SendFailureKind] name —
  /// snake-cased where the enum name is not already a code — for a terminal failure. This file
  /// invents no vocabulary of its own and interprets none: it writes down what the pipeline said.
  String? _reasonOf(SendOutcome outcome) => switch (outcome) {
    Incomplete() => 'attachment_incomplete',
    Failed(kind: final SendFailureKind kind) => switch (kind) {
      SendFailureKind.auth => 'auth',
      SendFailureKind.destinationGone => 'destination_gone',
      SendFailureKind.mapping => 'mapping',
      SendFailureKind.server => 'server',
    },
    _ => null,
  };

  @override
  String toString() => 'RetryService(${store.runtimeType})';
}

/// How one retry will be performed: the pipeline call, and the transition that reaches it.
final class _RetryPlan {
  /// A plan that creates (or reconciles) through `send`.
  const _RetryPlan({this.resumeWith});

  /// The record to resume against, or `null` when the plan is a `send`.
  final RecordId? resumeWith;

  /// [entry] moved to `sending`, through every transition the machine requires.
  ///
  /// `queued` and `uncertain` reach it in one step; `failed` reaches it the way a correction does,
  /// `failed` → `reviewing` → `sending` (design §5.3 of the store's change), because `failed` has no
  /// direct edge to `sending` and a state is only ever changed by that table.
  HistoryEntry toSending(HistoryEntry entry) {
    return switch (entry.state) {
      DocumentState.failed => transition(
        transition(entry, DocumentState.reviewing),
        DocumentState.sending,
      ),
      _ => transition(entry, DocumentState.sending),
    };
  }
}
