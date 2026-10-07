import 'package:paperdrop_core/paperdrop_core.dart';
import 'package:test/test.dart';

// Regression structure: a foreign-currency document whose currency cannot be
// sustained. The amounts are suppressed rather than written against the
// wrong currency. This file names no document.
void main() {
  final eur = CurrencyCode.parse('EUR')!;

  test('an unsustained currency suppresses every amount', () {
    final amounts = <FieldValue<Money>>[
      Present<Money>(Money(100, eur), Provenance.read, ConfidenceState.green),
      Present<Money>(Money(200, eur), Provenance.read, ConfidenceState.amber),
      Present<Money>(
        Money(300, eur),
        Provenance.derived,
        ConfidenceState.amber,
      ),
    ];

    final suppressed = applyCurrencyGate(const Absent<CurrencyCode>(), amounts);

    expect(suppressed, [
      const Absent<Money>(),
      const Absent<Money>(),
      const Absent<Money>(),
    ]);
  });
}
