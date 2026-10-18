/// Group 1 of the negative release checklist: **no backend call** (Funcional §10.6, §1.2).
///
/// The non-goal: *the app never runs a backend service and never creates a Paperdrop user
/// account*, and every document, image and extracted value leaves the device **only** toward the
/// user's own Ninox database. The requirement it protects: NFR-PRV-001 (*no network call other
/// than to the user's own Ninox database exists in the codebase or in observed traffic*),
/// NFR-PRF-002 (reading needs no network), NFR-PRF-003 / NFR-OFL-001 in the offline direction,
/// ADR-002 (on-device extraction, no backend) and ADR-017 (the host is configuration).
///
/// **What this file proves.** Two things, and they cover each other's blind spot:
///
/// * *lexically* — the shipped sources of the application and of both packages contain no
///   network client except the two files that are allowed to (the classic adapter of ADR-003 and
///   the composition root that builds its `http.Client`), and every host name in shipped code is
///   on a list of four entries, each with a reason;
/// * *at run time* — a whole send over the fake port and a whole extraction over fake ports open
///   **no** connection while an `HttpOverrides` is watching, and the same guard, given the
///   adapter on a private-cloud endpoint, sees exactly one `GET /v1/teams` and it goes to the
///   configured host and not to the vendor's cloud.
///
/// **Where it stops.** The scan reads names and literals, not types (see
/// `checklist_support.dart`), and the run-time half can only watch the calls the paths it drives
/// actually make: a network client behind a name neither the scan nor the path exercises is not
/// found here. What the guard cannot miss is any code built on `package:http` or `dart:io`'s
/// `HttpClient`, because that is the only way out of a Dart process.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:ninox_client/ninox_client.dart';
import 'package:paperdrop/adapters/ocr/ocr_text_source.dart';
import 'package:paperdrop/adapters/pdf_text/pdf_text_source.dart';
import 'package:paperdrop/features/extraction/extraction_router.dart';
import 'package:paperdrop/features/extraction/extraction_service.dart';
import 'package:paperdrop/history/history_entry.dart';
import 'package:paperdrop/history/history_store.dart';
import 'package:paperdrop/intake/intake_result.dart';
import 'package:paperdrop_core/paperdrop_core.dart';

import 'checklist_support.dart';

/// The names a network client answers to, as a lexical scan can see them.
///
/// `package:http/` is the one client this product uses; the rest is what a second lane would add
/// to reach a service of its own — a socket, a web socket, a raw server, an address lookup, a
/// browser-side client. The scan reads them **whole-word and outside comments**, so
/// `SocketException` and a host named in a doc comment are not findings.
const List<String> networkClientTokens = <String>[
  'package:http/',
  'package:dio/',
  'package:grpc/',
  'package:web_socket_channel/',
  'dart:html',
  'HttpClient',
  'HttpServer',
  'Socket',
  'RawSocket',
  'SecureSocket',
  'WebSocket',
  'InternetAddress',
];

/// The only two files of the product that may hold a network client, and why (design §1 of
/// `implement-negative-release-checklist`: *the only allowed outbound code is `ninox_client`*).
const Map<String, String> networkClientAllowlist = <String, String>{
  'packages/ninox_client/lib/src/classic_adapter.dart|package:http/':
      'the adapter of ADR-003: the one client, and every request it builds is built on the '
      'configured NinoxEndpoint (ADR-017)',
  'app/lib/features/wizard/data/port_factory.dart|package:http/':
      'the composition root: it builds the http.Client the adapter owns and makes no request '
      'of its own',
};

/// A host name in shipped code may be one of these four, and each is a vendor address with a
/// documented job — not a service of the publisher's (ADR-012, NFR-PRV-002).
const Map<String, String> hostAllowlist = <String, String>{
  'packages/ninox_client/lib/src/endpoint.dart|api.ninox.com':
      'the API host of ADR-017: a default, overridden per destination, never compiled in as '
      'the only possibility',
  'packages/ninox_client/lib/src/send/send_links.dart|next.ninox.com':
      'the web application\'s host for the deep link of FR-SND-006: a link a browser opens, '
      'never a request of this app',
  'app/lib/features/wizard/token/system_browser.dart|admin.ninox.com': 'the vendor\'s own token page (FR-WIZ-003), handed to the platform\'s browser',
  'app/lib/l10n/generated/app_localizations_en.dart|api.ninox.com':
      'the token step\'s placeholder text, generated from `app_en.arb`: a hint on a screen, '
      'not an address any code sends to',
};

