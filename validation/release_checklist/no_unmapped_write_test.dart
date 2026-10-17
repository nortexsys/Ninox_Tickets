/// Group 4 of the negative release checklist: **no unmapped write** (Funcional §10.6, §1.2).
///
/// The non-goal: no record of the user's database is written in a shape the user did not ask for.
/// The requirement it protects is BR-15 (*never write an unmapped field* — *the app never writes a
/// Ninox field the user has not explicitly mapped; no marker field may be relied on to exist, and
/// duplicate prevention is handled read-side*), with ADR-004's payload shape, ADR-013's read-side
/// reconciliation, and DEC-005 / GAP-022: a formula field is never a mapping candidate because the
/// schema listing omits it and the app adds no second request that would find one.
///
/// **What this file proves.** A destination with no mapping sends `{}` and still creates the
/// record with its document; a destination with two mappings sends those two names and no third
/// key, and no marker; a rejected write — an HTTP 500, which is how Ninox reports a formula or
/// read-only field name — is retried **once with the same payload**, never with a payload edited
/// to fit the schema; and the schema a mapping is built from is one listing, with no second
/// endpoint that could offer a formula field.
///
/// **Where it stops.** The pipeline decides no value and builds no mapping (its own contract), so
/// what is asserted here is that it passes the caller's map through untouched. Whether the
/// *caller* put the right fields in the map is the mapping screen's, and its own tests'
/// (`app/test/features/wizard/mapping/`).
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ninox_client/ninox_client.dart';

import 'checklist_support.dart';

/// A port that forwards every call to [inner] and keeps the payload of each create.
///
/// The pipeline's own fake keeps the *last* payload; a test about a retried create needs both, so
/// that "the payload was not edited to fit the schema" is a comparison and not a memory.
final class _PayloadRecorder implements NinoxPort {
  _PayloadRecorder(this.inner);

  final NinoxPort inner;

  /// Every payload a create was given, in order, copied so a later call cannot rewrite it.
  final List<Map<String, Object?>> creates = <Map<String, Object?>>[];

  @override
  Future<RecordId> createRecord(
    TableRef ref,
    Map<String, Object?> fieldsByName,
  ) {
    creates.add(Map<String, Object?>.of(fieldsByName));
    return inner.createRecord(ref, fieldsByName);
  }

  @override
  Future<List<NinoxTeam>> listTeams() => inner.listTeams();

  @override
  Future<List<NinoxDatabase>> listDatabases(String teamId) =>
      inner.listDatabases(teamId);

  @override
  Future<List<NinoxTable>> listTables(String teamId, String databaseId) =>
      inner.listTables(teamId, databaseId);

  @override
  Future<NinoxRecord> readRecord(TableRef ref, RecordId recordId) =>
      inner.readRecord(ref, recordId);

  @override
  Future<void> updateRecord(
    TableRef ref,
    RecordId recordId,
    Map<String, Object?> fieldsByName,
  ) => inner.updateRecord(ref, recordId, fieldsByName);

  @override
  Future<void> uploadFile(
    TableRef ref,
    RecordId recordId, {
    required String filename,
    required Uint8List bytes,
    required String contentType,
  }) => inner.uploadFile(
    ref,
    recordId,
    filename: filename,
    bytes: bytes,
    contentType: contentType,
  );

  @override
  Future<List<NinoxFile>> listFiles(TableRef ref, RecordId recordId) =>
      inner.listFiles(ref, recordId);

  @override
  Future<List<NinoxRecord>> listRecords(
    TableRef ref, {
    int? page,
    int? perPage,
    String? order,
    bool? desc,
  }) => inner.listRecords(
    ref,
    page: page,
    perPage: perPage,
    order: order,
    desc: desc,
  );
}

/// A name that reads as a marker the app might add to a record to find it again — which BR-15
/// forbids, because it would be a field the user never mapped.
final RegExp _markerName = RegExp(
  'paperdrop|marker|duplicate|docid|doc_id|source|signature|hash',
  caseSensitive: false,
);

/// A write that fails as Ninox reports a formula or read-only field name: HTTP 500.
const ServerError _mappingRefusal = ServerError(500, 'a formula field');

