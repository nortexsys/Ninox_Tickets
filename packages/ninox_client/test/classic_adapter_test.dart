import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ninox_client/ninox_client.dart';
import 'package:test/test.dart';

import 'fixture_files.dart';

/// A synthetic token, short on purpose: it never looks like a credential that could leak.
const String _token = 'synthetic-token';

final NinoxEndpoint _cloud = NinoxEndpoint.parse('api.ninox.com')!;
final NinoxEndpoint _privateCloud = NinoxEndpoint.parse(
  'ninox.example.de:8443',
)!;

const TableRef _ref = TableRef(
  teamId: 't1a2b3c4d5e6f7g8h',
  databaseId: 'db1a2b3c4d',
  tableId: 'T1',
);

/// A client that answers every request with [body] and records what it was asked.
///
/// No test of this package may reach the network: the adapter's `http.Client` is a required
/// constructor argument, so every test here passes one of these (design §1, §5).
MockClient _answering(
  String body, {
  int status = 200,
  List<http.Request>? seen,
}) => MockClient((request) async {
  seen?.add(request);
  return http.Response(body, status);
});

ClassicNinoxAdapter _adapter(
  http.Client client, {
  NinoxEndpoint? endpoint,
  Duration timeout = const Duration(seconds: 30),
}) => ClassicNinoxAdapter(
  endpoint: endpoint ?? _cloud,
  credentials: const NinoxCredentials(_token),
  client: client,
  timeout: timeout,
);

/// A client that answers each endpoint of the classic API with its own recorded body, and records
/// what it was asked. The path, not the body, decides: a test that asserts a path while the client
/// answers everything with one fixture would prove nothing about the path.
MockClient _routing(List<http.Request> seen) => MockClient((request) async {
  seen.add(request);
  final path = request.url.path;
  if (path.endsWith('/teams')) {
    return http.Response(classicFixture('teams.json'), 200);
  }
  if (path.endsWith('/databases')) {
    return http.Response(classicFixture('databases.json'), 200);
  }
  if (path.endsWith('/tables')) {
    return http.Response(classicFixture('tables.json'), 200);
  }
  if (path.endsWith('/files')) {
    return http.Response(classicFixture('files.json'), 200);
  }
  if (path.endsWith('/records')) {
    return http.Response(classicFixture('records.json'), 200);
  }
  return http.Response(classicFixture('record.json'), 200);
});

