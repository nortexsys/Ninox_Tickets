import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:paperdrop/adapters/intake/incoming_document.dart';
import 'package:paperdrop/app/paperdrop_app.dart';
import 'package:paperdrop/features/capture/capture_controller.dart';
import 'package:paperdrop/features/capture/intake_screen.dart';
import 'package:paperdrop/intake/intake_failure.dart';
import 'package:paperdrop/intake/intake_result.dart';
import 'package:paperdrop/l10n/generated/app_localizations.dart';

import '../../tool/fakes.dart';
import '../../tool/synthetic_documents.dart';

/// The picker and the Android share-in of design §3, both feeding the same
/// store and both landing on `/intake/:docId`.
///
/// The store itself is doubled here, because its work is real file work and a
/// widget test's clock is fake; the double still hashes the whole stream, so the
/// bytes the source produced are the bytes the store was handed. What the real
/// store does with them is `test/intake/document_intake_test.dart`.
///
/// The `one-entry-point-four-paths` scenario *every path lands on the same
/// screen* is written on the review screen's field set (M2) and carries no tag
/// here; what is proved is that the two paths of this change reach the same
/// route with the same result.
void main() {
  late Directory root;
  late FakeDocumentIntake intake;
  late FakeFilePickerSource picker;
  late FakeShareInSource shareIn;
  late CaptureController controller;
  late AppLocalizations en;

  setUpAll(() async {
    en = await AppLocalizations.delegate.load(const Locale('en'));
  });

  setUp(() {
    root = Directory('paperdrop-capture-test');
    intake = FakeDocumentIntake(root: root);
    picker = FakeFilePickerSource();
    shareIn = FakeShareInSource();
    controller = CaptureController(
      intake: intake,
      picker: picker,
      shareIn: shareIn,
    );
  });

  tearDown(() async {
    await shareIn.close();
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(PaperdropApp(controller: controller));
    await tester.pumpAndSettle();
  }

  /// The route the shell is on, read from the screen that is on top.
  String currentLocation(WidgetTester tester) =>
      GoRouterState.of(tester.element(find.byType(IntakeScreen))).uri.path;

  IntakeResult shownResult(WidgetTester tester) =>
      tester.widget<IntakeScreen>(find.byType(IntakeScreen)).result!;

  testWidgets('the picker stores the document and opens the intake route', (
    tester,
  ) async {
    final Uint8List pdf = syntheticPdf();
    picker.document = incomingDocument(
      IntakeSource.picker,
      pdf,
      mediaType: 'application/pdf',
    );

    await pumpApp(tester);
    await tester.tap(find.text(en.captureChooseFileAction));
    await tester.pumpAndSettle();

    expect(picker.calls, 1);
    expect(intake.sources, <IntakeSource>[IntakeSource.picker]);
    expect(find.byType(IntakeScreen), findsOneWidget);
    expect(find.text('application/pdf'), findsOneWidget);

    final IntakeResult result = shownResult(tester);
    expect(currentLocation(tester), '/intake/${result.docId}');
    expect(result.source, IntakeSource.picker);
    expect(result.byteLength, pdf.length);
    expect(
      result.sha256,
      sha256.convert(pdf).toString(),
      reason: 'the bytes that reached the store are the bytes the picker gave',
    );
  });

  testWidgets('share-in opens the same route with the same result', (
    tester,
  ) async {
    final Uint8List pdf = syntheticPdf();
    await pumpApp(tester);

    shareIn.share(<IncomingDocument>[
      incomingDocument(IntakeSource.shareIn, pdf, mediaType: 'application/pdf'),
    ]);
    await tester.pumpAndSettle();

    expect(intake.sources, <IntakeSource>[IntakeSource.shareIn]);
    expect(find.byType(IntakeScreen), findsOneWidget);
    expect(find.text('application/pdf'), findsOneWidget);

    final IntakeResult result = shownResult(tester);
    expect(currentLocation(tester), '/intake/${result.docId}');
    expect(result.source, IntakeSource.shareIn);
    expect(result.byteLength, pdf.length);
    expect(result.sha256, sha256.convert(pdf).toString());
  });

  test('the two paths produce the same result shape', () async {
    final Uint8List pdf = syntheticPdf();
    picker.document = incomingDocument(
      IntakeSource.picker,
      pdf,
      mediaType: 'application/pdf',
    );

    final CaptureOutcome picked = await controller.chooseFile();
    shareIn.share(<IncomingDocument>[
      incomingDocument(IntakeSource.shareIn, pdf, mediaType: 'application/pdf'),
    ]);
    final CaptureOutcome shared = await controller.sharedDocuments().first;

    expect(picked, isA<CaptureStored>());
    expect(shared, isA<CaptureStored>());
    final IntakeResult byPicker = (picked as CaptureStored).result;
    final IntakeResult byShare = (shared as CaptureStored).result;

    expect(byShare.mediaType, byPicker.mediaType);
    expect(byShare.byteLength, byPicker.byteLength);
    expect(byShare.sha256, byPicker.sha256);
    expect(byShare.source, isNot(byPicker.source));
    expect(byShare.docId, isNot(byPicker.docId));
    // The same place, under a different identifier: the store's layout is one.
    expect(
      byShare.storedPath.replaceAll(byShare.docId, '<id>'),
      byPicker.storedPath.replaceAll(byPicker.docId, '<id>'),
    );
  });

  testWidgets(
    'several files shared at once are refused, and nothing is stored',
    (tester) async {
      await pumpApp(tester);

      shareIn.share(<IncomingDocument>[
        incomingDocument(
          IntakeSource.shareIn,
          syntheticPdf(),
          mediaType: 'application/pdf',
        ),
        incomingDocument(
          IntakeSource.shareIn,
          syntheticPdf(text: 'Second document of the same share'),
          mediaType: 'application/pdf',
        ),
      ]);
      await tester.pumpAndSettle();

      // The refusal is a string from the resources, not a literal
      // (NFR-I18N-001).
      expect(find.text(en.errorSeveralFilesShared), findsOneWidget);
      expect(find.byType(IntakeScreen), findsNothing);
      expect(
        intake.calls,
        0,
        reason: 'the store was never asked, so nothing was stored',
      );
    },
  );

  testWidgets('a media type outside the three is refused with its message', (
    tester,
  ) async {
    await pumpApp(tester);

    shareIn.share(<IncomingDocument>[
      incomingDocument(
        IntakeSource.shareIn,
        syntheticJpeg(),
        mediaType: 'image/heic',
        filename: 'scan.heic',
      ),
    ]);
    await tester.pumpAndSettle();

    expect(find.text(en.errorUnsupportedMediaType), findsOneWidget);
    expect(find.byType(IntakeScreen), findsNothing);
  });

  testWidgets('a share that carries no document is refused with its message', (
    tester,
  ) async {
    await pumpApp(tester);

    shareIn.share(<IncomingDocument>[]);
    await tester.pumpAndSettle();

    expect(find.text(en.errorNoDocumentShared), findsOneWidget);
    expect(intake.calls, 0);
  });

  testWidgets('closing the picker leaves the screen as it was', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text(en.captureChooseFileAction));
    await tester.pumpAndSettle();

    expect(picker.calls, 1);
    expect(intake.calls, 0);
    expect(find.byType(IntakeScreen), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('a picker that fails is reported, not thrown', (tester) async {
    picker.error = const IntakeFailure(IntakeFailureCode.intakeFailed);
    await pumpApp(tester);

    await tester.tap(find.text(en.captureChooseFileAction));
    await tester.pumpAndSettle();

    expect(find.text(en.errorIntakeFailed), findsOneWidget);
    expect(find.byType(IntakeScreen), findsNothing);
  });

  testWidgets('a share that fails on its way in is reported', (tester) async {
    await pumpApp(tester);

    shareIn.fail(const IntakeFailure(IntakeFailureCode.intakeFailed));
    await tester.pumpAndSettle();

    expect(find.text(en.errorIntakeFailed), findsOneWidget);
    expect(intake.calls, 0);
  });
}
