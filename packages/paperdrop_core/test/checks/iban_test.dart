import 'package:paperdrop_core/paperdrop_core.dart';
import 'package:test/test.dart';

void main() {
  group('Iban', () {
    test('[countries-languages/universal-core] the IBAN check', () {
      for (final iban in <String>[
        'DE89370400440532013000',
        'ES9121000418450200051332',
        'GB82WEST12345698765432',
        'FR1420041010050500013M02606',
        'NO9386011117947',
      ]) {
        expect(Iban.normalise(iban).isValid, CheckResult.valid, reason: iban);
      }

      for (final iban in <String>[
        'GB82TEST12345698765432',
        'DE89370400440532013001',
        'DE8937040044053201300',
        'QQ89370400440532013000',
      ]) {
        expect(Iban.normalise(iban).isValid, CheckResult.invalid, reason: iban);
      }
    });

    test('a grouped IBAN normalises and passes', () {
      final iban = Iban.normalise('DE89 3704 0044 0532 0130 00');
      expect(iban.normalised, 'DE89370400440532013000');
      expect(iban.isValid, CheckResult.valid);
    });

    test('an unknown country code is invalid, not an exception', () {
      expect(Iban.normalise('QQ1234567890123456').isValid, CheckResult.invalid);
    });

    test('a malformed alphabet is invalid', () {
      expect(
        Iban.normalise('DE89-3704-0044-0532-0130-00').isValid,
        CheckResult.invalid,
      );
    });
  });
}
