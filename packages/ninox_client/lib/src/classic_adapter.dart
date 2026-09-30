import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'credentials.dart';
import 'endpoint.dart';
import 'errors.dart';
import 'model.dart';
import 'port.dart';

/// The classic REST implementation of [NinoxPort] (ADR-003, ADR-004).
///
/// **It reaches the network through one injected `http.Client` and nothing else.** No test of this
/// package can therefore reach Ninox by accident: the client is a required constructor argument,
/// and every test passes `package:http/testing.dart`'s `MockClient` (design §1, §5).
///
/// **It never retries.** A 500, a timeout and a lost create response are classified and thrown;
/// the matrix's *retry once*, *reconcile* and *ask the human* answers belong to the send pipeline's
/// state machine (T1.11). The one classification this class owes the matrix is that a **create
/// whose response was lost is uncertain, not safely retryable** — see [createRecord].
///
/// The team and the database are arguments of every call. Nothing here reads an environment
/// variable, and the production-database variable of `AGENTS.md` §1.4 is never named in this
/// package.
final class ClassicNinoxAdapter implements NinoxPort {
  /// Builds an adapter for one host and one token.
  ///
  /// [client] is required on purpose: it is the only way out to the network, so a caller — or a
  /// test — states which one it is. [timeout] applies to each request and defaults to 30 seconds;
  /// a caller that knows its network may choose another.
  factory ClassicNinoxAdapter({
    required NinoxEndpoint endpoint,
    required NinoxCredentials credentials,
    required http.Client client,
    Duration timeout = const Duration(seconds: 30),
  }) => ClassicNinoxAdapter._(endpoint, credentials, client, timeout);

  ClassicNinoxAdapter._(
    this._endpoint,
    this._credentials,
    this._client,
    this.timeout,
  );

  final NinoxEndpoint _endpoint;
  final NinoxCredentials _credentials;
  final http.Client _client;

  /// The per-request timeout.
  final Duration timeout;

  @override
  Future<List<NinoxTeam>> listTeams() async {
    final body = await _getBody(_uri(const ['teams']));
    return jsonObjectList(
      body,
      what: 'the teams list',
    ).map((json) => NinoxTeam.fromJson(json)).toList();
  }

  @override
  Future<List<NinoxDatabase>> listDatabases(String teamId) async {
    final body = await _getBody(_uri(['teams', teamId, 'databases']));
    return jsonObjectList(
      body,
      what: 'the databases list',
    ).map((json) => NinoxDatabase.fromJson(json)).toList();
  }

  @override
  Future<List<NinoxTable>> listTables(String teamId, String databaseId) async {
    // One call. The fields come back with the tables, and `.../tables/{table}/fields` does not
    // exist (it answers 404), so there is nothing else to ask for (ADR-004, verified).
    final body = await _getBody(
      _uri(['teams', teamId, 'databases', databaseId, 'tables']),
    );
    return jsonObjectList(
      body,
      what: 'the tables list',
    ).map((json) => NinoxTable.fromJson(json)).toList();
  }

  @override
  Future<RecordId> createRecord(
    TableRef ref,
    Map<String, Object?> fieldsByName,
  ) async {
    // ADR-004 payload shape: the values nest under a `fields` key, keyed by the fields' current
    // names. An empty mapping is sent as `{"fields": {}}` — no field key is ever invented, because
    // a destination may have mapped none (`never-write-an-unmapped-field`).
    //
    // The values are re-encoded, never re-interpreted: a `YYYY-MM-DD` string and the integers of
    // `paperdrop_core`'s `Money` and `RateBp` leave here exactly as the caller built them, because
    // an amount that round-trips through a binary float is an amount that comes back a cent wrong.
    final request = http.Request('POST', _uri([..._tablePath(ref), 'records']))
      ..bodyBytes = utf8.encode(jsonEncode({'fields': fieldsByName}));
    request.headers['Content-Type'] = 'application/json';

    // A create whose response is lost may have created the record (ADR-013): it is uncertain, not
    // retryable, and this adapter never retries it.
    final answer = await _send(request, uncertainWhenLost: true);
    _throwUnlessSuccess(answer);
    final json = jsonObject(answer.body, what: 'the create response');
    return recordIdFromJson(json, what: 'the create response');
  }

