/// The collaborators a send pipeline's test injects, and the request it sends.
///
/// One place builds the four things the pipeline reads from the outside — the port, the journal,
/// the clock and the sleeper — so that a test states only what it is about: the fake port's scripts
/// and its call log. Nothing here talks to Ninox, holds a token or waits.
library;

import 'dart:typed_data';

import 'package:ninox_client/ninox_client.dart';

import 'fake_ninox_port.dart';

/// The destination every test sends to: a team, a database and a table, all invented.
const TableRef testRef = TableRef(
  teamId: 'team-1',
  databaseId: 'db-1',
  tableId: 'T1',
);

/// The instant the injected clock starts at, so that a reconciliation window is arithmetic and not
/// a wait.
final DateTime testNow = DateTime.utc(2026, 10, 10, 12);

/// An invented request: two mapped fields with invented values, and a small invented document.
///
/// Two mapped fields is the number a reconciliation needs to compare against
/// (`ninox-send/reconciliation-of-an-uncertain-create`); a test that wants none passes an empty map.
SendRequest testRequest({
  String docId = 'document-1',
  Map<String, Object?>? fieldsByName,
}) => SendRequest(
  ref: testRef,
  fieldsByName:
      fieldsByName ??
      const <String, Object?>{'Importe': 1999, 'Fecha': '2026-10-10'},
  docId: docId,
  filename: 'receipt.pdf',
  bytes: Uint8List.fromList(const <int>[37, 80, 68, 70]),
  contentType: 'application/pdf',
);

/// The file the tests upload, as Ninox would give it back: the same name, size and content type.
NinoxFile storedFile({String filename = 'receipt.pdf', int size = 4}) =>
    NinoxFile(name: filename, size: size, contentType: 'application/pdf');

/// A pipeline wired for a test: a scripted port, an in-memory journal, a frozen clock and a sleeper
/// that records instead of waiting.
final class SendHarness {
  /// Wires the pipeline. Every bound the pipeline has is settable here, so that a test can send it
  /// to its limit without sending four calls.
  SendHarness({
    DateTime? now,
    Duration reconcileWindow = const Duration(minutes: 2),
    int attachmentAttempts = 4,
    int maxPages = 200,
    bool withRefreshSchema = true,
  }) : now = now ?? testNow {
    pipeline = SendPipeline(
      port,
      journal: journal,
      clock: () => this.now,
      sleep: (Duration duration) async => slept.add(duration),
      refreshSchema: withRefreshSchema
          ? () async {
              refreshes++;
            }
          : null,
      reconcileWindow: reconcileWindow,
      attachmentAttempts: attachmentAttempts,
      maxPages: maxPages,
    );
  }

  /// The port everything goes to, with its scripts and its log.
  final FakeNinoxPort port = FakeNinoxPort();

  /// What the pipeline reported, in order.
  final InMemorySendJournal journal = InMemorySendJournal();

  /// Every duration the pipeline asked to sleep for, in order — the backoff, as numbers.
  final List<Duration> slept = <Duration>[];

  /// How often the schema was refreshed: the 500 row's *refresh the schema*, counted.
  int refreshes = 0;

  /// What the injected clock answers. Settable, so that a candidate can be put outside the window.
  DateTime now;

  /// The pipeline under test.
  late final SendPipeline pipeline;

  /// Completes one send so that the pipeline learns the token's user from the read-back — the only
  /// way it can (design §4: no call of the port says who the token is).
  ///
  /// After this, [port]'s call log and [journal] carry that first send: a test that asserts on
  /// either clears them.
  Future<SendOutcome> learnTokenUser(String user) async {
    final SendRequest teaching = testRequest(docId: 'document-0');
    port.nextRecord = NinoxRecord(
      id: port.nextId,
      fields: teaching.fieldsByName,
      createdBy: user,
    );
    port.nextFiles = <NinoxFile>[storedFile(size: teaching.bytes.length)];
    return pipeline.send(teaching);
  }

  /// Clears the call log, the page reads and the journal, so that the scenario under test is the
  /// only evidence.
  void forget() {
    port.calls.clear();
    port.pageReads.clear();
    journal.entries.clear();
  }
}
