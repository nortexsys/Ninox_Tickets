import 'package:paperdrop_core/paperdrop_core.dart';
import 'package:test/test.dart';

// Annex D.4 — a card charge abroad prints a currency-conversion mark-up of
// 4,5 %. The negative-context dictionary suppresses it as a tax candidate,
// and the amount is captured as `surcharges[]` with label `dcc_markup`. No
// tax line at 4,5 % is written.
void main() {
  final eur = CurrencyCode.parse('EUR')!;
  final es = CountryTable.es;

  PositionedWord word(String text, int x0, int x1, int top, int bottom) =>
      PositionedWord(text, x0, x1, top, bottom);

  group('Annex D.4', () {
    test('the mark-up is suppressed and captured as dcc_markup', () {
      final page = TextPage(0, 300000, 200000, [
        word('mark-up', 100000, 108000, 100000, 120000),
        word('4,5', 112000, 120000, 100000, 120000),
        word('%', 124000, 132000, 100000, 120000),
        word('0,45', 136000, 150000, 100000, 120000),
      ]);

      final operands = readOperands([page], es);
      final result = applyNegativeContext(
        operands: operands,
        pages: [page],
        country: es,
      );

      expect(result.kept.rates, isEmpty);
      expect(result.suppressed.single.rate, RateBp(450));
      expect(result.surcharges.single.label, SurchargeLabel.dccMarkup);
      expect(
        result.surcharges.single.amount,
        Present<Money>(Money(45, eur), Provenance.read, ConfidenceState.amber),
      );
    });

    test('negative variant: 4,5 % is not a legal tax rate', () {
      expect(admitPrintedRate(RateBp(450), es), isFalse);
    });
  });
}
