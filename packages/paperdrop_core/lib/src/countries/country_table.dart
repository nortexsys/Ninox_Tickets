/// The country table for the launch rows ES and DE.
///
/// Requirement served: `countries-languages` · `country-table-contract` and
/// `launch-rows`. Adding a country is one row plus at most one small
/// check-digit function; the universal core still applies where no row exists.
library;

import '../format/date.dart';
import '../format/decimal.dart';
import '../money/currency.dart';
import '../money/rate.dart';
import 'tax_id.dart';

final RegExp _countryCodeShape = RegExp(r'^[A-Z]{2}$');

/// The cash-rounding rule declared by a country row.
enum CashRounding {
  /// No rounding adjustment is declared; both launch rows use this value.
  none,
}

/// One country row of the country table.
class CountryRow {
  /// The ISO 3166-1 alpha-2 country code.
  final String countryCode;

  /// The currency the row declares for its documents.
  final CurrencyCode currency;

  /// The tax identifier types the row recognises.
  final List<TaxIdType> taxIdTypes;

  /// The legal tax rates, in basis points, the zero rate included.
  final Set<RateBp> legalRates;

  /// The printed date order.
  final DateOrder dateOrder;

  /// The printed date separator (`.` or `/` for the launch rows).
  final String dateSeparator;

  /// The printed decimal convention.
  final DecimalConvention decimalConvention;

  /// The cash-rounding rule; `none` for both launch rows.
  final CashRounding cashRounding;

  /// Creates a country row.
  ///
  /// The [countryCode] must be two upper-case letters. [taxIdTypes] and
  /// [legalRates] are copied into unmodifiable collections.
  CountryRow({
    required this.countryCode,
    required this.currency,
    required List<TaxIdType> taxIdTypes,
    required Set<RateBp> legalRates,
    required this.dateOrder,
    required this.dateSeparator,
    required this.decimalConvention,
    required this.cashRounding,
  }) : taxIdTypes = List.unmodifiable(taxIdTypes),
       legalRates = Set.unmodifiable(legalRates) {
    if (!_countryCodeShape.hasMatch(countryCode)) {
      throw ArgumentError.value(
        countryCode,
        'countryCode',
        'must be an ISO 3166-1 alpha-2 code',
      );
    }
  }

  /// The number of tax slots this row implies: exactly [legalRates]'s length.
  ///
  /// It is never a stored field (`country-table-contract`, *the slot count
  /// follows the rate set*).
  int get slotCount => legalRates.length;

  /// Whether [rate] is one of this row's legal rates.
  bool isLegalRate(RateBp rate) => legalRates.contains(rate);

  /// A value-only string form naming the country code and slot count.
  @override
  String toString() => 'CountryRow($countryCode, $slotCount slots)';

  /// Value equality on every declared field.
  @override
  bool operator ==(Object other) {
    if (other is! CountryRow) {
      return false;
    }
    return other.countryCode == countryCode &&
        other.currency == currency &&
        _listEquals(other.taxIdTypes, taxIdTypes) &&
        _setEquals(other.legalRates, legalRates) &&
        other.dateOrder == dateOrder &&
        other.dateSeparator == dateSeparator &&
        other.decimalConvention == decimalConvention &&
        other.cashRounding == cashRounding;
  }

  @override
  int get hashCode => Object.hash(
    countryCode,
    currency,
    Object.hashAll(taxIdTypes),
    Object.hashAllUnordered(legalRates),
    dateOrder,
    dateSeparator,
    decimalConvention,
    cashRounding,
  );
}

/// The launch country table: ES and DE.
class CountryTable {
  /// The rows in this table, in declaration order.
  final List<CountryRow> rows;

  /// Creates a table from [rows], copied into an unmodifiable list.
  CountryTable(Iterable<CountryRow> rows) : rows = List.unmodifiable(rows);

  /// The Spanish row: EUR; `ES_NIF`, `ES_NIE`, `ES_CIF`; 2100, 1000, 400, 0;
  /// `DD/MM/YYYY`; decimal comma; no cash rounding.
  static final CountryRow es = CountryRow(
    countryCode: 'ES',
    currency: CurrencyCode.parse('EUR')!,
    taxIdTypes: <TaxIdType>[TaxIdType.esNif, TaxIdType.esNie, TaxIdType.esCif],
    legalRates: <RateBp>{RateBp(2100), RateBp(1000), RateBp(400), RateBp(0)},
    dateOrder: DateOrder.dmy,
    dateSeparator: '/',
    decimalConvention: DecimalConvention.commaDecimal,
    cashRounding: CashRounding.none,
  );

  /// The German row: EUR; `DE_USTID`, `DE_STNR`; 1900, 700, 0;
  /// `DD.MM.YYYY`; decimal comma; no cash rounding.
  static final CountryRow de = CountryRow(
    countryCode: 'DE',
    currency: CurrencyCode.parse('EUR')!,
    taxIdTypes: <TaxIdType>[TaxIdType.deUstid, TaxIdType.deStnr],
    legalRates: <RateBp>{RateBp(1900), RateBp(700), RateBp(0)},
    dateOrder: DateOrder.dmy,
    dateSeparator: '.',
    decimalConvention: DecimalConvention.commaDecimal,
    cashRounding: CashRounding.none,
  );

  /// The launch table containing [es] and [de].
  static final CountryTable launch = CountryTable(<CountryRow>[es, de]);

  /// Returns the row for [countryCode], or `null` when no row exists.
  CountryRow? rowFor(String countryCode) {
    for (final row in rows) {
      if (row.countryCode == countryCode) {
        return row;
      }
    }
    return null;
  }

  /// Returns the row that recognises [type].
  ///
  /// Every [TaxIdType] in this dispatch belongs to the ES or DE row, so a row
  /// always exists.
  CountryRow rowForTaxIdType(TaxIdType type) {
    for (final row in rows) {
      if (row.taxIdTypes.contains(type)) {
        return row;
      }
    }
    throw StateError('no country row for tax id type ${type.wireName}');
  }

  /// A value-only string form naming the row count.
  @override
  String toString() => 'CountryTable(${rows.length} rows)';

  /// Value equality on the row list.
  @override
  bool operator ==(Object other) {
    if (other is! CountryTable) {
      return false;
    }
    if (other.rows.length != rows.length) {
      return false;
    }
    for (var i = 0; i < rows.length; i++) {
      if (other.rows[i] != rows[i]) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(rows);
}

bool _listEquals(List<TaxIdType> left, List<TaxIdType> right) {
  if (left.length != right.length) {
    return false;
  }
  for (var i = 0; i < left.length; i++) {
    if (left[i] != right[i]) {
      return false;
    }
  }
  return true;
}

bool _setEquals(Set<RateBp> left, Set<RateBp> right) {
  if (left.length != right.length) {
    return false;
  }
  return left.containsAll(right);
}
