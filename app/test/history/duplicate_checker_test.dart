/// The duplicate criteria: hash, or supplier and date and total together, read side against local
/// history (`document-history/duplicate-criteria`, FR-DUP-001; design §2 of
/// `implement-history-retry-duplicates`).
///
/// The four scenarios of the requirement drive this file, one test each, and the "read-side" one is
/// proved with a store that counts its calls rather than with a comment.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:paperdrop/history/duplicate_checker.dart';
import 'package:paperdrop/history/history_entry.dart';
import 'package:paperdrop/history/history_store.dart';
import 'package:paperdrop_core/paperdrop_core.dart';
import 'package:path/path.dart' as p;

import 'history_fixtures.dart';
import 'send_fakes.dart';

void main() {
  late Directory root;
  late FileHistoryStore store;
  late DuplicateChecker checker;

  setUp(() {
    root = Directory.systemTemp.createTempSync('paperdrop-duplicate-test');
    store = FileHistoryStore(root);
    checker = DuplicateChecker(store);
  });

  tearDown(() {
    if (root.existsSync()) {
      root.deleteSync(recursive: true);
    }
  });

  /// A document with the three content values the criteria compare, each optionally absent.
  ///
  /// [supplier] is an edited value — the user's own, which is the value sent
  /// (`review-screen/user-edits-are-authoritative`) — and an absent one is the `Absent` case, which
  /// is what "nothing was read" means in the core's model. [currency] is the document's own, because
  /// the core refuses a total in another currency than the document's.
  CanonicalDocument aDocument({
    String? supplier = 'ACME Ibérica, S.L.',
    CalendarDate? date,
    Money? total,
    String currency = 'EUR',
  }) => CanonicalDocument(
    docDate: Present<CalendarDate>(
      date ?? CalendarDate(2026, 10, 1),
      Provenance.read,
      ConfidenceState.green,
    ),
    supplierName: supplier == null
        ? const Absent<String>()
        : Edited<String>(supplier),
    grossTotal: total == null
        ? const Absent<Money>()
        : Present<Money>(total, Provenance.read, ConfidenceState.green),
    currency: Present<CurrencyCode>(
      CurrencyCode.parse(currency)!,
      Provenance.read,
      ConfidenceState.green,
    ),
    needsReview: false,
    recognitionEngine: 'pdfium',
    sourceHash: aDocumentHash('duplicate-test'),
  );

  /// The total the fixtures and the candidates share unless a test varies it: 19,99 EUR.
  Money total([int minor = 1999]) => Money(minor, CurrencyCode.parse('EUR')!);

  group('normaliseSupplier', () {
    test('case-folds and collapses whitespace, and nothing else', () {
      expect(
        normaliseSupplier('  ACME   Ibérica,\n S.L. '),
        'acme ibérica, s.l.',
      );
    });

    test('a supplier that normalises to nothing identifies nothing', () {
      expect(normaliseSupplier('   '), isNull);
      expect(normaliseSupplier(''), isNull);
      expect(normaliseSupplier(null), isNull);
    });

    test('no fuzzy matching: two different spellings stay two suppliers', () {
      expect(
        normaliseSupplier('Acme Iberica SL'),
        isNot(normaliseSupplier('ACME Ibérica, S.L.')),
      );
    });
  });

  group('check', () {
    test('[document-history/duplicate-criteria] the same file captured twice matches on '
        'hash', () async {
      final HistoryEntry earlier = anEntry(
        docId: aDocId(1),
        state: DocumentState.sent,
        documentHash: aDocumentHash('receipt-photo'),
      );
      await store.create(earlier);

      final DuplicateMatch? match = await checker.check(
        DuplicateCandidate(
          docId: aDocId(2),
          documentHash: aDocumentHash('receipt-photo'),
        ),
      );

      expect(match, isNotNull);
      expect(match!.docId, earlier.docId);
      expect(match.criterion, DuplicateCriterion.hash);
    });

    test('[document-history/duplicate-criteria] two photographs of one receipt match on '
        'their content', () async {
      // Two different captures of one receipt: different bytes, so a different hash, and one of
      // them recognised the supplier's name spaced differently.
      final HistoryEntry earlier = anEntry(
        docId: aDocId(11),
        state: DocumentState.sent,
        documentHash: aDocumentHash('photo-1'),
        values: aDocument(supplier: 'ACME Ibérica,  S.L.', total: total()),
      );
      await store.create(earlier);

      final DuplicateMatch? match = await checker.check(
        DuplicateCandidate.fromDocument(
          docId: aDocId(12),
          documentHash: aDocumentHash('photo-2'),
          values: aDocument(supplier: 'acme ibérica, s.l.', total: total()),
        ),
      );

      expect(match, isNotNull);
      expect(match!.docId, earlier.docId);
      expect(match.criterion, DuplicateCriterion.content);
    });

    test('[document-history/duplicate-criteria] two documents from one supplier on one day '
        'do not match', () async {
      final HistoryEntry earlier = anEntry(
        docId: aDocId(21),
        state: DocumentState.sent,
        documentHash: aDocumentHash('day-1'),
        values: aDocument(total: total(1999)),
      );
      await store.create(earlier);

      final DuplicateMatch? match = await checker.check(
        DuplicateCandidate.fromDocument(
          docId: aDocId(22),
          documentHash: aDocumentHash('day-2'),
          values: aDocument(total: total(4999)),
        ),
      );

      expect(match, isNull);
    });

    test(
      'a different date on the same total is not a duplicate either',
      () async {
        final HistoryEntry earlier = anEntry(
          docId: aDocId(31),
          state: DocumentState.sent,
          documentHash: aDocumentHash('september'),
          values: aDocument(date: CalendarDate(2026, 9, 30)),
        );
        await store.create(earlier);

        final DuplicateMatch? match = await checker.check(
          DuplicateCandidate.fromDocument(
            docId: aDocId(32),
            documentHash: aDocumentHash('october'),
            values: aDocument(date: CalendarDate(2026, 10, 1)),
          ),
        );

        expect(match, isNull);
      },
    );

    test(
      'the same minor units in another currency are another total',
      () async {
        final HistoryEntry earlier = anEntry(
          docId: aDocId(41),
          state: DocumentState.sent,
          documentHash: aDocumentHash('eur'),
          values: aDocument(total: total(1999)),
        );
        await store.create(earlier);

        final DuplicateMatch? match = await checker.check(
          DuplicateCandidate.fromDocument(
            docId: aDocId(42),
            documentHash: aDocumentHash('chf'),
            values: aDocument(
              currency: 'CHF',
              total: Money(1999, CurrencyCode.parse('CHF')!),
            ),
          ),
        );

        expect(match, isNull);
      },
    );

    test('a document still in review is not an earlier send', () async {
      final HistoryEntry earlier = anEntry(
        docId: aDocId(51),
        state: DocumentState.reviewing,
        documentHash: aDocumentHash('not-sent'),
        values: aDocument(),
      );
      await store.create(earlier);

      expect(
        await checker.check(
          DuplicateCandidate(
            docId: aDocId(52),
            documentHash: aDocumentHash('not-sent'),
          ),
        ),
        isNull,
        reason:
            'the criterion is an earlier send, and this document is not one',
      );
    });

    test('a document is not a duplicate of its own entry', () async {
      final String docId = aDocId(61);
      await store.create(
        anEntry(
          docId: docId,
          state: DocumentState.sent,
          documentHash: aDocumentHash('itself'),
          values: aDocument(),
        ),
      );

      expect(
        await checker.check(
          DuplicateCandidate(
            docId: docId,
            documentHash: aDocumentHash('itself'),
            supplier: 'ACME Ibérica, S.L.',
            docDate: CalendarDate(2026, 10, 1),
            total: total(),
          ),
        ),
        isNull,
      );
    });

    test('a candidate with nothing read cannot match on content', () async {
      await store.create(
        anEntry(
          docId: aDocId(71),
          state: DocumentState.sent,
          documentHash: aDocumentHash('stored'),
          values: aDocument(),
        ),
      );

      final DuplicateMatch? match = await checker.check(
        DuplicateCandidate(
          docId: aDocId(72),
          documentHash: aDocumentHash('other'),
          supplier: 'ACME Ibérica, S.L.',
          // No date and no total: an unknown total is not the same as the stored one.
        ),
      );

      expect(match, isNull);
    });

    test('the hash wins when both criteria would hit', () async {
      await store.create(
        anEntry(
          docId: aDocId(81),
          state: DocumentState.sent,
          documentHash: aDocumentHash('both'),
          values: aDocument(),
        ),
      );

      final DuplicateMatch? match = await checker.check(
        DuplicateCandidate(
          docId: aDocId(82),
          documentHash: aDocumentHash('both'),
          supplier: 'ACME Ibérica, S.L.',
          docDate: CalendarDate(2026, 10, 1),
          total: total(),
        ),
      );

      expect(match!.criterion, DuplicateCriterion.hash);
    });

    test('an unreadable entry is skipped, never fatal', () async {
      // A document whose `entry.json` this app did not write: `list()` reports it and goes on.
      final Directory broken = Directory(p.join(root.path, aDocId(91)))
        ..createSync(recursive: true);
      File(p.join(broken.path, FileHistoryStore.entryFileName))
          .writeAsStringSync('{"docId": 4');
      final HistoryEntry earlier = anEntry(
        docId: aDocId(92),
        state: DocumentState.sent,
        documentHash: aDocumentHash('readable'),
      );
      await store.create(earlier);

      final DuplicateMatch? match = await checker.check(
        DuplicateCandidate(
          docId: aDocId(93),
          documentHash: aDocumentHash('readable'),
        ),
      );

      expect(match, isNotNull);
      expect(match!.docId, earlier.docId);
    });

    test('[document-history/duplicate-criteria] the check is read-side and cannot use a '
        'marker field', () async {
      final CountingStore counting = CountingStore(store);
      final DuplicateChecker countingChecker = DuplicateChecker(counting);
      final HistoryEntry earlier = anEntry(
        docId: aDocId(101),
        state: DocumentState.sent,
        documentHash: aDocumentHash('read-side'),
      );
      await store.create(earlier);

      expect(
        await countingChecker.check(
          DuplicateCandidate(
            docId: aDocId(102),
            documentHash: aDocumentHash('read-side'),
          ),
        ),
        isNotNull,
      );

      expect(counting.calls, <String>['list']);
      final HistoryEntry after = await store.get(earlier.docId);
      expect(after, earlier, reason: 'the check wrote nothing at all');
      expect(
        after.duplicateFlagged,
        isFalse,
        reason: 'flagging is a separate, explicit act',
      );
    });
  });

  group('markDuplicate', () {
    test(
      'sets the flag without changing the state, and bumps the revision',
      () async {
        final HistoryEntry stored = anEntry(
          docId: aDocId(111),
          revision: 3,
          state: DocumentState.reviewing,
        );
        await store.create(stored);

        final HistoryEntry flagged = await checker.markDuplicate(stored.docId);

        expect(flagged.duplicateFlagged, isTrue);
        expect(
          flagged.state,
          DocumentState.reviewing,
          reason: 'DEC-016: the flag sits beside the state the document has',
        );
        expect(flagged.revision, 4);
        expect(await store.get(stored.docId), flagged);
      },
    );

    test('an entry that is already flagged is returned as it is', () async {
      final HistoryEntry flagged = anEntry(
        docId: aDocId(121),
        state: DocumentState.reviewing,
        duplicateFlagged: true,
      );
      await store.create(flagged);
      final CountingStore counting = CountingStore(store);
      final DuplicateChecker countingChecker = DuplicateChecker(counting);

      expect(await countingChecker.markDuplicate(flagged.docId), flagged);
      expect(counting.calls, <String>['get']);
    });

    test('a document with no entry is refused by the store', () async {
      expect(
        () => checker.markDuplicate(aDocId(131)),
        throwsA(
          isA<HistoryStoreFailure>().having(
            (HistoryStoreFailure failure) => failure.code,
            'code',
            HistoryStoreFailureCode.notFound,
          ),
        ),
      );
    });
  });
}
