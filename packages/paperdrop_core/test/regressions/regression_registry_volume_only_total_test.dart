import 'package:paperdrop_core/paperdrop_core.dart';
import 'package:test/test.dart';

// Regression structure: a document whose only number near a total label is a
// commercial-register volume reference. The volume is never used as the
// total. This file names no document.
void main() {
  final es = CountryTable.es;

  PositionedWord word(String text, int x0, int x1, int top, int bottom) =>
      PositionedWord(text, x0, x1, top, bottom);

  test('the volume is suppressed and the total stays empty', () {
    final page = TextPage(0, 300000, 300000, [
      word('TOTAL', 100000, 120000, 100000, 120000),
      word('8.741', 130000, 160000, 100000, 120000),
      word('Tomo', 170000, 200000, 100000, 120000),
    ]);

    final result = solveAmounts(
      pages: [page],
      country: es,
      table: CountryTable.launch,
    );

    expect(result.grossTotal, const Absent<Money>());
    expect(result.suppressedFigures, isNotEmpty);
  });
}
