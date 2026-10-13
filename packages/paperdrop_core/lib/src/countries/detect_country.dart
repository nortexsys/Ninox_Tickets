/// Country detection from the document's own evidence.
///
/// Requirement served: `countries-languages` ·
/// `deterministic-country-detection`. Detection reads only shape-level
/// evidence — tax identifiers, a closed country-name list, dictionary language
/// and currency — never a locale, a destination or a preference, and it never
/// returns document text.
library;

import '../dictionaries/lookup.dart';
import '../layout/lines.dart';
import '../layout/text_page.dart';
import '../money/currency.dart';
import '../solver/currency.dart';
import 'country_table.dart';
import 'tax_id.dart';

/// The kinds of evidence [Detected] may report.
enum CountryEvidenceKind {
  /// A tax identifier shape of a table country.
  taxId,

  /// A country name adjacent to an address block.
  countryName,

  /// The language of the label dictionaries.
  dictionaryLanguage,

  /// A printed ISO 4217 code or currency symbol.
  currency,
}

/// The reason a country could not be detected.
enum UndetectedReason {
  /// No evidence named a table country.
  noEvidence,

  /// Strong evidence named two or more countries and no medium evidence
  /// broke the tie.
  conflictingEvidence,

  /// The evidence points only at a country with no row (or a currency no row
  /// declares).
  countryWithoutRow,
}

/// The answer of [detectCountry].
sealed class CountryDetection {
  /// Creates a country detection answer.
  const CountryDetection();
}

/// A detected country row and the evidence kinds that decided it.
final class Detected extends CountryDetection {
  /// The country row that applies.
  final CountryRow row;

  /// The evidence kinds that decided the country, in decision order.
  final List<CountryEvidenceKind> evidence;

  /// Creates a detected country from [row] and [evidence].
  Detected({required this.row, required List<CountryEvidenceKind> evidence})
    : evidence = List.unmodifiable(evidence);

  /// The country and its evidence kinds, never any document text.
  @override
  String toString() => 'Detected(${row.countryCode}, $evidence)';

  /// Value equality on the row and evidence list.
  @override
  bool operator ==(Object other) =>
      other is Detected &&
      other.row == row &&
      _evidenceListEquals(other.evidence, evidence);

  @override
  int get hashCode => Object.hash(row, Object.hashAll(evidence));
}

/// An undetected country, with the reason why.
final class Undetected extends CountryDetection {
  /// The reason no country row applies.
  final UndetectedReason reason;

  /// Creates an undetected country from [reason].
  const Undetected({required this.reason});

  /// The reason, and nothing else.
  @override
  String toString() => 'Undetected($reason)';

  /// Value equality on the reason.
  @override
  bool operator ==(Object other) =>
      other is Undetected && other.reason == reason;

  @override
  int get hashCode => reason.hashCode;
}

/// Detects the country row that governs [pages] from the document's own
/// evidence.
///
/// The rules are applied in this order, with no scoring and no weighting:
///
/// 1. Exactly one country named by tax identifiers, with a row, is detected.
/// 2. Two or more tax-identifier countries fall back to medium evidence
///    (a country name adjacent to an address block); exactly one survivor is
///    detected, otherwise the evidence is conflicting.
/// 3. With no tax identifiers, one medium country is detected; dictionary
///    language alone is never enough.
/// 4. Evidence that points only at a country with no row, or a currency no
///    row declares, is `countryWithoutRow`.
CountryDetection detectCountry({
  required Iterable<TextPage> pages,
  required CountryTable table,
}) {
  final strongCountries = <String>{};
  var strongWithoutRow = false;

  for (final page in pages) {
    for (final word in page.words) {
      final type = classifyTaxId(normaliseTaxId(word.text));
      if (type == null) {
        continue;
      }

      final row = _rowForTaxIdType(table, type);
      if (row == null) {
        strongWithoutRow = true;
      } else {
        strongCountries.add(row.countryCode);
      }
    }
  }

  // Rule 1: one strong country with a row, and no strong no-row id.
  if (strongCountries.length == 1 && !strongWithoutRow) {
    return Detected(
      row: table.rowFor(strongCountries.single)!,
      evidence: const <CountryEvidenceKind>[CountryEvidenceKind.taxId],
    );
  }

  // A strong identifier of a country with no row is itself an answer when no
  // row country was also named.
  if (strongWithoutRow && strongCountries.isEmpty) {
    return const Undetected(reason: UndetectedReason.countryWithoutRow);
  }

  // Rule 2: conflicting tax-identifier countries need a medium tiebreak.
  if (strongCountries.length > 1) {
    final survivors = strongCountries.intersection(
      _mediumCountries(pages, table),
    );
    if (survivors.length == 1) {
      return Detected(
        row: table.rowFor(survivors.single)!,
        evidence: const <CountryEvidenceKind>[
          CountryEvidenceKind.taxId,
          CountryEvidenceKind.countryName,
        ],
      );
    }
    return const Undetected(reason: UndetectedReason.conflictingEvidence);
  }

  // A known strong country plus a no-row strong country is a conflict, never
  // a vote for the known country.
  if (strongCountries.length == 1 && strongWithoutRow) {
    return const Undetected(reason: UndetectedReason.conflictingEvidence);
  }

  // Rule 3: no strong evidence. A single medium country is detected; weak
  // dictionary language alone is never enough.
  if (strongCountries.isEmpty) {
    final mediumCountries = _mediumCountries(pages, table);
    if (mediumCountries.length == 1) {
      return Detected(
        row: table.rowFor(mediumCountries.single)!,
        evidence: const <CountryEvidenceKind>[CountryEvidenceKind.countryName],
      );
    }

    if (_dictionaryLanguageCountries(pages, table).isNotEmpty) {
      return const Undetected(reason: UndetectedReason.noEvidence);
    }

    // Rule 4: currency evidence that no row declares points at a country
    // without a row.
    if (_hasUndeclaredCurrency(pages, table)) {
      return const Undetected(reason: UndetectedReason.countryWithoutRow);
    }

    return const Undetected(reason: UndetectedReason.noEvidence);
  }

  return const Undetected(reason: UndetectedReason.noEvidence);
}

