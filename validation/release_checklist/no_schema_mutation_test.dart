/// Group 2 of the negative release checklist: **no schema mutation** (Funcional §10.6, §1.2).
///
/// The non-goal: *the app never creates, renames or deletes fields or tables in the user's Ninox
/// database*, and *never deletes or modifies a record it did not create*. The requirement it
/// protects is BR-16 (*never touch schema or records the app did not create*), whose own
/// acceptance sentence is *no API call from the app targets a schema endpoint; a correction
/// updates a record whose identifier the app itself received from a create* — and with it the
/// §2.4 contract line 6, ADR-003's port, and DEC-005 / GAP-022 in the formula-field direction
/// (a formula field is not offered because the schema listing omits it, not because a filter
/// guesses).
///
/// **What this file proves.** The port's surface is exactly the nine calls the application is
/// allowed to make; driving all nine through the real adapter produces exactly those nine
/// requests and no other; no verb outside `GET`/`POST`/`PUT` is ever used; no request addresses a
/// schema or table-definition path (`…/schema`, `…/tables/{id}/fields`); and no shipped source
/// names a schema-mutating call or verb.
///
/// **Where it stops.** The request list is the one the nine methods make against a mocked
/// transport: a second implementation of `NinoxPort` would have to be added to the surface test
/// deliberately, which is the point — the surface is the contract. The lexical half reads names
/// and literals only.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ninox_client/ninox_client.dart';

import 'checklist_support.dart';

/// The nine calls of the port, named here so that a tenth one has to be argued for in review.
const Set<String> portMethods = <String>{
  'listTeams',
  'listDatabases',
  'listTables',
  'createRecord',
  'readRecord',
  'updateRecord',
  'uploadFile',
  'listFiles',
  'listRecords',
};

/// The names a schema-mutating call would answer to, as a lexical scan sees them.
const List<String> schemaMutationTokens = <String>[
  'DELETE',
  'PATCH',
  '/schema',
  'createField',
  'renameField',
  'deleteField',
  'createTable',
  'renameTable',
  'deleteTable',
  'dropTable',
  'addField',
  'deleteRecord',
];

/// The destination every case sends to: three invented identifiers.
const TableRef ref = TableRef(
  teamId: 'team-1',
  databaseId: 'db-1',
  tableId: 'T1',
);

/// The nine requests the nine methods make, in order — the whole of what this app does to Ninox.
const List<String> expectedRequests = <String>[
  'GET /v1/teams',
  'GET /v1/teams/team-1/databases',
  'GET /v1/teams/team-1/databases/db-1/tables',
  'POST /v1/teams/team-1/databases/db-1/tables/T1/records',
  'GET /v1/teams/team-1/databases/db-1/tables/T1/records/1416',
  'PUT /v1/teams/team-1/databases/db-1/tables/T1/records/1416',
  'POST /v1/teams/team-1/databases/db-1/tables/T1/records/1416/files',
  'GET /v1/teams/team-1/databases/db-1/tables/T1/records/1416/files',
  'GET /v1/teams/team-1/databases/db-1/tables/T1/records?page=1&perPage=100',
];

/// A transport that answers each endpoint of the classic API and records what it was asked.
///
/// The answers are invented and minimal: this test is about the verb and the path, and about a
/// request that does not exist — not about a body the model would parse.
MockClient _recording(List<String> seen) => MockClient((
  http.Request request,
) async {
  final String query = request.url.query.isEmpty ? '' : '?${request.url.query}';
  seen.add('${request.method} ${request.url.path}$query');
  final String path = request.url.path;
  if (request.method == 'POST' && path.endsWith('/files')) {
    return http.Response('File Uploaded Successfully', 200);
  }
  if (request.method == 'POST' && path.endsWith('/records')) {
    return http.Response(jsonEncode(<String, Object?>{'id': '1416'}), 200);
  }
  if (path.endsWith('/teams')) {
    return http.Response(
      jsonEncode(<Object?>[
        <String, Object?>{'id': 'team-1', 'name': 'Team One'},
      ]),
      200,
    );
  }
  if (path.endsWith('/databases')) {
    return http.Response(
      jsonEncode(<Object?>[
        <String, Object?>{'id': 'db-1', 'name': 'Database One'},
      ]),
      200,
    );
  }
  if (path.endsWith('/tables')) {
    return http.Response(
      jsonEncode(<Object?>[
        <String, Object?>{
          'id': 'T1',
          'name': 'Receipts',
          'fields': <Object?>[
            <String, Object?>{'id': 'A', 'name': 'Issued on', 'type': 'date'},
            <String, Object?>{'id': 'B', 'name': 'Amount', 'type': 'number'},
          ],
        },
      ]),
      200,
    );
  }
  if (path.endsWith('/files')) {
    return http.Response(
      jsonEncode(<Object?>[
        <String, Object?>{
          'name': 'receipt.pdf',
          'size': 4,
          'contentType': 'application/pdf',
        },
      ]),
      200,
    );
  }
  if (path.endsWith('/records')) {
    return http.Response(
      jsonEncode(<Object?>[
        <String, Object?>{
          'id': '1416',
          'fields': <String, Object?>{'Amount': 1999},
        },
      ]),
      200,
    );
  }
  return http.Response(
    jsonEncode(<String, Object?>{
      'id': '1416',
      'fields': <String, Object?>{'Amount': 1999},
      'createdBy': 'user-1',
    }),
    200,
  );
});

/// The adapter over [client] on an invented private-cloud host.
ClassicNinoxAdapter _adapter(http.Client client) => ClassicNinoxAdapter(
  endpoint: NinoxEndpoint.parse('ninox.example.de')!,
  credentials: const NinoxCredentials('synthetic-token'),
  client: client,
);

