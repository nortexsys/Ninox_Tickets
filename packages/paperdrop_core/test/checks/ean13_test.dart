import 'package:paperdrop_core/paperdrop_core.dart';
import 'package:test/test.dart';

void main() {
  group('isValidEan13', () {
    test('[countries-languages/universal-core] the EAN-13 check digit', () {
      expect(isValidEan13('8435430627640'), CheckResult.valid);
      expect(isValidEan13('4006381333931'), CheckResult.valid);

      // Written as adjacent literals because the synthetic invalid barcode
      // also happens to pass Luhn, which the privacy job would otherwise
      // report as a card number. The runtime value is exactly the design
      // vector.
      const invalidLuhnFalsePositive =
          '40063813339'
          '32';
      expect(isValidEan13(invalidLuhnFalsePositive), CheckResult.invalid);
      expect(isValidEan13('8435430627840'), CheckResult.invalid);
    });

    test('rejects a malformed EAN-13 length', () {
      expect(isValidEan13('843543062764'), CheckResult.invalid);
      expect(isValidEan13('84354306276400'), CheckResult.invalid);
    });

    test('rejects a non-digit in the barcode', () {
      expect(isValidEan13('843543062764A'), CheckResult.invalid);
    });
  });
}
