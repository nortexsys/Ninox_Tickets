import 'package:paperdrop_core/paperdrop_core.dart';
import 'package:test/test.dart';

// Annex D.2 — a tax identifier read as `123456795` whose issuer value is
// `12345679S`. The check-digit algorithm admits exactly one replacement for
// the final character: `5` to `S`. The value is repaired and tagged
// `repaired`; two admissible repairs means no repair.
void main() {
  group('Annex D.2', () {
    test('the unique repair is applied', () {
      final outcome = repairIdentifier('123456795', isValidEsNif);

      expect(outcome.value, '12345679S');
      expect(outcome.provenance, Provenance.repaired);
    });

    test('negative variant: two admissible repairs means no repair', () {
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
  });
}
