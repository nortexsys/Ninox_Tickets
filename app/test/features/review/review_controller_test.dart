import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ninox_client/ninox_client.dart' show Clock;
import 'package:paperdrop/features/review/capture_discard.dart';
import 'package:paperdrop/features/review/destination_acknowledgement.dart';
import 'package:paperdrop/features/review/review_controller.dart';
import 'package:paperdrop/features/review/review_field.dart';
import 'package:paperdrop/features/review/review_sender.dart';
import 'package:paperdrop/features/wizard/data/destination_store.dart';
import 'package:paperdrop/history/duplicate_checker.dart';
import 'package:paperdrop/history/history_entry.dart';
import 'package:paperdrop/history/history_store.dart';
import 'package:paperdrop_core/paperdrop_core.dart';
import 'package:path/path.dart' as p;

import '../../history/history_fixtures.dart';
import 'review_fixtures.dart';

/// The review controller against a store in a folder the test owns: **no device, no Ninox, no
/// token**, and a sender that records what a save was handed.
///
/// One group per requirement of the cut, so a scenario that stops holding says which requirement it
/// stopped holding for.
void main() {
  late Directory root;
  late FileHistoryStore store;

  setUp(() {
    root = Directory.systemTemp.createTempSync('paperdrop-review');
    store = FileHistoryStore(root);
  });

  tearDown(() {
    if (root.existsSync()) {
      root.deleteSync(recursive: true);
    }
  });

  /// The controller over the test's own pieces, with every collaborator replaceable.
  ReviewController aController({
    HistoryEntry? entry,
    DestinationStore? destinations,
    DestinationAcknowledgement? acknowledgement,
    ReviewSender? sender,
    CaptureDiscard? discard,
    Clock? clock,
  }) => ReviewController(
    store: store,
    duplicates: DuplicateChecker(store),
    destinations: destinations ?? FakeDestinationStore(),
    acknowledgement: acknowledgement ?? MemoryAcknowledgement(fixedDay()),
    sender: sender ?? FakeReviewSender(),
    discard: discard ?? FakeCaptureDiscard(),
    clock: clock ?? fixedClock,
    entry: entry,
  );

  group('[review-screen/six-core-fields-in-fixed-order]', () {
    test(
      'the stored document is shown as six fields in the fixed order',
      () async {
        final HistoryEntry entry = aReviewingEntry();
        await store.create(entry);
        final ReviewController controller = aController();

        await controller.load(entry.docId);

        final ReviewState state = controller.state;
        expect(state.ready, isTrue);
        expect(
          state.fields.map((ReviewFieldValue value) => value.text),
          <String>[
            '2026-10-01',
            'Acme Ibérica',
            'B00000000',
            '2026-0042',
            '12.10',
            'EUR',
          ],
        );
        expect(state.focusField, ReviewField.docDate);
      },
    );

    test('the entry a caller already has is not read again', () async {
      final HistoryEntry entry = aReviewingEntry();
      // Not stored anywhere: a controller given the entry must not need the store for it.
      final ReviewController controller = aController(entry: entry);

      await controller.load();

      expect(controller.state.ready, isTrue);
      expect(controller.state.entry, entry);
    });

    test('focus goes to what needs attention', () async {
      final CanonicalDocument confirmed = aConfirmedDocument();
      final CanonicalDocument withoutSupplier = CanonicalDocument(
        docDate: confirmed.docDate,
        docNumber: confirmed.docNumber,
        grossTotal: confirmed.grossTotal,
        currency: confirmed.currency,
        needsReview: false,
        recognitionEngine: 'pdf-text/pdfrx',
        sourceHash: confirmed.sourceHash,
      );
      final ReviewController controller = aController(
        entry: aReviewingEntry(values: withoutSupplier),
      );

      await controller.load();

      expect(controller.state.focusField, ReviewField.supplierName);
    });

    test(
      'a document read without a country row stays amber and says so',
      () async {
        final ReviewController controller = aController(
          entry: aReviewingEntry(values: aDocumentWithoutCountryRow()),
        );

        await controller.load();

        // No fourth state: the three of `validation-confidence` are all there is (PO, 2026-10-17).
        expect(controller.state.needsReview, isTrue);
        for (final ReviewFieldValue value in controller.state.fields) {
          expect(
            value.confidence,
            anyOf(
              ConfidenceState.amber,
              ConfidenceState.green,
              ConfidenceState.red,
            ),
          );
        }
        expect(
          reviewFieldValue(
            controller.state.document!,
            ReviewField.grossTotal,
          ).confidence,
          ConfidenceState.amber,
        );
      },
    );

    test(
      'a document that could not be opened is reported, not thrown',
      () async {
        final ReviewController controller = aController();

        await controller.load(aDocId(7));

        expect(controller.state.ready, isFalse);
        expect(controller.state.loadFailure, HistoryStoreFailureCode.notFound);
      },
    );
  });

  group('[review-screen/destination-bar]', () {
    test('the bar is pre-loaded with the destination used last', () async {
      final ReviewController controller = aController(entry: aReviewingEntry());

      await controller.load();

      expect(controller.state.destination!.teamId, 'team-1');
      expect(controller.state.destination!.databaseId, 'db-1');
      expect(controller.state.destination!.tableId, 'Expenses 2026');
    });

    test('the destination changes without losing the document', () async {
      final HistoryEntry entry = aReviewingEntry();
      await store.create(entry);
      final ReviewController controller = aController();
      await controller.load(entry.docId);
      controller.unlock(ReviewField.supplierName);
      controller.edit(ReviewField.supplierName, 'Typed by the user');

      controller.chooseDestination(anotherStoredDestination);

      expect(controller.state.destination!.tableId, 'Other table');
      expect(controller.state.entry, entry);
      expect(
        reviewFieldValue(
          controller.state.document!,
          ReviewField.supplierName,
        ).text,
        'Typed by the user',
      );
    });

    test(
      'a destination file that cannot be read still shows the bar',
      () async {
        final ReviewController controller = aController(
          entry: aReviewingEntry(),
          destinations: FakeDestinationStore()..unreadable = true,
        );

        await controller.load();

        expect(controller.state.destinations, isEmpty);
        expect(controller.state.destination!.tableId, 'Expenses 2026');
      },
    );
  });

  group('[review-screen/daily-destination-confirmation]', () {
    test('the first capture of a day requires acknowledgement', () async {
      final ReviewController controller = aController(
        entry: aReviewingEntry(),
        acknowledgement: MemoryAcknowledgement(),
      );

      await controller.load();

      expect(controller.state.acknowledgementRequired, isTrue);
      expect(controller.state.saveEnabled, isFalse);
    });

    test('later captures on the same day do not', () async {
      final ReviewController controller = aController(
        entry: aReviewingEntry(),
        acknowledgement: MemoryAcknowledgement(fixedDay()),
      );

      await controller.load();

      expect(controller.state.acknowledgementRequired, isFalse);
      expect(controller.state.acknowledgedOn, fixedDay());
    });

    test('a previous day does require it again', () async {
      final ReviewController controller = aController(
        entry: aReviewingEntry(),
        acknowledgement: MemoryAcknowledgement(CalendarDate(2026, 10, 16)),
      );

      await controller.load();

      expect(controller.state.acknowledgementRequired, isTrue);
    });

    test('acknowledging records the day and re-enables the save', () async {
      final MemoryAcknowledgement acknowledgement = MemoryAcknowledgement();
      final ReviewController controller = aController(
        entry: aReviewingEntry(),
        acknowledgement: acknowledgement,
      );
      await controller.load();

      await controller.acknowledge();

      expect(acknowledgement.day, fixedDay());
      expect(controller.state.acknowledgementRequired, isFalse);
      expect(controller.state.saveEnabled, isTrue);
    });
  });

  group('[review-screen/never-block-a-save]', () {
    test('an empty document can still be saved', () async {
      final FakeReviewSender sender = FakeReviewSender();
      final ReviewController controller = aController(
        entry: aReviewingEntry(withoutValues: true),
        sender: sender,
      );
      await controller.load();

      expect(
        controller.state.fields.every((ReviewFieldValue value) => !value.read),
        isTrue,
      );
      expect(controller.state.saveEnabled, isTrue);

      await controller.save();

      expect(sender.sent, hasLength(1));
      final CanonicalDocument sent = sender.sent.single.values!;
      expect(sent.grossTotal, isA<Absent<Money>>());
      expect(sent.supplierName, isA<Absent<String>>());
      expect(controller.state.outcome, isNotNull);
    });

    test('a red or amber field does not disable the action', () async {
      final ReviewController controller = aController(
        entry: aReviewingEntry(values: aTotalOnlyDocument()),
      );

      await controller.load();

      expect(controller.state.saveEnabled, isTrue);
      expect(
        controller.state.fields.any(
          (ReviewFieldValue value) => value.confidence == ConfidenceState.amber,
        ),
        isTrue,
      );
    });

    test('a store that refuses sends nothing and says so', () async {
      final FakeReviewSender sender = FakeReviewSender();
      final HistoryEntry earlier = anEntry(
        docId: aDocId(9),
        state: DocumentState.sent,
        values: aConfirmedDocument(),
        documentHash: aDocumentHash('earlier'),
      );
      final HistoryEntry entry = aReviewingEntry();
      await store.create(earlier);
      await store.create(entry);
      final ReviewController controller = aController(sender: sender);
      await controller.load(entry.docId);
      expect(controller.state.duplicate, isNotNull);
      // The entry the flag has to be written to is gone: the store refuses, and nothing is sent.
      File(p.join(root.path, entry.docId, FileHistoryStore.entryFileName))
          .deleteSync();

      await controller.save();

      expect(controller.state.saveFailed, isTrue);
      expect(sender.sent, isEmpty);
    });
  });

  group('[review-screen/user-edits-are-authoritative]', () {
    test('the correction is what reaches the send', () async {
      final FakeReviewSender sender = FakeReviewSender();
      final ReviewController controller = aController(
        entry: aReviewingEntry(),
        sender: sender,
      );
      await controller.load();
      controller.unlock(ReviewField.grossTotal);

      expect(controller.edit(ReviewField.grossTotal, '99.95'), isTrue);
      await controller.save();

      expect(
        sender.sent.single.values!.grossTotal,
        Edited<Money>(Money(9995, euro)),
      );
    });

    test('a green value opens only after its lock is tapped', () async {
      final ReviewController controller = aController(entry: aReviewingEntry());
      await controller.load();

      expect(controller.canEdit(ReviewField.grossTotal), isFalse);
      expect(controller.edit(ReviewField.grossTotal, '1.00'), isFalse);
      expect(
        controller.state.document!.grossTotal,
        aConfirmedDocument().grossTotal,
      );

      controller.unlock(ReviewField.grossTotal);

      expect(controller.canEdit(ReviewField.grossTotal), isTrue);
      expect(controller.edit(ReviewField.grossTotal, '1.00'), isTrue);
    });

    test('an amber value is editable without unlocking', () async {
      final ReviewController controller = aController(entry: aReviewingEntry());
      await controller.load();

      expect(controller.edit(ReviewField.supplierName, 'Corrected'), isTrue);
      expect(
        reviewFieldValue(
          controller.state.document!,
          ReviewField.supplierName,
        ).edited,
        isTrue,
      );
    });

    test('a refused edit says why and changes nothing', () async {
      final ReviewController controller = aController(entry: aReviewingEntry());
      await controller.load();
      controller.unlock(ReviewField.docDate);

      expect(controller.edit(ReviewField.docDate, '01/10/2026'), isFalse);
      expect(controller.state.editRefusal, ReviewEditRefusal.notADate);
      expect(controller.state.document!.docDate, aConfirmedDocument().docDate);
    });
  });

  group('[review-screen/amounts-block-collapse-rule]', () {
    test('the block is the check\'s, and the values are the user\'s', () async {
      final ReviewController controller = aController(entry: aReviewingEntry());
      await controller.load();
      expect(controller.state.amounts!.collapsed, isTrue);

      controller.unlock(ReviewField.grossTotal);
      controller.edit(ReviewField.grossTotal, '99.95');

      // DEC-007: the block stays as the check left it, and the amount is marked as edited.
      expect(controller.state.amounts!.collapsed, isTrue);
      expect(controller.state.amounts!.totalEdited, isTrue);
      expect(controller.state.amounts!.total, Money(9995, euro));
    });
  });

  group('[review-screen/duplicate-notice]', () {
    test('the notice links to what already exists', () async {
      final HistoryEntry earlier = anEntry(
        docId: aDocId(9),
        state: DocumentState.sent,
        values: aConfirmedDocument(),
        documentHash: aDocumentHash('earlier'),
      );
      final HistoryEntry entry = aReviewingEntry();
      await store.create(earlier);
      await store.create(entry);
      final ReviewController controller = aController();

      await controller.load(entry.docId);

      expect(controller.state.duplicate!.docId, aDocId(9));
      expect(controller.state.duplicateLink, isNotNull);
      expect(controller.state.duplicateLink.toString(), contains('team-1'));
      expect(controller.state.duplicateLink.toString(), contains('record-1'));
    });
  });

  group('[review-screen/discard-a-document]', () {
    test('discarding leaves nothing behind', () async {
      final HistoryEntry entry = aReviewingEntry();
      await store.create(entry);
      final File original = File(p.join(root.path, entry.docId, 'original.pdf'))
        ..writeAsStringSync('%PDF-1.7');
      final File thumbnail = File(p.join(root.path, entry.docId, 'thumb.png'))
        ..writeAsStringSync('not a picture');
      final FakeReviewSender sender = FakeReviewSender();
      final ReviewController controller = aController(
        entry: entry,
        sender: sender,
        discard: FileCaptureDiscard(root),
      );
      await controller.load();
      expect(original.existsSync(), isTrue);

      final bool gone = await controller.discardDocument();

      expect(gone, isTrue);
      expect(controller.state.discarded, isTrue);
      expect(Directory(p.join(root.path, entry.docId)).existsSync(), isFalse);
      expect(thumbnail.existsSync(), isFalse);
      expect((await store.list()).entries, isEmpty);
      expect(sender.sent, isEmpty);
    });

    test(
      'a discard the file system refuses deletes nothing and claims nothing',
      () async {
        final ReviewController controller = aController(
          entry: aReviewingEntry(),
          discard: FakeCaptureDiscard()..refuse = true,
        );
        await controller.load();

        final bool gone = await controller.discardDocument();

        expect(gone, isFalse);
        expect(controller.state.discarded, isFalse);
      },
    );
  });
}
