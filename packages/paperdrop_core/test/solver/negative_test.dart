import 'package:paperdrop_core/paperdrop_core.dart';
import 'package:test/test.dart';

void main() {
  final eur = CurrencyCode.parse('EUR')!;
  final es = CountryTable.es;

  PositionedWord word(String text, int x0, int x1, int top, int bottom) =>
      PositionedWord(text, x0, x1, top, bottom);

  group('applyNegativeContext', () {
    test('[extraction-pipeline/negative-context-suppresses-non-tax-figures] '
        'registry boilerplate is not a total', () {
      final page = TextPage(0, 300000, 300000, [
        word('TOTAL', 100000, 120000, 100000, 120000),
        word('96,76', 130000, 160000, 100000, 120000),
        word('Tomo', 170000, 200000, 100000, 120000),
        word('BASE', 100000, 120000, 140000, 160000),
        word('80,00', 130000, 160000, 140000, 160000),
        word('Folio', 170000, 200000, 140000, 160000),
        word('IVA', 100000, 120000, 180000, 200000),
        word('16,76', 130000, 160000, 180000, 200000),
        word('Registro', 170000, 200000, 180000, 200000),
        word('Mercantil', 210000, 250000, 180000, 200000),
      ]);

      final operands = readOperands([page], es);
      final result = applyNegativeContext(
        operands: operands,
        pages: [page],
        country: es,
      );

      expect(result.kept.gross, isEmpty);
      expect(result.kept.bases, isEmpty);
      expect(result.kept.taxes, isEmpty);
      expect(result.suppressed, hasLength(3));
      expect(result.surcharges, isEmpty);
    });

    test('[extraction-pipeline/negative-context-suppresses-non-tax-figures] '
        'a conversion mark-up is not a tax rate', () {
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
      expect(result.suppressed, hasLength(1));
      expect(result.suppressed.single.rate, RateBp(450));
      expect(result.surcharges, hasLength(1));
      expect(result.surcharges.single.label, SurchargeLabel.dccMarkup);
      expect(
        result.surcharges.single.amount,
        Present<Money>(Money(45, eur), Provenance.read, ConfidenceState.amber),
      );
    });

    test('moving the influence radius changes the suppression outcome', () {
      final page = TextPage(0, 300000, 300000, [
        word('Tomo', 100000, 120000, 100000, 120000),
        word('TOTAL', 100000, 120000, 240000, 260000),
        word('96,76', 130000, 160000, 240000, 260000),
      ]);

      final operands = readOperands([page], es);

      final defaultResult = applyNegativeContext(
        operands: operands,
        pages: [page],
        country: es,
      );
      expect(defaultResult.kept.gross, hasLength(1));
      expect(defaultResult.suppressed, isEmpty);

      final movedResult = applyNegativeContext(
        operands: operands,
        pages: [page],
        country: es,
        radiusMilliPoints: 200000,
      );
      expect(movedResult.kept.gross, isEmpty);
      expect(movedResult.suppressed, hasLength(1));
    });
  });
}
