import 'package:paperdrop_core/paperdrop_core.dart';
import 'package:test/test.dart';

/// Pins the minor-unit exponent of the ISO 4217 codes most at risk of a
/// transcription error (an exponent that differs from the neighbouring "2"
/// by a wrong digit is a silent x10 error on every amount in that currency).
///
/// The values below were verified on 2026-09-30 against the ISO 4217
/// "List One" published by SIX Financial Information (`Pblshd="2026-09-17"`),
/// fetched from the maintenance agency directly rather than taken from
/// memory. See `validation/reviews/iso4217-2026-09-30.md` for the full
/// comparison: 165 codes checked in both directions, zero differences,
/// including every code pinned here.
void main() {
  group('CurrencyCode.parse pins exponents at risk of transcription error', () {
    const pinned = <String, int>{
      // Zero-exponent currencies: easy to mistake for a "2" default.
      'JPY': 0,
      'KRW': 0,
      'ISK': 0,
      'CLP': 0,
      // Three-exponent currencies: the rarest exponent, easy to drop to 2.
      'BHD': 3,
      'KWD': 3,
      'JOD': 3,
      'OMR': 3,
      'TND': 3,
      'LYD': 3,
      'IQD': 3,
      // Four-exponent currencies: the only two ISO 4217 codes with
      // exponent 4.
      'CLF': 4,
      'UYW': 4,
      // The two most common exponent-2 currencies, as a control.
      'EUR': 2,
      'USD': 2,
    };

    for (final entry in pinned.entries) {
      test('${entry.key} has exponent ${entry.value}', () {
        final currency = CurrencyCode.parse(entry.key);

        expect(
          currency,
          isNotNull,
          reason: '${entry.key} must be a known ISO 4217 code',
        );
        expect(currency!.exponent, entry.value);
      });
    }
  });
}
