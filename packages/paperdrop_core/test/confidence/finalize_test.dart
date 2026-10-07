import 'package:paperdrop_core/paperdrop_core.dart';
import 'package:test/test.dart';

void main() {
  final eur = CurrencyCode.parse('EUR')!;
  final zero = Money(0, eur);

  group('finalize', () {
    test('[validation-confidence/absent-is-not-zero] '
        'the default is empty, not zero', () {
      expect(
        finalize<Money>(const Absent<Money>(), zero: zero),
        const Absent<Money>(),
      );
    });

    test('[validation-confidence/absent-is-not-zero] '
        'the destination setting decides and nothing else changes', () {
      final present = Present<Money>(
        Money(100, eur),
        Provenance.read,
        ConfidenceState.green,
      );
      final edited = Edited<Money>(Money(200, eur));
      const notInXml = NotInXml<Money>();

      expect(
        finalize<Money>(
          const Absent<Money>(),
          zero: zero,
          policy: AbsentPolicy.zero,
        ),
        Present<Money>(zero, Provenance.read, ConfidenceState.amber),
      );
      expect(
        finalize<Money>(present, zero: zero, policy: AbsentPolicy.zero),
        present,
      );
      expect(
        finalize<Money>(edited, zero: zero, policy: AbsentPolicy.zero),
        edited,
      );
      expect(
        finalize<Money>(notInXml, zero: zero, policy: AbsentPolicy.zero),
        notInXml,
      );
    });

    test('Absent, NotInXml and Present(0) stay unequal', () {
      final presentZero = Present<Money>(
        zero,
        Provenance.read,
        ConfidenceState.amber,
      );

      expect(const Absent<Money>(), isNot(equals(const NotInXml<Money>())));
      expect(const Absent<Money>(), isNot(equals(presentZero)));
      expect(const NotInXml<Money>(), isNot(equals(presentZero)));
    });
  });
}
