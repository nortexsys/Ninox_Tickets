import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ninox_client/ninox_client.dart';
import 'package:test/test.dart';

import 'fixture_files.dart';

const String _token = 'synthetic-token';

final NinoxEndpoint _cloud = NinoxEndpoint.parse('api.ninox.com')!;

const TableRef _ref = TableRef(
  teamId: 't1a2b3c4d5e6f7g8h',
  databaseId: 'db1a2b3c4d',
  tableId: 'T1',
);

ClassicNinoxAdapter _adapter(
  http.Client client, {
  Duration timeout = const Duration(seconds: 30),
}) => ClassicNinoxAdapter(
  endpoint: _cloud,
  credentials: const NinoxCredentials(_token),
  client: client,
  timeout: timeout,
);

/// A client that answers every request with one status and body, and records the requests.
MockClient _answering(String body, int status, {List<http.Request>? seen}) =>
    MockClient((request) async {
      seen?.add(request);
      return http.Response(body, status);
    });

/// Every call of the port, so that a property can be asserted over all of them.
Map<String, Future<void> Function(ClassicNinoxAdapter)> _calls() => {
  'listTeams': (adapter) => adapter.listTeams(),
  'listDatabases': (adapter) => adapter.listDatabases('t1a2b3c4d5e6f7g8h'),
  'listTables': (adapter) =>
      adapter.listTables('t1a2b3c4d5e6f7g8h', 'db1a2b3c4d'),
  'createRecord': (adapter) =>
      adapter.createRecord(_ref, const {'Amount': 1999}),
  'updateRecord': (adapter) => adapter.updateRecord(
    _ref,
    const RecordId('1416'),
    const {'Amount': 2049},
  ),
  'readRecord': (adapter) => adapter.readRecord(_ref, const RecordId('1413')),
  'listFiles': (adapter) => adapter.listFiles(_ref, const RecordId('1416')),
  'listRecords': (adapter) => adapter.listRecords(_ref),
  'uploadFile': (adapter) => adapter.uploadFile(
    _ref,
    const RecordId('1416'),
    filename: 'receipt.pdf',
    bytes: Uint8List.fromList(const [1, 2, 3]),
    contentType: 'application/pdf',
  ),
};

