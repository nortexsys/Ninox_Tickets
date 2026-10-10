/// The port the send pipeline's tests run on: scripted answers, and a log of every call.
///
/// This is T1.1 of the change. Nothing here reaches the network, and no test of this package holds a
/// token: the fake answers from its own scripts, and a failure is written into the script as an
/// instance of the port's own typed failures. Two properties make the pipeline's behaviour
/// assertable rather than inferred:
///
/// * **the order of the calls** — [calls] keeps `createRecord:T1`, `uploadFile:T1#1416`,
///   `readRecord:T1#1416`, `listFiles:T1#1416` …, which is how *create → attach → read back* is
///   proved as an order and how *a reconciliation ran before the one retried create* is proved;
/// * **the scripted failure of one call and not the next** — each method takes its answers from a
///   queue, so a timeout on the second upload is a script of two entries and not a property of the
///   fake.
library;

import 'dart:typed_data';

import 'package:ninox_client/ninox_client.dart';

/// A [NinoxPort] that answers from scripts and can fail on demand.
final class FakeNinoxPort implements NinoxPort {
  /// Every call, in order, as `method:table` or `method:table#record`.
  final List<String> calls = <String>[];

  /// The payload the last `createRecord` was given, so a test can prove it was passed through
  /// unchanged — the pipeline decides no value and builds no mapping.
  Map<String, Object?>? createdFields;

  /// The document the last `uploadFile` was given, so a test can prove the bytes, the name and the
  /// content type travelled as they were handed over (ADR-007, BR-17).
  Uint8List? uploadedBytes;

  /// The name the last upload was given.
  String? uploadedFilename;

  /// The content type the last upload was given.
  String? uploadedContentType;

  /// The table the last listing was asked for.
  TableRef? listedRef;

  /// The `perPage` the last listing was asked with.
  int? listedPerPage;

  /// Every `listRecords` call, in order, with the arguments it was made with — so that a test can
  /// assert which pages were read, in which order, and that no `order` or `desc` was asked for.
  final List<ListingCall> pageReads = <ListingCall>[];

  /// The answers `createRecord` gives, one per call: a `RecordId`, or a [NinoxFailure] to throw.
  List<Object> creates = <Object>[];

  /// The answers `uploadFile` gives, one per call: `null` for success, or a [NinoxFailure].
  List<Object> uploads = <Object>[];

  /// The answers `readRecord` gives, one per call: a `NinoxRecord`, or a [NinoxFailure].
  List<Object> reads = <Object>[];

  /// The answers `listFiles` gives, one per call: a `List<NinoxFile>`, or a [NinoxFailure].
  List<Object> files = <Object>[];

  /// The answers `listRecords` gives, one per call: a `List<NinoxRecord>`, or a [NinoxFailure].
  List<Object> listings = <Object>[];

  /// What `createRecord` answers when its script has run out. The identifier is invented.
  RecordId nextId = const RecordId('1416');

  /// What `readRecord` answers when its script has run out. Its `id` is replaced by the identifier
  /// that was asked for, so a test states the values once.
  NinoxRecord nextRecord = const NinoxRecord(
    id: RecordId('1416'),
    fields: <String, Object?>{},
  );

  /// What `listFiles` answers when its script has run out.
  List<NinoxFile> nextFiles = const <NinoxFile>[];

  /// What `listRecords` answers when its script has run out, **paged honestly**.
  ///
  /// The records are returned in the order they are given here — a test that wants the record a
  /// reconciliation must find at the end of a long table puts it last, which is exactly the case the
  /// vendor's unknown default order can produce — one page of `perPage` rows at a time, following
  /// `page`. A page past the end is empty, and the default `perPage` is the API's own page of 100.
  List<NinoxRecord> nextListing = const <NinoxRecord>[];

  @override
  Future<RecordId> createRecord(
    TableRef ref,
    Map<String, Object?> fieldsByName,
  ) async {
    calls.add('createRecord:${ref.tableId}');
    createdFields = fieldsByName;
    return _answer<RecordId>(creates, () => nextId);
  }

  @override
  Future<NinoxRecord> readRecord(TableRef ref, RecordId recordId) async {
    calls.add('readRecord:${ref.tableId}#${recordId.value}');
    return _answer<NinoxRecord>(
      reads,
      () => NinoxRecord(
        id: recordId,
        fields: nextRecord.fields,
        createdAt: nextRecord.createdAt,
        createdBy: nextRecord.createdBy,
        modifiedAt: nextRecord.modifiedAt,
        modifiedBy: nextRecord.modifiedBy,
        sequence: nextRecord.sequence,
      ),
    );
  }

