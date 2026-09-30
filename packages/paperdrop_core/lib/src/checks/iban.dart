/// IBAN normalisation, the SWIFT length table and modulo-97 validation.
///
/// The length table below is transcribed from the SWIFT IBAN Registry,
/// release 101. The IBAN check is part of the universal core and does not
/// depend on the country table.
///
/// Requirement served: `countries-languages` · `universal-core`
/// (`the IBAN check`).
library;

import 'check_result.dart';

/// A normalised IBAN and its modulo-97 verdict.
class Iban {
  /// The upper-case IBAN with every space removed.
  final String normalised;

  const Iban._(this.normalised);

  static final RegExp _pattern = RegExp(r'^[A-Z]{2}[0-9]{2}[A-Z0-9]+$');

  /// The fixed IBAN length of every country in the SWIFT IBAN Registry.
  ///
  /// The registry entry for a country code is its total IBAN length: two
  /// country letters, two check digits and the national BBAN.
  static const Map<String, int> _lengthByCountry = <String, int>{
    'AD': 24,
    'AE': 23,
    'AL': 28,
    'AT': 20,
    'AZ': 28,
    'BA': 20,
    'BE': 16,
    'BG': 22,
    'BH': 22,
    'BI': 27,
    'BR': 29,
    'BY': 28,
    'CH': 21,
    'CR': 22,
    'CY': 28,
    'CZ': 24,
    'DE': 22,
    'DJ': 27,
    'DK': 18,
    'DO': 28,
    'EE': 20,
    'EG': 29,
    'ES': 24,
    'FI': 18,
    'FK': 18,
    'FO': 18,
    'FR': 27,
    'GB': 22,
    'GE': 22,
    'GI': 23,
    'GL': 18,
    'GR': 27,
    'GT': 28,
    'HN': 28,
    'HR': 21,
    'HU': 28,
    'IE': 22,
    'IL': 23,
    'IQ': 23,
    'IS': 26,
    'IT': 27,
    'JO': 30,
    'KW': 30,
    'KZ': 20,
    'LB': 28,
    'LC': 32,
    'LI': 21,
    'LT': 20,
    'LU': 20,
    'LV': 21,
    'LY': 25,
    'MC': 27,
    'MD': 24,
    'ME': 22,
    'MK': 19,
    'MN': 20,
    'MR': 27,
    'MT': 31,
    'MU': 30,
    'NI': 28,
    'NL': 18,
    'NO': 15,
    'OM': 23,
    'PK': 24,
    'PL': 28,
    'PS': 29,
    'PT': 25,
    'QA': 29,
    'RO': 24,
    'RS': 22,
    'RU': 33,
    'SA': 24,
    'SC': 31,
    'SD': 18,
    'SE': 24,
    'SI': 19,
    'SK': 24,
    'SM': 27,
    'SO': 23,
    'ST': 25,
    'SV': 28,
    'TL': 23,
    'TN': 24,
    'TR': 26,
    'UA': 29,
    'VA': 22,
    'VG': 24,
    'XK': 20,
    'YE': 30,
  };

  /// Normalises [raw] by upper-casing it and removing every space.
  ///
  /// Normalisation is not validation: the result may still be an unknown
  /// country code, the wrong length, or a failed modulo-97 check. Callers that
  /// need the verdict use [isValid].
  static Iban normalise(String raw) =>
      Iban._(raw.toUpperCase().replaceAll(' ', ''));

  /// Validates the normalised IBAN: known country code, exact registry length,
  /// and remainder 1 after moving the first four characters to the end and
  /// converting letters to 10 through 35.
  ///
  /// The remainder is computed piecewise on `int`, so the largest intermediate
  /// value stays below one thousand.
  CheckResult get isValid {
    if (normalised.length < 4 || !_pattern.hasMatch(normalised)) {
      return CheckResult.invalid;
    }

    final countryCode = normalised.substring(0, 2);
    final expectedLength = _lengthByCountry[countryCode];
    if (expectedLength == null || normalised.length != expectedLength) {
      return CheckResult.invalid;
    }

    final rearranged = normalised.substring(4) + normalised.substring(0, 4);
    var remainder = 0;
    for (var i = 0; i < rearranged.length; i++) {
      final code = rearranged.codeUnitAt(i);
      if (code >= 0x41 && code <= 0x5A) {
        remainder = _feed(remainder, code - 0x41 + 10);
      } else {
        remainder = _feed(remainder, code - 0x30);
      }
    }

    return remainder == 1 ? CheckResult.valid : CheckResult.invalid;
  }

  int _feed(int remainder, int value) {
    if (value >= 10) {
      remainder = (remainder * 10 + value ~/ 10) % 97;
    }
    return (remainder * 10 + value % 10) % 97;
  }

  /// The normalised IBAN, as the value itself.
  @override
  String toString() => normalised;

  /// Value equality on the normalised text.
  @override
  bool operator ==(Object other) =>
      other is Iban && other.normalised == normalised;

  @override
  int get hashCode => normalised.hashCode;
}
