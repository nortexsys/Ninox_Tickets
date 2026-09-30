import 'package:paperdrop_core/paperdrop_core.dart';
import 'package:test/test.dart';

void main() {
  final eur = CurrencyCode.parse('EUR')!;

  test(
    '[countries-languages/launch-rows] the German row applies its own rates',
    () {
      final de = CountryTable.de;

      expect(de.isLegalRate(RateBp(1900)), isTrue);
      expect(de.isLegalRate(RateBp(700)), isTrue);
      expect(de.isLegalRate(RateBp(0)), isTrue);
      expect(de.isLegalRate(RateBp(2000)), isFalse);
      expect(de.isLegalRate(RateBp(2100)), isFalse);
      expect(de.currency, eur);
    },
  );

  test('[countries-languages/country-table-contract] '
      'the slot count follows the rate set', () {
    expect(CountryTable.es.slotCount, CountryTable.es.legalRates.length);
    expect(CountryTable.es.slotCount, 4);
    expect(CountryTable.de.slotCount, CountryTable.de.legalRates.length);
    expect(CountryTable.de.slotCount, 3);
  });

  test('[countries-languages/deterministic-country-detection] '
      'a Spanish ticket is detected from its identifier', () {
    final row = CountryTable.launch.rowForTaxIdType(TaxIdType.esCif);
    expect(row.countryCode, 'ES');
    expect(row.taxIdTypes, contains(TaxIdType.esCif));
    expect(row.currency, eur);
  });

  test('[countries-languages/country-table-contract] '
      'adding a country touches almost nothing', () {
    final thirdRow = CountryRow(
      countryCode: 'AT',
      currency: eur,
      taxIdTypes: <TaxIdType>[TaxIdType.deUstid],
      legalRates: <RateBp>{RateBp(2000), RateBp(1300), RateBp(1000), RateBp(0)},
      dateOrder: DateOrder.dmy,
      dateSeparator: '.',
      decimalConvention: DecimalConvention.commaDecimal,
      cashRounding: CashRounding.none,
    );

    final table = CountryTable(<CountryRow>[
      CountryTable.es,
      CountryTable.de,
      thirdRow,
    ]);

    expect(table.rowFor('AT'), thirdRow);
    expect(table.rowFor('ES'), CountryTable.es);
    expect(table.rowFor('DE'), CountryTable.de);
    expect(table.rowFor('CH'), isNull);
    expect(thirdRow.slotCount, 4);
    expect(thirdRow.isLegalRate(RateBp(2000)), isTrue);
    expect(thirdRow.isLegalRate(RateBp(1900)), isFalse);
  });

  test('a German identifier resolves to the German row', () {
    expect(
      CountryTable.launch.rowForTaxIdType(TaxIdType.deUstid).countryCode,
      'DE',
    );
    expect(
      CountryTable.launch.rowForTaxIdType(TaxIdType.deStnr).countryCode,
      'DE',
    );
  });

  test('a country with no row returns null but the core still applies', () {
    expect(CountryTable.launch.rowFor('CH'), isNull);
    expect(isValidEan13('8435430627640'), CheckResult.valid);
    expect(Iban.normalise('DE89370400440532013000').isValid, CheckResult.valid);
  });
}
