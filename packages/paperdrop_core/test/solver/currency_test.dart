import 'package:paperdrop_core/paperdrop_core.dart';
import 'package:test/test.dart';

void main() {
  final eur = CurrencyCode.parse('EUR')!;
  final usd = CurrencyCode.parse('USD')!;

  group('resolveCurrency', () {
    test('[extraction-pipeline/currency-is-read-from-the-document] '
        'a euro receipt is tagged EUR', () {
      final page = TextPage(0, 100000, 100000, [
        PositionedWord('EUR', 10000, 20000, 10000, 20000),
      ]);

      final evidence = readCurrencyEvidence([page]);
      final currency = resolveCurrency(evidence, CountryTable.launch);

      expect(
        currency,
        Present<CurrencyCode>(eur, Provenance.read, ConfidenceState.amber),
      );
    });

    test('[extraction-pipeline/currency-is-read-from-the-document] '
        'a dollar invoice is not turned into euros', () {
      final page = TextPage(0, 100000, 100000, [
        PositionedWord(r'$', 10000, 20000, 10000, 20000),
      ]);

      final evidence = readCurrencyEvidence([page]);
      final currency = resolveCurrency(evidence, CountryTable.launch);

      expect(
        currency,
        Present<CurrencyCode>(usd, Provenance.read, ConfidenceState.amber),
      );
      expect(
        currency,
        isNot(
          Present<CurrencyCode>(eur, Provenance.read, ConfidenceState.amber),
        ),
      );
    });

    test('[extraction-pipeline/currency-is-read-from-the-document] '
        'an unreadable currency is not defaulted', () {
      final page = TextPage(0, 100000, 100000, [
        PositionedWord('nada', 10000, 20000, 10000, 20000),
      ]);

      final evidence = readCurrencyEvidence([page]);
      final currency = resolveCurrency(evidence, CountryTable.launch);

      expect(currency, const Absent<CurrencyCode>());
    });

    test('the issuer country resolves through the country table', () {
      const evidence = CurrencyEvidence(issuerCountry: 'ES');

      expect(
        resolveCurrency(evidence, CountryTable.launch),
        Present<CurrencyCode>(eur, Provenance.read, ConfidenceState.amber),
      );
    });

    test('conflicting evidence leaves the currency Absent', () {
      final page = TextPage(0, 100000, 100000, [
        PositionedWord('EUR', 10000, 20000, 10000, 20000),
        PositionedWord(r'$', 30000, 40000, 10000, 20000),
      ]);

      final evidence = readCurrencyEvidence([page]);
      final currency = resolveCurrency(evidence, CountryTable.launch);

      expect(currency, const Absent<CurrencyCode>());
    });

    test('a symbol resolves on a synthetic page', () {
      final page = TextPage(0, 100000, 100000, [
        PositionedWord('€', 10000, 20000, 10000, 20000),
      ]);

      expect(
        resolveCurrency(readCurrencyEvidence([page]), CountryTable.launch),
        Present<CurrencyCode>(eur, Provenance.read, ConfidenceState.amber),
      );
    });
  });
}
