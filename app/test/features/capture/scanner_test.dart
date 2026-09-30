import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperdrop/app/paperdrop_app.dart';
import 'package:paperdrop/features/capture/capture_controller.dart';
import 'package:paperdrop/features/capture/intake_screen.dart';
import 'package:paperdrop/intake/intake_failure.dart';
import 'package:paperdrop/intake/intake_result.dart';
import 'package:paperdrop/l10n/generated/app_localizations.dart';

import '../../tool/fakes.dart';
import '../../tool/synthetic_documents.dart';

/// The scanner path of design §3: ML Kit Document Scanner's own PDF, handed to
/// the store unchanged, onto the same route as the other two paths.
///
/// The scanner itself is doubled — the platform's is only exercised by the
/// device check of design §4 — but the bytes it produces go through the **real**
/// store here, because this is a plain `test` and the clock is real. What the
/// double stands in for is the platform's dialog, not the store.
void main() {
  late Directory root;
  late FakeDocumentScanner scanner;
  late CaptureController controller;
  late AppLocalizations en;

  setUpAll(() async {
    en = await AppLocalizations.delegate.load(const Locale('en'));
  });

  setUp(() {
    root = Directory.systemTemp.createTempSync('paperdrop-scanner-test');
    scanner = FakeDocumentScanner();
    controller = CaptureController(
      intake: temporaryIntake(root),
      scanner: scanner,
      picker: FakeFilePickerSource(),
      shareIn: FakeShareInSource(),
    );
  });

  tearDown(() {
    if (root.existsSync()) {
      root.deleteSync(recursive: true);
    }
  });

  test('the scanner\'s PDF reaches the store unchanged', () async {
    // The platform's scanner produced a PDF; the app may not touch it.
    final List<int> scannerPdf = syntheticPdf(text: 'Two pages, one document');
    scanner.document = incomingDocument(
      IntakeSource.scanner,
      scannerPdf,
      mediaType: 'application/pdf',
    );

    final CaptureOutcome outcome = await controller.scan();

    expect(outcome, isA<CaptureStored>());
    final IntakeResult result = (outcome as CaptureStored).result;
    expect(scanner.calls, 1);
    expect(result.source, IntakeSource.scanner);
    expect(result.mediaType, 'application/pdf');
    expect(result.sha256, sha256.convert(scannerPdf).toString());
    expect(File(result.storedPath).readAsBytesSync(), scannerPdf);
  });

  test('leaving the scanner stores nothing and says nothing', () async {
    scanner.document = null;

    expect(await controller.scan(), isA<CaptureCancelled>());
    expect(scanner.calls, 1);
  });

  test(
    'a scanner that answers without a PDF is refused, not improvised',
    () async {
      // The app assembles no PDF of its own: if the platform hands back images
      // only, that is a failure to report (design §3).
      scanner.error = const IntakeFailure(
        IntakeFailureCode.scannerProducedNoPdf,
      );

      final CaptureOutcome outcome = await controller.scan();

      expect(outcome, isA<CaptureRefused>());
      expect(
        (outcome as CaptureRefused).failure.code,
        IntakeFailureCode.scannerProducedNoPdf,
      );
    },
  );

  testWidgets('scanning opens the intake route', (tester) async {
    final FakeDocumentIntake store = FakeDocumentIntake(root: root);
    final CaptureController widgetController = CaptureController(
      intake: store,
      scanner: scanner,
      picker: FakeFilePickerSource(),
      shareIn: FakeShareInSource(),
    );
    final List<int> scannerPdf = syntheticPdf(text: 'One page');
    scanner.document = incomingDocument(
      IntakeSource.scanner,
      scannerPdf,
      mediaType: 'application/pdf',
    );

    await tester.pumpWidget(PaperdropApp(controller: widgetController));
    await tester.pumpAndSettle();
    await tester.tap(find.text(en.captureScanAction));
    await tester.pumpAndSettle();

    expect(scanner.calls, 1);
    expect(find.byType(IntakeScreen), findsOneWidget);
    final IntakeResult result = tester
        .widget<IntakeScreen>(find.byType(IntakeScreen))
        .result!;
    expect(result.source, IntakeSource.scanner);
    expect(result.sha256, sha256.convert(scannerPdf).toString());
  });

  testWidgets('a scanner that answers without a PDF says so, in the '
      'resources\' words', (tester) async {
    final CaptureController widgetController = CaptureController(
      intake: FakeDocumentIntake(root: root),
      scanner: scanner,
      picker: FakeFilePickerSource(),
      shareIn: FakeShareInSource(),
    );
    scanner.error = const IntakeFailure(IntakeFailureCode.scannerProducedNoPdf);

    await tester.pumpWidget(PaperdropApp(controller: widgetController));
    await tester.pumpAndSettle();
    await tester.tap(find.text(en.captureScanAction));
    await tester.pumpAndSettle();

    expect(find.text(en.errorScannerReturnedNoPdf), findsOneWidget);
    expect(find.byType(IntakeScreen), findsNothing);
  });
}
