import 'package:paperdrop_core/paperdrop_core.dart';
import 'package:test/test.dart';

void main() {
  ReadOperand rate(int bp) => ReadOperand.rate(
    rate: RateBp(bp),
    words: [PositionedWord('$bp%', 0, 10, 0, 10)],
    pageIndex: 0,
  );

  group('admitPrintedRate', () {
    test('admits every ES legal rate and rejects its neighbours', () {
      expect(admitPrintedRate(RateBp(2100), CountryTable.es), isTrue);
      expect(admitPrintedRate(RateBp(1000), CountryTable.es), isTrue);
      expect(admitPrintedRate(RateBp(400), CountryTable.es), isTrue);
      expect(admitPrintedRate(RateBp(0), CountryTable.es), isTrue);

      expect(admitPrintedRate(RateBp(2200), CountryTable.es), isFalse);
      expect(admitPrintedRate(RateBp(900), CountryTable.es), isFalse);
      expect(admitPrintedRate(RateBp(500), CountryTable.es), isFalse);
      expect(admitPrintedRate(RateBp(3000), CountryTable.es), isFalse);
    });

    test('admits every DE legal rate and rejects its neighbours', () {
      expect(admitPrintedRate(RateBp(1900), CountryTable.de), isTrue);
      expect(admitPrintedRate(RateBp(700), CountryTable.de), isTrue);
      expect(admitPrintedRate(RateBp(0), CountryTable.de), isTrue);

      expect(admitPrintedRate(RateBp(1800), CountryTable.de), isFalse);
      expect(admitPrintedRate(RateBp(800), CountryTable.de), isFalse);
      expect(admitPrintedRate(RateBp(100), CountryTable.de), isFalse);
      expect(admitPrintedRate(RateBp(2200), CountryTable.de), isFalse);
    });
  });

  group('gatePrintedRates', () {
    test('[extraction-pipeline/legal-rate-gate-before-derivation] '
        'a rejected rate cannot drive a derivation', () {
      final legal = rate(2100);
      final illegal = rate(3000);

      final result = gatePrintedRates([legal, illegal], CountryTable.es);

      expect(result.admitted, [legal]);
      expect(result.discarded, [illegal]);
    });
  });
}