void main() {
  group(
    'every read is built on the configured endpoint, with one credential',
    () {
      test('the adapter implements the port', () {
        expect(
          _adapter(_answering(classicFixture('teams.json'))),
          isA<NinoxPort>(),
        );
      });

      test(
        'the Authorization header is the only header, and it is Bearer',
        () async {
          final seen = <http.Request>[];

          // BR-19, `product-invariants/token-is-the-only-credential`: the client asks for one bearer
          // token and nothing else and transmits no second credential. Partial proof, untagged
          // (design §1): the user-facing half — no surface where a password could be entered — is the
          // app's, not this package's.
          await _adapter(_answering(classicFixture('teams.json'), seen: seen))
              .listTeams();

          expect(seen, hasLength(1));
          expect(seen.single.headers.keys.map((key) => key.toLowerCase()), [
            'authorization',
          ]);
          expect(seen.single.headers['Authorization'], 'Bearer $_token');
        },
      );
    },
  );

  group('listTeams', () {
    test('GET /v1/teams, and the teams are read from the body', () async {
      final seen = <http.Request>[];
      final adapter = _adapter(
        _answering(classicFixture('teams.json'), seen: seen),
      );

      final teams = await adapter.listTeams();

      expect(seen.single.method, 'GET');
      expect(seen.single.url, Uri.parse('https://api.ninox.com/v1/teams'));
      expect(teams, [
        const NinoxTeam(id: 't1a2b3c4d5e6f7g8h', name: 'Synthetic Workspace'),
        const NinoxTeam(
          id: 'z9y8x7w6v5u4t3s2r',
          name: 'Second Synthetic Workspace',
        ),
      ]);
    });

    test('never asks a second question', () async {
      final seen = <http.Request>[];

      await _adapter(_answering(classicFixture('teams.json'), seen: seen))
          .listTeams();

      expect(seen, hasLength(1));
    });
  });

  group('listDatabases', () {
    test('GET /v1/teams/{team}/databases', () async {
      final seen = <http.Request>[];
      final adapter = _adapter(
        _answering(classicFixture('databases.json'), seen: seen),
      );

      final databases = await adapter.listDatabases('t1a2b3c4d5e6f7g8h');

      expect(seen.single.method, 'GET');
      expect(
        seen.single.url,
        Uri.parse('https://api.ninox.com/v1/teams/t1a2b3c4d5e6f7g8h/databases'),
      );
      expect(databases, [
        const NinoxDatabase(id: 'db1a2b3c4d', name: 'Receipts (synthetic)'),
        const NinoxDatabase(
          id: 'db9z8y7x6w',
          name: 'Second database (synthetic)',
        ),
      ]);
    });

    test('the team is an argument, never a default', () async {
      final seen = <http.Request>[];

      await _adapter(_answering(classicFixture('databases.json'), seen: seen))
          .listDatabases('another-team');

      expect(seen.single.url.path, '/v1/teams/another-team/databases');
    });
  });

  group('listTables', () {
    test(
      'GET .../tables, and the fields come back with the tables in one call',
      () async {
        final seen = <http.Request>[];
        final adapter = _adapter(
          _answering(classicFixture('tables.json'), seen: seen),
        );

        final tables = await adapter.listTables(
          't1a2b3c4d5e6f7g8h',
          'db1a2b3c4d',
        );

        expect(seen.single.method, 'GET');
        expect(
          seen.single.url,
          Uri.parse(
            'https://api.ninox.com/v1/teams/t1a2b3c4d5e6f7g8h/databases/db1a2b3c4d/tables',
          ),
        );
        expect(
          seen,
          hasLength(1),
          reason:
              'no second call: the fields come with the tables, and '
              '.../tables/{table}/fields does not exist (ADR-004)',
        );
        expect(tables, hasLength(2));
        expect(tables.first.id, 'T1');
        expect(tables.first.fields.map((field) => field.name), [
          'Issued on',
          'Amount',
          'VAT amount',
          'Category',
          'Linked card',
          'Currency code',
        ]);
        expect(tables.first.fields[1].type, 'number');
      },
    );
  });

  group('readRecord', () {
    test('GET .../records/{id}, and the record is parsed', () async {
      final seen = <http.Request>[];
      final adapter = _adapter(
        _answering(classicFixture('record.json'), seen: seen),
      );

      final record = await adapter.readRecord(_ref, const RecordId('1413'));

      expect(seen.single.method, 'GET');
      expect(
        seen.single.url,
        Uri.parse(
          'https://api.ninox.com/v1/teams/t1a2b3c4d5e6f7g8h'
          '/databases/db1a2b3c4d/tables/T1/records/1413',
        ),
      );
      expect(record.id, const RecordId('1413'));
      expect(record.fields['Amount'], 1651);
    });

    test('the audit keys are read when the endpoint returns them', () async {
      final records =
          jsonDecode(classicFixture('records.json')) as List<Object?>;
      final one = jsonEncode(records.first);
      final adapter = _adapter(_answering(one));

      final record = await adapter.readRecord(_ref, const RecordId('1414'));

      expect(record.createdAt, '2026-08-19T09:41:02Z');
      expect(record.createdBy, 'synthetic-user');
      expect(record.sequence, 90001);
    });
  });

  group('listFiles', () {
    test(
      'GET .../records/{id}/files, with name, size and content type',
      () async {
        final seen = <http.Request>[];
        final adapter = _adapter(
          _answering(classicFixture('files.json'), seen: seen),
        );

        final files = await adapter.listFiles(_ref, const RecordId('1416'));

        expect(seen.single.method, 'GET');
        expect(
          seen.single.url,
          Uri.parse(
            'https://api.ninox.com/v1/teams/t1a2b3c4d5e6f7g8h'
            '/databases/db1a2b3c4d/tables/T1/records/1416/files',
          ),
        );
        expect(files, [
          const NinoxFile(
            name: 'receipt.pdf',
            size: 1024,
            contentType: 'application/pdf',
          ),
        ]);
      },
    );
  });

  group('listRecords', () {
    test(
      'GET .../records with no query at all when the caller asks for nothing',
      () async {
        final seen = <http.Request>[];
        final adapter = _adapter(
          _answering(classicFixture('records.json'), seen: seen),
        );

        final records = await adapter.listRecords(_ref);

        expect(seen.single.method, 'GET');
        expect(
          seen.single.url,
          Uri.parse(
            'https://api.ninox.com/v1/teams/t1a2b3c4d5e6f7g8h'
            '/databases/db1a2b3c4d/tables/T1/records',
          ),
        );
        expect(
          seen.single.url.hasQuery,
          isFalse,
          reason:
              'no parameter is invented: limit and pageSize are accepted and ignored '
              '(plan §6.2), so they are never sent',
        );
        expect(records, hasLength(2));
        expect(records.first.id, const RecordId('1414'));
        expect(records.first.createdAt, '2026-08-19T09:41:02Z');
      },
    );

    test('page, perPage, order and desc are the only query parameters, spelled as measured', () async {
      final seen = <http.Request>[];
      final adapter = _adapter(
        _answering(classicFixture('records.json'), seen: seen),
      );

      await adapter.listRecords(
        _ref,
        page: 2,
        perPage: 50,
        order: 'sequence',
        desc: true,
      );

      expect(
        seen.single.url.path,
        '/v1/teams/t1a2b3c4d5e6f7g8h/databases/db1a2b3c4d/tables/T1/records',
      );
      expect(seen.single.url.queryParameters, {
        'page': '2',
        'perPage': '50',
        'order': 'sequence',
        'desc': 'true',
      });
    });

    test('desc false is sent as false, and a partial set of parameters is sent as given', () async {
      final seen = <http.Request>[];
      final adapter = _adapter(
        _answering(classicFixture('records.json'), seen: seen),
      );

      await adapter.listRecords(_ref, perPage: 2, desc: false);

      expect(seen.single.url.queryParameters, {
        'perPage': '2',
        'desc': 'false',
      });
      expect(seen.single.url.queryParameters.containsKey('order'), isFalse);
      expect(seen.single.url.queryParameters.containsKey('page'), isFalse);
    });
  });

  group('the host is configuration', () {
    test('a private host is where every request goes, and nothing is sent anywhere else', () async {
      final seen = <http.Request>[];
      final adapter = _adapter(_routing(seen), endpoint: _privateCloud);

      await adapter.listTeams();
      await adapter.listDatabases('t1a2b3c4d5e6f7g8h');
      await adapter.listTables('t1a2b3c4d5e6f7g8h', 'db1a2b3c4d');
      await adapter.readRecord(_ref, const RecordId('1413'));
      await adapter.listFiles(_ref, const RecordId('1416'));
      await adapter.listRecords(_ref);

      // FR-DST-008, `destinations-mapping/configurable-ninox-host`, scenario "a private-cloud
      // customer needs no fork": partial proof, untagged (design §1) — this layer proves every
      // call is built on the configured host and that no request goes to the vendor's host; that
      // the user can enter the host is the wizard's (T1.10).
      expect(seen, hasLength(6));
      for (final request in seen) {
        expect(request.url.host, 'ninox.example.de');
        expect(request.url.port, 8443);
        expect(request.url.scheme, 'https');
        expect(request.url.host, isNot('api.ninox.com'));
      }
    });
  });
}
