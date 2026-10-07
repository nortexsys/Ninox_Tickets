/// Currency evidence and resolution from the document's own evidence.
///
/// Requirement served: `extraction-pipeline` ·
/// `currency-is-read-from-the-document` — the currency comes from the printed
/// ISO code, the printed symbol or the issuer country, never from a default.
library;

import '../countries/country_table.dart';
import '../layout/text_page.dart';
import '../model/confidence.dart';
import '../model/field_value.dart';
import '../model/provenance.dart';
import '../money/currency.dart';

/// The document's own currency evidence.
class CurrencyEvidence {
  /// Printed ISO 4217 codes, in reading order.
  final List<CurrencyCode> isoCodes;

  /// Currencies named by printed symbols, in reading order.
  final List<CurrencyCode> symbols;

  /// The issuer country, as an ISO 3166-1 alpha-2 code, when known.
  final String? issuerCountry;

  /// Creates currency evidence.
  const CurrencyEvidence({
    this.isoCodes = const <CurrencyCode>[],
    this.symbols = const <CurrencyCode>[],
    this.issuerCountry,
  });

  /// A value-only string form naming the evidence.
  @override
  String toString() =>
      'CurrencyEvidence(iso: $isoCodes, symbols: $symbols, '
      'issuerCountry: $issuerCountry)';

  /// Value equality on every field.
  @override
  bool operator ==(Object other) =>
      other is CurrencyEvidence &&
      other.issuerCountry == issuerCountry &&
      _listEquals(other.isoCodes, isoCodes) &&
      _listEquals(other.symbols, symbols);

  @override
  int get hashCode => Object.hash(
    issuerCountry,
    Object.hashAll(isoCodes),
    Object.hashAll(symbols),
  );
}

/// Reads currency evidence from [pages].
///
/// ISO codes are matched case-insensitively; symbols are matched exactly.
/// [issuerCountry] is the country detection's result, not something read from
/// the page here.
CurrencyEvidence readCurrencyEvidence(
  Iterable<TextPage> pages, {
  String? issuerCountry,
}) {
  final isoCodes = <CurrencyCode>[];
  final symbols = <CurrencyCode>[];

  for (final page in pages) {
    for (final word in page.words) {
      final isoCode = CurrencyCode.parse(word.text.toUpperCase());
      if (isoCode != null) {
        isoCodes.add(isoCode);
      }

      final symbol = _currencyForSymbol(word.text);
      if (symbol != null) {
        symbols.add(symbol);
      }
    }
  }

  return CurrencyEvidence(
    isoCodes: isoCodes,
    symbols: symbols,
    issuerCountry: issuerCountry,
  );
}

/// Resolves [evidence] into a currency field value.
///
/// When the ISO codes, symbols and issuer country all agree on one currency,
/// that currency is present with `read` provenance. Conflicting evidence, and
/// no evidence, leave the currency [Absent]; the table's currency is never
/// substituted for the document's own evidence.
FieldValue<CurrencyCode> resolveCurrency(
  CurrencyEvidence evidence,
  CountryTable table,
) {
  final codes = <CurrencyCode>{};
  codes.addAll(evidence.isoCodes);
  codes.addAll(evidence.symbols);

  final issuerCountry = evidence.issuerCountry;
  if (issuerCountry != null) {
    final issuerCurrency = table.rowFor(issuerCountry)?.currency;
    if (issuerCurrency != null) {
      codes.add(issuerCurrency);
    }
  }

  if (codes.length == 1) {
    return Present<CurrencyCode>(
      codes.single,
      Provenance.read,
      ConfidenceState.amber,
    );
  }

  return const Absent<CurrencyCode>();
}

const Map<String, String> _symbolToCode = <String, String>{
  '€': 'EUR',
  r'$': 'USD',
  '£': 'GBP',
  '¥': 'JPY',
};

CurrencyCode? _currencyForSymbol(String text) {
  final code = _symbolToCode[text];
  if (code == null) {
    return null;
  }
  return CurrencyCode.parse(code);
}

bool _listEquals(List<CurrencyCode> left, List<CurrencyCode> right) {
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
