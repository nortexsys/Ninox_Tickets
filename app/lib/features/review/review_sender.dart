/// The one thing the review screen asks of the send lane: send this document.
///
/// Requirement served: FR-REV-009 (`review-screen/never-block-a-save`) — the save builds its
/// request from the edited-or-extracted values and calls the pipeline, and whatever the pipeline
/// answers leaves the screen free to try again — and FR-REV-010, because the entry this port is
/// handed is the edited one. Design §5 of `implement-review-screen` settles the seam, and
/// `review-screen`'s *Out of Scope* puts the send, the read-back and the confirmation screen in
/// `ninox-send`: **nothing here creates a record, writes a state or touches Ninox**.
///
/// **Why it is a port and not the pipeline.** A host test drives the screen with a fake sender, so
/// no widget test needs a token, a device or a database (design §1 and §7), and the one place that
/// would make a call is a forwarding class in this file and nowhere else. The real implementation
/// reuses the send lane's own two pieces — [DocumentSender], the pipeline port
/// `history/send_retry.dart` already defines, and [SendRequestBuilder], which is how the payload
/// and the document's bytes are built — so the review screen repeats neither the payload nor the
/// bytes and holds no Ninox call of its own.
library;

import 'package:ninox_client/ninox_client.dart' show SendOutcome;
import 'package:paperdrop/history/history_entry.dart';
import 'package:paperdrop/history/send_retry.dart'
    show DocumentSender, SendRequestBuilder;

/// How a reviewed document is sent: one call, and the pipeline's own answer to it.
abstract interface class ReviewSender {
  /// Sends [entry] — its destination, its edited-or-extracted values and its document.
  ///
  /// The entry is the one the screen has been building: its `values` are the canonical document
  /// with the user's edits as [Edited] values, its `destination` is the one the bar shows, and its
  /// `duplicateFlagged` is set when the user chose to proceed past a duplicate notice. An
  /// implementation moves the entry through the state machine and writes it back or leaves it as
  /// it is: the state a save reaches is `document-history`'s and the send's, not this screen's.
  ///
  /// Nothing is caught here. Whatever the pipeline answers is an outcome the caller reads; a
  /// failure of the pipeline's transport is the pipeline's to classify (`ninox-send`), and a
  /// [SendOutcome] of `Failed` is a document that was not sent, not an exception.
  Future<SendOutcome> send(HistoryEntry entry);
}

/// The real [ReviewSender]: the send lane's pipeline port, given the send lane's request builder.
///
/// It is two forwardings and no decision: the request is built by [requestFor] — which is where the
/// payload (keyed by the destination's current field names) and the stored document's bytes come
/// from, both of them `ninox-send`'s — and the send itself is [sender]'s.
final class PipelineReviewSender implements ReviewSender {
  /// Binds the pipeline port to the builder of the request of one entry.
  const PipelineReviewSender({required this.sender, required this.requestFor});

  /// How a document is created and attached.
  final DocumentSender sender;

  /// How the request of one entry is built.
  final SendRequestBuilder requestFor;

  @override
  Future<SendOutcome> send(HistoryEntry entry) async =>
      sender.send(await requestFor(entry));

  @override
  String toString() => 'PipelineReviewSender(${sender.runtimeType})';
}
