import 'package:paperdrop_core/paperdrop_core.dart';
import 'package:test/test.dart';

// Annex D.5 — a document prints a total of `19.98` and no rate. A pipeline
// derives `base = 16.51` and `tax = 3.47`, then evaluates
// `16.51 + 3.47 = 19.98`. The arithmetic agrees with itself on a wrong
// premise and confirms nothing; the same numbers all read do confirm.
void main() {
  final eur = CurrencyCode.parse('EUR')!;

  group('Annex D.5', () {
    test('a derived breakdown leaves the total amber', () {
      final arithmeticPassed = sumMatchesTotal(
        Money(1651, eur),
        Money(347, eur),
        Money(1998, eur),
      );

      final outcome = checkOutcome(
        arithmeticPassed: arithmeticPassed,
        operands: [Provenance.derived, Provenance.derived],
      );

      expect(outcome, CheckOutcome.nonConfirmatory);
      expect(
        assignConfidence(kind: FieldKind.amount, check: outcome),
        ConfidenceState.amber,
      );
    });

    test('negative variant: the all-read figures confirm', () {
      final arithmeticPassed = sumMatchesTotal(
        Money(1651, eur),
        Money(347, eur),
        Money(1998, eur),
      );

      final outcome = checkOutcome(
        arithmeticPassed: arithmeticPassed,
        operands: [Provenance.read, Provenance.read],
      );

      expect(outcome, CheckOutcome.passed);
      expect(
        assignConfidence(kind: FieldKind.amount, check: outcome),
        ConfidenceState.green,
      );
    });
  });
}
