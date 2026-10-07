import 'package:paperdrop_core/paperdrop_core.dart';
import 'package:test/test.dart';

void main() {
  group('repairIdentifier', () {
    test('[validation-confidence/repair-to-the-only-consistent-value] '
        'the unique repair is applied and shown', () {
      final outcome = repairIdentifier('123456795', isValidEsNif);

      expect(outcome.value, '12345679S');
      expect(outcome.provenance, Provenance.repaired);
    });

    test('[validation-confidence/repair-to-the-only-consistent-value] '
        'two admissible repairs means no repair', () {
      CheckResult syntheticValidator(String value) {
        if (value == 'AS5' || value == 'A5S') {
          return CheckResult.valid;
        }
        return CheckResult.invalid;
      }

      final outcome = repairIdentifier('A55', syntheticValidator);

      expect(outcome.value, 'A55');
      expect(outcome.provenance, Provenance.read);
    });

    test('an already valid reading is not repaired', () {
      final outcome = repairIdentifier('12345679S', isValidEsNif);

      expect(outcome.value, '12345679S');
      expect(outcome.provenance, Provenance.read);
    });
  });
}