  @override
  Future<NinoxRecord> readRecord(TableRef ref, RecordId recordId) async {
    final body = await _getBody(
      _uri([..._tablePath(ref), 'records', recordId.value]),
    );
    return NinoxRecord.fromJson(jsonObject(body, what: 'the record'));
  }

  @override
  Future<void> uploadFile(
    TableRef ref,
    RecordId recordId, {
    required String filename,
    required Uint8List bytes,
    required String contentType,
  }) async {
    // The part is named `file`, which is what the verified trace used (`corpus_test/REPORT.md`
    // §3: "campo `file`"). The document belongs to the **record**, so it is not a field of the
    // payload and no field name appears here.
    final http.MediaType mediaType;
    try {
      mediaType = http.MediaType.parse(contentType);
    } on FormatException {
      // A programming error, not a failure of the destination: it is refused before anything is
      // sent, so no port failure type is the right answer.
      throw ArgumentError.value(
        contentType,
        'contentType',
        'is not a media type',
      );
    }
    final request =
        http.MultipartRequest(
            'POST',
            _uri([..._tablePath(ref), 'records', recordId.value, 'files']),
          )
          ..files.add(
            http.MultipartFile.fromBytes(
              'file',
              bytes,
              filename: filename,
              contentType: mediaType,
            ),
          );

    // A timeout here cannot create a second record, so it is a plain transport failure and the
    // matrix's bounded backoff may retry it (the retrying itself is the pipeline's).
    final answer = await _send(request, uncertainWhenLost: false);
    _throwUnlessSuccess(answer);
  }

  @override
  Future<List<NinoxFile>> listFiles(TableRef ref, RecordId recordId) async {
    final body = await _getBody(
      _uri([..._tablePath(ref), 'records', recordId.value, 'files']),
    );
    return jsonObjectList(
      body,
      what: 'the files list',
    ).map((json) => NinoxFile.fromJson(json)).toList();
  }

  @override
  Future<List<NinoxRecord>> listRecords(
    TableRef ref, {
    int? page,
    int? perPage,
    String? order,
    bool? desc,
  }) async {
    // Only the parameters the caller supplies are sent. `limit` and `pageSize` are accepted by the
    // API and ignored, so they are not offered at all (plan §6.2); `order` and `desc` are passed
    // through and are not trusted until GAP-023's read-only check has been recorded.
    final query = <String, String>{};
    if (page != null) {
      query['page'] = '$page';
    }
    if (perPage != null) {
      query['perPage'] = '$perPage';
    }
    if (order != null) {
      query['order'] = order;
    }
    if (desc != null) {
      query['desc'] = '$desc';
    }
    final body = await _getBody(
      _uri([
        ..._tablePath(ref),
        'records',
      ], query: query.isEmpty ? null : query),
    );
    return jsonObjectList(
      body,
      what: 'the records list',
    ).map((json) => NinoxRecord.fromJson(json)).toList();
  }

  List<String> _tablePath(TableRef ref) => [
    'teams',
    ref.teamId,
    'databases',
    ref.databaseId,
    'tables',
    ref.tableId,
  ];

  /// `https://<host>/v1` plus the given path segments, on the configured endpoint and nowhere else
  /// (`configurable-ninox-host`: a private-cloud customer needs no fork, and no request of this
  /// adapter can be built from a compiled-in host).
  Uri _uri(List<String> segments, {Map<String, String>? query}) {
    final base = _endpoint.baseUri;
    return base.replace(
      pathSegments: [...base.pathSegments, ...segments],
      queryParameters: query,
    );
  }

  Future<String> _getBody(Uri uri) async {
    final answer = await _send(
      http.Request('GET', uri),
      uncertainWhenLost: false,
    );
    _throwUnlessSuccess(answer);
    return answer.body;
  }

