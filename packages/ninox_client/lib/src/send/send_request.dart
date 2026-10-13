/// One document to send, and the record the send is aimed at.
///
/// The request carries the two halves of a send and nothing else: the destination tuple
/// ([ref]), the payload already built ([fieldsByName]) and the document itself
/// ([filename], [bytes], [contentType]). The `docId` is the local document's identifier, and it is
/// the key the pipeline reports its transitions under (`SendJournal.record`).
///
/// **The pipeline decides no value and builds no mapping.** [fieldsByName] arrives already built —
/// keyed by the destination's **current field names** (`ninox-send/payload-shape`, ADR-004),
/// amounts as integers in the currency's minor unit, rates as integers in basis points, dates as
/// `YYYY-MM-DD` — and it is handed to the port unchanged. Nothing in this package inspects a value
/// to decide whether it may be written (`validation-confidence` owns that) and nothing writes a
/// field the caller did not put in the map (`destinations-mapping/never-write-an-unmapped-field`).
///
/// **The document is not a mapping target.** It travels beside [fieldsByName] rather than inside
/// it, because a file attaches to the **record** and not to a field of it
/// (`ninox-send/attachment-upload`, ADR-004).
library;

import 'dart:typed_data';

import '../port.dart';

/// Everything a send needs: where it goes, what it writes and what it attaches.
final class SendRequest {
  /// Builds a request from a destination and a document that is already in hand.
  ///
  /// [bytes] are the document's bytes exactly as they will be uploaded — never re-encoded, never
  /// re-rendered (ADR-007, BR-17) — and [contentType] is the type declared for them.
  const SendRequest({
    required this.ref,
    required this.fieldsByName,
    required this.docId,
    required this.filename,
    required this.bytes,
    required this.contentType,
  });

  /// The team, database and table the record is created in, all three explicit (`AGENTS.md` §1.4).
  final TableRef ref;

  /// The payload, keyed by the destination's current field names and already built. It is sent
  /// under the port's `fields` key exactly as it is given here.
  final Map<String, Object?> fieldsByName;

  /// The local document's identifier: what the journal is keyed by and what the history shows.
  final String docId;

  /// The name the document is stored under, as the read-back compares it.
  final String filename;

  /// The document's bytes.
  final Uint8List bytes;

  /// The content type declared for [bytes].
  final String contentType;

  /// Prints the destination and the shape of the payload — never a value, because a record's
  /// values are a person's data.
  @override
  String toString() =>
      'SendRequest(${ref.tableId}, ${fieldsByName.length} fields, $filename, '
      '${bytes.length} bytes)';
}
