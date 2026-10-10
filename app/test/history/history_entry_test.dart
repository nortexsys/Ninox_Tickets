/// The entry of a document: what it holds, what it refuses, and how it round-trips
/// (FR-HIS-001, FR-HIS-002; design §5.2).
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ninox_client/ninox_client.dart';
import 'package:paperdrop/history/history_entry.dart';
import 'package:paperdrop_core/paperdrop_core.dart';

import 'history_fixtures.dart';

void main() {
  test('[document-history/content-of-a-history-entry] all eight items are '
      'present', () {
    // The scenario's *opened* half is the history detail screen (M2). What is
    // proved here is the half this change owns: an entry carries all eight items
    // of FR-HIS-001 — the thumbnail, the values with their provenance, the
    // destination, the state, the confidence, the hash and, once sent, the
    // record identifier — and gives every one of them back.
    final HistoryEntry entry = anEntry(
      state: DocumentState.sent,
      confidence: ConfidenceState.amber,
      values: aCanonicalDocument(),
      thumbnailPath: 'thumbs/one.jpg',
    );

    expect(entry.thumbnailPath, 'thumbs/one.jpg');
    expect(entry.values, isNotNull);
    expect(entry.destination, aDestination);
    expect(entry.state, DocumentState.sent);
    expect(entry.confidence, ConfidenceState.amber);
    expect(entry.documentHash, aDocumentHash());
    expect(entry.ninoxRecordId, const RecordId('record-1'));

    expect(HistoryEntry.fromJson(entry.toJson()), entry);
  });

  test('an entry round-trips through the core\'s own JSON', () {
    // Design §5.6: "round trip with money {"minor": 1999, "currency": "EUR"} and
    // provenance by wire name". The nested value is the core's own JSON — the
    // store is a reader of the contract, not a second author (BR-09) — so the
    // expected shape below is the one `paperdrop_core` writes, compared whole:
    // a key this store had renamed or an amount it had turned into a decimal
    // would fail here.
    final HistoryEntry entry = anEntry(
      state: DocumentState.sending,
      values: aCanonicalDocument(),
    );

    final Object? valuesJson = entry.toJson()['values'];
    expect(valuesJson, isA<Map<String, Object?>>());
    final Map<String, Object?> values = valuesJson! as Map<String, Object?>;
    expect(values['grossTotal'], <String, Object?>{
      'state': 'present',
      'value': <String, Object?>{'minor': 1999, 'currency': 'EUR'},
      'provenance': 'read',
      'confidence': 'green',
      'source': 'document',
    });

    final HistoryEntry read = HistoryEntry.fromJson(
      jsonDecode(jsonEncode(entry.toJson())),
    );
    final Present<Money>? total = read.values?.grossTotal as Present<Money>?;
    expect(total?.value, Money(1999, CurrencyCode.parse('EUR')!));
    expect(total?.provenance, Provenance.read);
    expect(total?.provenance.wireName, 'read');
    expect(read, entry);
  });

  test('provenance is visible locally though it is never sent', () {
    // Names the `content-of-a-history-entry` scenario *provenance is visible
    // locally though it is never sent*, and proves its local half only: a sent
    // entry keeps the provenance of its values, by wire name, where history can
    // read it. The other half — that the provenance was never written to Ninox —
    // is the send lane's, and no test here can prove it.
    final HistoryEntry entry = anEntry(
      state: DocumentState.sent,
      values: aCanonicalDocument(),
    );

    expect(entry.values?.grossTotal, isA<Present<Money>>());
    expect(
      (entry.values!.docDate as Present<CalendarDate>).provenance.wireName,
      'read',
    );
    expect(HistoryEntry.fromJson(entry.toJson()).values, entry.values);
  });

  test('[document-history/document-states] no entry holds two states at once', () {
    // Exactly one state, and DEC-016's flag is not a second one: eight stored
    // values, one `state` string in the file beside a boolean, and neither the
    // functional's finer steps nor `duplicate-flagged` readable as a state.
    expect(DocumentState.values, hasLength(8));

    for (final DocumentState state in DocumentState.values) {
      final HistoryEntry entry = anEntry(state: state, duplicateFlagged: true);
      final Map<String, Object?> stored = entry.toJson();

      expect(entry.state, state);
      expect(stored['state'], state.name);
      expect(stored['state'], isA<String>());
      expect(stored['duplicateFlagged'], isTrue);
      expect(DocumentState.fromJson(stored['state']), state);
    }

    for (final String notAState in <String>[
      'duplicate_flagged',
      'duplicate-flagged',
      'capturing',
      'ingested',
      'attaching',
      'reading_back',
      'reconciling',
      'discarded',
      '',
    ]) {
      expect(
        () => DocumentState.fromJson(notAState),
        throwsFormatException,
        reason: '`$notAState` is not one of the eight stored states',
      );
    }
  });

  test('a sent entry without a record identifier is refused', () {
    // The refusal half of `document-states` · *a completed send carries its
    // record identifier*: `sent` requires the identifier of the record the
    // create was confirmed by (design §5.3), so an entry in `sent` without one
    // cannot be built and cannot be read back from a file. The entry is built
    // here by hand, because the fixture supplies a record identifier to every
    // entry in `sent` — an entry without one is the case under test.
    expect(
      () => HistoryEntry(
        docId: aDocId(),
        revision: 1,
        createdAt: DateTime.utc(2026, 10, 10, 9),
        state: DocumentState.sent,
        documentHash: aDocumentHash(),
        destination: aDestination,
      ),
      throwsArgumentError,
    );
    expect(
      () => HistoryEntry.fromJson(<String, Object?>{
        ...anEntry(state: DocumentState.sending).toJson(),
        'state': 'sent',
      }),
      throwsFormatException,
    );
  });

  test('an entry that could not be true is refused', () {
    // Each of these is a value that would make the entry claim something false,
    // and every one of them is refused where it is written and where it is read.
    expect(() => anEntry(docId: '../escape'), throwsArgumentError);
    expect(() => anEntry(revision: 0), throwsArgumentError);
    expect(
      () => anEntry(documentHash: aDocumentHash().toUpperCase()),
      throwsArgumentError,
    );
    expect(() => anEntry(thumbnailPath: ''), throwsArgumentError);
    expect(
      () =>
          anEntry(state: DocumentState.sent, ninoxRecordId: const RecordId('')),
      throwsArgumentError,
    );
    // A failure reason is a code, never a message with a value in it.
    expect(
      () => anEntry(failureReason: 'failed for 1.999,00 EUR'),
      throwsArgumentError,
    );
    expect(
      () => anEntry(failureReason: 'the response was lost'),
      throwsArgumentError,
    );
    expect(
      anEntry(
        state: DocumentState.failed,
        failureReason: 'attachment_incomplete',
      ).failureReason,
      'attachment_incomplete',
    );
  });

  test('a file that is not an entry is refused, never read as no entry', () {
    final Map<String, Object?> stored = anEntry().toJson();

    for (final Object? broken in <Object?>[
      <String, Object?>{...stored}..remove('docId'),
      <String, Object?>{...stored, 'revision': '1'},
      <String, Object?>{...stored, 'createdAt': 'yesterday'},
      <String, Object?>{...stored, 'documentHash': 'not a digest'},
      <String, Object?>{
        ...stored,
        'destination': <String, Object?>{'team': 't'},
      },
      <String, Object?>{
        ...stored,
        'values': <String, Object?>{'grossTotal': 1},
      },
      <String, Object?>{...stored, 'confidence': 'purple'},
      <String, Object?>{...stored, 'failureReason': <String, Object?>{}},
      'a string where an object belongs',
    ]) {
      expect(
        () => HistoryEntry.fromJson(broken),
        throwsFormatException,
        reason: 'a stored entry is read strictly',
      );
    }
  });

  test('the entry prints its state line and no document content', () {
    // A diagnostic carries no document content (`local-config-privacy` · *no
    // document content appears in a diagnostic*): the state line names the state
    // and the revision, and no amount, path, hash or record identifier.
    final HistoryEntry entry = anEntry(
      state: DocumentState.sent,
      values: aCanonicalDocument(),
      thumbnailPath: 'thumbs/one.jpg',
    );

    final String text = entry.toString();
    expect(text, contains('sent'));
    expect(text, isNot(contains('1999')));
    expect(text, isNot(contains('EUR')));
    expect(text, isNot(contains('one.jpg')));
    expect(text, isNot(contains(entry.documentHash)));
    expect(text, isNot(contains('record-1')));
  });
}
