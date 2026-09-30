import 'package:paperdrop_core/paperdrop_core.dart';
import 'package:test/test.dart';

void main() {
  final eur = CurrencyCode.parse('EUR')!;
  final jpy = CurrencyCode.parse('JPY')!;

  group('inferDecimalConvention', () {
    test('[countries-languages/format-inference] '
        'grouping separates the two decimal conventions', () {
      expect(
        inferDecimalConvention(<String>['1.234,56']),
        DecimalConvention.commaDecimal,
      );
      expect(
        inferDecimalConvention(<String>['1,234.56']),
        DecimalConvention.dotDecimal,
      );
    });

    test('a single separator followed by two digits decides', () {
      expect(
        inferDecimalConvention(<String>['12,34']),
        DecimalConvention.commaDecimal,
      );
      expect(
        inferDecimalConvention(<String>['12.34']),
        DecimalConvention.dotDecimal,
      );
    });

    test('a lone separator followed by three digits decides nothing', () {
      expect(inferDecimalConvention(<String>['1.234']), isNull);
      expect(inferDecimalConvention(<String>['1,234']), isNull);
    });

    test('no evidence returns null, never a default', () {
      expect(inferDecimalConvention(<String>['123']), isNull);
      expect(inferDecimalConvention(<String>[]), isNull);
    });

    test('contradictory evidence returns null', () {
      expect(inferDecimalConvention(<String>['1.234,56', '1,234.56']), isNull);
    });
  });

  group('parsePrintedAmount', () {
    test('parses both conventions exactly', () {
      expect(
        parsePrintedAmount('1.234,56', DecimalConvention.commaDecimal, eur),
        Money(123456, eur),
      );
      expect(
        parsePrintedAmount('1,234.56', DecimalConvention.dotDecimal, eur),
        Money(123456, eur),
      );
    });

    test('rejects the wrong convention', () {
      expect(
        parsePrintedAmount('1.234,56', DecimalConvention.dotDecimal, eur),
        isNull,
      );
    });

    test('parses comma-decimal minor amounts and rejects three decimals', () {
      expect(
        parsePrintedAmount('0,5', DecimalConvention.commaDecimal, eur),
        Money(50, eur),
      );
      expect(
        parsePrintedAmount('12,345', DecimalConvention.commaDecimal, eur),
        isNull,
      );
    });

    test('parses integer amounts in a zero-exponent currency', () {
      expect(
        parsePrintedAmount('100', DecimalConvention.commaDecimal, jpy),
        Money(100, jpy),
      );
      expect(
        parsePrintedAmount('100', DecimalConvention.dotDecimal, jpy),
        Money(100, jpy),
      );
    });

    test('removes grouping spaces', () {
      expect(
        parsePrintedAmount('1 234,56', DecimalConvention.commaDecimal, eur),
        Money(123456, eur),
      );
    });

    test('accepts a leading or trailing minus', () {
      expect(
        parsePrintedAmount('-1,00', DecimalConvention.commaDecimal, eur),
        Money(-100, eur),
      );
      expect(
        parsePrintedAmount('1,00-', DecimalConvention.commaDecimal, eur),
        Money(-100, eur),
      );
    });
  });
}