/// A host-shaped string literal: a dot-separated name with a top-level label this scan knows.
final RegExp _hostLiteral = RegExp(
  r'[a-z0-9](?:[a-z0-9-]*[a-z0-9])?(?:\.[a-z0-9](?:[a-z0-9-]*[a-z0-9])?)+\.'
  r'(?:com|de|net|org|io|cloud|dev|local)',
  caseSensitive: false,
);

/// A text-layer port that answers with one readable page and records what it was asked.
final class _TextSource implements PdfTextSource {
  _TextSource(this.pages);

  final List<TextPage> pages;
  final List<String> readPaths = <String>[];

  @override
  Future<List<TextPage>> read(String path) async {
    readPaths.add(path);
    return pages;
  }
}

/// A recognition port that records being asked: on the text-layer route it must not be.
final class _OcrSource implements OcrTextSource {
  final List<String> recognisePaths = <String>[];

  @override
  Future<List<OcrPass>> recognise(String path) async {
    recognisePaths.add(path);
    return const <OcrPass>[];
  }
}

/// One page with a word on it, so that the route selector finds a text layer.
TextPage _readablePage() => TextPage(0, 300000, 300000, <PositionedWord>[
  PositionedWord('TOTAL', 100000, 120000, 100000, 120000),
]);

void main() {
  const String nonGoal = 'no backend call';
  const String requirements = 'NFR-PRV-001, NFR-PRF-002, ADR-002, ADR-017';

  test('[$nonGoal] the shipped code holds one network client and no other '
      '($requirements)', () {
    final List<File> sources = shippedSources();
    expect(
      sources.length,
      greaterThan(40),
      reason:
          'the scan read ${sources.length} files, so it proves nothing about '
          'a product of this size',
    );

    final List<TokenOccurrence> found = occurrencesIn(
      sources,
      networkClientTokens,
    );
    expect(
      unauthorised(found, networkClientAllowlist),
      isEmpty,
      reason:
          '[$nonGoal] the only outbound code may be ninox_client on the '
          'configured host ($requirements): the occurrences above are a second '
          'way out of the device',
    );
    expect(
      unmatchedEntries(found, networkClientAllowlist),
      isEmpty,
      reason:
          '[$nonGoal] an allowlist entry that matches nothing is stale, and a '
          'stale entry is how this check would quietly stop working',
    );

    // The allowlist is not decoration: both of its entries are live today.
    expect(found, hasLength(networkClientAllowlist.length * 1));
  });

  test('[$nonGoal] every host name in shipped code is a vendor address with a '
      'reason ($requirements)', () {
    final List<TokenOccurrence> found = <TokenOccurrence>[
      for (final File file in shippedSources())
        for (final TokenOccurrence literal in literalsIn(file))
          for (final RegExpMatch match in _hostLiteral.allMatches(
            literal.token,
          ))
            TokenOccurrence(
              path: literal.path,
              line: literal.line,
              token: match.group(0)!,
              excerpt: literal.excerpt,
            ),
    ];
    expect(
      found,
      isNotEmpty,
      reason: 'the literal scan found no host at all, so it proves nothing',
    );
    expect(
      unauthorised(found, hostAllowlist),
      isEmpty,
      reason:
          '[$nonGoal] a host name outside the allowlist is a place this app '
          'could send a document that is not the user\'s Ninox database '
          '($requirements)',
    );
    expect(
      unmatchedEntries(found, hostAllowlist),
      isEmpty,
      reason: '[$nonGoal] a host allowlist entry that matches nothing is stale',
    );
  });

  test('[$nonGoal] a whole send opens no connection: create, attach and read '
      'back all go through the port (NFR-PRV-001, ADR-002)', () async {
    final RecordingHttpOverrides guard = RecordingHttpOverrides();
    final SendHarness harness = SendHarness();
    harness.port.nextRecord = NinoxRecord(
      id: const RecordId('1416'),
      fields: const <String, Object?>{'Importe': 1999},
      createdBy: 'user-1',
    );
    harness.port.nextFiles = <NinoxFile>[storedFile(size: 4)];

    final SendOutcome outcome = await HttpOverrides.runZoned(
      () => harness.pipeline.send(testRequest()),
      createHttpClient: guard.createHttpClient,
    );

    expect(outcome, isA<Sent>());
    expect(harness.port.calls, <String>[
      'createRecord:T1',
      'uploadFile:T1#1416',
      'readRecord:T1#1416',
      'listFiles:T1#1416',
    ], reason: 'the three steps of FR-SND-001 are the whole of a send');
    expect(
      guard.attempts,
      isEmpty,
      reason:
          '[$nonGoal] the send path never reaches the network itself: the port '
          'owns every request ($requirements)',
    );
    expect(
      guard.clientsCreated,
      0,
      reason: '[$nonGoal] nothing under the pipeline even built an HttpClient',
    );
  });

  test('[$nonGoal] a whole extraction opens no connection: reading is on the '
      'device (NFR-PRF-002, ADR-002)', () async {
    final Directory root = Directory.systemTemp.createTempSync(
      'release-checklist-extraction',
    );
    addTearDown(() {
      if (root.existsSync()) {
        root.deleteSync(recursive: true);
      }
    });

    final String docId = aDocId(7);
    final String hash = aDocumentHash('release-checklist');
    final FileHistoryStore store = FileHistoryStore(root);
    await store.create(
      anEntry(docId: docId, state: DocumentState.pending, documentHash: hash),
    );
    final IntakeResult document = IntakeResult(
      docId: docId,
      source: IntakeSource.picker,
      mediaType: 'application/pdf',
      byteLength: 4,
      sha256: hash,
      storedPath: '${root.path}/original.pdf',
    );

    final _TextSource text = _TextSource(<TextPage>[_readablePage()]);
    final _OcrSource ocr = _OcrSource();
    final ExtractionService service = ExtractionService(
      store: store,
      router: ExtractionRouter(pdfText: text, ocr: ocr),
    );

    final RecordingHttpOverrides guard = RecordingHttpOverrides();
    final ExtractionOutcome outcome = await HttpOverrides.runZoned(
      () => service.extract(document),
      createHttpClient: guard.createHttpClient,
    );

    expect(outcome, isA<ExtractionCompleted>());
    expect(text.readPaths, hasLength(1));
    expect(
      ocr.recognisePaths,
      isEmpty,
      reason: 'a PDF with a text layer takes the text-layer route (FR-EXT-002)',
    );
    expect(
      guard.attempts,
      isEmpty,
      reason:
          '[$nonGoal] extraction is entirely on the device (NFR-PRF-002, '
          'ADR-002)',
    );
    expect(guard.clientsCreated, 0);
  });

  test('[$nonGoal] the guard sees the one call the adapter makes, and it goes '
      'to the configured host (ADR-017)', () async {
    // This test is the one that keeps the guard honest: without it, "no attempt was recorded"
    // could mean the override was never installed.
    final NinoxEndpoint privateCloud = NinoxEndpoint.parse(
      'ninox.example.de:8443',
    )!;
    final RecordingHttpOverrides guard = RecordingHttpOverrides();
    await HttpOverrides.runZoned(() async {
      // The composition root's own line (`port_factory.dart`): one endpoint, one credential,
      // one client. Built inside the zone, so the HttpClient beneath it is the guard's.
      final ClassicNinoxAdapter adapter = ClassicNinoxAdapter(
        endpoint: privateCloud,
        credentials: const NinoxCredentials('synthetic-token'),
        client: http.Client(),
      );
      await expectLater(
        adapter.listTeams(),
        throwsA(isA<TransportFailure>()),
        reason:
            'the guard refuses the connection, and the adapter classifies it '
            'as the transport failure it is',
      );
    }, createHttpClient: guard.createHttpClient);

    expect(guard.attempts, hasLength(1));
    expect(guard.attempts.single.method, 'GET');
    expect(guard.attempts.single.uri.host, 'ninox.example.de');
    expect(guard.attempts.single.uri.port, 8443);
    expect(guard.attempts.single.uri.path, '/v1/teams');
    expect(
      guard.attempts.single.uri.host,
      isNot(NinoxEndpoint.cloud.host),
      reason:
          '[$nonGoal] the host comes from the destination, not from a '
          'compiled-in constant (ADR-017)',
    );
  });
}
