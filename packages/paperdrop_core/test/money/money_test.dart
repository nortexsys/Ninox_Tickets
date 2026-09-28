import 'package:paperdrop_core/paperdrop_core.dart';
import 'package:test/test.dart';

void main() {
  final eur = CurrencyCode.parse('EUR')!;
  final usd = CurrencyCode.parse('USD')!;
  final jpy = CurrencyCode.parse('JPY')!;

  group('Money.parseDecimal', () {
    test('accepts the canonical decimal form', () {
      expect(Money.parseDecimal('19.99', eur), Money(1999, eur));
      expect(Money.parseDecimal('19.9', eur), Money(1990, eur));
      expect(Money.parseDecimal('100', jpy), Money(100, jpy));
      expect(Money.parseDecimal('-0.05', eur), Money(-5, eur));
    });

    test('rejects more fractional digits than the exponent', () {
      expect(() => Money.parseDecimal('19.999', eur), throwsFormatException);
      expect(() => Money.parseDecimal('1.5', jpy), throwsFormatException);
    });

    test('rejects locale formats', () {
      for (final text in <String>[
        '19,99',
        '1.234,56',
        '19.99 EUR',
        'EUR 19.99',
      ]) {
        expect(() => Money.parseDecimal(text, eur), throwsFormatException);
      }
    });

    test('rejects non-canonical punctuation and empty text', () {
      for (final text in <String>[
        '',
        '.99',
        '19.',
        '+19.99',
        '1.2.3',
        '1,000',
      ]) {
        expect(() => Money.parseDecimal(text, eur), throwsFormatException);
      }
    });
  });

  group('Money arithmetic', () {
    test('adds and subtracts in the same currency', () {
      expect(Money(1999, eur) + Money(1, eur), Money(2000, eur));
      expect(Money(1999, eur) - Money(1000, eur), Money(999, eur));
    });

    test('unary minus keeps the currency', () {
      expect(-Money(1999, eur), Money(-1999, eur));
      expect(-Money(-5, eur), Money(5, eur));
    });

    test('compareTo, isZero and isNegative work', () {
      expect(Money(10, eur).compareTo(Money(9, eur)), greaterThan(0));
      expect(Money(10, eur).compareTo(Money(10, eur)), 0);
      expect(Money(10, eur).compareTo(Money(11, eur)), lessThan(0));

      expect(Money(0, eur).isZero, isTrue);
      expect(Money(1, eur).isZero, isFalse);
      expect(Money(-1, eur).isNegative, isTrue);
      expect(Money(1, eur).isNegative, isFalse);
    });

    test('operands of different currencies throw CurrencyMismatchError', () {
      final eurMoney = Money(10, eur);
      final usdMoney = Money(10, usd);

      expect(() => eurMoney + usdMoney, throwsA(isA<CurrencyMismatchError>()));
      expect(() => eurMoney - usdMoney, throwsA(isA<CurrencyMismatchError>()));
      expect(
        () => eurMoney.compareTo(usdMoney),
        throwsA(isA<CurrencyMismatchError>()),
      );
    });
  });

  group('Money range bound', () {
    test('construction rejects amounts outside the bound', () {
      expect(
        () => Money(1000000000000001, eur),
        throwsA(isA<MoneyRangeError>()),
      );
      expect(
        () => Money(-1000000000000001, eur),
        throwsA(isA<MoneyRangeError>()),
      );
      expect(Money(1000000000000000, eur).minor, 1000000000000000);
      expect(Money(-1000000000000000, eur).minor, -1000000000000000);
    });

    test('arithmetic rejects results outside the bound', () {
      final max = Money(1000000000000000, eur);

      expect(() => max + Money(1, eur), throwsA(isA<MoneyRangeError>()));
      expect(() => -max - Money(1, eur), throwsA(isA<MoneyRangeError>()));
    });
  });

  group('Money.toDecimalString', () {
    test('renders the canonical text form', () {
      expect(Money(1999, eur).toDecimalString(), '19.99');
      expect(Money(-5, eur).toDecimalString(), '-0.05');
      expect(Money(100, jpy).toDecimalString(), '100');
      expect(Money(1990, eur).toDecimalString(), '19.90');
    });
  });

  group('Money.timesRate', () {
    test('keeps the exact rational product without rounding', () {
      final product = Money(550, eur).timesRate(RateBp(2100));

      expect(product.numerator, BigInt.from(1155000));
      expect(product.denominator, 10000);
      expect(product.currency, eur);

      expect(product.compareToMoney(Money(115, eur)), greaterThan(0));
      expect(product.compareToMoney(Money(116, eur)), lessThan(0));
    });

    test('distanceInMinorUnits returns the exact rational distance', () {
      final product = Money(550, eur).timesRate(RateBp(2100));

      final distance = product.distanceInMinorUnits(Money(116, eur));
      expect(distance.numerator, BigInt.from(5000));
      expect(distance.denominator, 10000);
      expect(distance.isZero, isFalse);

      final exact = Money(550, eur).timesRate(RateBp(1000));
      final exactDistance = exact.distanceInMinorUnits(Money(55, eur));
      expect(exactDistance.numerator, BigInt.zero);
      expect(exactDistance.isZero, isTrue);
    });

    test('comparison against another currency throws', () {
      final product = Money(100, eur).timesRate(RateBp(1000));

      expect(
        () => product.compareToMoney(Money(10, usd)),
        throwsA(isA<CurrencyMismatchError>()),
      );
    });
  });
}
