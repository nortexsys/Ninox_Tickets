import 'package:paperdrop_core/paperdrop_core.dart';
import 'package:test/test.dart';

void main() {
  group('CurrencyCode.parse', () {
    const vectors = <String, int>{
      'EUR': 2,
      'USD': 2,
      'GBP': 2,
      'CHF': 2,
      'MAD': 2,
      'SEK': 2,
      'JPY': 0,
      'KRW': 0,
      'KWD': 3,
      'BHD': 3,
      'TND': 3,
      'CLF': 4,
    };

    for (final entry in vectors.entries) {
      test('${entry.key} has exponent ${entry.value}', () {
        final currency = CurrencyCode.parse(entry.key);

        expect(currency, isNotNull);
        expect(currency!.code, entry.key);
        expect(currency.exponent, entry.value);
      });
    }

    test('an unknown code returns null', () {
      expect(CurrencyCode.parse('XXX'), isNull);
      expect(CurrencyCode.parse('ABC'), isNull);
    });

    test('there is no default exponent for an unknown code', () {
      // The only construction path is parse, and it returns null for unknown
      // codes rather than fabricating a CurrencyCode with a default exponent.
      expect(CurrencyCode.parse('ABC'), isNull);
      expect(CurrencyCode.values.every((c) => c.exponent >= 0), isTrue);
    });
  });

  test('values contains only upper-case three-letter codes', () {
    expect(CurrencyCode.values, isNotEmpty);

    for (final currency in CurrencyCode.values) {
      expect(currency.code, matches(r'^[A-Z]{3}$'));
      expect(currency.exponent, inInclusiveRange(0, 4));
    }
  });

  test('value equality and string form use the code', () {
    final eur = CurrencyCode.parse('EUR')!;

    expect(eur, equals(CurrencyCode.parse('EUR')));
    expect(eur.toString(), 'EUR');
    expect(eur.hashCode, CurrencyCode.parse('EUR')!.hashCode);
  });
}
