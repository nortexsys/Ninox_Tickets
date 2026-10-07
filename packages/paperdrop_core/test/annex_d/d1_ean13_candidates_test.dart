import 'package:paperdrop_core/paperdrop_core.dart';
import 'package:test/test.dart';

// Annex D.1 — two EAN-13 candidates. The check digit decides: only
// `8435430627640` satisfies the weighted sum, and `8435430627840` is ruled
// out. Neither candidate is chosen without its check digit.
void main() {
  group('Annex D.1', () {
    test('the check digit admits the first candidate', () {
      expect(isValidEan13('8435430627640'), CheckResult.valid);
    });

    test('negative variant: the competing candidate is rejected', () {
      expect(isValidEan13('8435430627840'), CheckResult.invalid);
    });
  });
}
