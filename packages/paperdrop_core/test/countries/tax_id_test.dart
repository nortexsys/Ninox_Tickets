import 'package:paperdrop_core/paperdrop_core.dart';
import 'package:test/test.dart';

// The three valid NIE vectors are the public documentation examples of the
// format. They are written once, as plain literals, so the privacy job can
// find and report them (design §4); the lane does not dodge that finding.
const String validNieX = 'X1234567L';
const String validNieY = 'Y1234567X';
const String validNieZ = 'Z1234567R';

void main() {
  group('TaxId normalisation', () {
    test('[countries-languages/tax-identifier-normalisation] '
        'a printed form and its normalised form are both kept', () {
      final taxId = TaxId.parse('DE 123 456 789');
      expect(taxId.raw, 'DE 123 456 789');
      expect(taxId.normalised, 'DE123456789');
      expect(taxId.type, TaxIdType.deUstid);
    });

    test('[countries-languages/tax-identifier-normalisation] '
        'punctuation is removed from a Spanish identifier', () {
      final taxId = TaxId.parse('A-28.017.895');
      expect(taxId.raw, 'A-28.017.895');
      expect(taxId.normalised, 'A28017895');
      expect(taxId.type, TaxIdType.esCif);
    });

    test('an ES prefix is kept and the type is decided after it', () {
      final taxId = TaxId.parse('ESA28017895');
      expect(taxId.normalised, 'ESA28017895');
      expect(taxId.type, TaxIdType.esCif);
    });
  });

  group('TaxId classification', () {
    test('classifies the three Spanish shapes and the German UStID', () {
      expect(classifyTaxId('12345679S'), TaxIdType.esNif);
      expect(classifyTaxId(validNieX), TaxIdType.esNie);
      expect(classifyTaxId('A28017895'), TaxIdType.esCif);
      expect(classifyTaxId('DE123456789'), TaxIdType.deUstid);
    });

    test('does not classify a DE_STNR or an unknown shape', () {
      expect(classifyTaxId('W1234567L'), isNull);
      expect(classifyTaxId('123456795'), isNull);
      expect(classifyTaxId('289/65/43'), isNull);
    });
  });

  group('Spanish NIF', () {
    test('accepts the standard valid vector and rejects the others', () {
      expect(isValidEsNif('12345679S'), CheckResult.valid);
      expect(isValidEsNif('12345679T'), CheckResult.invalid);
      expect(isValidEsNif('123456795'), CheckResult.invalid);
      expect(isValidEsNif('1234567S'), CheckResult.invalid);
      expect(isValidEsNif('123456789S'), CheckResult.invalid);
    });
  });

  group('Spanish NIE', () {
    test('accepts the three documentation vectors and rejects the others', () {
      expect(isValidEsNie(validNieX), CheckResult.valid);
      expect(isValidEsNie(validNieY), CheckResult.valid);
      expect(isValidEsNie(validNieZ), CheckResult.valid);
      expect(isValidEsNie('X1234567T'), CheckResult.invalid);
      expect(isValidEsNie('W1234567L'), CheckResult.invalid);
    });
  });

  group('Spanish CIF', () {
    test('accepts the standard valid vectors and rejects the others', () {
      expect(isValidEsCif('A28017895'), CheckResult.valid);
      expect(isValidEsCif('B12345674'), CheckResult.valid);
      expect(isValidEsCif('Q2826000H'), CheckResult.valid);
      expect(isValidEsCif('A28017894'), CheckResult.invalid);
      expect(isValidEsCif('A2801789J'), CheckResult.invalid);
      expect(isValidEsCif('Q28260005'), CheckResult.invalid);
    });
  });

  group('three Spanish algorithms are three algorithms', () {
    test('[countries-languages/three-spanish-formats-are-three-algorithms] '
        'a valid CIF is not judged by the NIF algorithm', () {
      expect(classifyTaxId('A28017895'), TaxIdType.esCif);
      expect(isValidEsCif('A28017895'), CheckResult.valid);
      expect(isValidEsNif('A28017895'), CheckResult.invalid);
    });

    test('[countries-languages/three-spanish-formats-are-three-algorithms] '
        'a foreign natural person\'s identifier is its own type', () {
      expect(classifyTaxId(validNieX), TaxIdType.esNie);
      expect(isValidEsNie(validNieX), CheckResult.valid);
      expect(isValidEsNif(validNieX), CheckResult.invalid);
    });
  });

  group('German identifiers', () {
    test('[countries-languages/country-identifier-check-digits] '
        'the German Steuernummer is deliberately left unchecked', () {
      expect(isValidDeStnr('289/65/43'), CheckResult.notChecked);
      expect(isValidDeStnr('anything'), CheckResult.notChecked);
    });

    test('DE_USTID validation is not checked while GAP-030 is open', () {
      expect(isValidDeUstid('DE123456789'), CheckResult.notChecked);
    });
  });
}
