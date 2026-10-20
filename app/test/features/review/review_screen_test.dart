import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ninox_client/ninox_client.dart' show SendOutcome;
import 'package:paperdrop/features/review/capture_discard.dart';
import 'package:paperdrop/features/review/destination_acknowledgement.dart';
import 'package:paperdrop/features/review/review_amounts.dart';
import 'package:paperdrop/features/review/review_controller.dart';
import 'package:paperdrop/features/review/review_field.dart';
import 'package:paperdrop/features/review/review_screen.dart';
import 'package:paperdrop/features/review/review_second_read.dart';
import 'package:paperdrop/features/review/review_sender.dart';
import 'package:paperdrop/features/review/review_thumbnail.dart';
import 'package:paperdrop/features/wizard/data/destination_store.dart';
import 'package:paperdrop/features/wizard/destination.dart' show Destination;
import 'package:paperdrop/history/duplicate_checker.dart';
import 'package:paperdrop/history/history_entry.dart';
import 'package:paperdrop/l10n/generated/app_localizations.dart';
import 'package:paperdrop/settings/country_setting.dart';
import 'package:paperdrop_core/paperdrop_core.dart';

import '../../history/history_fixtures.dart';
import 'review_fixtures.dart';

/// The review screen as a person meets it: the six fields, the amounts block, the bar, the
/// acknowledgement, the duplicate notice, the save and the discarding, all over a store in memory.
///
/// **No call leaves the machine, and no widget test waits on the file system** (design §7): the
/// store is `MemoryHistoryStore`, the sender is scripted, and the destination store and the
/// acknowledgement are in memory. The file-backed store, the discard that deletes a folder and the
/// acknowledgement file are covered by their own host tests, which are plain `test` bodies.
void main() {
  late AppLocalizations en;
  late MemoryHistoryStore store;

  setUpAll(() async {
    en = await AppLocalizations.delegate.load(const Locale('en'));
  });

  setUp(() {
    store = MemoryHistoryStore();
  });

  /// The controller the screen is pumped over, with every collaborator replaceable.
  ReviewController aController({
    HistoryEntry? entry,
    DestinationStore? destinations,
    DestinationAcknowledgement? acknowledgement,
    ReviewSender? sender,
    CaptureDiscard? discard,
    CountrySettingStore? country,
    ReviewSecondRead? secondRead,
  }) => ReviewController(
    store: store,
    duplicates: DuplicateChecker(store),
    destinations:
        destinations ??
        FakeDestinationStore(<Destination>[
          aStoredDestination,
          anotherStoredDestination,
        ]),
    acknowledgement: acknowledgement ?? MemoryAcknowledgement(fixedDay()),
    sender: sender ?? FakeReviewSender(),
    discard: discard ?? FakeCaptureDiscard(),
    country: country ?? FakeCountrySetting(),
    secondRead: secondRead ?? FakeReviewSecondRead(),
    clock: fixedClock,
    entry: entry,
  );

  /// Pumps the screen over [controller] and lets the load and the first frame settle.
  ///
  /// The default window is tall enough to hold the whole screen: a `ListView` builds only what is
  /// visible, and a field below the fold is not there to be found.
  Future<void> pumpReview(
    WidgetTester tester,
    ReviewController controller, {
    Size screen = const Size(600, 1600),
  }) async {
    tester.view.physicalSize = screen;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ReviewScreen(controller: controller),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// The plain-language name of one field, as the screen reads it from the resources.
  String fieldLabel(ReviewField field) => switch (field) {
    ReviewField.docDate => en.reviewFieldDocDate,
    ReviewField.supplierName => en.reviewFieldSupplierName,
    ReviewField.supplierTaxId => en.reviewFieldSupplierTaxId,
    ReviewField.docNumber => en.reviewFieldDocNumber,
    ReviewField.grossTotal => en.reviewFieldGrossTotal,
    ReviewField.currency => en.reviewFieldCurrency,
  };

  /// The value text of one field of a fully read document, as the screen shows it.
  String fieldText(ReviewField field) {
    final ReviewFieldValue value = reviewFieldValue(
      aConfirmedDocument(),
      field,
    );
    return en.reviewFieldValue(
      fieldLabel(field),
      value.text.isEmpty ? en.reviewValueNotRead : value.text,
    );
  }

  group('[review-screen/six-core-fields-in-fixed-order]', () {
    testWidgets('the six fields appear in the same order, with their colours', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpReview(tester, aController(entry: aReviewingEntry()));

      double previous = 0;
      for (final ReviewField field in ReviewField.values) {
        final double top = tester
            .getTopLeft(find.byKey(ReviewScreen.fieldKey(field)))
            .dy;
        expect(top, greaterThan(previous), reason: field.wireName);
        previous = top;
      }
      expect(find.text(fieldText(ReviewField.docDate)), findsOneWidget);

      // The colour is never the only cue (NFR-ACC-001): the state's name is in the semantics tree.
      expect(
        find.bySemanticsLabel(RegExp(en.reviewConfidenceGreen)),
        findsWidgets,
      );
      expect(
        find.bySemanticsLabel(RegExp(en.reviewConfidenceAmber)),
        findsWidgets,
      );
      handle.dispose();
    });

    testWidgets('focus lands on the first field that was not read', (
      WidgetTester tester,
    ) async {
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
      await pumpReview(
        tester,
        aController(entry: aReviewingEntry(values: withoutSupplier)),
      );

      expect(
        tester.binding.focusManager.primaryFocus?.debugLabel,
        'review-field-supplier_name',
      );
    });

    testWidgets('a fully read document focuses its first field', (
      WidgetTester tester,
    ) async {
      await pumpReview(tester, aController(entry: aReviewingEntry()));

      expect(
        tester.binding.focusManager.primaryFocus?.debugLabel,
        'review-field-doc_date',
      );
    });

    testWidgets('an amber value is edited in place and shows the edited mark', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpReview(tester, aController(entry: aReviewingEntry()));

      await tester.tap(find.text(fieldText(ReviewField.supplierName)));
      await tester.pumpAndSettle();
      expect(
        find.byKey(ReviewScreen.editorKey(ReviewField.supplierName)),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(ReviewScreen.editorKey(ReviewField.supplierName)),
        'Corrected S.L.',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(
        find.text(
          en.reviewFieldValue(en.reviewFieldSupplierName, 'Corrected S.L.'),
        ),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel(RegExp(en.reviewEdited)), findsOneWidget);
      handle.dispose();
    });

    testWidgets('a green value opens only after its lock is tapped', (
      WidgetTester tester,
    ) async {
      await pumpReview(tester, aController(entry: aReviewingEntry()));

      await tester.tap(find.text(fieldText(ReviewField.grossTotal)));
      await tester.pumpAndSettle();
      expect(
        find.byKey(ReviewScreen.editorKey(ReviewField.grossTotal)),
        findsNothing,
      );

      await tester.tap(
        find.byKey(ReviewScreen.lockKey(ReviewField.grossTotal)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(fieldText(ReviewField.grossTotal)));
      await tester.pumpAndSettle();

      expect(
        find.byKey(ReviewScreen.editorKey(ReviewField.grossTotal)),
        findsOneWidget,
      );
    });
  });

  group('[review-screen/amounts-block-collapse-rule]', () {
    testWidgets('a confirmed document shows a single confirming line', (
      WidgetTester tester,
    ) async {
      await pumpReview(tester, aController(entry: aReviewingEntry()));

      expect(find.byKey(ReviewScreen.amountsConfirmedKey), findsOneWidget);
      expect(find.text(en.reviewAmountsConfirmed('12.10')), findsOneWidget);
    });

    testWidgets('a slip with only a total shows the block expanded', (
      WidgetTester tester,
    ) async {
      await pumpReview(
        tester,
        aController(entry: aReviewingEntry(values: aTotalOnlyDocument())),
      );

      expect(find.byKey(ReviewScreen.amountsConfirmedKey), findsNothing);
      expect(
        find.byKey(ReviewScreen.amountLineKey(AmountLineKind.total, 0)),
        findsOneWidget,
      );
      expect(find.text(en.reviewAmountsTotal('19.99')), findsOneWidget);
    });

    testWidgets('a multi-rate receipt whose check fails shows every slot', (
      WidgetTester tester,
    ) async {
      await pumpReview(
        tester,
        aController(entry: aReviewingEntry(values: aMultiRateDocument())),
      );

      expect(find.text(en.reviewAmountsSlot('21', '2.10')), findsOneWidget);
      expect(find.text(en.reviewAmountsSlot('10', '0.90')), findsOneWidget);
    });
  });

  group('[review-screen/destination-bar]', () {
    testWidgets(
      'the bar shows team, database and table, and changes the destination',
      (WidgetTester tester) async {
        final ReviewController controller = aController(
          entry: aReviewingEntry(),
        );
        await pumpReview(tester, controller);

        expect(
          find.text(en.reviewDestinationBar('team-1', 'db-1', 'Expenses 2026')),
          findsOneWidget,
        );

        await tester.tap(find.byKey(ReviewScreen.destinationBarKey));
        await tester.pumpAndSettle();
        expect(find.text(en.reviewDestinationTitle), findsOneWidget);

        await tester.tap(
          find.text(en.reviewDestinationBar('team-2', 'db-2', 'Other table')),
        );
        await tester.pumpAndSettle();

        // The document is still there when the selection closes (FR-REV-001).
        expect(
          find.text(en.reviewDestinationBar('team-2', 'db-2', 'Other table')),
          findsOneWidget,
        );
        expect(find.text(fieldText(ReviewField.supplierName)), findsOneWidget);
      },
    );
  });

  group('[review-screen/daily-destination-confirmation]', () {
    testWidgets(
      'the first capture of a day disables the save until acknowledged',
      (WidgetTester tester) async {
        final MemoryAcknowledgement acknowledgement = MemoryAcknowledgement();
        await pumpReview(
          tester,
          aController(
            entry: aReviewingEntry(),
            acknowledgement: acknowledgement,
          ),
        );

        expect(find.text(en.reviewAcknowledgePrompt), findsOneWidget);
        expect(
          tester
              .widget<FilledButton>(find.byKey(ReviewScreen.saveKey))
              .onPressed,
          isNull,
        );

        await tester.tap(find.byKey(ReviewScreen.acknowledgeKey));
        await tester.pumpAndSettle();

        expect(find.text(en.reviewAcknowledgePrompt), findsNothing);
        expect(
          tester
              .widget<FilledButton>(find.byKey(ReviewScreen.saveKey))
              .onPressed,
          isNotNull,
        );
        expect(acknowledgement.day, fixedDay());
      },
    );

    testWidgets('a later capture of the same day asks nothing', (
      WidgetTester tester,
    ) async {
      await pumpReview(tester, aController(entry: aReviewingEntry()));

      expect(find.text(en.reviewAcknowledgePrompt), findsNothing);
      expect(
        tester.widget<FilledButton>(find.byKey(ReviewScreen.saveKey)).onPressed,
        isNotNull,
      );
    });
  });

  group('[review-screen/save-button-names-the-destination]', () {
    testWidgets(
      'the label names the table and the button stays at the bottom',
      (WidgetTester tester) async {
        final ReviewController controller = aController(
          entry: aReviewingEntry(values: aMultiRateDocument()),
        );
        await pumpReview(tester, controller, screen: const Size(400, 700));

        expect(find.text(en.reviewSaveAction('Expenses 2026')), findsOneWidget);
        final Offset before = tester.getTopLeft(
          find.byKey(ReviewScreen.saveKey),
        );

        await tester.drag(find.byType(ListView), const Offset(0, -240));
        await tester.pumpAndSettle();

        expect(
          tester.getTopLeft(find.byKey(ReviewScreen.saveKey)),
          before,
          reason:
              'the save button is fixed at the bottom, not part of the scroll',
        );
      },
    );
  });

  group('[review-screen/duplicate-notice]', () {
    testWidgets('the notice appears, links, and lets the save proceed', (
      WidgetTester tester,
    ) async {
      final HistoryEntry earlier = anEntry(
        docId: aDocId(9),
        state: DocumentState.sent,
        values: aConfirmedDocument(),
        documentHash: aDocumentHash('earlier'),
      );
      final HistoryEntry entry = aReviewingEntry();
      await store.create(earlier);
      await store.create(entry);
      final FakeReviewSender sender = FakeReviewSender();
      Uri? opened;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ReviewScreen(
            controller: aController(entry: entry, sender: sender),
            onOpenDuplicate: (Uri link) => opened = link,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(ReviewScreen.duplicateNoticeKey), findsOneWidget);
      expect(find.text(en.reviewDuplicateNotice), findsOneWidget);

      await tester.tap(find.byKey(ReviewScreen.duplicateLinkKey));
      await tester.pumpAndSettle();
      expect(opened, isNotNull);

      await tester.tap(find.byKey(ReviewScreen.duplicateProceedKey));
      await tester.pumpAndSettle();

      expect(sender.sent.single.duplicateFlagged, isTrue);
      await tester.pump(const Duration(seconds: 5));
    });
  });

  group('[review-screen/never-block-a-save]', () {
    testWidgets('an empty document is saved with its attachment and no data', (
      WidgetTester tester,
    ) async {
      final FakeReviewSender sender = FakeReviewSender();
      SendOutcome? saved;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ReviewScreen(
            controller: aController(
              entry: aReviewingEntry(withoutValues: true),
              sender: sender,
            ),
            onSaved: (SendOutcome outcome) => saved = outcome,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(ReviewScreen.saveKey));
      await tester.pumpAndSettle();

      expect(sender.sent, hasLength(1));
      expect(sender.sent.single.values!.grossTotal, isA<Absent<Money>>());
      expect(saved, isNotNull);
      await tester.pump(const Duration(seconds: 5));
    });
  });

  group('[review-screen/thumbnail-with-the-read-region]', () {
    testWidgets('the thumbnail opens the document full screen, and closes', (
      WidgetTester tester,
    ) async {
      final HistoryEntry entry = aReviewingEntry();
      // The thumbnail is the app's own file in a folder the test owns; written synchronously, so
      // nothing here waits on the file system while the tree is pumped.
      final String thumbnail = aThumbnailFor(aTempRoot(), entry.docId);
      final ReviewController controller = aController(
        entry: aReviewingEntry(docId: entry.docId, thumbnailPath: thumbnail),
      );
      await pumpReview(tester, controller);

      await tester.tap(find.byKey(ReviewThumbnail.thumbnailKey));
      await tester.pumpAndSettle();
      expect(find.byKey(ReviewThumbnail.fullScreenKey), findsOneWidget);

      await tester.tap(find.byTooltip(en.reviewCloseAction));
      await tester.pumpAndSettle();
      expect(find.byKey(ReviewThumbnail.fullScreenKey), findsNothing);
    });

    testWidgets('a document with no thumbnail shows the placeholder', (
      WidgetTester tester,
    ) async {
      await pumpReview(tester, aController(entry: aReviewingEntry()));

      expect(find.text(en.reviewNoThumbnail), findsOneWidget);
      expect(find.byKey(ReviewThumbnail.thumbnailKey), findsNothing);
    });
  });

  group('[review-screen/discard-a-document]', () {
    testWidgets(
      'discarding asks for the capture to be deleted and reports it',
      (WidgetTester tester) async {
        final HistoryEntry entry = aReviewingEntry();
        await store.create(entry);
        final FakeCaptureDiscard discard = FakeCaptureDiscard();
        bool discarded = false;
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ReviewScreen(
              controller: aController(entry: entry, discard: discard),
              onDiscarded: () => discarded = true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(ReviewScreen.discardKey));
        await tester.pumpAndSettle();

        expect(discarded, isTrue);
        expect(discard.deleted, <String>[entry.docId]);
      },
    );

    testWidgets('a discard the file system refuses claims nothing', (
      WidgetTester tester,
    ) async {
      final FakeCaptureDiscard discard = FakeCaptureDiscard()..refuse = true;
      bool discarded = false;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ReviewScreen(
            controller: aController(entry: aReviewingEntry(), discard: discard),
            onDiscarded: () => discarded = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(ReviewScreen.discardKey));
      await tester.pumpAndSettle();

      expect(discarded, isFalse);
      expect(find.text(en.reviewDiscardFailed), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    });
  });

  testWidgets('the review screen meets the platform accessibility guidelines', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await pumpReview(tester, aController(entry: aReviewingEntry()));

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));

    handle.dispose();
  });

  group('[review-screen/country-shown-and-editable-per-ticket]', () {
    testWidgets('the ticket shows the country it was read under, and where it '
        'came from', (WidgetTester tester) async {
      await pumpReview(
        tester,
        aController(
          entry: aReviewingEntry(),
          country: FakeCountrySetting(const CountrySetting('DE')),
        ),
      );

      expect(
        find.text(en.reviewFieldValue(en.reviewCountryLabel, 'DE')),
        findsOneWidget,
      );
      expect(find.text(en.reviewCountryFromSettings), findsOneWidget);
      expect(
        find.byKey(ReviewScreen.countryWarningKey),
        findsNothing,
        reason: 'Germany has a row, so there is nothing to warn about',
      );
    });

    testWidgets('the country changes for this ticket, without leaving the '
        'document and without touching the settings', (
      WidgetTester tester,
    ) async {
      final FakeCountrySetting settings = FakeCountrySetting(
        const CountrySetting('DE'),
      );
      final ReviewController controller = aController(
        entry: aReviewingEntry(),
        country: settings,
      );
      await pumpReview(tester, controller);
      final List<String> before = controller.state.fields
          .map((ReviewFieldValue value) => value.text)
          .toList();

      await tester.tap(find.byKey(ReviewScreen.countryActionKey));
      await tester.pumpAndSettle();
      expect(find.text(en.reviewCountryTitle), findsOneWidget);
      await tester.tap(find.byKey(ReviewScreen.countryChoiceKey('ES')));
      await tester.pumpAndSettle();

      expect(
        find.text(en.reviewFieldValue(en.reviewCountryLabel, 'ES')),
        findsOneWidget,
      );
      expect(find.text(en.reviewCountryForTicket), findsOneWidget);
      expect(
        settings.writes,
        0,
        reason: 'the settings keep their default: the change is the ticket\'s',
      );
      expect(settings.setting, const CountrySetting('DE'));
      expect(
        controller.state.fields
            .map((ReviewFieldValue value) => value.text)
            .toList(),
        before,
        reason: 'what was read is what stays on screen',
      );
      expect(
        find.byKey(ReviewScreen.fieldKey(ReviewField.grossTotal)),
        findsOneWidget,
        reason: 'the document is still under review',
      );
    });

    testWidgets('a country with no row is announced on the ticket', (
      WidgetTester tester,
    ) async {
      await pumpReview(
        tester,
        aController(
          entry: aReviewingEntry(),
          country: FakeCountrySetting(const CountrySetting('PT')),
        ),
      );

      expect(find.text(en.reviewCountryNoRowWarning), findsOneWidget);
      expect(find.text(en.reviewCountryUnsetWarning), findsNothing);
    });

    testWidgets('a settings file with no country at all says so, and warns', (
      WidgetTester tester,
    ) async {
      await pumpReview(
        tester,
        aController(
          entry: aReviewingEntry(),
          country: FakeCountrySetting()..unreadable = true,
        ),
      );

      expect(
        find.text(
          en.reviewFieldValue(en.reviewCountryLabel, en.reviewCountryUnset),
        ),
        findsOneWidget,
      );
      expect(find.text(en.reviewCountryUnsetWarning), findsOneWidget);
    });

    testWidgets('the currency says it comes from the country setting', (
      WidgetTester tester,
    ) async {
      await pumpReview(
        tester,
        aController(entry: aReviewingEntry(values: aPhotoDocument())),
      );

      expect(
        find.byKey(ReviewScreen.fieldSourceKey(ReviewField.currency)),
        findsOneWidget,
        reason: 'DEC-023: the green of the currency has to name its source',
      );
      expect(find.text(en.reviewCurrencySourceCountrySetting), findsOneWidget);
      expect(
        find.byKey(ReviewScreen.fieldSourceKey(ReviewField.grossTotal)),
        findsNothing,
        reason: 'a value read from the document has no source to declare',
      );
    });
  });

  group('[review-screen/second-read-is-requested-and-shown-running]', () {
    testWidgets('the user asks for it, the screen shows it running, and then '
        'stops showing it', (WidgetTester tester) async {
      final FakeReviewSecondRead secondRead = FakeReviewSecondRead(
        answer: (HistoryEntry entry) => aDocumentWithOnlyTheDate(),
      )..pending = Completer<void>();
      await pumpReview(
        tester,
        aController(entry: aReviewingEntry(), secondRead: secondRead),
      );

      await tester.tap(find.byKey(ReviewScreen.reReadKey));
      await tester.pump();
      expect(find.byKey(ReviewScreen.reReadRunningKey), findsOneWidget);
      expect(find.text(en.reviewReReadRunning), findsOneWidget);

      secondRead.pending!.complete();
      await tester.pumpAndSettle();

      expect(find.byKey(ReviewScreen.reReadRunningKey), findsNothing);
    });

    testWidgets('a total the user typed is still on screen after the second '
        'read', (WidgetTester tester) async {
      final FakeReviewSecondRead secondRead = FakeReviewSecondRead(
        answer: (HistoryEntry entry) => aConfirmedDocument(),
      );
      final ReviewController controller = aController(
        entry: aReviewingEntry(values: aPhotoDocument()),
        secondRead: secondRead,
      );
      await pumpReview(tester, controller);

      // An amber total is directly editable: tap it and type another one.
      await tester.tap(
        find.byKey(ReviewScreen.fieldKey(ReviewField.grossTotal)),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(ReviewScreen.editorKey(ReviewField.grossTotal)),
        '13.00',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(ReviewScreen.reReadKey));
      await tester.pumpAndSettle();

      expect(
        find.text(en.reviewFieldValue(en.reviewFieldGrossTotal, '13.00')),
        findsOneWidget,
        reason: 'the user\'s value is the value kept (FR-REV-010, DEC-024)',
      );
    });

    testWidgets(
      'a second read that could not run says so and changes nothing',
      (WidgetTester tester) async {
        final FakeReviewSecondRead secondRead = FakeReviewSecondRead()
          ..failure = const FileSystemException('the file could not be read');
        await pumpReview(
          tester,
          aController(entry: aReviewingEntry(), secondRead: secondRead),
        );

        await tester.tap(find.byKey(ReviewScreen.reReadKey));
        await tester.pumpAndSettle();

        expect(find.byKey(ReviewScreen.reReadFailedKey), findsOneWidget);
        expect(find.byKey(ReviewScreen.reReadRunningKey), findsNothing);
        expect(
          find.text(en.reviewFieldValue(en.reviewFieldGrossTotal, '12.10')),
          findsOneWidget,
          reason: 'the values stay exactly as they were',
        );
      },
    );

    testWidgets('a save is not held back while the second read runs', (
      WidgetTester tester,
    ) async {
      final FakeReviewSecondRead secondRead = FakeReviewSecondRead(
        answer: (HistoryEntry entry) => aConfirmedDocument(),
      )..pending = Completer<void>();
      final FakeReviewSender sender = FakeReviewSender();
      await pumpReview(
        tester,
        aController(
          entry: aReviewingEntry(),
          secondRead: secondRead,
          sender: sender,
        ),
      );

      await tester.tap(find.byKey(ReviewScreen.reReadKey));
      await tester.pump();
      await tester.tap(find.byKey(ReviewScreen.saveKey));
      await tester.pump();

      expect(sender.sent, hasLength(1));

      secondRead.pending!.complete();
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 5));
    });
  });
}
