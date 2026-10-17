/// The fakes the retry, retention and queue tests share.
///
/// **No call leaves the machine.** The sender is scripted, the port records and refuses, and the
/// connectivity port is a stream a test drives: every test here is a host test over
/// `FileHistoryStore` in a folder the test owns (`implement-history-retry-duplicates`, design §5).
/// No device, no Ninox and no token are involved, so nothing in this file can write to a database.
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:ninox_client/ninox_client.dart';
import 'package:paperdrop/history/connectivity.dart';
import 'package:paperdrop/history/history_entry.dart';
import 'package:paperdrop/history/history_store.dart';
import 'package:paperdrop/history/send_retry.dart';

/// The read-back of a send whose record carries the document: one file named [filename].
///
/// It is what a `Sent` outcome is built from — the pipeline reports the record **as Ninox stored
/// it** and never what was sent (`ninox-send/create-attach-read-back`) — and the history copies the
/// identifier out of it.
Sent aSent({String recordId = 'record-1', String filename = 'original.pdf'}) =>
    Sent(
      recordId: RecordId(recordId),
      readBack: NinoxRecord(
        id: RecordId(recordId),
        fields: const <String, Object?>{},
      ),
      files: <NinoxFile>[
        NinoxFile(name: filename, size: 3, contentType: 'application/pdf'),
      ],
    );

/// The request of one entry, as the send lane would build it.
///
/// The payload is the test's own, and it is deliberately *small*: what the retry decides is which
/// call to make with a request, not what the request says, and a payload with a value in it would
/// only make a failure message harder to read.
SendRequest aRequestFor(HistoryEntry entry) => SendRequest(
  ref: entry.destination,
  fieldsByName: <String, Object?>{'Total': 1999},
  docId: entry.docId,
  filename: 'original.pdf',
  bytes: Uint8List.fromList(<int>[1, 2, 3]),
  contentType: 'application/pdf',
);

/// The request builder a [RetryService] is given in these tests.
///
/// Async, as a builder that reads the stored document's bytes has to be; it reads no file, because
/// nothing here sends anything anywhere.
Future<SendRequest> requestOf(HistoryEntry entry) async => aRequestFor(entry);

/// A [DocumentSender] a test scripts: what each call is, in order, and what it answers.
///
/// The two calls are told apart because the whole of design §3 is which one a state earns: a test
/// that only counted "a send happened" could not tell a create from an attachment to a record that
/// already exists, and that difference is a duplicate record.
final class FakeSender implements DocumentSender {
  /// Builds the fake over the answer each call gets.
  ///
  /// [answer] receives the request and, for a `resume`, the record it was aimed at; the default
  /// answers a completed send, which is the outcome most tests want and the one they vary.
  FakeSender({
    SendOutcome Function(SendRequest request, RecordId? recordId)? answer,
  }) : answer =
           answer ??
           ((SendRequest request, RecordId? recordId) =>
               aSent(recordId: recordId?.value ?? 'record-1'));

  /// What a call answers.
  final SendOutcome Function(SendRequest request, RecordId? recordId) answer;

  /// Every call made, in order: `send:<docId>` or `resume:<docId>:<recordId>`.
  final List<String> calls = <String>[];

  /// Every request the sender was handed, in order.
  final List<SendRequest> requests = <SendRequest>[];

  @override
  Future<SendOutcome> send(SendRequest request) async {
    calls.add('send:${request.docId}');
    requests.add(request);
    return answer(request, null);
  }

  @override
  Future<SendOutcome> resume(SendRequest request, RecordId recordId) async {
    calls.add('resume:${request.docId}:${recordId.value}');
    requests.add(request);
    return answer(request, recordId);
  }
}

/// A [NinoxPort] that records an update and refuses everything else.
///
/// **A create is an [`UnimplementedError`], and that is the point.** A correction that created a
/// record would be the duplicate `correction-and-re-send` forbids, so the fake makes one impossible
/// and a test asserts the port was asked for nothing but the update.
final class RecordingPort implements NinoxPort {
  /// Every update made, in order: the destination, the record and the payload.
  final List<RecordedUpdate> updates = <RecordedUpdate>[];

  /// Every call made, in order, by the port's own method name.
  final List<String> calls = <String>[];

  /// What `updateRecord` throws instead of answering, when a test sets one.
  NinoxFailure? failure;

