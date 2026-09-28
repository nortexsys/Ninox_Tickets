/// ISO 4217 alphabetic currency codes and their minor-unit exponents.
///
/// The table below is transcribed from the ISO 4217 "List One" published by
/// SIX Financial Information, the ISO 4217 maintenance agency, on 2026-09-17.
/// Only active codes that carry a numeric minor unit are included: a code such
/// as `XXX` (no currency) has no exponent and is therefore not a currency.
///
/// Requirement served: BR-09 (`money-as-integer-minor-units`) — every amount is
/// an integer in its currency's minor unit, and the exponent comes from this
/// table, never from a default.
library;

class CurrencyCode {
  /// The three-letter upper-case ISO 4217 code.
  final String code;

  /// The number of minor units per major unit, expressed as a power of ten.
  ///
  /// For example, `EUR` has exponent 2 (100 minor units per euro), `JPY` has
  /// exponent 0, and `CLF` has exponent 4.
  final int exponent;

  const CurrencyCode._(this.code, this.exponent);

  static final Map<String, CurrencyCode> _byCode = Map.unmodifiable(
    <String, CurrencyCode>{for (final c in values) c.code: c},
  );

  /// Parses a three-letter upper-case ISO 4217 code.
  ///
  /// Returns `null` for an unknown code. There is deliberately no default
  /// exponent: an unknown code is not a currency, and a missing exponent must
  /// never silently become 2.
  static CurrencyCode? parse(String code) => _byCode[code];