void main() {
  group(
    'every status of the matrix that this layer can see maps to its condition',
    () {
      final conditions = <int, Matcher>{
        401: isA<Unauthorized>(),
        403: isA<Unauthorized>(),
        404: isA<NotFound>(),
        429: isA<RateLimited>(),
        500: isA<ServerError>(),
        502: isA<ServerError>(),
        503: isA<ServerError>(),
        400: isA<UnexpectedResponse>(),
        405: isA<UnexpectedResponse>(),
        418: isA<UnexpectedResponse>(),
      };

      conditions.forEach((status, matcher) {
        test('HTTP $status', () async {
          final adapter = _adapter(
            _answering('{"message":"Synthetic failure"}', status),
          );

          await expectLater(adapter.listTeams(), throwsA(matcher));
        });
      });

      test(
        'a 401 or a 403 is authentication, and the matrix says no retry',
        () async {
          final seen = <http.Request>[];
          final adapter = _adapter(
            _answering('{"message":"Unauthorized"}', 401, seen: seen),
          );

          // `ninox-send/the-retry-matrix`, scenario "an authentication failure asks for the token":
          // partial proof, untagged (design §1) — this layer proves the condition is classified as
          // authentication and that nothing is retried; asking the user is the pipeline's (T1.11).
          await expectLater(adapter.listTeams(), throwsA(isA<Unauthorized>()));
          expect(seen, hasLength(1), reason: 'the adapter never retries');
        },
      );

      test(
        'a 404 is a vanished destination, and the matrix says no retry',
        () async {
          final seen = <http.Request>[];
          final adapter = _adapter(
            _answering(classicFixture('error-404.json'), 404, seen: seen),
          );

          // `ninox-send/the-retry-matrix`, scenario "a vanished destination is not retried": partial
          // proof, untagged (design §1) — the classification is proved here, sending the user to the
          // destination is the pipeline's.
          final failure = await _failureOf(
            adapter.listTables('t1a2b3c4d5e6f7g8h', 'db1a2b3c4d'),
          );

          expect(failure, isA<NotFound>());
          expect(
            failure.message,
            'Team Not Found',
            reason: 'the body carries the useful part; report it rather than the status alone',
          );
          expect(seen, hasLength(1));
        },
      );

      test('a 500 is a server error and is not retried, refreshed or reinterpreted here', () async {
        final seen = <http.Request>[];
        final adapter = _adapter(
          _answering(classicFixture('error-500.json'), 500, seen: seen),
        );

        // `ninox-send/the-retry-matrix`, scenario "a 500 is reported as a mapping error": partial
        // proof, untagged (design §1). This layer proves the 500 arrives as a ServerError with its
        // status — it does NOT refresh a schema, retry or call it a mapping error, because that is
        // the pipeline's rule and Ninox answers an invalid, formula or read-only field name this way
        // (ADR-004).
        final failure = await _failureOf(
          adapter.createRecord(_ref, const {'Amount': 1999}),
        );

        expect(failure, isA<ServerError>());
        expect((failure as ServerError).status, 500);
        expect(failure.message, 'Unknown field: Amount paid');
        expect(
          seen,
          hasLength(1),
          reason: 'the client never retries; the pipeline retries once',
        );
      });

      test(
        'a 500 on an update is a ServerError as well, and is not retried here',
        () async {
          final seen = <http.Request>[];
          final adapter = _adapter(
            _answering(classicFixture('error-500.json'), 500, seen: seen),
          );

          final failure = await _failureOf(
            adapter.updateRecord(_ref, const RecordId('1416'), const {
              'Amount': 2049,
            }),
          );

          expect(failure, isA<ServerError>());
          expect((failure as ServerError).status, 500);
          expect(seen, hasLength(1));
        },
      );
    },
  );

  group('a success whose body is not the documented shape', () {
    test('is an UnexpectedResponse, not a crash', () async {
      final adapter = _adapter(_answering('not json at all', 200));

      await expectLater(
        adapter.listTeams(),
        throwsA(isA<UnexpectedResponse>()),
      );
    });

    test('a create that answers 200 without an identifier is an UnexpectedResponse', () async {
      final adapter = _adapter(_answering('{"fields":{}}', 200));

      await expectLater(
        adapter.createRecord(_ref, const {'Amount': 1999}),
        throwsA(isA<UnexpectedResponse>()),
      );
    });
  });

  group('a lost create is uncertain, and a lost read is retryable', () {
    test(
      'a timeout on create is CreateOutcomeUncertain, and nothing is retried',
      () async {
        final seen = <http.Request>[];
        final adapter = _adapter(
          MockClient((request) async {
            seen.add(request);
            await Future<void>.delayed(const Duration(milliseconds: 200));
            return http.Response(classicFixture('create-response.json'), 200);
          }),
          timeout: const Duration(milliseconds: 20),
        );

        // `ninox-send/the-retry-matrix`, scenario "a timed-out create is not retried": partial proof,
        // untagged (design §1) — the classification and the absence of a retry are proved here; that
        // it "enters reconciliation instead" is the pipeline's (T1.11).
        final failure = await _failureOf(
          adapter.createRecord(_ref, const {'Amount': 1999}),
        );

        expect(failure, isA<CreateOutcomeUncertain>());
        expect(
          failure,
          isA<TransportFailure>(),
          reason: 'it is a transport failure that a caller may recognise as unsafe to retry',
        );
        expect(
          seen,
          hasLength(1),
          reason: 'a lost create is NEVER blind-retried (ADR-013)',
        );
      },
    );

    test('a timeout on the attachment is a plain TransportFailure', () async {
      final adapter = _adapter(
        MockClient((request) async {
          await Future<void>.delayed(const Duration(milliseconds: 200));
          return http.Response('File Uploaded Successfully', 200);
        }),
        timeout: const Duration(milliseconds: 20),
      );

      // `ninox-send/the-retry-matrix`, scenario "an attachment timeout is safe to retry": partial
      // proof, untagged (design §1) — this layer proves the condition is a plain transport failure
      // rather than an uncertain create, so the pipeline may back off and retry it; the backoff is
      // the pipeline's.
      final failure = await _failureOf(
        adapter.uploadFile(
          _ref,
          const RecordId('1416'),
          filename: 'receipt.pdf',
          bytes: Uint8List.fromList(const [1, 2, 3]),
          contentType: 'application/pdf',
        ),
      );

      expect(failure, isA<TransportFailure>());
      expect(failure, isNot(isA<CreateOutcomeUncertain>()));
    });

    test('a timeout on an update is a plain TransportFailure, because an update is idempotent', () async {
      final seen = <http.Request>[];
      final adapter = _adapter(
        MockClient((request) async {
          seen.add(request);
          await Future<void>.delayed(const Duration(milliseconds: 200));
          return http.Response('', 200);
        }),
        timeout: const Duration(milliseconds: 20),
      );

      // An update cannot create a record and cannot duplicate one: sending the same fields twice
      // leaves the record as one update would, so a lost response is retryable and is never
      // `uncertain` (ADR-013 is about creates).
      final failure = await _failureOf(
        adapter.updateRecord(_ref, const RecordId('1416'), const {
          'Amount': 2049,
        }),
      );

      expect(failure, isA<TransportFailure>());
      expect(failure, isNot(isA<CreateOutcomeUncertain>()));
      expect(seen, hasLength(1));
    });

    test('a connection that fails is a TransportFailure on a read', () async {
      final adapter = _adapter(
        MockClient(
          (request) => throw http.ClientException('connection refused'),
        ),
      );

      final failure = await _failureOf(adapter.listRecords(_ref));

      expect(failure, isA<TransportFailure>());
      expect(failure, isNot(isA<CreateOutcomeUncertain>()));
    });

    test('the failure hierarchy is what a caller switches on', () {
      expect(const CreateOutcomeUncertain(), isA<TransportFailure>());
      expect(const TransportFailure(), isA<NinoxFailure>());
      expect(const Unauthorized(), isA<NinoxFailure>());
      expect(const NotFound(), isA<NinoxFailure>());
      expect(const RateLimited(), isA<NinoxFailure>());
      expect(const ServerError(500), isA<NinoxFailure>());
      expect(const UnexpectedResponse(), isA<NinoxFailure>());
    });
  });

  group('no non-NinoxFailure escapes a port method', () {
    final broken = <String, http.Client>{
      'a connection that fails': MockClient(
        (request) => throw http.ClientException('connection refused'),
      ),
      'a socket that refuses': MockClient(
        (request) => throw const SocketException('connection refused'),
      ),
      'a request that never answers': MockClient((request) async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        return http.Response('{}', 200);
      }),
    };

    _calls().forEach((name, call) {
      broken.forEach((what, client) {
        test('$name with $what', () async {
          final adapter = _adapter(
            client,
            timeout: const Duration(milliseconds: 20),
          );

          await expectLater(call(adapter), throwsA(isA<NinoxFailure>()));
        });
      });
    });

    test('a programming error is not disguised as a NinoxFailure', () async {
      // An `Error` is a bug in the caller or the transport, not a condition of the retry matrix,
      // and the port's promise covers exceptions. Swallowing it would hide the bug behind a
      // transport failure that the pipeline would then retry.
      final adapter = _adapter(
        MockClient((request) => throw StateError('a bug')),
      );

      await expectLater(adapter.listTeams(), throwsA(isA<StateError>()));
    });
  });

  group('the token never leaves the Authorization header', () {
    /// Every failure this package can raise, with a token put where a leak would come from.
    Map<String, List<NinoxFailure>> failures() => {
      'a 401': [const Unauthorized('Unauthorized')],
      'a 404': [const NotFound('Team Not Found')],
      'a 429': [const RateLimited()],
      'a 500': [const ServerError(500, 'Unknown field')],
      'an unexpected status': [const UnexpectedResponse('HTTP 400')],
      'an unparsable body': [const UnexpectedResponse('the body is not JSON')],
      'a transport failure': [const TransportFailure('connection refused')],
      'a lost create': [
        const CreateOutcomeUncertain(
          'the request was sent and no response arrived',
        ),
      ],
    };

    failures().forEach((what, list) {
      test('$what, stringified, contains no token', () {
        for (final failure in list) {
          expect(failure.toString(), isNot(contains(_token)));
          expect(failure.message ?? '', isNot(contains(_token)));
        }
      });
    });

    test('the credentials, stringified, contain no token', () {
      const credentials = NinoxCredentials(_token);

      expect(credentials.toString(), isNot(contains(_token)));
      expect('$credentials', 'NinoxCredentials(***)');
    });

    test('a transport error that quotes the token is redacted before it is surfaced', () async {
      final adapter = _adapter(
        MockClient(
          (request) => throw http.ClientException(
            'rejected Authorization: Bearer '
            '$_token for ${request.url}',
          ),
        ),
      );

      final failure = await _failureOf(adapter.listTeams());

      expect(failure.message, isNot(contains(_token)));
      expect(failure.message, contains('***'));
    });

    test(
      'an error body that echoes the token is redacted before it is surfaced',
      () async {
        final adapter = _adapter(
          _answering('{"message":"Bad token $_token"}', 401),
        );

        final failure = await _failureOf(adapter.listTeams());

        expect(failure, isA<Unauthorized>());
        expect(failure.message, isNot(contains(_token)));
        expect(failure.message, contains('***'));
      },
    );

    test(
      'the failure message is bounded, so a huge body cannot flood a log',
      () async {
        final adapter = _adapter(
          _answering('{"message":"${'x' * 5000}"}', 500),
        );

        final failure = await _failureOf(adapter.listTeams());

        expect(failure.message!.length, lessThanOrEqualTo(301));
      },
    );
  });
}

/// Runs [call] and returns the failure it threw, failing the test when it does not throw one.
Future<NinoxFailure> _failureOf(Future<Object?> call) async {
  try {
    await call;
  } on NinoxFailure catch (failure) {
    return failure;
  }
  fail('the call was expected to fail');
}
