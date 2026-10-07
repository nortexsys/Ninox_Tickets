import 'package:paperdrop_core/paperdrop_core.dart';
import 'package:test/test.dart';

void main() {
  final eur = CurrencyCode.parse('EUR')!;
  final es = CountryTable.es;

  TextPage operandPage() {
    PositionedWord word(String text, int x0, int x1, int top, int bottom) =>
        PositionedWord(text, x0, x1, top, bottom);

    return TextPage(0, 200000, 300000, [
      word('TOTAL', 100000, 120000, 100000, 120000),
      word('96,76', 130000, 160000, 100000, 120000),
      word('BASE', 100000, 120000, 140000, 160000),
      word('80,00', 130000, 160000, 140000, 160000),
      word('IVA', 100000, 120000, 180000, 200000),
      word('16,76', 130000, 160000, 180000, 200000),
      word('21', 100000, 110000, 220000, 240000),
      word('%', 115000, 125000, 220000, 240000),
    ]);
  }

  group('readOperands', () {
    test('collects every printed operand with read provenance', () {
      final operands = readOperands([operandPage()], es);

      expect(operands.gross, hasLength(1));
      expect(operands.gross.single.amount, Money(9676, eur));
      expect(operands.gross.single.provenance, Provenance.read);

      expect(operands.bases, hasLength(1));
      expect(operands.bases.single.amount, Money(8000, eur));
      expect(operands.bases.single.provenance, Provenance.read);

      expect(operands.taxes, hasLength(1));
      expect(operands.taxes.single.amount, Money(1676, eur));
      expect(operands.taxes.single.provenance, Provenance.read);

      expect(operands.rates, hasLength(1));
      expect(operands.rates.single.rate, RateBp(2100));
      expect(operands.rates.single.provenance, Provenance.read);
    });

    test('computes no operand in this step', () {
      final operands = readOperands([operandPage()], es);

      expect(
        operands.operands.every(
          (ReadOperand operand) => operand.provenance == Provenance.read,
        ),
        isTrue,
      );
      expect(operands.operands, hasLength(4));
    });

    test('reads a localised rate percentage under the document convention', () {
      final page = TextPage(0, 200000, 200000, [
        PositionedWord('4,5', 100000, 120000, 100000, 120000),
        PositionedWord('%', 125000, 135000, 100000, 120000),
      ]);

      final operands = readOperands([page], es);

      expect(operands.rates, hasLength(1));
      expect(operands.rates.single.rate, RateBp(450));
    });
  });
}