  @override
  Future<void> uploadFile(
    TableRef ref,
    RecordId recordId, {
    required String filename,
    required Uint8List bytes,
    required String contentType,
  }) async {
    calls.add('uploadFile:${ref.tableId}#${recordId.value}');
    uploadedBytes = bytes;
    uploadedFilename = filename;
    uploadedContentType = contentType;
    _answer<Object?>(uploads, () => null);
  }

  @override
  Future<List<NinoxFile>> listFiles(TableRef ref, RecordId recordId) async {
    calls.add('listFiles:${ref.tableId}#${recordId.value}');
    return _answer<List<NinoxFile>>(files, () => nextFiles);
  }

  @override
  Future<List<NinoxRecord>> listRecords(
    TableRef ref, {
    int? page,
    int? perPage,
    String? order,
    bool? desc,
  }) async {
    calls.add('listRecords:${ref.tableId}');
    listedRef = ref;
    listedPerPage = perPage;
    pageReads.add(
      ListingCall(page: page, perPage: perPage, order: order, desc: desc),
    );
    return _answer<List<NinoxRecord>>(
      listings,
      () => _pageOf(nextListing, page: page, perPage: perPage),
    );
  }

  @override
  Future<void> updateRecord(
    TableRef ref,
    RecordId recordId,
    Map<String, Object?> fieldsByName,
  ) async {
    // The pipeline never sends an update: a correction is not a send, and a retried attachment
    // touches nothing but the attachment (`ninox-send/updates-are-merges`, FR-SND-008). A test that
    // reaches this line has found a call the pipeline must not make.
    calls.add('updateRecord:${ref.tableId}#${recordId.value}');
    throw const UnexpectedResponse('the fake serves no update');
  }

  @override
  Future<List<NinoxTeam>> listTeams() async {
    calls.add('listTeams');
    throw const UnexpectedResponse('the fake serves no teams listing');
  }

  @override
  Future<List<NinoxDatabase>> listDatabases(String teamId) async {
    calls.add('listDatabases:$teamId');
    throw const UnexpectedResponse('the fake serves no database listing');
  }

  @override
  Future<List<NinoxTable>> listTables(String teamId, String databaseId) async {
    calls.add('listTables:$teamId/$databaseId');
    throw const UnexpectedResponse('the fake serves no table listing');
  }

  /// Takes the next scripted answer, or falls back. A scripted [NinoxFailure] is thrown, which is
  /// how a call is made to fail without the fake deciding which calls may fail.
  T _answer<T>(List<Object> script, T Function() fallback) {
    if (script.isEmpty) return fallback();
    final Object answer = script.removeAt(0);
    if (answer is NinoxFailure) throw answer;
    return answer as T;
  }

  @override
  String toString() => 'FakeNinoxPort(${calls.length} calls)';
}

/// One page of a table, as the API serves it: the rows that `page` and `perPage` select, in the
/// order the table holds them, and an empty list past the end.
///
/// A `perPage` the caller did not give is the API's own default page of 100.
List<NinoxRecord> _pageOf(
  List<NinoxRecord> records, {
  int? page,
  int? perPage,
}) {
  final int size = perPage ?? 100;
  final int first = (page ?? 0) * size;
  if (first >= records.length) return const <NinoxRecord>[];
  final int last = first + size;
  return records.sublist(first, last < records.length ? last : records.length);
}

/// One `listRecords` call, as the fake received it.
///
/// It exists so that a test can assert **which pages** a read asked for, in which order, and that
/// it asked for no `order` and no `desc` — the two parameters whose server-side effect is
/// unverified (GAP-023) and which the reconciliation must therefore not depend on.
final class ListingCall {
  /// Builds the record of one call.
  const ListingCall({this.page, this.perPage, this.order, this.desc});

  /// The page asked for; `null` when the caller asked for none.
  final int? page;

  /// The rows per page asked for; `null` when the caller asked for none.
  final int? perPage;

  /// The `order` asked for; `null` is what a caller that does not trust server-side ordering sends.
  final String? order;

  /// The `desc` asked for.
  final bool? desc;

  @override
  String toString() =>
      'ListingCall(page: $page, perPage: $perPage, order: $order, desc: $desc)';
}
