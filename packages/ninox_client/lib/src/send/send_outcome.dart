/// How a send ended, and the four failures it is worth telling apart.
///
/// The outcomes are the pipeline's whole answer to a send: [Sent] carries the **read-back** and
/// not what was sent (`ninox-send/create-attach-read-back`, `ninox-send/automations-may-run-and-the-read-back-is-the-visibility`),
/// [Queued] says nothing left the device, [Uncertain] asks the user to choose between the records a
/// reconciliation could not tell apart, [Incomplete] says a record exists without a confirmed
/// document, and [Failed] is terminal until the user acts.
///
/// The states of the send as `document-history` defines them — `queued`, `sending`, `uncertain`,
/// `sent`, `failed` and the rest — are **that capability's** and are not redefined here: the
/// pipeline reports steps to a `SendJournal` and leaves the state machine to it.
library;

import '../errors.dart';
import '../model.dart';

/// The four failures a user has to be told apart, because each one has a different answer.
///
/// The retry matrix (`ninox-send/the-retry-matrix`, FR-SND-004) ends in one of these and never in a
/// retry loop: [auth] needs a new token, [destinationGone] needs another destination, [mapping]
/// needs the mapping fixed, and [server] is the only one where waiting is the user's own choice.
enum SendFailureKind {
  /// HTTP 401 or 403: the token is absent, expired, revoked or lacks access. No retry.
  auth,

  /// HTTP 404: the database or the table is no longer there. No retry.
  destinationGone,

  /// An HTTP 500 under a mapping the schema refresh did not explain: a field name, a formula field
  /// or a read-only field, reported as a **mapping** problem rather than as an outage.
  mapping,

  /// Anything else that stopped the send without an action for the user: an exhausted rate limit,
  /// an exhausted retry on a safe step, a response the adapter could not read.
  server,
}

/// A send that ran to the end and whose document is confirmed in the record.
///
/// [readBack] is what the UI shows: the record as Ninox stored it, where a formula field or a table
/// default may have silently overridden what was submitted, and the create response did not reveal
/// it. The pipeline never returns what it sent.
final class Sent extends SendOutcome {
  /// Builds the outcome of a completed send.
  const Sent({
    required this.recordId,
    required this.readBack,
    required this.files,
  });

  /// The identifier of the record the send created (or adopted).
  final RecordId recordId;

  /// The record read back from Ninox after the attachment: the values as stored.
  final NinoxRecord readBack;

  /// The record's files as read back, one of which matches the uploaded document.
  final List<NinoxFile> files;

  @override
  String toString() =>
      'Sent(${recordId.value}, ${readBack.fields.length} fields, ${files.length} files)';
}

/// A send that did not leave the device: the connectivity failure arrived before any request did.
///
/// The send is not lost and not failed: something outside this package — the queue that drains when
/// connectivity returns — sends it again (`ninox-send/the-retry-matrix`, plan: the offline queue is
/// Mobile's). This outcome is only reachable while **no record exists yet**: once a create has
/// landed, a lost connection is [Incomplete] with its record identifier, because a queue entry with
/// no identifier could not finish the attachment.
final class Queued extends SendOutcome {
  /// Builds the outcome of a send that nothing left the device for.
  const Queued();

  @override
  String toString() => 'Queued';
}

/// A create whose outcome is unknown, where the app will not guess between records.
///
/// `ninox-send/reconciliation-of-an-uncertain-create` (FR-SND-005): the app never blind-retries a
/// create, it reconciles; and where the evidence is genuinely ambiguous it asks the user instead of
/// deciding. [candidates] is what it found for the user to choose between — possibly empty, which
/// says the app could not read the evidence (the listing failed, or a filter could not be applied),
/// not that no record exists.
final class Uncertain extends SendOutcome {
  /// Builds the outcome of a reconciliation the app refuses to decide.
  const Uncertain({required this.candidates});

  /// The records the user chooses between, as they were read. They are candidates and not a
  /// verdict: the user's choice is what continues the flow, through `adopt`.
  final List<NinoxRecord> candidates;

  @override
  String toString() => 'Uncertain(${candidates.length} candidates)';
}

/// A record that exists without a document confirmed in it: incomplete, never done.
///
/// `ninox-send/attachment-upload` scenario *no record is created without its document*, and the
/// matrix's row *record created, attachment failed*: the record is not re-created, the attachment
/// is retried alone ([SendPipeline.resume]), and until then the send is not reported as sent.
final class Incomplete extends SendOutcome {
  /// Builds the outcome of a created record whose document is not confirmed.
  const Incomplete({required this.recordId, required this.reason});

  /// The identifier of the record that does exist, so the attachment can be retried against it.
  final RecordId recordId;

  /// Why the document is not confirmed: one fixed English sentence, never a field value and never
  /// the token. It names an exhausted retry or an attachment the read-back did not carry.
  final String reason;

  @override
  String toString() => 'Incomplete(${recordId.value}, $reason)';
}

/// A send that ended where the user has to act; nothing is retried after this.
///
/// [failure] is the port's own failure, unclassified by it and classified here: the pipeline is the
/// only place that knows a 500 is a mapping error and a 401 is not worth sleeping for.
final class Failed extends SendOutcome {
  /// Builds the outcome of a send that stopped at a terminal failure.
  const Failed({required this.kind, required this.failure});

  /// Which of the four terminal situations this is, and therefore what the user is asked to do.
  final SendFailureKind kind;

  /// What the port reported, with no token in it.
  final NinoxFailure failure;

  @override
  String toString() => 'Failed(${kind.name}, $failure)';
}

/// How a send ended. Sealed, so a caller's `switch` is checked for exhaustiveness.
sealed class SendOutcome {
  /// Const-constructible, so an outcome can be a compile-time constant.
  const SendOutcome();
}
