import 'package:paperdrop_core/paperdrop_core.dart';
import 'package:test/test.dart';

// Regression structure: a card-terminal slip with a printed total and no
// printed breakdown. Nothing is derived and the breakdown stays empty. This
// file names no document.
void main() {
  final es = CountryTable.es;

  PositionedWord word(String text, int x0, int x1, int top, int bottom) =>
      PositionedWord(text, x0, x1, top, bottom);

  test('no breakdown is derived from a total-only slip', () {
    final page = TextPage(0, 300000, 300000, [
      word('TOTAL', 100000, 120000, 100000, 120000),
      word('121,00', 130000, 160000, 100000, 120000),
    ]);

    final result = solveAmounts(
      pages: [page],
      country: es,
      table: CountryTable.launch,
    );

    expect(result.netTotal, const Absent<Money>());
    expect(result.taxTotal, const Absent<Money>());
    expect(result.surcharges, isEmpty);
    expect(result.discardedRates, isEmpty);
    expect(
      [result.grossTotal, result.netTotal, result.taxTotal].every(
        (FieldValue<Money> value) =>
            value is! Present<Money> || value.provenance != Provenance.derived,
      ),
      isTrue,
    );
  });
}