void main() {
  const String nonGoal = 'no unmapped write';
  const String requirements = 'BR-15, ADR-004, ADR-013, DEC-005 / GAP-022';

  test('[$nonGoal] a destination with no mapping sends no field key and still '
      'carries its document (BR-15)', () async {
    final SendHarness harness = SendHarness();
    final SendRequest request = testRequest(
      fieldsByName: const <String, Object?>{},
    );
    harness.port.nextRecord = NinoxRecord(
      id: const RecordId('1416'),
      fields: const <String, Object?>{},
    );
    harness.port.nextFiles = <NinoxFile>[
      storedFile(size: request.bytes.length),
    ];

    final SendOutcome outcome = await harness.pipeline.send(request);

    expect(outcome, isA<Sent>());
    expect(
      harness.port.createdFields,
      isEmpty,
      reason:
          '[$nonGoal] an empty mapping is `{"fields": {}}`: no field key is '
          'invented for a destination that mapped none ($requirements)',
    );
    expect(
      harness.port.calls,
      contains('uploadFile:T1#1416'),
      reason:
          '[$nonGoal] the document attaches to the record itself, so a '
          'destination with nothing mapped is still complete (BR-22)',
    );
    expect(harness.port.uploadedBytes, request.bytes);
  });

  test('[$nonGoal] only the mapped names travel, and no marker field is added '
      '(BR-15, ADR-013)', () async {
    final SendHarness harness = SendHarness();
    final Map<String, Object?> mapped = <String, Object?>{
      'Importe': 1999,
      'Fecha': '2026-10-10',
    };
    final SendRequest request = testRequest(fieldsByName: mapped);
    harness.port.nextFiles = <NinoxFile>[
      storedFile(size: request.bytes.length),
    ];

    await harness.pipeline.send(request);

    expect(
      harness.port.createdFields!.keys.toSet(),
      mapped.keys.toSet(),
      reason:
          '[$nonGoal] the payload is the caller\'s map: the pipeline decides no '
          'value and adds no key ($requirements)',
    );
    for (final String name in harness.port.createdFields!.keys) {
      expect(
        name,
        isNot(matches(_markerName)),
        reason:
            '[$nonGoal] `$name` reads as a marker field: BR-15 forbids relying '
            'on one, and duplicate prevention is read-side (ADR-013)',
      );
    }
    // The attachment is not a mapping target and does not become a field either (BR-22).
    expect(harness.port.createdFields!.containsKey('file'), isFalse);
  });

  test('[$nonGoal] a refused write is retried with the same payload, never '
      'with one edited to fit the schema (BR-15)', () async {
    final FakeNinoxPort fake = FakeNinoxPort()
      // The first create is refused as a formula field is; the second answers the identifier
      // the adapter would have returned (the fake's own default path).
      ..creates = <Object>[_mappingRefusal]
      ..nextId = const RecordId('1416')
      ..nextFiles = <NinoxFile>[storedFile(size: 4)];
    final _PayloadRecorder recorder = _PayloadRecorder(fake);
    int refreshes = 0;
    final SendPipeline pipeline = SendPipeline(
      recorder,
      journal: InMemorySendJournal(),
      sleep: (Duration duration) async {},
      refreshSchema: () async {
        refreshes++;
      },
    );

    final SendRequest request = testRequest();
    final SendOutcome outcome = await pipeline.send(request);

    expect(outcome, isA<Sent>());
    expect(
      refreshes,
      1,
      reason:
          'the 500 row refreshes the schema once and retries once '
          '(FR-SND-004)',
    );
    expect(
      recorder.creates,
      hasLength(2),
      reason:
          '[$nonGoal] the retry is a create with the same fields; the app never '
          'splits, renames or drops a field to get past a schema it does not '
          'own ($requirements)',
    );
    expect(
      recorder.creates.first.keys.toSet(),
      request.fieldsByName.keys.toSet(),
    );
    expect(
      recorder.creates.last.keys.toSet(),
      recorder.creates.first.keys.toSet(),
      reason:
          '[$nonGoal] a mapping error is reported, not worked around: the app '
          'writes what the user mapped or reports the mapping ($requirements)',
    );
    expect(recorder.creates.last.values, recorder.creates.first.values);
  });

  test('[$nonGoal] a formula field is never offered: the schema is one listing '
      'and no second endpoint is asked (DEC-005, GAP-022)', () async {
    const String tableId = 'T1';
    final List<String> requests = <String>[];
    final MockClient client = MockClient((http.Request request) async {
      requests.add('${request.method} ${request.url.path}');
      return http.Response(
        jsonEncode(<Object?>[
          <String, Object?>{
            'id': tableId,
            'name': 'Receipts',
            'fields': <Object?>[
              <String, Object?>{'id': 'A', 'name': 'Issued on', 'type': 'date'},
              <String, Object?>{'id': 'B', 'name': 'Amount', 'type': 'number'},
            ],
          },
        ]),
        200,
      );
    });
    final ClassicNinoxAdapter adapter = ClassicNinoxAdapter(
      endpoint: NinoxEndpoint.parse('ninox.example.de')!,
      credentials: const NinoxCredentials('synthetic-token'),
      client: client,
    );

    final List<NinoxTable> tables = await adapter.listTables('team-1', 'db-1');

    expect(
      requests,
      <String>['GET /v1/teams/team-1/databases/db-1/tables'],
      reason:
          '[$nonGoal] one listing and nothing else: `…/tables/{id}/fields` '
          'does not exist (ADR-004) and a schema endpoint is BR-16\'s to '
          'forbid ($requirements)',
    );
    expect(
      tables.single.fields.map((NinoxField field) => field.name).toList(),
      <String>['Issued on', 'Amount'],
      reason:
          '[$nonGoal] the candidates a mapping may offer are exactly what the '
          'listing returned: a formula field is absent from it, so nothing can '
          'propose or write one ($requirements)',
    );
  });
}
