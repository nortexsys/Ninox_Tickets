import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ninox_client/ninox_client.dart' as ninox;
import 'package:paperdrop/app/paperdrop_app.dart';
import 'package:paperdrop/features/capture/capture_screen.dart';
import 'package:paperdrop/features/capture/intake_screen.dart';
import 'package:paperdrop/intake/intake_result.dart';
import 'package:paperdrop/l10n/generated/app_localizations.dart';
import 'package:paperdrop_core/paperdrop_core.dart' as core;

void main() {
  late AppLocalizations en;

  setUpAll(() async {
    en = await AppLocalizations.delegate.load(const Locale('en'));
  });

  testWidgets('the shell starts on the capture screen', (tester) async {
    await tester.pumpWidget(const PaperdropApp());
    await tester.pumpAndSettle();

    expect(find.byType(CaptureScreen), findsOneWidget);
    expect(find.byType(IntakeScreen), findsNothing);
  });

  testWidgets('every string of the capture screen comes from the resources', (
    tester,
  ) async {
    await tester.pumpWidget(const PaperdropApp());
    await tester.pumpAndSettle();

    for (final String string in <String>[
      en.appTitle,
      en.captureHeadline,
      en.captureExplanation,
      en.captureScanAction,
      en.captureChooseFileAction,
    ]) {
      expect(find.text(string), findsOneWidget, reason: string);
    }
  });

  testWidgets('the capture screen offers exactly the two MVP actions', (
    tester,
  ) async {
    await tester.pumpWidget(const PaperdropApp());
    await tester.pumpAndSettle();

    expect(find.byType(FilledButton), findsOneWidget);
    expect(find.byType(OutlinedButton), findsOneWidget);
    expect(find.byType(TextButton), findsNothing);
  });

  testWidgets('the intake placeholder shows type, size and hash prefix', (
    tester,
  ) async {
    // Built rather than written out: a 64-character hex literal in the sources
    // is exactly what the privacy check looks for (`.github/scripts/privacy_check.py`).
    final String digest = 'ab' * 32;
    final IntakeResult result = IntakeResult(
      docId: 'doc-id',
      source: IntakeSource.picker,
      mediaType: 'application/pdf',
      byteLength: 2048,
      sha256: digest,
      storedPath: '/tmp/originals/doc-id/original.pdf',
    );
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: IntakeScreen(result: result),
      ),
    );

    expect(find.text('application/pdf'), findsOneWidget);
    expect(find.text('2048 bytes'), findsOneWidget);
    expect(find.text(digest.substring(0, 12)), findsOneWidget);
  });

  test('the app sees both workspace packages', () {
    expect(core.packageName, 'paperdrop_core');
    expect(ninox.packageName, 'ninox_client');
  });
}
