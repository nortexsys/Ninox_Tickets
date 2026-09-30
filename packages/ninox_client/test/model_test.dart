import 'dart:convert';

import 'package:ninox_client/ninox_client.dart';
import 'package:test/test.dart';

import 'fixture_files.dart';

Map<String, Object?> _object(String name) =>
    (jsonDecode(classicFixture(name)) as Map).cast<String, Object?>();

List<Object?> _list(String name) => jsonDecode(classicFixture(name)) as List;

Map<String, Object?> _element(String name, int index) =>
    (_list(name)[index] as Map).cast<String, Object?>();

void main() {
  group('the value types parse their fixture', () {
    test('NinoxTeam', () {
      final teams = _list('teams.json')
          .map(
            (json) => NinoxTeam.fromJson((json as Map).cast<String, Object?>()),
          )
          .toList();

      expect(teams, hasLength(2));
      expect(
        teams.first,
        const NinoxTeam(id: 't1a2b3c4d5e6f7g8h', name: 'Synthetic Workspace'),
      );
      expect(teams.first.id, 't1a2b3c4d5e6f7g8h');
      expect(teams.first.name, 'Synthetic Workspace');
    });

    test('NinoxDatabase', () {
      final databases = _list('databases.json')
          .map(
            (json) =>
                NinoxDatabase.fromJson((json as Map).cast<String, Object?>()),
          )
          .toList();

      expect(databases, hasLength(2));
      expect(
        databases.first,
        const NinoxDatabase(id: 'db1a2b3c4d', name: 'Receipts (synthetic)'),
      );
    });

    test('NinoxTable, with every field of the one tables call', () {
      final table = NinoxTable.fromJson(_element('tables.json', 0));

      expect(table.id, 'T1');
      expect(table.name, 'Receipts (synthetic)');
      expect(table.fields.map((field) => field.name), [
        'Issued on',
        'Amount',
        'VAT amount',
        'Category',
        'Linked card',
        'Currency code',
      ]);
      expect(
        table.fields.first,
        const NinoxField(id: 'A', name: 'Issued on', type: 'date'),
      );
      expect(
        table.fields[3],
        const NinoxField(id: 'D', name: 'Category', type: 'choice'),
        reason:
            'the keys a choice field adds (choices) are not modelled yet and must not '
            'break reading the field the port does expose',
      );
      expect(table.fields[4].type, 'ref');
      expect(table.fields[5].type, 'string');
    });

    test('NinoxTable reads the second table, with a rev field', () {
      final table = NinoxTable.fromJson(_element('tables.json', 1));

      expect(table.id, 'T2');
      expect(table.fields, hasLength(2));
      expect(table.fields.last.type, 'rev');
    });

    test(
      'NinoxRecord reads the single-record shape, which carries no audit keys',
      () {
        final record = NinoxRecord.fromJson(_object('record.json'));

        expect(record.id, const RecordId('1413'));
        expect(record.id.value, '1413');
        expect(record.fields['Issued on'], '2026-08-08');
        expect(record.fields['Amount'], 1651);
        expect(record.fields['VAT amount'], 347);
        expect(record.createdAt, isNull);
        expect(record.createdBy, isNull);
        expect(record.sequence, isNull);
      },
    );

    test('NinoxRecord reads the listing shape, with createdAt, createdBy and sequence', () {
      final record = NinoxRecord.fromJson(_element('records.json', 0));

      expect(record.id, const RecordId('1414'));
      expect(record.createdAt, '2026-08-19T09:41:02Z');
      expect(record.createdBy, 'synthetic-user');
      expect(record.modifiedAt, '2026-08-19T09:41:02Z');
      expect(record.modifiedBy, 'synthetic-user');
      expect(record.sequence, 90001);
      expect(record.fields, hasLength(4));
    });

    test('a record read twice is equal and hashes alike', () {
      final one = NinoxRecord.fromJson(_element('records.json', 0));
      final other = NinoxRecord.fromJson(_element('records.json', 0));
      final different = NinoxRecord.fromJson(_element('records.json', 1));

      expect(one, other);
      expect(one.hashCode, other.hashCode);
      expect(one, isNot(different));
      expect(one, isNot(NinoxRecord(id: one.id, fields: const {'Amount': 1})));
    });

    test('NinoxFile reads name, size and content type', () {
      final file = NinoxFile.fromJson(_element('files.json', 0));

      expect(
        file,
        const NinoxFile(
          name: 'receipt.pdf',
          size: 1024,
          contentType: 'application/pdf',
        ),
      );
      expect(file.size, 1024);
    });

    test('the create response gives the new record identifier', () {
      expect(
        recordIdFromJson(
          _object('create-response.json'),
          what: 'the create response',
        ),
        const RecordId('1416'),
      );
    });

    test(
      'an identifier returned as a string is read as the same identifier',
      () {
        expect(
          recordIdFromJson(const {'id': '1416'}, what: 'the create response'),
          recordIdFromJson(const {'id': 1416}, what: 'the create response'),
        );
      },
    );
  });

  group('TableRef', () {
    test('carries the three identifiers and compares by value', () {
      const ref = TableRef(teamId: 't1', databaseId: 'db1', tableId: 'T1');

      expect(ref.teamId, 't1');
      expect(ref.databaseId, 'db1');
      expect(ref.tableId, 'T1');
      expect(
        ref,
        const TableRef(teamId: 't1', databaseId: 'db1', tableId: 'T1'),
      );
      expect(
        ref.hashCode,
        const TableRef(teamId: 't1', databaseId: 'db1', tableId: 'T1').hashCode,
      );
      expect(
        ref,
        isNot(const TableRef(teamId: 't1', databaseId: 'db1', tableId: 'T2')),
      );
      expect(ref.toString(), 'TableRef(t1, db1, T1)');
    });
  });

  group('a malformed body is rejected, never guessed at', () {
    final rejected = <String, Object? Function()>{
      'not JSON at all': () => jsonObject('{"id": ', what: 'the teams list'),
      'a JSON object where a list was expected': () =>
          jsonObjectList('{"id":"t1"}', what: 'the teams list'),
      'a JSON array where an object was expected': () =>
          jsonObject('[]', what: 'a record'),
      'an array element that is not an object': () =>
          jsonObjectList('[1]', what: 'the teams list'),
      'a team without a name': () => NinoxTeam.fromJson(const {'id': 't1'}),
      'a team whose name is not a string': () =>
          NinoxTeam.fromJson(const {'id': 't1', 'name': 4}),
      'a team whose identifier is neither a string nor a whole number': () =>
          NinoxTeam.fromJson(const {'id': true, 'name': 'x'}),
      'a table whose fields are not an array': () => NinoxTable.fromJson(const {
        'id': 'T1',
        'name': 'x',
        'fields': <String, Object?>{},
      }),
      'a table with a field that is not an object': () =>
          NinoxTable.fromJson(const {
            'id': 'T1',
            'name': 'x',
            'fields': <Object?>['A'],
          }),
      'a record whose fields are not an object': () =>
          NinoxRecord.fromJson(const {'id': 1413, 'fields': <Object?>[]}),
      'a record without an identifier': () =>
          NinoxRecord.fromJson(const {'fields': <String, Object?>{}}),
      'a record whose sequence is not a whole number': () =>
          NinoxRecord.fromJson(const {'id': 1413, 'sequence': '90001'}),
      'a file whose size is not a whole number': () =>
          NinoxFile.fromJson(const {
            'name': 'receipt.pdf',
            'size': '1024',
            'contentType': 'application/pdf',
          }),
      'a create response with an empty identifier': () =>
          recordIdFromJson(const {'id': ''}, what: 'the create response'),
      'a create response with no identifier': () => recordIdFromJson(const {
        'fields': <String, Object?>{},
      }, what: 'the create response'),
    };

    rejected.forEach((reason, read) {
      test(reason, () {
        expect(read, throwsA(isA<UnexpectedResponse>()));
      });
    });
  });
}
