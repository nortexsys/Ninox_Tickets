/// The port and the stores the wizard's tests run on (design §1).
///
/// **No test makes a network call and none needs a token.** Every Ninox answer here is a list the
/// test put in the fake, and the identifiers are synthetic: the test base's identifiers appear in
/// no fixture and no test file.
///
/// The fakes are the only doubles the wizard needs. A widget takes a controller, a controller takes
/// a `NinoxPortFactory` and a `TokenStore`, and both of those are two of the classes below; the
/// third, [FakeSystemBrowser], is the platform's browser.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:ninox_client/ninox_client.dart';
import 'package:paperdrop/features/wizard/data/destination_store.dart';
import 'package:paperdrop/features/wizard/data/token_store.dart';
import 'package:paperdrop/features/wizard/destination.dart';
import 'package:paperdrop/features/wizard/token/system_browser.dart';
import 'package:paperdrop/features/wizard/wizard_controller.dart';

/// A controller over the fakes, with the lists a test chose.
///
/// The factory is a closure: it hands the fake the endpoint and the credential the controller built
/// it with, so a test can assert that the port was built from the **parsed** endpoint (design §4)
/// without any test ever owning a real credential.
///
/// [log] is a list the caller keeps: the port and the store append to it as they are called, so a
/// test can prove the order of the validating call and the keystore write.
({WizardController controller, FakeNinoxPort port, FakeTokenStore store})
wizardHarness({
  List<NinoxTeam>? teams,
  List<NinoxDatabase>? databases,
  List<NinoxTable>? tables,
  Destination? initial,
  List<String>? log,
}) {
  final FakeNinoxPort port = FakeNinoxPort(
    teams: teams,
    databases: databases,
    tables: tables,
  )..log = log;
  final FakeTokenStore store = FakeTokenStore()..log = log;
  final WizardController controller = WizardController(
    portFactory: (NinoxEndpoint endpoint, NinoxCredentials credentials) {
      port.builtWithEndpoint = endpoint;
      port.builtWithCredentials = credentials;
      return port;
    },
    tokenStorage: store,
    initial: initial,
  );
  return (controller: controller, port: port, store: store);
}

/// A [DestinationStore] that keeps what it is given in memory.
///
/// The flow's tests run on a widget clock, and the file-backed store's work is real file I/O that a
/// fake clock cannot advance — the reason `test/tool/fakes.dart` exists for the intake store at all.
/// So a widget test records the destination the wizard produced, and the file itself is proved in
/// `data/destination_store_test.dart`, a plain `test` with a real directory.
class FakeDestinationStore implements DestinationStore {
  /// Every destination the wizard saved, in order.
  final List<Destination> saved = <Destination>[];

  /// What the store holds: the last one saved, or nothing.
  List<Destination> stored = <Destination>[];

  /// Makes the next save fail, as a device that cannot write does (design §10.1). A failed save
  /// records nothing: nothing was saved.
  bool failing = false;

  @override
  Future<List<Destination>> readAll() async => List<Destination>.of(stored);

  @override
  Future<void> save(Destination destination) async {
    if (failing) {
      throw const FileSystemException('this device cannot write right now');
    }
    saved.add(destination);
    stored = <Destination>[destination];
  }
}

/// The platform's browser, replaced by what a test decides (design §4).
class FakeSystemBrowser implements SystemBrowser {
  /// Every address the step opened, in order. Empty is what "the browser was not opened" means.
  final List<Uri> opened = <Uri>[];

  /// What the platform answers. A platform that will not open the page answers `false`.
  bool succeeds = true;

  @override
  Future<bool> open(Uri url) async {
    opened.add(url);
    return succeeds;
  }
}

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
