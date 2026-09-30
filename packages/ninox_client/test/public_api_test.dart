import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ninox_client/ninox_client.dart';
import 'package:test/test.dart';

/// The package exports one library, and this file is the list of what that library offers: every
/// name below is reachable from `package:ninox_client/ninox_client.dart` alone. It is written for
/// the orchestrator's review of the public API (change task 1.7) as much as for the compiler.
void main() {
  test('the library resolves and still carries the workspace name', () {
    expect(packageName, 'ninox_client');
  });

  test('the host is configuration, with a default', () {
    const NinoxEndpoint defaultHost = NinoxEndpoint.cloud;
    final NinoxEndpoint configured = NinoxEndpoint.parse(
      'ninox.example.de:8443',
    )!;

    expect(defaultHost.baseUri.toString(), endsWith('/v1'));
    expect(defaultHost.host, isNotEmpty);
    expect(configured.host, 'ninox.example.de');
    expect(configured.port, 8443);
    expect(NinoxEndpoint.parse('http://ninox.example.de'), isNull);
    expect(configured, isNot(defaultHost));
  });

  test('the credential is the token alone, and it prints as stars', () {
    const NinoxCredentials credentials = NinoxCredentials('synthetic-token');

    expect(credentials.token, 'synthetic-token');
    expect(credentials.authorizationHeader, startsWith('Bearer '));
    expect(credentials.toString(), isNot(contains('synthetic-token')));
  });

  test('a call states its team, database and table, and its record', () {
    const TableRef ref = TableRef(
      teamId: 't1a2b3c4d5e6f7g8h',
      databaseId: 'db1a2b3c4d',
      tableId: 'T1',
    );
    const RecordId recordId = RecordId('1413');

    expect(ref.teamId, 't1a2b3c4d5e6f7g8h');
    expect(ref.databaseId, 'db1a2b3c4d');
    expect(ref.tableId, 'T1');
    expect(recordId.value, '1413');
  });

  test('the value types the endpoints return are all reachable', () {
    const NinoxTeam team = NinoxTeam(id: 't1', name: 'Synthetic Workspace');
    const NinoxDatabase database = NinoxDatabase(id: 'db1', name: 'Receipts');
    const NinoxField field = NinoxField(
      id: 'A',
      name: 'Issued on',
      type: 'date',
    );
    const NinoxTable table = NinoxTable(
      id: 'T1',
      name: 'Receipts',
      fields: [field],
    );
    const NinoxRecord record = NinoxRecord(
      id: RecordId('1413'),
      fields: {'Amount': 1999},
    );
    const NinoxFile file = NinoxFile(
      name: 'receipt.pdf',
      size: 1024,
      contentType: 'application/pdf',
    );

    expect(team.id, 't1');
    expect(database.name, 'Receipts');
    expect(table.fields.single.type, 'date');
    expect(record.id.value, '1413');
    expect(file.contentType, 'application/pdf');
  });

  test('every failure of the matrix is here, and a lost create is an uncertain transport one', () {
    const List<NinoxFailure> failures = [
      Unauthorized(),
      NotFound(),
      RateLimited(),
      ServerError(500, 'Unknown field'),
      UnexpectedResponse('HTTP 400'),
      TransportFailure('connection refused'),
      CreateOutcomeUncertain('the response was lost'),
    ];

    expect(failures, everyElement(isA<Exception>()));
    expect(const CreateOutcomeUncertain(), isA<TransportFailure>());
    expect(const ServerError(500).status, 500);
  });

  test('the adapter is the classic implementation of the port', () async {
    final ClassicNinoxAdapter adapter = ClassicNinoxAdapter(
      endpoint: NinoxEndpoint.cloud,
      credentials: const NinoxCredentials('synthetic-token'),
      client: MockClient((request) async => http.Response('[]', 200)),
    );

    expect(adapter, isA<NinoxPort>());
    expect(adapter.timeout, const Duration(seconds: 30));

    // The merge update of `ninox-send/updates-are-merges` (FR-SND-008) is part of the port: it is
    // reached here through the interface, so a second implementation has to provide it too.
    final NinoxPort port = adapter;
    await port.updateRecord(
      const TableRef(teamId: 't1', databaseId: 'db1', tableId: 'T1'),
      const RecordId('1416'),
      const {'Amount': 2049},
    );
  });
}