CountryRow? _rowForTaxIdType(CountryTable table, TaxIdType type) {
  for (final row in table.rows) {
    if (row.taxIdTypes.contains(type)) {
      return row;
    }
  }
  return null;
}

/// The country names that appear next to an address line.
///
/// A country name is medium evidence only when its line, or the line directly
/// above or below it, also carries a postal-code-shaped token. Elsewhere a
/// country name is only mentioned, not the issuer.
Set<String> _mediumCountries(Iterable<TextPage> pages, CountryTable table) {
  final countries = <String>{};

  for (final page in pages) {
    final lines = groupIntoLines(page);
    final addressLines = <int>{};
    for (var i = 0; i < lines.length; i++) {
      if (_lineLooksLikeAddress(lines[i])) {
        addressLines.add(i);
      }
    }

    for (var i = 0; i < lines.length; i++) {
      final nearAddress =
          addressLines.contains(i) ||
          (i > 0 && addressLines.contains(i - 1)) ||
          (i + 1 < lines.length && addressLines.contains(i + 1));
      if (!nearAddress) {
        continue;
      }

      for (final word in lines[i].words) {
        final country = _countryForName(word.text, table);
        if (country != null) {
          countries.add(country);
        }
      }
    }
  }

  return countries;
}

bool _lineLooksLikeAddress(LayoutLine line) =>
    line.words.any((word) => _postalCodeShape.hasMatch(word.text.trim()));

final RegExp _postalCodeShape = RegExp(r'^[0-9]{4,5}$');

String? _countryForName(String text, CountryTable table) {
  final token = _normalizeCountryToken(text);
  if (token.isEmpty) {
    return null;
  }

  for (final row in table.rows) {
    for (final name in row.countryNames) {
      if (_normalizeCountryToken(name) == token) {
        return row.countryCode;
      }
    }
  }
  return null;
}

/// The countries named by the language of the dictionary terms on the page.
///
/// Only languages that unambiguously name one row in this table count; the
/// result is weak evidence and never decides on its own.
Set<String> _dictionaryLanguageCountries(
  Iterable<TextPage> pages,
  CountryTable table,
) {
  final countries = <String>{};

  for (final page in pages) {
    for (final line in groupIntoLines(page)) {
      for (final match in findTerms(line.text)) {
        final country = _languageCountry[match.language];
        if (country != null && table.rowFor(country) != null) {
          countries.add(country);
        }
      }
    }
  }

  return countries;
}

const Map<String, String> _languageCountry = <String, String>{
  'es': 'ES',
  'de': 'DE',
};

bool _hasUndeclaredCurrency(Iterable<TextPage> pages, CountryTable table) {
  final declared = <CurrencyCode>{for (final row in table.rows) row.currency};
  final evidence = readCurrencyEvidence(pages);

  for (final code in evidence.isoCodes) {
    if (!declared.contains(code)) {
      return true;
    }
  }
  for (final code in evidence.symbols) {
    if (!declared.contains(code)) {
      return true;
    }
  }
  return false;
}

String _normalizeCountryToken(String text) {
  final normalized = text.toLowerCase().replaceAllMapped(
    _diacriticsPattern,
    (Match match) => _diacriticFold[match.group(0)]!,
  );

  var start = 0;
  while (start < normalized.length &&
      !_isAsciiLetter(normalized.codeUnitAt(start))) {
    start++;
  }
  var end = normalized.length;
  while (end > start && !_isAsciiLetter(normalized.codeUnitAt(end - 1))) {
    end--;
  }

  if (start >= end) {
    return '';
  }
  return normalized.substring(start, end);
}

bool _isAsciiLetter(int code) => code >= 0x61 && code <= 0x7A;

final RegExp _diacriticsPattern = RegExp('[áàâäãåéèêëíìîïóòôöõúùûüñçýÿ]');

const Map<String, String> _diacriticFold = <String, String>{
  'á': 'a',
  'à': 'a',
  'â': 'a',
  'ä': 'a',
  'ã': 'a',
  'å': 'a',
  'é': 'e',
  'è': 'e',
  'ê': 'e',
  'ë': 'e',
  'í': 'i',
  'ì': 'i',
  'î': 'i',
  'ï': 'i',
  'ó': 'o',
  'ò': 'o',
  'ô': 'o',
  'ö': 'o',
  'õ': 'o',
  'ú': 'u',
  'ù': 'u',
  'û': 'u',
  'ü': 'u',
  'ñ': 'n',
  'ç': 'c',
  'ý': 'y',
  'ÿ': 'y',
};

bool _evidenceListEquals(
  List<CountryEvidenceKind> left,
  List<CountryEvidenceKind> right,
) {
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
