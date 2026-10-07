import 'package:paperdrop_core/paperdrop_core.dart';
import 'package:test/test.dart';

void main() {
  final eur = CurrencyCode.parse('EUR')!;

  group('checkOutcome', () {
    test(
      '[validation-confidence/a-check-confirms-only-if-every-operand-was-read] '
      'a derived value raises nothing',
      () {
        final outcome = checkOutcome(
          arithmeticPassed: true,
          operands: [Provenance.derived, Provenance.read],
        );

        expect(outcome, CheckOutcome.nonConfirmatory);
        expect(
          assignConfidence(kind: FieldKind.amount, check: outcome),
          ConfidenceState.amber,
        );
      },
    );

    test('the same numbers all read go green', () {
      final outcome = checkOutcome(
        arithmeticPassed: true,
        operands: [Provenance.read, Provenance.read],
      );

      expect(outcome, CheckOutcome.passed);
      expect(
        assignConfidence(kind: FieldKind.amount, check: outcome),
        ConfidenceState.green,
      );
    });

    test('a failed check is red', () {
      final outcome = checkOutcome(
        arithmeticPassed: false,
        operands: [Provenance.read, Provenance.read],
      );

      expect(outcome, CheckOutcome.failed);
      expect(
        assignConfidence(kind: FieldKind.amount, check: outcome),
        ConfidenceState.red,
      );
    });
  });

  group('assignConfidence', () {
    test('[validation-confidence/three-confidence-strengths] '
        'a clean reading with nothing to cross against is amber', () {
      expect(assignConfidence(kind: FieldKind.amount), ConfidenceState.amber);
    });

    test('[validation-confidence/what-never-reaches-green] '
        'no document number is ever green', () {
      expect(
        assignConfidence(kind: FieldKind.docNumber, check: CheckOutcome.passed),
        ConfidenceState.amber,
      );
    });

    test('supplier name is never green in the MVP', () {
      expect(
        assignConfidence(
          kind: FieldKind.supplierName,
          check: CheckOutcome.passed,
        ),
        ConfidenceState.amber,
      );
    });

    test('repaired and check-digit-consistent values are amber', () {
      expect(
        assignConfidence(kind: FieldKind.taxId, repaired: true),
        ConfidenceState.amber,
      );
      expect(
        assignConfidence(kind: FieldKind.taxId, checkDigitConsistent: true),
        ConfidenceState.amber,
      );
    });

    test('the numeric score influences no state', () {
      final cases =
          <
            ({
              FieldKind kind,
              CheckOutcome check,
              bool repaired,
              bool checkDigit,
            })
          >[
            (
              kind: FieldKind.amount,
              check: CheckOutcome.none,
              repaired: false,
              checkDigit: false,
            ),
            (
              kind: FieldKind.amount,
              check: CheckOutcome.passed,
              repaired: false,
              checkDigit: false,
            ),
            (
              kind: FieldKind.amount,
              check: CheckOutcome.nonConfirmatory,
              repaired: false,
              checkDigit: false,
            ),
            (
              kind: FieldKind.taxId,
              check: CheckOutcome.none,
              repaired: true,
              checkDigit: false,
            ),
            (
              kind: FieldKind.taxId,
              check: CheckOutcome.none,
              repaired: false,
              checkDigit: true,
            ),
            (
              kind: FieldKind.docNumber,
              check: CheckOutcome.passed,
              repaired: false,
              checkDigit: false,
            ),
          ];

      for (final c in cases) {
        expect(
          assignConfidence(
            kind: c.kind,
            check: c.check,
            repaired: c.repaired,
            checkDigitConsistent: c.checkDigit,
            score: 0,
          ),
          assignConfidence(
            kind: c.kind,
            check: c.check,
            repaired: c.repaired,
            checkDigitConsistent: c.checkDigit,
            score: 99,
          ),
        );
      }
    });
  });

  group('applyCurrencyGate', () {
    test('[validation-confidence/currency-carries-its-own-confidence-state] '
        'an unsustained currency suppresses the amounts', () {
      final amounts = <FieldValue<Money>>[
        Present<Money>(Money(100, eur), Provenance.read, ConfidenceState.green),
        Present<Money>(Money(200, eur), Provenance.read, ConfidenceState.amber),
      ];

      final suppressed = applyCurrencyGate(
        const Absent<CurrencyCode>(),
        amounts,
      );

      expect(suppressed, [const Absent<Money>(), const Absent<Money>()]);
    });

    test('a sustained currency leaves every amount unchanged', () {
      final amounts = <FieldValue<Money>>[
        Present<Money>(Money(100, eur), Provenance.read, ConfidenceState.green),
      ];

      final kept = applyCurrencyGate(
        Present<CurrencyCode>(eur, Provenance.read, ConfidenceState.amber),
        amounts,
      );

      expect(kept, amounts);
    });
  });
}