/// The method names the `NinoxPort` interface declares, read off its own source.
///
/// Read lexically from the interface body: the abstract class is the contract, and a method
/// added to it is a call the application may make. Comments are masked, so a method named in
/// prose is not a declaration.
Set<String> _declaredPortMethods() {
  final String source = maskComments(
    fileAt('packages/ninox_client/lib/src/port.dart').readAsStringSync(),
  );
  final int start = source.indexOf('abstract interface class NinoxPort {');
  expect(
    start,
    isNonNegative,
    reason: 'the port interface was not found, so this test proves nothing',
  );
  final int end = source.indexOf('\n}', start);
  final String body = source.substring(start, end);
  return <String>{
    for (final RegExpMatch match in RegExp(
      r'Future<[^(]*>\s+(\w+)\(',
    ).allMatches(body))
      match.group(1)!,
  };
}

void main() {
  const String nonGoal = 'no schema mutation';
  const String requirements = 'BR-16, §2.4 contract 6, DEC-005 / GAP-022';

  test('[$nonGoal] the port declares the nine record-and-read calls and '
      'nothing else ($requirements)', () {
    final Set<String> declared = _declaredPortMethods();

    expect(
      declared,
      isNotEmpty,
      reason: 'the interface body was not read, so this test proves nothing',
    );
    expect(
      declared,
      portMethods,
      reason:
          '[$nonGoal] a method added to NinoxPort is a call this application '
          'may make: the port is the whole surface, and none of these nine can '
          'create, rename or delete a field, a table or a record it did not '
          'create ($requirements)',
    );
    for (final String method in declared) {
      expect(
        method.toLowerCase(),
        isNot(matches(RegExp('delete|rename|drop|alter|schema|field'))),
        reason:
            '[$nonGoal] `$method` reads as a schema mutation ($requirements)',
      );
    }
  });

  test('[$nonGoal] driving every call produces exactly nine requests, none of '
      'them to a schema path ($requirements)', () async {
    final List<String> seen = <String>[];
    final ClassicNinoxAdapter adapter = _adapter(_recording(seen));

    await adapter.listTeams();
    await adapter.listDatabases(ref.teamId);
    await adapter.listTables(ref.teamId, ref.databaseId);
    await adapter.createRecord(ref, <String, Object?>{'Amount': 1999});
    await adapter.readRecord(ref, const RecordId('1416'));
    await adapter.updateRecord(ref, const RecordId('1416'), <String, Object?>{
      'Amount': 1999,
    });
    await adapter.uploadFile(
      ref,
      const RecordId('1416'),
      filename: 'receipt.pdf',
      bytes: Uint8List.fromList(<int>[37, 80, 68, 70]),
      contentType: 'application/pdf',
    );
    await adapter.listFiles(ref, const RecordId('1416'));
    await adapter.listRecords(ref, page: 1, perPage: 100);

    expect(
      seen,
      expectedRequests,
      reason:
          '[$nonGoal] the requests of this app are the nine of the port, and '
          'each one is a read or a record-level write ($requirements)',
    );

    // The rules below are the reason the list above is the right one, written out so that a
    // failure says which rule broke rather than only that a string differs.
    for (final String request in seen) {
      final String verb = request.split(' ').first;
      expect(
        <String>['GET', 'POST', 'PUT'],
        contains(verb),
        reason:
            '[$nonGoal] `$verb` is not a verb this app uses ($requirements)',
      );
      expect(
        request,
        isNot(contains('schema')),
        reason:
            '[$nonGoal] no call of this app addresses a schema endpoint '
            '($requirements)',
      );
      expect(
        request,
        isNot(matches(RegExp(r'/tables/[^/]+/fields'))),
        reason:
            '[$nonGoal] `…/tables/{id}/fields` is the table-definition '
            'endpoint that does not exist and must not be called ($requirements)',
      );
    }
    for (final String request in seen.where(
      (String request) => request.startsWith('POST'),
    )) {
      expect(
        request,
        anyOf(endsWith('/records'), endsWith('/records/1416/files')),
        reason:
            '[$nonGoal] a create and a file upload are the only POSTs of this '
            'app ($requirements)',
      );
    }
    for (final String request in seen.where(
      (String request) => request.startsWith('PUT'),
    )) {
      expect(
        request,
        matches(RegExp(r'/records/\d+$')),
        reason:
            '[$nonGoal] the only update is on a record identifier the create '
            'returned ($requirements)',
      );
    }
  });

  test('[$nonGoal] no shipped source names a schema-mutating call or verb '
      '($requirements)', () {
    final List<TokenOccurrence> found = occurrencesIn(
      shippedSources(),
      schemaMutationTokens,
    );
    expect(
      unauthorised(found, const <String, String>{}),
      isEmpty,
      reason:
          '[$nonGoal] the occurrences above are a call this app is forbidden '
          'to make ($requirements)',
    );
  });

  test('[$nonGoal] the scan catches a planted mutating verb, and not the one '
      'in a comment', () {
    // A guard is only worth having if it would catch the thing it is written for. `maskComments`
    // is what makes this more than a grep: the rule may be *stated* in prose.
    const String planted = '''
// The app never sends DELETE to a table.
const String verb = 'DELETE';
''';
    final List<TokenOccurrence> found = findOccurrences(
      planted,
      schemaMutationTokens,
      path: 'planted.dart',
    );
    expect(found, hasLength(1));
    expect(found.single.token, 'DELETE');
    expect(found.single.line, 2);
  });
}