  /// The active ISO 4217 codes that have a numeric minor unit, in code order.
  static const List<CurrencyCode> values = <CurrencyCode>[
    CurrencyCode._('AED', 2),
    CurrencyCode._('AFN', 2),
    CurrencyCode._('ALL', 2),
    CurrencyCode._('AMD', 2),
    CurrencyCode._('AOA', 2),
    CurrencyCode._('ARS', 2),
    CurrencyCode._('AUD', 2),
    CurrencyCode._('AWG', 2),
    CurrencyCode._('AZN', 2),
    CurrencyCode._('BAM', 2),
    CurrencyCode._('BBD', 2),
    CurrencyCode._('BDT', 2),
    CurrencyCode._('BHD', 3),
    CurrencyCode._('BIF', 0),
    CurrencyCode._('BMD', 2),
    CurrencyCode._('BND', 2),
    CurrencyCode._('BOB', 2),
    CurrencyCode._('BOV', 2),
    CurrencyCode._('BRL', 2),
    CurrencyCode._('BSD', 2),
    CurrencyCode._('BTN', 2),
    CurrencyCode._('BWP', 2),
    CurrencyCode._('BYN', 2),
    CurrencyCode._('BZD', 2),
    CurrencyCode._('CAD', 2),
    CurrencyCode._('CDF', 2),
    CurrencyCode._('CHE', 2),
    CurrencyCode._('CHF', 2),
    CurrencyCode._('CHW', 2),
    CurrencyCode._('CLF', 4),
    CurrencyCode._('CLP', 0),
    CurrencyCode._('CNY', 2),
    CurrencyCode._('COP', 2),
    CurrencyCode._('COU', 2),
    CurrencyCode._('CRC', 2),
    CurrencyCode._('CUP', 2),
    CurrencyCode._('CVE', 2),
    CurrencyCode._('CZK', 2),
    CurrencyCode._('DJF', 0),
    CurrencyCode._('DKK', 2),
    CurrencyCode._('DOP', 2),
    CurrencyCode._('DZD', 2),
    CurrencyCode._('EGP', 2),
    CurrencyCode._('ERN', 2),
    CurrencyCode._('ETB', 2),
    CurrencyCode._('EUR', 2),
    CurrencyCode._('FJD', 2),
    CurrencyCode._('FKP', 2),
    CurrencyCode._('GBP', 2),
    CurrencyCode._('GEL', 2),
    CurrencyCode._('GHS', 2),
    CurrencyCode._('GIP', 2),
    CurrencyCode._('GMD', 2),
    CurrencyCode._('GNF', 0),
    CurrencyCode._('GTQ', 2),
    CurrencyCode._('GYD', 2),
    CurrencyCode._('HKD', 2),
    CurrencyCode._('HNL', 2),
    CurrencyCode._('HTG', 2),
    CurrencyCode._('HUF', 2),
    CurrencyCode._('IDR', 2),
    CurrencyCode._('ILS', 2),
    CurrencyCode._('INR', 2),
    CurrencyCode._('IQD', 3),
    CurrencyCode._('IRR', 2),
    CurrencyCode._('ISK', 0),
    CurrencyCode._('JMD', 2),
    CurrencyCode._('JOD', 3),
    CurrencyCode._('JPY', 0),
    CurrencyCode._('KES', 2),
    CurrencyCode._('KGS', 2),
    CurrencyCode._('KHR', 2),
    CurrencyCode._('KMF', 0),
    CurrencyCode._('KPW', 2),
    CurrencyCode._('KRW', 0),
    CurrencyCode._('KWD', 3),
    CurrencyCode._('KYD', 2),
    CurrencyCode._('KZT', 2),
    CurrencyCode._('LAK', 2),
    CurrencyCode._('LBP', 2),
    CurrencyCode._('LKR', 2),
    CurrencyCode._('LRD', 2),
    CurrencyCode._('LSL', 2),
    CurrencyCode._('LYD', 3),
    CurrencyCode._('MAD', 2),
    CurrencyCode._('MDL', 2),
    CurrencyCode._('MGA', 2),
    CurrencyCode._('MKD', 2),
    CurrencyCode._('MMK', 2),
    CurrencyCode._('MNT', 2),
    CurrencyCode._('MOP', 2),
    CurrencyCode._('MRU', 2),
    CurrencyCode._('MUR', 2),
    CurrencyCode._('MVR', 2),
    CurrencyCode._('MWK', 2),
    CurrencyCode._('MXN', 2),
    CurrencyCode._('MXV', 2),
    CurrencyCode._('MYR', 2),
    CurrencyCode._('MZN', 2),
    CurrencyCode._('NAD', 2),
    CurrencyCode._('NGN', 2),
    CurrencyCode._('NIO', 2),
    CurrencyCode._('NOK', 2),
    CurrencyCode._('NPR', 2),
    CurrencyCode._('NZD', 2),
    CurrencyCode._('OMR', 3),
    CurrencyCode._('PAB', 2),
    CurrencyCode._('PEN', 2),
    CurrencyCode._('PGK', 2),
    CurrencyCode._('PHP', 2),
    CurrencyCode._('PKR', 2),
    CurrencyCode._('PLN', 2),
    CurrencyCode._('PYG', 0),
    CurrencyCode._('QAR', 2),
    CurrencyCode._('RON', 2),
    CurrencyCode._('RSD', 2),
    CurrencyCode._('RUB', 2),
    CurrencyCode._('RWF', 0),
    CurrencyCode._('SAR', 2),
    CurrencyCode._('SBD', 2),
    CurrencyCode._('SCR', 2),
    CurrencyCode._('SDG', 2),
    CurrencyCode._('SEK', 2),
    CurrencyCode._('SGD', 2),
    CurrencyCode._('SHP', 2),
    CurrencyCode._('SLE', 2),
    CurrencyCode._('SOS', 2),
    CurrencyCode._('SRD', 2),
    CurrencyCode._('SSP', 2),
    CurrencyCode._('STN', 2),
    CurrencyCode._('SVC', 2),
    CurrencyCode._('SYP', 2),
    CurrencyCode._('SZL', 2),
    CurrencyCode._('THB', 2),
    CurrencyCode._('TJS', 2),
    CurrencyCode._('TMT', 2),
    CurrencyCode._('TND', 3),
    CurrencyCode._('TOP', 2),
    CurrencyCode._('TRY', 2),
    CurrencyCode._('TTD', 2),
    CurrencyCode._('TWD', 2),
    CurrencyCode._('TZS', 2),
    CurrencyCode._('UAH', 2),
    CurrencyCode._('UGX', 0),
    CurrencyCode._('USD', 2),
    CurrencyCode._('USN', 2),
    CurrencyCode._('UYI', 0),
    CurrencyCode._('UYU', 2),
    CurrencyCode._('UYW', 4),
    CurrencyCode._('UZS', 2),
    CurrencyCode._('VED', 2),
    CurrencyCode._('VES', 2),
    CurrencyCode._('VND', 0),
    CurrencyCode._('VUV', 0),
    CurrencyCode._('WST', 2),
    CurrencyCode._('XAD', 2),
    CurrencyCode._('XAF', 0),
    CurrencyCode._('XCD', 2),
    CurrencyCode._('XCG', 2),
    CurrencyCode._('XOF', 0),
    CurrencyCode._('XPF', 0),
    CurrencyCode._('YER', 2),
    CurrencyCode._('ZAR', 2),
    CurrencyCode._('ZMW', 2),
    CurrencyCode._('ZWG', 2),
  ];

  /// The ISO 4217 code, as the value itself.
  @override
  String toString() => code;

  /// Value equality: same code and same exponent.
  @override
  bool operator ==(Object other) =>
      other is CurrencyCode && other.code == code && other.exponent == exponent;

  @override
  int get hashCode => Object.hash(code, exponent);

  /// Serialises this code as its ISO 4217 text form.
  Object? toJson() => code;

  /// Reads an ISO 4217 code from a JSON value.
  static CurrencyCode? fromJson(Object? json) =>
      json is String ? parse(json) : null;
}
