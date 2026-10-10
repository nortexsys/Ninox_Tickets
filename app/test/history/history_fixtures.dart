/// The entries, identifiers and destinations the history tests share.
///
/// **Every identifier is built at run time.** A 32-character document identifier or a
/// 64-character SHA-256 written as a literal in a tracked file is a token-like string to
/// `.github/scripts/privacy_check.py`, which fails the build on one; the fixtures compute both
/// instead, so the tests use the same shapes `DocumentIntake` produces (design §3) without
/// writing one down.
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:ninox_client/ninox_client.dart';
import 'package:paperdrop/history/history_entry.dart';
import 'package:paperdrop_core/paperdrop_core.dart';

/// A document identifier in the shape `DocumentIntake` assigns: 128 bits as lowercase hex.
String aDocId([int seed = 1]) => seed.toRadixString(16).padLeft(32, '0');

/// A SHA-256 in lowercase hex, computed exactly as `DocumentIntake` computes one.
String aDocumentHash([String seed = 'document-a']) =>
    sha256.convert(utf8.encode(seed)).toString();

/// The destination an entry carries: the three identifiers and nothing else (design §5.2).
const TableRef aDestination = TableRef(
  teamId: 'team-1',
  databaseId: 'db-1',
  tableId: 'table-1',
);

/// The extraction's output: a canonical document with a date, a money amount and a currency,
/// each with its provenance tag, in the core's own types.
CanonicalDocument aCanonicalDocument({String seed = 'document-a'}) =>
    CanonicalDocument(
      docDate: Present<CalendarDate>(
        CalendarDate(2026, 10, 1),
        Provenance.read,
        ConfidenceState.green,
      ),
      grossTotal: Present<Money>(
        Money(1999, CurrencyCode.parse('EUR')!),
        Provenance.read,
        ConfidenceState.green,
      ),
      currency: Present<CurrencyCode>(
        CurrencyCode.parse('EUR')!,
        Provenance.read,
        ConfidenceState.green,
      ),
      needsReview: false,
      recognitionEngine: 'pdfium',
      sourceHash: aDocumentHash(seed),
    );

/// An entry of [docId] in [state], with everything else at a value a test can vary.
///
/// An entry in `sent` is given a record identifier by default, because one without is refused:
/// `sent` requires the identifier of the record the create was confirmed by (design §5.3).
HistoryEntry anEntry({
  String? docId,
  int revision = 1,
  DateTime? createdAt,
  DocumentState state = DocumentState.pending,
  bool duplicateFlagged = false,
  String? documentHash,
  TableRef? destination,
  String? thumbnailPath,
  CanonicalDocument? values,
  ConfidenceState? confidence,
  RecordId? ninoxRecordId,
  String? failureReason,
}) => HistoryEntry(
  docId: docId ?? aDocId(),
  revision: revision,
  createdAt: createdAt ?? DateTime.utc(2026, 10, 10, 9),
  state: state,
  documentHash: documentHash ?? aDocumentHash(),
  destination: destination ?? aDestination,
  duplicateFlagged: duplicateFlagged,
  thumbnailPath: thumbnailPath,
  values: values,
  confidence: confidence,
  ninoxRecordId:
      ninoxRecordId ??
      (state == DocumentState.sent ? const RecordId('record-1') : null),
  failureReason: failureReason,
);