  @override
  Future<void> updateRecord(
    TableRef ref,
    RecordId recordId,
    Map<String, Object?> fieldsByName,
  ) async {
    calls.add('updateRecord');
    updates.add(
      RecordedUpdate(ref: ref, recordId: recordId, fields: fieldsByName),
    );
    final NinoxFailure? reported = failure;
    if (reported != null) {
      throw reported;
    }
  }

  @override
  Future<RecordId> createRecord(
    TableRef ref,
    Map<String, Object?> fieldsByName,
  ) => throw _never('createRecord');

  @override
  Future<NinoxRecord> readRecord(TableRef ref, RecordId recordId) =>
      throw _never('readRecord');

  @override
  Future<List<NinoxTeam>> listTeams() => throw _never('listTeams');

  @override
  Future<List<NinoxDatabase>> listDatabases(String teamId) =>
      throw _never('listDatabases');

  @override
  Future<List<NinoxTable>> listTables(String teamId, String databaseId) =>
      throw _never('listTables');

  @override
  Future<void> uploadFile(
    TableRef ref,
    RecordId recordId, {
    required String filename,
    required Uint8List bytes,
    required String contentType,
  }) => throw _never('uploadFile');

  @override
  Future<List<NinoxFile>> listFiles(TableRef ref, RecordId recordId) =>
      throw _never('listFiles');

  @override
  Future<List<NinoxRecord>> listRecords(
    TableRef ref, {
    int? page,
    int? perPage,
    String? order,
    bool? desc,
  }) => throw _never('listRecords');

  /// Reaching one of these is the bug a test is looking for.
  UnimplementedError _never(String call) =>
      UnimplementedError('a history retry never calls `$call`');
}

/// One update a [RecordingPort] was asked for.
final class RecordedUpdate {
  /// Binds the destination, the record and the payload of one update.
  const RecordedUpdate({
    required this.ref,
    required this.recordId,
    required this.fields,
  });

  /// The destination the update was aimed at.
  final TableRef ref;

  /// The record the update targeted: the entry's own, never another.
  final RecordId recordId;

  /// The fields the update carried, keyed by their current names.
  final Map<String, Object?> fields;

  @override
  String toString() =>
      'RecordedUpdate(${ref.tableId}, ${recordId.value}, ${fields.length} fields)';
}

/// A [Connectivity] a test drives: it answers [isOnline] and reports changes on demand.
final class FakeConnectivity implements Connectivity {
  /// Builds the fake, online or offline to begin with.
  FakeConnectivity({this.online = true});

  /// Whether the port currently answers that a request could leave the device.
  bool online;

  /// The controller the reports travel on. Broadcast, as a platform's own report is.
  final StreamController<bool> _changes = StreamController<bool>.broadcast();

  /// How many times [isOnline] was asked, so a test can prove the queue checked before each entry.
  int asked = 0;

  /// Whether the port currently reports a connection.
  bool get isUp => online;

  @override
  Future<bool> isOnline() async {
    asked++;
    return online;
  }

  @override
  Stream<bool> get changes => _changes.stream;

  /// Reports a change of connectivity, as the platform would: it both changes the answer
  /// [isOnline] gives and emits on [changes].
  void report({required bool online}) {
    this.online = online;
    _changes.add(online);
  }

  /// Ends the stream, as a disposal would.
  Future<void> close() => _changes.close();
}

/// A [HistoryStore] that forwards to a real one and counts what was asked of it.
///
/// It exists for one claim: the duplicate check is **read-side**
/// (`duplicate-criteria` · *the check is read-side and cannot use a marker field*), so a test can
/// assert that checking a candidate read the history and wrote nothing.
final class CountingStore implements HistoryStore {
  /// Wraps [inner], the store that does the work.
  CountingStore(this.inner);

  /// The store the calls go to.
  final HistoryStore inner;

  /// Every call made, in order, by the interface's own method name.
  final List<String> calls = <String>[];

  @override
  Future<void> create(HistoryEntry entry) {
    calls.add('create');
    return inner.create(entry);
  }

  @override
  Future<HistoryEntry> get(String docId) {
    calls.add('get');
    return inner.get(docId);
  }

  @override
  Future<void> update(String docId, HistoryEntry entry) {
    calls.add('update');
    return inner.update(docId, entry);
  }

  @override
  Future<HistoryListing> list() {
    calls.add('list');
    return inner.list();
  }

  @override
  Future<void> deleteOriginal(String docId) {
    calls.add('deleteOriginal');
    return inner.deleteOriginal(docId);
  }
}
