import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:paperdrop/adapters/pdf_text/pdfrx_text_source.dart';
import 'package:paperdrop_core/paperdrop_core.dart';
import 'package:path/path.dart' as p;

/// The synthetic regression asserted through **Core's binder**
/// (`close-adr-011-pdf-text-route`, design §5 and task 2.3).
///
/// **What it proves, and where.** The fixture
/// (`test/fixtures/pdf/tomo_regression.pdf`) is read by the adapter that ships,
/// on a device, and the pages go to Core's layout reasoning — the binder behind
/// `readOperands`, which is the public path a label and its value travel. On
/// **page 1** the total is on the label's own line to its right and binds from
/// there; on **page 2** the total is on the line **below** the label and binds
/// from there. On neither page is the commercial-register volume `8.741` bound
/// to the total label, which is the failure ADR-011 exists to prevent. And the
/// fixture is unchanged on disk when the test is over (ADR-015).
///
/// **Why it is an integration test.** PDFium is the only way to turn those two
/// pages into words, and PDFium is a native library: the orchestrator runs this
/// on a device. The fixture has to be on that device, so the test reads it from
/// the directory the harness uses — `--dart-define=PDF_EVAL_DIR=…`, the app's
/// private storage — and skips itself when the define is not given, like the
/// harness does. Pushing the fixture there is one command:
///
///     adb push app/test/fixtures/pdf/tomo_regression.pdf <PDF_EVAL_DIR>/
///
/// **What never enters the repository.** Both pages are synthetic (see the
/// generator); the private corpus is not read, copied or named here, and the
/// document that failed, PRO1013-26, is not reproduced — only the structure of
/// the failure.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const String evalDirectory = String.fromEnvironment('PDF_EVAL_DIR');
  const String fixtureName = 'tomo_regression.pdf';

  test('the binder takes the total, and never the registry volume', () async {
    final Directory directory = Directory(evalDirectory);
    if (!directory.existsSync()) {
      fail('PDF_EVAL_DIR is not a directory on this device: $evalDirectory');
    }
    final File fixture = File(p.join(directory.path, fixtureName));
    if (!fixture.existsSync()) {
      fail(
        '$fixtureName is not in PDF_EVAL_DIR: push the fixture that is in the '
        'repository (app/test/fixtures/pdf/$fixtureName) before this test runs',
      );
    }

    final String sha256Before = sha256
        .convert(fixture.readAsBytesSync())
        .toString();
    final List<TextPage> pages = await const PdfrxTextSource().read(
      fixture.path,
    );
    // Read-only, proved and not inspected (ADR-015): the fixture after the read
    // is the fixture before it.
    expect(
      sha256.convert(fixture.readAsBytesSync()).toString(),
      sha256Before,
      reason: 'reading a document must not write to it',
    );

    expect(pages, hasLength(2));
    expect(
      pages.every((TextPage page) => page.hasTextLayer),
      isTrue,
      reason: 'both fixture pages carry a text layer, so nothing falls through',
    );

    // What Core read off each page, through its own entry point for printed
    // operands: labels are matched, bound by layout and parsed under the
    // document's convention. Germany, because the label is 'Gesamtbetrag' and
    // the amount is printed with a comma decimal.
    final List<ReadOperand> operands = readOperands(
      pages,
      CountryTable.de,
    ).operands;
    final List<ReadOperand> gross = operands
        .where((ReadOperand operand) => operand.role == OperandRole.gross)
        .toList();

    // The volume is never anywhere: not bound to the label, not read as an
    // amount beside it.
    expect(
      operands
          .expand((ReadOperand operand) => operand.words)
          .map((PositionedWord word) => word.text),
      isNot(contains('8.741')),
      reason: 'the registry volume must never be bound as the total',
    );
    expect(
      operands
          .where((ReadOperand operand) => operand.amount?.minor == 8741)
          .toList(),
      isEmpty,
    );

    expect(
      gross,
      hasLength(2),
      reason: 'one total label per page, and both of them bind',
    );

    // Page 1: the total is on the label's own line, to the right of it — the
    // rule's first branch.
    final ReadOperand pageOne = gross.singleWhere(
      (ReadOperand operand) => operand.pageIndex == 0,
    );
    expect(pageOne.amount, Money(123450, CurrencyCode.parse('EUR')!));
    final TextPage first = pages[0];
    final PositionedWord labelOne = _only(first, 'Gesamtbetrag');
    final PositionedWord boundOne = pageOne.words.single;
    expect(boundOne.text, '1.234,50');
    expect(
      _lineOf(first, labelOne).words,
      contains(boundOne),
      reason: 'page 1 puts the value on the label\'s own line',
    );
    expect(boundOne.x0, greaterThan(labelOne.x1));

    // Page 2: the same total, bound from the line **below** the label, which is
    // the branch the scenario "a label on another line still binds its value"
    // needs and the one a plain-text parser replaced with the volume.
    final ReadOperand pageTwo = gross.singleWhere(
      (ReadOperand operand) => operand.pageIndex == 1,
    );
    expect(pageTwo.amount, Money(123450, CurrencyCode.parse('EUR')!));
    final TextPage second = pages[1];
    final PositionedWord labelTwo = _only(second, 'Gesamtbetrag');
    final PositionedWord boundTwo = pageTwo.words.single;
    expect(boundTwo.text, '1.234,50');
    final LayoutLine labelTwoLine = _lineOf(second, labelTwo);
    expect(
      labelTwoLine.words,
      isNot(contains(boundTwo)),
      reason: 'page 2 puts the value on another line',
    );
    expect(
      boundTwo.top,
      greaterThan(labelTwoLine.bottom),
      reason: 'and that line is below the label, not above it',
    );
    expect(
      boundTwo.top - labelTwoLine.bottom,
      lessThan(labelTwoLine.height),
      reason:
          'one line step below, no further: the rule reaches no deeper '
          'than one label-line height',
    );

    // The volume is on page 2 as well: the row above the label, and the words
    // right after it in the page's own order — nearer to the label in
    // extraction order than the total is, and still not bound.
    final List<PositionedWord> pageTwoWords = second.words;
    final int labelIndex = pageTwoWords.indexOf(labelTwo);
    expect(
      pageTwoWords
          .sublist(labelIndex + 1, labelIndex + 3)
          .map((PositionedWord word) => word.text),
      <String>['Tomo', '8.741'],
      reason: 'the volume is the label\'s extraction-order neighbour',
    );
    expect(_only(second, '8.741').top, lessThan(labelTwo.top));
  }, skip: evalDirectory.isEmpty ? _noDirectory : null);
}

/// The line of [page] that [word] sits on.
LayoutLine _lineOf(TextPage page, PositionedWord word) =>
    groupIntoLines(page)
        .firstWhere((LayoutLine line) => line.words.contains(word));

PositionedWord _only(TextPage page, String text) {
  final List<PositionedWord> matches = page.words
      .where((PositionedWord word) => word.text == text)
      .toList();
  expect(matches, hasLength(1), reason: '"$text" once on the page');
  return matches.single;
}

const String _noDirectory =
    'PDF_EVAL_DIR is not set: this test needs the fixture pushed to the device, '
    'and reads nothing here';
