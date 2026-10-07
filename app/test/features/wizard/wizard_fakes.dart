/// The port and the stores the wizard's tests run on (design §1).
///
/// **No test makes a network call and none needs a token.** Every Ninox answer here is a list the
/// test put in the fake, and the identifiers are synthetic: the test base's identifiers appear in
/// no fixture and no test file.
///
/// The fakes are the only doubles the wizard needs. A widget takes a controller, a controller takes
/// a `NinoxPortFactory` and a `TokenStore`, and both of those are these two classes.
library;

import 'dart:typed_data';

import 'package:ninox_client/ninox_client.dart';
import 'package:paperdrop/features/wizard/data/token_store.dart';

/// A [NinoxPort] whose answers a test sets, which counts what was asked of it, and which records
/// the order of its calls in a shared log.
///
/// The port's write half is not implemented: the wizard reads a subscription and never sends, so a
/// call to it would be a bug in the code under test and says so.
class FakeNinoxPort implements NinoxPort {
  /// Builds the fake with the lists `listTeams`, `listDatabases` and `listTables` will answer with.
  FakeNinoxPort({
    List<NinoxTeam>? teams,
    List<NinoxDatabase>? databases,
    List<NinoxTable>? tables,
  }) : teams = teams ?? const <NinoxTeam>[],
       databases = databases ?? const <NinoxDatabase>[],
       tables = tables ?? const <NinoxTable>[];

  /// What `listTeams` answers with.
  List<NinoxTeam> teams;

  /// What `listDatabases` answers with.
  List<NinoxDatabase> databases;

  /// What `listTables` answers with — tables **with their fields**, as the port returns them.
  List<NinoxTable> tables;

  /// What a named call throws instead of answering, keyed by the call's own name
  /// (`listTeams`, `listDatabases`, `listTables`).
  final Map<String, NinoxFailure> failures = <String, NinoxFailure>{};

  /// Every read call made, in order, by name. A test asserts "one call per list, none twice" and
  /// "no call at all" against this.
  final List<String> calls = <String>[];

  /// An optional log shared with a [FakeTokenStore], so a test can prove the order of the
  /// validating call and the keystore write (design §4).
  List<String>? log;

  /// The endpoint the factory was handed, once a port has been built.
  NinoxEndpoint? builtWithEndpoint;

  /// The credentials the factory was handed. A fake may hold them; nothing prints them.
  NinoxCredentials? builtWithCredentials;

  @override
  Future<List<NinoxTeam>> listTeams() async {
    calls.add('listTeams');
    log?.add('listTeams');
    _failIfAsked('listTeams');
    return teams;
  }

  @override
  Future<List<NinoxDatabase>> listDatabases(String teamId) async {
    calls.add('listDatabases');
    log?.add('listDatabases');
    _failIfAsked('listDatabases');
    return databases;
  }

  @override
  Future<List<NinoxTable>> listTables(String teamId, String databaseId) async {
    calls.add('listTables');
    log?.add('listTables');
    _failIfAsked('listTables');
    return tables;
  }

  void _failIfAsked(String call) {
    final NinoxFailure? failure = failures[call];
    if (failure != null) {
      throw failure;
    }
  }

  @override
  Future<RecordId> createRecord(
    TableRef ref,
    Map<String, Object?> fieldsByName,
  ) => throw _never();

  @override
  Future<NinoxRecord> readRecord(TableRef ref, RecordId recordId) =>
      throw _never();

  @override
  Future<void> updateRecord(
    TableRef ref,
    RecordId recordId,
    Map<String, Object?> fieldsByName,
  ) => throw _never();

  @override
  Future<void> uploadFile(
    TableRef ref,
    RecordId recordId, {
    required String filename,
    required Uint8List bytes,
    required String contentType,
  }) => throw _never();

  @override
  Future<List<NinoxFile>> listFiles(TableRef ref, RecordId recordId) =>
      throw _never();

  @override
  Future<List<NinoxRecord>> listRecords(
    TableRef ref, {
    int? page,
    int? perPage,
    String? order,
    bool? desc,
  }) => throw _never();

  /// The wizard reads a subscription and never sends: a test that reaches this has found a bug.
  UnimplementedError _never() =>
      UnimplementedError('the wizard never writes to Ninox');
}

/// A [TokenStore] that keeps its token in memory, counts the writes and can share a log with a
/// [FakeNinoxPort].
class FakeTokenStore implements TokenStore {
  /// Builds the store, optionally with a token already in it.
  FakeTokenStore({this.stored});

  /// What the store holds. A test asserts it stays `null` after a call that failed.
  String? stored;

  /// Every token written, in order. The token never appears in a message a test asserts on: the
  /// write count is what a test uses.
  final List<String> writes = <String>[];

  /// How many times [clear] was called. Nothing in the wizard calls it (R1's action does).
  int clears = 0;

  /// An optional log shared with a [FakeNinoxPort].
  List<String>? log;

  @override
  Future<String?> read() async => stored;

  @override
  Future<void> write(String token) async {
    writes.add(token);
    stored = token;
    log?.add('writeToken');
  }

  @override
  Future<void> clear() async {
    clears++;
    stored = null;
  }
}
