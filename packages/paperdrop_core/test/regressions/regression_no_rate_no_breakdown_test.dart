import 'package:paperdrop_core/paperdrop_core.dart';
import 'package:test/test.dart';

// Regression structure: a document printing no tax rate. No breakdown is
// derived and no rate is assumed. This file names no document.
void main() {
  final es = CountryTable.es;

  PositionedWord word(String text, int x0, int x1, int top, int bottom) =>
      PositionedWord(text, x0, x1, top, bottom);

  test('without a printed rate the breakdown stays empty', () {
    final page = TextPage(0, 300000, 300000, [
      word('TOTAL', 100000, 120000, 100000, 120000),
      word('121,00', 130000, 160000, 100000, 120000),
      word('IVA', 100000, 120000, 140000, 160000),
      word('21,00', 130000, 160000, 140000, 160000),
    ]);

    final result = solveAmounts(
      pages: [page],
      country: es,
      table: CountryTable.launch,
    );

    expect(result.netTotal, const Absent<Money>());
    expect(result.grossTotal, const Absent<Money>());
    expect(result.discardedRates, isEmpty);
  });
}
