import 'package:paperdrop_core/paperdrop_core.dart';
import 'package:test/test.dart';

void main() {
  group('[validation-confidence/check-digit-validators] '
      'each validator is accepted against vectors', () {
    test('IBAN', () {
      expect(
        Iban.normalise('DE89370400440532013000').isValid,
        CheckResult.valid,
      );
      expect(
        Iban.normalise('ES9121000418450200051332').isValid,
        CheckResult.valid,
      );
      expect(
        Iban.normalise('DE89370400440532013001').isValid,
        CheckResult.invalid,
      );
      expect(
        Iban.normalise('QQ89370400440532013000').isValid,
        CheckResult.invalid,
      );
    });

    test('EAN-13', () {
      expect(isValidEan13('8435430627640'), CheckResult.valid);
      expect(isValidEan13('4006381333931'), CheckResult.valid);
      expect(isValidEan13('8435430627840'), CheckResult.invalid);
      expect(isValidEan13('843543062764A'), CheckResult.invalid);
    });

    test('ES NIF', () {
      expect(isValidEsNif('12345679S'), CheckResult.valid);
      expect(isValidEsNif('12345679T'), CheckResult.invalid);
      expect(isValidEsNif('123456795'), CheckResult.invalid);
    });

    test('ES NIE', () {
      expect(
        isValidEsNie(
          'X1234567'
          'L',
        ),
        CheckResult.valid,
      );
      expect(
        isValidEsNie(
          'Y1234567'
          'X',
        ),
        CheckResult.valid,
      );
      expect(
        isValidEsNie(
          'Z1234567'
          'R',
        ),
        CheckResult.valid,
      );
      expect(
        isValidEsNie(
          'X1234567'
          'T',
        ),
        CheckResult.invalid,
      );
      expect(
        isValidEsNie(
          'W1234567'
          'L',
        ),
        CheckResult.invalid,
      );
    });

    test('ES CIF', () {
      expect(isValidEsCif('A28017895'), CheckResult.valid);
      expect(isValidEsCif('B12345674'), CheckResult.valid);
      expect(isValidEsCif('Q2826000H'), CheckResult.valid);
      expect(isValidEsCif('A28017894'), CheckResult.invalid);
      expect(isValidEsCif('A2801789J'), CheckResult.invalid);
    });
  });

  group('German identifiers left unchecked', () {
    test('[validation-confidence/check-digit-validators] '
        'the German Steuernummer is not validated', () {
      expect(isValidDeStnr('289/65/43'), CheckResult.notChecked);
      expect(isValidDeUstid('DE123456789'), CheckResult.notChecked);
    });
  });
}
