import 'package:paperdrop_core/paperdrop_core.dart';
import 'package:test/test.dart';

void main() {
  final eur = CurrencyCode.parse('EUR')!;

  group('FieldValue cases', () {
    test('Present carries provenance, confidence and source', () {
      final value = Present<Money>(
        Money(1999, eur),
        Provenance.fromXml,
        ConfidenceState.green,
        source: ValueSource.memory,
      );

      expect(value.value, Money(1999, eur));
      expect(value.provenance, Provenance.fromXml);
      expect(value.confidence, ConfidenceState.green);
      expect(value.source, ValueSource.memory);
    });

    test('Present only accepts document or memory as its source', () {
      expect(ValueSource.values, <ValueSource>[
        ValueSource.document,
        ValueSource.memory,
      ]);

      expect(
        Present<Money>(
          Money(1, eur),
          Provenance.read,
          ConfidenceState.amber,
          source: ValueSource.document,
        ).source,
        ValueSource.document,
      );
      expect(
        Present<Money>(
          Money(1, eur),
          Provenance.read,
          ConfidenceState.amber,
          source: ValueSource.memory,
        ).source,
        ValueSource.memory,
      );
    });

    test(
      'FieldValue.edit turns every case into an Edited holding only value',
      () {
        final fromPresent = Present<Money>(
          Money(1, eur),
          Provenance.read,
          ConfidenceState.green,
        ).edit(Money(2, eur));
        final fromAbsent = Absent<Money>().edit(Money(2, eur));
        final fromNotInXml = NotInXml<Money>().edit(Money(2, eur));

        expect(fromPresent, isA<Edited<Money>>());
        expect(fromAbsent, isA<Edited<Money>>());
        expect(fromNotInXml, isA<Edited<Money>>());

        expect(fromPresent.value, Money(2, eur));
        expect(fromAbsent.value, Money(2, eur));
        expect(fromNotInXml.value, Money(2, eur));
      },
    );

    test('Edited has no provenance and no confidence', () {
      final edited = Edited<Money>(Money(1, eur));

      expect(edited, isA<Edited<Money>>());
      expect(edited.value, Money(1, eur));
      expect(edited, isNot(isA<Present<Money>>()));
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
      );

      final decoded = FieldValue.fromJson<Money>(
        value.toJson(moneyCodec),
        moneyCodec,
      );

      expect(decoded, value);
    });

    test('Edited round-trips with no provenance or confidence key', () {
      final value = Edited<Money>(Money(1999, eur));
      final json = value.toJson(moneyCodec) as Map<String, Object?>;

      expect(json['state'], 'edited');
      expect(json['value'], Money(1999, eur).toJson());
      expect(json.containsKey('provenance'), isFalse);
      expect(json.containsKey('confidence'), isFalse);

      final decoded = FieldValue.fromJson<Money>(json, moneyCodec);

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
