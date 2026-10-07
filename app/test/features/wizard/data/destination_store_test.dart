import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ninox_client/ninox_client.dart';
import 'package:paperdrop/features/wizard/data/destination_store.dart';
import 'package:paperdrop/features/wizard/destination.dart';
import 'package:path/path.dart' as p;

import '../../../tool/fakes.dart';

/// The destination's stored form (design §6, FR-DST-001, FR-DST-003, FR-CFG-004).
///
/// **A real file in a directory the test owns**, so the round trip is the one the device performs:
/// `path_provider` sits behind `AppStorage`, and the test's storage is a temporary folder. No test
/// here needs a device, a network or a token.
void main() {
  late Directory root;
  late DestinationStore store;
  late File file;

  setUp(() {
    root = Directory.systemTemp.createTempSync('paperdrop-destination-test');
    store = FileDestinationStore(storage: TemporaryStorage(root));
    file = File(p.join(root.path, FileDestinationStore.fileName));
  });

  tearDown(() {
    if (root.existsSync()) {
      root.deleteSync(recursive: true);
    }
  });

  /// A destination with every mappable field mapped, one of them with the other absent setting, on a
  /// private-cloud host.
  Destination destinationOfEverything() => Destination(
    endpoint: NinoxEndpoint.parse('ninox.example.de:8443')!,
    teamId: 'team-1',
    databaseId: 'db-1',
    tableId: 'table-1',
    mappings: <FieldMapping>[
      for (final CoreField coreField in CoreField.values)
        FieldMapping(
          coreField: coreField,
          ninoxFieldId: 'field-${coreField.wireName}',
          ninoxFieldName: 'Column ${coreField.wireName}',
          absent: coreField == CoreField.taxTotal
              ? AbsentSetting.zero
              : AbsentSetting.empty,
        ),
    ],
  );

  test('a destination round-trips with every identifier, the host and every '
      'absent setting', () async {
    final Destination destination = destinationOfEverything();

    await store.save(destination);
    final List<Destination> read = await store.readAll();

    expect(read, hasLength(1));
    expect(read.single, destination);
    // The host is the one that was configured, port and all, and not a default.
    expect(read.single.endpoint, NinoxEndpoint.parse('ninox.example.de:8443'));
    expect(
      read.single.mappings
          .firstWhere(
            (FieldMapping mapping) => mapping.coreField == CoreField.taxTotal,
          )
          .absent,
      AbsentSetting.zero,
    );
  });

  test('the file is a list of one, and it holds identifiers', () async {
    await store.save(destinationOfEverything());

    final Object? decoded = jsonDecode(file.readAsStringSync());
    expect(decoded, isA<List<Object?>>());
    final List<Object?> list = decoded! as List<Object?>;
    expect(list, hasLength(1));

    final Map<String, Object?> entry = list.single! as Map<String, Object?>;
    // The three identifiers, the host, and the mappings — by identifier (FR-DST-003).
    expect(entry['team'], 'team-1');
    expect(entry['database'], 'db-1');
    expect(entry['table'], 'table-1');
    expect(entry['host'], 'ninox.example.de:8443');
    final List<Object?> mappings = entry['mappings']! as List<Object?>;
    expect(mappings, hasLength(CoreField.values.length));
    final Map<String, Object?> first = mappings.first! as Map<String, Object?>;
    expect(first['field_id'], 'field-doc_date');
    expect(first['core_field'], 'doc_date');
    expect(first['absent'], 'empty');
  });

  test('nothing in the file names a credential', () async {
    // The token is not asked for, not held and not written: the store has no parameter for one, the
    // destination has no field for one, and the file shows it.
    await store.save(destinationOfEverything());

    final String text = file.readAsStringSync().toLowerCase();
    expect(text, isNot(contains('token')));
    expect(text, isNot(contains('bearer')));
    expect(text, isNot(contains('credential')));
    expect(text, isNot(contains('api_key')));
  });

  test('saving twice leaves one destination, the last one', () async {
    await store.save(destinationOfEverything());
    await store.save(
      const Destination(
        endpoint: NinoxEndpoint.cloud,
        teamId: 'team-2',
        databaseId: 'db-2',
        tableId: 'table-2',
      ),
    );

    final List<Destination> read = await store.readAll();
    expect(read, hasLength(1));
    expect(read.single.teamId, 'team-2');
    expect(read.single.mappings, isEmpty);
  });

  test(
    'a destination that is not there yet is nothing, not an error',
    () async {
      expect(await store.readAll(), isEmpty);
      expect(file.existsSync(), isFalse);
    },
  );

  test(
    'a destination with nothing mapped round-trips as nothing mapped',
    () async {
      // FR-WIZ-007: no mapping is mandatory, and the empty mapping is a destination like any other.
      const Destination destination = Destination(
        endpoint: NinoxEndpoint.cloud,
        teamId: 'team-1',
        databaseId: 'db-1',
        tableId: 'table-1',
      );

      await store.save(destination);

      expect((await store.readAll()).single, destination);
      expect((await store.readAll()).single.mappings, isEmpty);
    },
  );

  test('a file the app cannot read is reported, not read as nothing', () async {
    // An empty list would look like a user who configured nothing, and the app would offer the
    // wizard as if their destination had never existed.
    file.writeAsStringSync('{"team": "team-1"}');
    expect(store.readAll(), throwsFormatException);

    file.writeAsStringSync('[{"host": "not a host", "team": "t"}]');
    expect(store.readAll(), throwsFormatException);

    file.writeAsStringSync('[{"host": "api.ninox.com"}]');
    expect(store.readAll(), throwsFormatException);

    file.writeAsStringSync(
      '[{"host": "api.ninox.com", "team": "t", '
      '"database": "d", "table": "b", "mappings": [{"core_field": "nope", '
      '"field_id": "1", "field_name": "X", "absent": "empty"}]}]',
    );
    expect(store.readAll(), throwsFormatException);
  });
}
