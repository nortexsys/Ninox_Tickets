import 'package:paperdrop_core/paperdrop_core.dart';
import 'package:test/test.dart';

// Annex D.3 — a retail total read ambiguously as `19.98` or `19.99` with a
// base of `16.52` and tax of `3.47`. In integer minor units,
// `1652 + 347 = 1999` holds exactly and `1652 + 347 = 1998` does not.
void main() {
  final eur = CurrencyCode.parse('EUR')!;

  group('Annex D.3', () {
    test('the exact sum confirms the total', () {
      expect(
        sumMatchesTotal(Money(1652, eur), Money(347, eur), Money(1999, eur)),
        isTrue,
      );
    });

    test('negative variant: the one-unit misread is not absorbed', () {
      expect(
        sumMatchesTotal(Money(1652, eur), Money(347, eur), Money(1998, eur)),
        isFalse,
      );
    });
  });
}
