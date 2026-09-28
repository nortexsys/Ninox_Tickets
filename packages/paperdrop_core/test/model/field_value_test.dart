import 'package:paperdrop_core/paperdrop_core.dart';
import 'package:test/test.dart';

void main() {
  final eur = CurrencyCode.parse('EUR')!;

  group('FieldValue cases', () {
    test('Present carries provenance, confidence, source and edited', () {
      final value = Present<Money>(
        Money(1999, eur),
        Provenance.fromXml,
        ConfidenceState.green,
        source: ValueSource.memory,
        edited: true,
      );

      expect(value.value, Money(1999, eur));
      expect(value.provenance, Provenance.fromXml);
      expect(value.confidence, ConfidenceState.green);
      expect(value.source, ValueSource.memory);
      expect(value.edited, isTrue);
    });

    test('copyWithEdit keeps provenance and confidence but marks the edit', () {
      final value = Present<Money>(
        Money(1999, eur),
        Provenance.fromXml,
        ConfidenceState.green,
      );

      final edited = value.copyWithEdit(Money(2000, eur));

      expect(edited.value, Money(2000, eur));
      expect(edited.provenance, Provenance.fromXml);
      expect(edited.confidence, ConfidenceState.green);
      expect(edited.source, ValueSource.user);
      expect(edited.edited, isTrue);
    });

    test('Absent, NotInXml and Present(0) are three unequal values', () {
      final absent = Absent<Money>();
      final notInXml = NotInXml<Money>();
      final zero = Present<Money>(
        Money(0, eur),
        Provenance.read,
        ConfidenceState.amber,
      );

      expect(absent, isNot(equals(notInXml)));
      expect(absent, isNot(equals(zero)));
      expect(notInXml, isNot(equals(zero)));

      expect(absent, isA<Absent<Money>>());
      expect(notInXml, isA<NotInXml<Money>>());
      expect(zero, isA<Present<Money>>());
    });
  });

  group('FieldValue JSON', () {
    test('Present round-trips through its codec', () {
      final value = Present<Money>(
        Money(1999, eur),
        Provenance.fromXml,
        ConfidenceState.green,
        source: ValueSource.memory,
        edited: true,
      );

      final decoded = FieldValue.fromJson<Money>(
        value.toJson(moneyCodec),
        moneyCodec,
      );

      expect(decoded, value);
    });

    test('Absent and NotInXml round-trip as their state', () {
      final absent = FieldValue.fromJson<Money>(
        const Absent<Money>().toJson(moneyCodec),
        moneyCodec,
      );
      final notInXml = FieldValue.fromJson<Money>(
        const NotInXml<Money>().toJson(moneyCodec),
        moneyCodec,
      );

      expect(absent, const Absent<Money>());
      expect(notInXml, const NotInXml<Money>());
    });
  });
}
