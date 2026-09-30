import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperdrop/features/capture/capture_controller.dart';
import 'package:paperdrop/features/capture/capture_screen.dart';
import 'package:paperdrop/l10n/generated/app_localizations.dart';

import '../tool/fakes.dart';

/// NFR-ACC-001 · `accessibility`, the baseline half (design §2).
///
/// Three of the requirement's statements are proved on the capture screen here:
/// every control that can be tapped is labelled, every touch target reaches
/// 48 dp, and text contrast holds. The requirement's own three scenarios —
/// confidence never by colour alone, the read region exposed to assistive
/// technology, and the auditor over review and history — are the review and
/// history screens' (M2), and this change tags none of them.
void main() {
  late AppLocalizations en;
  late CaptureController controller;

  setUpAll(() async {
    en = await AppLocalizations.delegate.load(const Locale('en'));
  });

  setUp(() {
    controller = CaptureController(
      intake: FakeDocumentIntake(root: Directory('paperdrop-a11y-test')),
      scanner: FakeDocumentScanner(),
      picker: FakeFilePickerSource(),
      shareIn: FakeShareInSource(),
    );
  });

  Future<void> pumpCaptureScreen(WidgetTester tester, {double scale = 1.0}) {
    return tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: CaptureScreen(controller: controller),
        ),
      ),
    );
  }

  testWidgets(
    'the capture screen meets the platform accessibility guidelines',
    (tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpCaptureScreen(tester);

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));

      handle.dispose();
    },
  );

  testWidgets('every tappable control carries a label from the resources', (
    tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await pumpCaptureScreen(tester);

    // The scan action is wired by task 1.5; until then it is disabled, and a
    // Both actions are wired (tasks 1.3–1.5), so both are tappable and both
    // carry a tap action to label.
    final SemanticsNode scan = tester.getSemantics(
      find.widgetWithText(FilledButton, en.captureScanAction),
    );
    expect(scan.label, en.captureScanAction);
    expect(scan.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);

    final SemanticsNode chooseFile = tester.getSemantics(
      find.widgetWithText(OutlinedButton, en.captureChooseFileAction),
    );
    expect(chooseFile.label, en.captureChooseFileAction);
    expect(
      chooseFile.getSemanticsData().hasAction(SemanticsAction.tap),
      isTrue,
    );

    // Nothing else on the screen carries text of its own.
    for (final String string in <String>[
      en.appTitle,
      en.captureHeadline,
      en.captureExplanation,
    ]) {
      expect(tester.getSemantics(find.text(string)).label, string);
    }

    handle.dispose();
  });

  testWidgets('no control fixes the text scale of the system', (tester) async {
    Future<double> heightAt(double scale) async {
      await pumpCaptureScreen(tester, scale: scale);
      return tester.getSize(find.text(en.captureHeadline)).height;
    }

    final double normal = await heightAt(1.0);
    final double large = await heightAt(2.0);
    expect(large, greaterThan(normal));
  });
}