  /// Sends one request, or reports why it could not be sent or answered.
  ///
  /// [uncertainWhenLost] is true only for a create: if the request never left, the answer is
  /// merely a transport failure, but `package:http` cannot tell that apart from a response lost
  /// after the request landed, so a create says [CreateOutcomeUncertain] — the safe side, because
  /// the other way round costs a duplicate record (ADR-013, design §4, §8).
  Future<_Answer> _send(
    http.BaseRequest request, {
    required bool uncertainWhenLost,
  }) async {
    // The one credential, in the one header it travels in (ADR-004, BR-19). It is set here rather
    // than at each call site so that no request of this adapter can go out without it — and so
    // that it never has to be written into a body, a query or a log to be carried.
    request.headers['Authorization'] = _credentials.authorizationHeader;
    final http.Response response;
    try {
      response = await _perform(request).timeout(timeout);
    } on Exception catch (error) {
      final detail = _redacted(error.toString());
      throw uncertainWhenLost
          ? CreateOutcomeUncertain(detail)
          : TransportFailure(detail);
    }
    return _Answer(response.statusCode, _decodeBody(response));
  }

  Future<http.Response> _perform(http.BaseRequest request) async =>
      http.Response.fromStream(await _client.send(request));

  /// Reads the body as UTF-8, whatever the `Content-Type` says or omits.
  ///
  /// JSON is UTF-8 by RFC 8259 and Ninox's own field names carry accents (`Código Presupuestario`,
  /// `Año` in the spike's database), so a body is never decoded through the header's charset
  /// default — which is latin-1 when a response declares none, and would silently mangle them.
  String _decodeBody(http.Response response) {
    try {
      return utf8.decode(response.bodyBytes);
    } on FormatException {
      throw UnexpectedResponse('the body is not UTF-8');
    }
  }

  /// Maps a status this API was measured to return onto the condition it is (design §4).
  ///
  /// The adapter stops at the classification. A 5xx is [ServerError] and **not** retried or called
  /// a mapping error here: Ninox answers an invalid, formula or read-only field name with HTTP 500,
  /// and *refresh the schema, retry once, then report a mapping error* is the pipeline's rule.
  void _throwUnlessSuccess(_Answer answer) {
    final status = answer.status;
    if (status >= 200 && status < 300) return;
    final message = _messageOf(answer.body);
    if (status == 401 || status == 403) throw Unauthorized(message);
    if (status == 404) throw NotFound(message);
    if (status == 429) throw RateLimited(message);
    if (status >= 500) throw ServerError(status, message);
    throw UnexpectedResponse(
      'HTTP $status${message == null ? '' : ': $message'}',
    );
  }

  /// The `message` of the API's small error object (`{"message":"Team Not Found"}`), which the
  /// skill's trace shows is more useful than the status alone. Never a record's values.
  String? _messageOf(String body) {
    final Object? decoded = _tryDecode(body);
    if (decoded is! Map) return null;
    final message = decoded['message'];
    if (message is! String || message.isEmpty) return null;
    return _redacted(message);
  }

  static Object? _tryDecode(String body) {
    try {
      return jsonDecode(body);
    } on FormatException {
      return null;
    }
  }

  /// Removes the token from anything this class is about to put in a failure.
  ///
  /// Nothing here is supposed to carry it — it travels in one request header — but a server that
  /// echoes an `Authorization` header in an error body, or a transport error that quotes the
  /// request, would otherwise put it into a log or a transcript. The token never appears in a
  /// failure this package raises, whatever the source says.
  String _redacted(String text) {
    final token = _credentials.token;
    final safe = token.isEmpty ? text : text.replaceAll(token, '***');
    return safe.length <= 300 ? safe : '${safe.substring(0, 300)}…';
  }
}

/// One answered request: the status and the body, already decoded.
final class _Answer {
  const _Answer(this.status, this.body);

  final int status;
  final String body;
}
