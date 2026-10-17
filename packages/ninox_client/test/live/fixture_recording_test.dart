/// The fixture re-recording helper, proved **without a token and without a live body**.
///
/// Change design §3 re-records `create-response` and `error-500` from the real responses,
/// **structure only**: keys and types kept, every value replaced by a synthetic one. That
/// transformation is `structureOnlyFixture` in `fixture_recording.dart`, and this file is what shows
/// it does what it says — in every lane and in every CI run, long before the machine with the token
/// applies it:
///
/// * the keys survive and the types survive;
/// * **no value of the recorded body survives** — that is the whole point, because a recorded body
///   is a real response from a real database and may hold a person's name, an identifier or a
///   document's text;
/// * an array keeps one example of each distinct structure and not its length, so that how many
///   records a listing happened to hold is not read as part of the shape;
/// * the result is valid JSON, and applying the transformation to it changes nothing — a fixture
///   re-recorded from a fixture is the same fixture.
///
/// Every value in this file is invented here. Nothing here reaches the network, reads the
/// environment or writes a file.
library;

import 'dart:convert';

import 'package:test/test.dart';

import 'fixture_recording.dart';

void main() {
  test(
    'the keys and the types of a recorded body survive, and its value does not',
    () {
      const String recorded = '{"id": 1416}';

      final Object? fixture = jsonDecode(structureOnlyFixture(recorded));

      expect(fixture, isA<Map<String, Object?>>());
      final Map<String, Object?> object = fixture! as Map<String, Object?>;
      expect(object.keys, <String>[
        'id',
      ], reason: 'the key set is the structure');
      expect(object['id'], isA<int>(), reason: 'an integer stays an integer');
      expect(object['id'], syntheticInteger);
      expect(structureOnlyFixture(recorded), isNot(contains('1416')));
    },
  );

  test('a string, a decimal, a boolean and a null each keep their type', () {
    const String recorded =
        '{"text": "A Person Name", "rate": 12.5, "flag": false, "absent": null}';

    final Map<String, Object?> object =
        jsonDecode(structureOnlyFixture(recorded))! as Map<String, Object?>;

    expect(object['text'], syntheticText);
    expect(object['text'], isA<String>());
    expect(object['rate'], syntheticDecimal);
    expect(object['rate'], isA<double>());
    expect(object['flag'], syntheticBoolean);
    expect(object['flag'], isA<bool>());
    expect(object.containsKey('absent'), isTrue);
    expect(object['absent'], isNull);
  });

  test(
    'a nested object keeps every key at every level and no value anywhere',
    () {
      // The keys are what a fixture is read for, so they are structure and they are kept — a field
      // name is the destination's schema, not a person. The values are what the run must not carry.
      const String recorded =
          '{"fields": {"Fecha": "2026-10-17", "Importe": 424242}, '
          '"message": "Unknown field: Importe", "createdBy": "A Person Name"}';

      final String fixture = structureOnlyFixture(recorded);
      final Map<String, Object?> object =
          jsonDecode(fixture)! as Map<String, Object?>;

      expect(
        object.keys,
        <String>['fields', 'message', 'createdBy'],
        reason: 'the keys are what a fixture asserts on, so they are kept at every level',
      );
      expect((object['fields']! as Map<String, Object?>).keys, <String>[
        'Fecha',
        'Importe',
      ]);
      // The point of the whole transformation: none of these values reaches the fixture.
      expect(fixture, isNot(contains('A Person Name')));
      expect(fixture, isNot(contains('2026-10-17')));
      expect(fixture, isNot(contains('424242')));
      expect(fixture, isNot(contains('Unknown field')));
    },
  );

  test(
    'an array keeps one example of each distinct structure, not its length',
    () {
      const String recorded =
          '{"records": [{"id": 1, "name": "one"}, {"id": 2, "name": "two"}, '
          '{"id": 3, "other": "three"}]}';

      final Map<String, Object?> object =
          jsonDecode(structureOnlyFixture(recorded))! as Map<String, Object?>;
      final List<Object?> records = object['records']! as List<Object?>;

      expect(
        records,
        hasLength(2),
        reason:
            'the first two elements have the same structure and collapse to one; the third has '
            'another key set and survives. How many rows a listing held is a fact about the live '
            'database, not about its shape',
      );
      expect((records.first! as Map<String, Object?>).keys, <String>[
        'id',
        'name',
      ]);
      expect((records.last! as Map<String, Object?>).keys, <String>[
        'id',
        'other',
      ]);
    },
  );

  test('a body is JSON in and JSON out, indented like every fixture', () {
    final String fixture = structureOnlyFixture('{"id": 1416}');

    expect(
      fixture,
      '{\n  "id": $syntheticInteger\n}',
      reason: 'the fixtures in test/fixtures/classic/ are two-space indented and end at the brace',
    );
    expect(() => jsonDecode(fixture), returnsNormally);
  });

  test('applying it to its own output changes nothing', () {
    const String recorded =
        '{"id": 1416, "fields": {"Fecha": "2026-10-17", "Importe": 1999}, '
        '"files": [{"name": "a.pdf", "size": 1024}]}';

    final String once = structureOnlyFixture(recorded);
    final String twice = structureOnlyFixture(once);

    expect(
      twice,
      once,
      reason: 'the transformation is a projection, not an edit',
    );
  });

  test('an empty object and an empty array survive as what they are', () {
    expect(structureOnlyFixture('{}'), '{}');
    expect(structureOnlyFixture('{"fields": {}}'), '{\n  "fields": {}\n}');
    expect(structureOnlyFixture('[]'), '[]');
  });

  test('a body that is not JSON is refused rather than guessed at', () {
    expect(
      () => structureOnlyFixture('<html>not an API</html>'),
      throwsFormatException,
    );
  });

  test('a body whose top level is not a response is refused', () {
    // A recorded response is an object or a list. A bare number or string would become a fixture
    // nothing can be read from, which is worse than no fixture at all.
    expect(() => structureOnlyFixture('42'), throwsFormatException);
    expect(
      () => structureOnlyFixture('"just a string"'),
      throwsFormatException,
    );
    expect(() => structureOnlyFixture('null'), throwsFormatException);
  });
}
