/// T1.9, the live **write** run — **written, and not run by the lane**.
///
/// This file is the code the orchestrator runs on the product owner's machine, with the approval of
/// 2026-10-08. The lane that wrote it had no token, made no call, and claims **no measured result**:
/// every number this file produces is produced on the machine that runs it, and is written to
/// `test/live/out/t19_results.json` and printed to stdout so that it can be read without this file.
///
/// ## What it measures (GAP-004)
///
/// 1. create → read back → merge update → read back, on one record: the payload shape, the
///    read-after-create and the merge semantics of ADR-004 together, on invented values.
/// 2. a small PDF uploaded and read back (name, size, content type), then a ladder of sizes —
///    1, 2, 5, 10, 15, 20 and 25 MiB — **stopping at the first failure**, each step on a record of
///    its own, recording the failure type, the status and the elapsed time. The largest size that
///    succeeded is what the next step sits near.
/// 3. a **multipage** PDF at the largest size that succeeded, with a read-back.
/// 4. the timings of all of it: the elapsed milliseconds and the MiB/s of every upload, from the
///    product owner's own network, which is the measurement GAP-004 is waiting for and which a
///    cloud container's numbers are not.
///
/// ## The bounds it stays inside (approved scope, 2026-10-08)
///
/// * **Only table `EF` (`Paperdrop_test`) of `jd1m8n8l4j7i`.** The team, the database and the table
///   are literals below, never read from the environment; the file refuses to run at all when any
///   of them fails to resolve to what it names (`_resolveTarget`), checked with GET requests before
///   the first write.
/// * **The records that were already there are never touched.** Their identifiers are recorded
///   before the first write (`preexistingRecordIds`) and the run may delete **only** ids it created
///   itself (`_deleteOne` refuses anything else, and refuses a pre-existing id even if a listing
///   claims it); at the end it lists the table again and reports every pre-existing id that is
///   missing, and every id that is still there that it created.
/// * **Invented data and generated documents only.** The values are synthetic, and the attachments
///   are PDFs built in this process by `syntheticPdf` — never a real document, nothing from the
///   product owner's corpus, no file read from disk.
/// * **Hard caps, enforced before each call** by [WriteBudget]: at most **30 records created**,
///   at most **25 MiB per attachment**, at most **150 MiB uploaded in total**. A cap does not report
///   afterwards that it was passed: it throws before the call, and the run stops there.
///
/// ## The guard
///
/// It is the same opt-in guard as `order_desc_check_test.dart`, for the same reason and with more
/// at stake, because this file writes: it refuses to run unless `PAPERDROP_LIVE_NINOX=1` **and** a
/// token is in `NINOX_API_KEY`, read here, in this file, and asked twice — as each test's `skip:`
/// and again inside each body, because `--run-skipped` overrides a load-time skip. The orchestrator
/// runs it with:
///
///     PAPERDROP_LIVE_NINOX=1 dart test packages/ninox_client --run-skipped -t live
///
/// (on Windows: `set PAPERDROP_LIVE_NINOX=1 && dart test packages/ninox_client --run-skipped -t live`).
/// The read-only GAP-023 check in the same directory is selected by the same tag and runs too; it
/// issues GET requests only. To run **this file alone**, name it:
///
///     PAPERDROP_LIVE_NINOX=1 dart test packages/ninox_client/test/live/write_limits_test.dart --run-skipped
///
/// ## Cleanup
///
/// Deletion of the run's own records happens in **two** places: in the `finally` of the run body,
/// so that an unexpected throw — a 5xx, a dropped connection, a bug in this file — cannot leave a
/// record behind, and again in `tearDownAll`, which also writes the results file, prints the table
/// and reports any record it could not delete, with its id, for the product owner to remove by
/// hand.
///
/// ## What it does not do
///
/// It adds nothing to the port's public API: the records are deleted with this file's own
/// `http.Client`, because the port has no delete and this change does not add one.
@Tags(['live'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:ninox_client/ninox_client.dart';
import 'package:test/test.dart';

import '../fixture_files.dart';
import 't19_support.dart';

/// The variable the token is read from, as the spike and the skill's checker read it.
const String _tokenVariable = 'NINOX_API_KEY';

/// The variable that has to equal `1` before any live test of this package may run.
const String _optInVariable = 'PAPERDROP_LIVE_NINOX';

/// The value [_optInVariable] has to have.
const String _optInValue = '1';

/// The test environment, named explicitly and never taken from the environment (`AGENTS.md` §1.4).
const String _teamId = 'qCq3JS7q7ptoap8Yg';

/// `JI-PRUEBAS-CLAUDE`, the test database: a copy of a whole ERP, of which this run touches **one**
/// table.
const String _databaseId = 'jd1m8n8l4j7i';

/// The disposable table the product owner created for this change.
const String _tableId = 'EF';

/// Its name, checked against the listing before anything is written: if the id resolves to another
/// table, this file refuses to run rather than write into the wrong one.
const String _tableName = 'Paperdrop_test';

/// The date field and the number field the schema has to show, by name and by type.
const String _dateField = 'Fecha';

/// See [_dateField].
const String _numberField = 'Importe';

/// The value the run writes into the date field: the day of the approval.
const String _inventedDate = '2026-10-08';

/// The value the create writes into the number field, and the one the merge replaces it with.
/// Amounts are integers (paperdrop_core's convention); the table is disposable either way.
const int _inventedAmount = 1999;

/// See [_inventedAmount].
const int _mergedAmount = 2049;

/// The ladder, in mebibytes. Each size gets a record of its own; the ladder stops at the first
/// failure.
const List<int> _ladderSizes = [1, 2, 5, 10, 15, 20, 25];

/// The page the listing is walked in. 100 is the API's own default, stated so that paging is
/// deliberate rather than accidental.
const int _pageSize = 100;

/// The most pages [_allRecordIds] will walk before it refuses to write: 2,000 records. A table
/// bigger than that makes "the ids that were here before" an unreliable statement, and this run
/// does not write when it cannot make it.
const int _maxPages = 20;

/// The results file, inside the git-ignored `test/live/out/`.
const String _resultsFileName = 't19_results.json';

void main() {
  final token = Platform.environment[_tokenVariable];
  final refusal = _refusal(
    token: token,
    optIn: Platform.environment[_optInVariable],
  );

  group('T1.9 live writes on $_tableId', () {
    _Run? active;

    setUpAll(() async {
      // The guard first: when the run is refused, `setUpAll` must not make a single request. Every
      // call before the first write is a GET, and it is a GET for the ids that are already there.
      if (refusal != null) return;
      active = await _Run.begin(token: token!);
      stdout.writeln(active!.describeTarget());
    });

    tearDownAll(() async {
      await active?.finish();
    });

    test('create, read back, merge, then the attachment ladder', () async {
      if (refusal != null) {
        markTestSkipped(refusal);
        return;
      }
      final run = active!;
      try {
        await run.roundTrip();
        await run.smallAttachment();
        await run.sizeLadder();
        await run.multipage();
        expect(
          run.findings,
          isEmpty,
          reason:
              'the run completed and left findings, all recorded in ${run.resultsPath}: '
              '${run.findings.join(' | ')}',
        );
      } finally {
        // Cleanup also here, and not only in `tearDownAll`: an unexpected throw must not leave a
        // record behind in the product owner's table. `deleteCreated` is idempotent — it deletes
        // each id once and only ids this run created.
        await run.deleteCreated();
      }
    }, skip: refusal);

    test(
      'every record that was in the table before the run is still there',
      () async {
        if (refusal != null) {
          markTestSkipped(refusal);
          return;
        }
        final run = active!;
        await run.verify();

        expect(
          run.verification['preexistingAllPresent'],
          isTrue,
          reason:
              'records that were in $_tableId before the run are missing: '
              '${run.verification['missingPreexistingIds']}',
        );
        expect(
          run.verification['recordsLeftByThisRun'],
          isEmpty,
          reason: 'this run created records and did not delete them',
        );
        expect(
          run.failedDeletes,
          isEmpty,
          reason:
              'a record this run created could not be deleted. Remove it by hand: '
              '${run.failedDeletes}',
        );
        expect(
          run.untrackedNewIds,
          isEmpty,
          reason:
              'ids that were not in the table before the run and that this run did not create: they '
              'are listed in the results file and NOTHING was deleted for them — check them by hand',
        );
      },
      skip: refusal,
    );
  });
}

/// Why this live test must not run, or `null` when it may.
///
/// The same two checks as the read-only GAP-023 check, and the same order: the token, because a
/// live call needs one, and an explicit opt-in, because the presence of a token must not be enough
/// for a test that writes. A machine with a token but no opt-in is refused with the opt-in named;
/// a machine with the opt-in but no token is refused with the token named.
String? _refusal({required String? token, required String? optIn}) {
  if (optIn != _optInValue) {
    return 'live tests are opt-in: set $_optInVariable=$_optInValue, and put a token in '
        '$_tokenVariable, to run these writes against a real workspace.';
  }
  if (token == null) {
    return '$_tokenVariable is absent: set it, and $_optInVariable=$_optInValue, to run these '
        'live writes.';
  }
  return null;
}

/// One execution of the approved run: what it created, what it measured, what it has to delete.
final class _Run {
  _Run._({
    required this.token,
    required this.adapter,
    required this.deleteClient,
    required this.ref,
    required this.startedAt,
  });

  /// Resolves the target **read-only** and records the ids that are already there.
  ///
  /// Every call here is a GET. If anything the literals name fails to resolve, this throws and no
  /// test runs a write: the refusal is the point, not an inconvenience to work around.
  static Future<_Run> begin({required String token}) async {
    final run = _Run._(
      token: token,
      adapter: ClassicNinoxAdapter(
        endpoint: NinoxEndpoint.cloud,
        credentials: NinoxCredentials(token),
        client: http.Client(),
        timeout: const Duration(seconds: 180),
      ),
      deleteClient: http.Client(),
      ref: const TableRef(
        teamId: _teamId,
        databaseId: _databaseId,
        tableId: _tableId,
      ),
      startedAt: DateTime.now().toUtc(),
    );
    await run._resolveTarget();
    run.preexistingRecordIds = await _allRecordIds(run.adapter, run.ref);
    return run;
  }

  final String token;
  final ClassicNinoxAdapter adapter;
  final http.Client deleteClient;
  final TableRef ref;
  final DateTime startedAt;
  final WriteBudget budget = WriteBudget();

  /// Every id the table held **before** the first write. Nothing in this list is ever deleted.
  late Set<String> preexistingRecordIds;

  final List<String> createdRecordIds = [];
  final List<String> deletedRecordIds = [];
  final List<Map<String, Object?>> failedDeletes = [];
  final List<Map<String, Object?>> steps = [];
  final List<String> findings = [];

  /// Every time the cap refused a call, with the arithmetic. A run that stayed inside the caps
  /// leaves this empty, and either way it is recorded rather than asserted.
  final List<String> capRefusals = [];

  /// Ids that were not there before the run and that this run did not create. Reported, never
  /// deleted: this run does not remove what it cannot account for.
  List<String> untrackedNewIds = [];

  Map<String, Object?> verification = const {};

  String? dateField;
  String? numberField;
  String? textField;
  String? resolvedTableName;
  int? largestSuccessBytes;

  /// Why the run cannot continue, when it cannot.
  String? haltedReason;

  /// Why the ladder ended before its last size, when it did.
  String? ladderStopReason;

  bool verified = false;
  bool finished = false;

  bool get halted => haltedReason != null;

  String get resultsPath =>
      '${packageRoot().path}${Platform.pathSeparator}test'
      '${Platform.pathSeparator}live${Platform.pathSeparator}out'
      '${Platform.pathSeparator}$_resultsFileName';

  // ---------------------------------------------------------------------------------------------
  // Resolving the target, before the first write
  // ---------------------------------------------------------------------------------------------

  Future<void> _resolveTarget() async {
    final teams = await adapter.listTeams();
    _refuseUnless(
      teams.any((team) => team.id == _teamId),
      'the team $_teamId is not among the ${teams.length} teams this token can see',
    );

    final databases = await adapter.listDatabases(_teamId);
    _refuseUnless(
      databases.any((database) => database.id == _databaseId),
      'the database $_databaseId is not among the ${databases.length} databases of team '
      '$_teamId',
    );

    final tables = await adapter.listTables(_teamId, _databaseId);
    NinoxTable? table;
    for (final candidate in tables) {
      if (candidate.id == _tableId) table = candidate;
    }
    _refuseUnless(
      table != null,
      'the table $_tableId is not among the ${tables.length} tables of database $_databaseId',
    );
    resolvedTableName = table!.name;
    _refuseUnless(
      table.name == _tableName,
      'the id $_tableId resolves to a table called "${table.name}", not "$_tableName": this file '
      'refuses to write into a table it cannot identify',
    );

    String? dateField;
    String? numberField;
    String? textField;
    for (final field in table.fields) {
      if (field.name == _dateField && field.type == 'date') {
        dateField = field.name;
      }
      if (field.name == _numberField && field.type == 'number') {
        numberField = field.name;
      }
      if (textField == null && field.type == 'string') textField = field.name;
    }
    _refuseUnless(
      dateField != null,
      'the table has no "$_dateField" of type date; its fields are ${_describe(table.fields)}',
    );
    _refuseUnless(
      numberField != null,
      'the table has no "$_numberField" of type number; its fields are '
      '${_describe(table.fields)}',
    );
    this.dateField = dateField;
    this.numberField = numberField;
    // Not required: the run works with the two fields the scope names. If the schema shows a text
    // field, the invented marker goes there too, which is one more field to prove the merge leaves
    // alone.
    this.textField = textField;
  }

  String _describe(List<NinoxField> fields) =>
      fields.map((field) => '${field.name} (${field.type})').join(', ');

  // ---------------------------------------------------------------------------------------------
  // The steps
  // ---------------------------------------------------------------------------------------------

  /// Create, read back, merge, read back (ADR-004's payload shape and merge semantics).
  Future<void> roundTrip() async {
    if (halted) {
      _skipStep('the round trip', haltedReason!);
      return;
    }
    final fields = _inventedValues('round trip');
    final id = await _createForStep('the round-trip record');
    if (id == null) return;

    final stored = await _readBack(id, 'read after create', fields);
    if (stored == null) return;

    final update = <String, Object?>{numberField!: _mergedAmount};
    final watch = Stopwatch()..start();
    try {
      await adapter.updateRecord(ref, id, update);
    } on NinoxFailure catch (failure) {
      watch.stop();
      _addStep(
        'merge update',
        recordId: id,
        elapsedMs: watch.elapsedMilliseconds,
        status: 'failed',
        note: failure.toString(),
      );
      findings.add('the merge update failed: $failure');
      haltedReason = 'the merge update failed';
      return;
    }
    watch.stop();
    _addStep(
      'merge update',
      recordId: id,
      elapsedMs: watch.elapsedMilliseconds,
      note: 'sent only ${update.keys.join(', ')}',
    );

    final merged = await _readBack(
      id,
      'read after the merge',
      <String, Object?>{...fields, ...update},
    );
    if (merged == null) return;

    // `ninox-send/updates-are-merges`, scenario "a correction leaves the rest untouched": the merge
    // sent one field, and the fields it did not send are still what the create stored.
    for (final entry in fields.entries) {
      if (update.containsKey(entry.key)) continue;
      final afterMerge = merged.fields[entry.key];
      if (!sameValue(
        entry.value,
        afterMerge,
        asDate: entry.key == _dateField,
      )) {
        findings.add(
          'the merge did not leave "${entry.key}" untouched: it was ${entry.value} after the '
          'create and $afterMerge after the merge, which sent only ${update.keys.join(', ')}',
        );
      }
    }
  }

  /// One small PDF, uploaded and read back: name, size and content type (FR-SND-003).
  Future<void> smallAttachment() async {
    if (halted) {
      _skipStep('the small attachment', haltedReason!);
      return;
    }
    const filename = 'paperdrop-t19-small.pdf';
    final bytes = syntheticPdf(pages: 1, targetBytes: 48 * 1024);
    final id = await _createForStep('the small-attachment record');
    if (id == null) return;
    if (!await _upload(
      id,
      bytes,
      filename,
      phase: 'small',
      label: 'the small attachment',
    )) {
      return;
    }
    await _readFilesBack(id, filename, bytes, 'read back the small attachment');
  }

  /// The ladder of sizes, stopping at the first failure.
  Future<void> sizeLadder() async {
    if (halted) {
      _skipStep('the size ladder', haltedReason!);
      return;
    }
    for (final mebibytes in _ladderSizes) {
      if (halted || ladderStopReason != null) break;
      final target = mebibytes * mebibyte;
      final bytes = syntheticPdf(pages: 1, targetBytes: target);
      final id = await _createForStep('the $mebibytes MiB record');
      if (id == null) return;
      final filename = 'paperdrop-t19-$mebibytes-miB.pdf';
      if (!await _upload(
        id,
        bytes,
        filename,
        phase: 'ladder',
        label: '$mebibytes MiB',
      )) {
        return;
      }
      largestSuccessBytes = bytes.length;
      await _readFilesBack(id, filename, bytes, 'read back $mebibytes MiB');
    }
    _addStep(
      'the size ladder',
      status: ladderStopReason == null ? 'completed' : 'stopped',
      note:
          ladderStopReason ??
          'every size in the ladder succeeded; the largest was '
              '${largestSuccessBytes ?? 0} bytes',
    );
  }

  /// A multipage PDF near the largest size that succeeded — GAP-004's other question.
  Future<void> multipage() async {
    if (halted) {
      _skipStep('the multipage document', haltedReason!);
      return;
    }
    final largest = largestSuccessBytes;
    if (largest == null) {
      _addStep(
        'the multipage document',
        status: 'skipped',
        note: 'no size in the ladder succeeded, so there is no largest size to sit near',
      );
      return;
    }
    final pages = (largest ~/ (256 * 1024)).clamp(2, 12);
    final bytes = syntheticPdf(pages: pages, targetBytes: largest);
    final filename = 'paperdrop-t19-multipage-$pages-pages.pdf';
    final id = await _createForStep('the multipage record');
    if (id == null) return;
    if (!await _upload(
      id,
      bytes,
      filename,
      phase: 'multipage',
      label: 'the multipage document ($pages pages)',
    )) {
      return;
    }
    await _readFilesBack(
      id,
      filename,
      bytes,
      'read back the multipage document',
    );
  }

  // ---------------------------------------------------------------------------------------------
  // One call at a time, with its cap, its timing and its failure
  // ---------------------------------------------------------------------------------------------

  /// Creates one record for a step, or explains why the run stops here.
  Future<RecordId?> _createForStep(String label) async {
    final fields = _inventedValues(label);
    try {
      budget.beforeCreate();
    } on WriteBudgetExceeded catch (cap) {
      _addStep(
        '$label: create',
        status: 'refused by the cap',
        note: cap.message,
      );
      haltedReason =
          'the record cap refused the create for $label: ${cap.message}';
      capRefusals.add(cap.message);
      return null;
    }
    final watch = Stopwatch()..start();
    final RecordId id;
    try {
      id = await adapter.createRecord(ref, fields);
    } on NinoxFailure catch (failure) {
      watch.stop();
      _addStep(
        '$label: create',
        elapsedMs: watch.elapsedMilliseconds,
        status: classify(failure).name,
        note: failure.toString(),
      );
      if (failure is CreateOutcomeUncertain) {
        // The POST may have landed. ADR-013: never retry it, look read-side instead — and adopt
        // whatever appeared, so that this run deletes its own record rather than leaving an orphan.
        await _adoptLostCreate();
      }
      haltedReason = 'the create for $label failed: $failure';
      if (failure is! CreateOutcomeUncertain) {
        findings.add('the create for $label failed: $failure');
      }
      return null;
    }
    watch.stop();
    budget.afterCreate();
    createdRecordIds.add(id.value);
    _addStep(
      '$label: create',
      recordId: id,
      elapsedMs: watch.elapsedMilliseconds,
      note: 'fields: ${fields.keys.join(', ')}',
    );
    return id;
  }

  /// Uploads one document, or records why it failed and what that means for the ladder.
  Future<bool> _upload(
    RecordId id,
    Uint8List bytes,
    String filename, {
    required String phase,
    required String label,
  }) async {
    try {
      budget.beforeUpload(bytes.length);
    } on WriteBudgetExceeded catch (cap) {
      _addStep(
        '$label: upload',
        recordId: id,
        bytes: bytes.length,
        status: 'refused by the cap',
        note: cap.message,
      );
      ladderStopReason ??=
          'the upload cap refused ${bytes.length} bytes: ${cap.message}';
      capRefusals.add(cap.message);
      return false;
    }
    final watch = Stopwatch()..start();
    try {
      await adapter.uploadFile(
        ref,
        id,
        filename: filename,
        bytes: bytes,
        contentType: 'application/pdf',
      );
    } on NinoxFailure catch (failure) {
      watch.stop();
      _recordAttachmentFailure(
        label: label,
        phase: phase,
        id: id,
        bytes: bytes.length,
        elapsedMs: watch.elapsedMilliseconds,
        failure: failure,
      );
      return false;
    }
    watch.stop();
    budget.afterUpload(bytes.length);
    _addStep(
      '$label: upload',
      recordId: id,
      bytes: bytes.length,
      elapsedMs: watch.elapsedMilliseconds,
      note:
          '${rateMibPerSecond(bytes.length, watch.elapsedMilliseconds)} MiB/s',
    );
    return true;
  }

  void _recordAttachmentFailure({
    required String label,
    required String phase,
    required RecordId id,
    required int bytes,
    required int elapsedMs,
    required NinoxFailure failure,
  }) {
    final verdict = classify(failure);
    _addStep(
      '$label: upload',
      recordId: id,
      bytes: bytes,
      elapsedMs: elapsedMs,
      status: verdict.name,
      note: failure.toString(),
    );
    switch (verdict) {
      case Verdict.limit:
        // The API's answer about a size, or a request that ran out of time at this size. This stop
        // is the measurement: it is what the ladder exists to find.
        final reason =
            '$label failed at $bytes bytes with $failure (after ${elapsedMs}ms)';
        if (phase == 'ladder') {
          ladderStopReason ??= reason;
        } else {
          _addStep('$label: stop', status: 'limit', note: reason);
        }
      case Verdict.unexpected:
        findings.add(
          '$label failed with $failure, which is not the API\'s answer about a size (after '
          '${elapsedMs}ms at $bytes bytes): the ladder stopped there',
        );
        ladderStopReason ??= '$label failed unexpectedly: $failure';
      case Verdict.fatal:
        findings.add('$label failed with $failure: the run stopped');
        haltedReason = '$label failed with $failure';
    }
  }

  /// Reads a record back and compares it with what was sent.
  ///
  /// A difference is a **finding**, not something to fix: the read-back is the truth, and a formula
  /// or a table default overriding a submitted value is exactly what ADR-004 says can happen.
  Future<NinoxRecord?> _readBack(
    RecordId id,
    String label,
    Map<String, Object?> expected,
  ) async {
    final watch = Stopwatch()..start();
    final NinoxRecord stored;
    try {
      stored = await adapter.readRecord(ref, id);
    } on NinoxFailure catch (failure) {
      watch.stop();
      _addStep(
        label,
        recordId: id,
        elapsedMs: watch.elapsedMilliseconds,
        status: 'failed',
        note: failure.toString(),
      );
      findings.add('$label failed: $failure');
      haltedReason = '$label failed';
      return null;
    }
    watch.stop();

    final differences = <String>[];
    for (final entry in expected.entries) {
      if (!stored.fields.containsKey(entry.key)) {
        differences.add('"${entry.key}" is not in the read-back');
      } else if (!sameValue(
        entry.value,
        stored.fields[entry.key],
        asDate: entry.key == _dateField,
      )) {
        differences.add(
          '"${entry.key}": sent ${entry.value}, stored '
          '${stored.fields[entry.key]}',
        );
      }
    }
    _addStep(
      label,
      recordId: id,
      elapsedMs: watch.elapsedMilliseconds,
      status: differences.isEmpty ? 'ok' : 'differs',
      note: differences.isEmpty
          ? 'all ${expected.length} values are as submitted'
          : differences.join('; '),
    );
    for (final difference in differences) {
      findings.add('$label: $difference');
    }
    return stored;
  }

  /// Reads the record's files back and compares name, size and content type with what was uploaded.
  Future<void> _readFilesBack(
    RecordId id,
    String filename,
    Uint8List bytes,
    String label,
  ) async {
    final watch = Stopwatch()..start();
    final List<NinoxFile> files;
    try {
      files = await adapter.listFiles(ref, id);
    } on NinoxFailure catch (failure) {
      watch.stop();
      _addStep(
        label,
        recordId: id,
        elapsedMs: watch.elapsedMilliseconds,
        status: 'failed',
        note: failure.toString(),
      );
      findings.add('$label failed: $failure');
      return;
    }
    watch.stop();

    NinoxFile? found;
    for (final file in files) {
      if (file.name == filename) found = file;
    }
    if (found == null) {
      _addStep(
        label,
        recordId: id,
        bytes: bytes.length,
        elapsedMs: watch.elapsedMilliseconds,
        status: 'missing',
        note: '$filename is not among the ${files.length} files of the record',
      );
      findings.add(
        '$label: the attachment "$filename" is not among the ${files.length} files of record '
        '${id.value}',
      );
      return;
    }
    final differences = <String>[];
    if (found.size != bytes.length) {
      differences.add('size: uploaded ${bytes.length}, stored ${found.size}');
    }
    if (found.contentType != 'application/pdf') {
      differences.add(
        'content type: uploaded application/pdf, stored ${found.contentType}',
      );
    }
    _addStep(
      label,
      recordId: id,
      bytes: bytes.length,
      elapsedMs: watch.elapsedMilliseconds,
      status: differences.isEmpty ? 'ok' : 'differs',
      note: differences.isEmpty
          ? 'name, size and content type match what was uploaded'
          : differences.join('; '),
    );
    for (final difference in differences) {
      findings.add('$label: $difference');
    }
  }

  /// A create whose response was lost: find it read-side, adopt it, and never retry it.
  ///
  /// ADR-013's discipline applied to this run's own cleanup. The ids that were not in the table
  /// before this run are the only candidates, and they are adopted so that `deleteCreated` removes
  /// them: leaving a record the run created inside the product owner's table would be the exact
  /// outcome this file is written to avoid.
  Future<void> _adoptLostCreate() async {
    findings.add(
      'a create was lost (the response never arrived): the record may exist, so no further create '
      'was attempted and the table was listed to find it',
    );
    try {
      final now = await _allRecordIds(adapter, ref);
      final appeared = now.difference(preexistingRecordIds);
      if (appeared.isEmpty) {
        _addStep(
          'a lost create',
          status: 'uncertain',
          note: 'no id appeared that was not there before, so the POST did not land',
        );
        return;
      }
      for (final id in appeared) {
        createdRecordIds.add(id);
        // The record exists, so it counts against the record cap: a lost create is still a create.
        budget.afterCreate();
        _addStep(
          'a lost create: adopted',
          recordId: RecordId(id),
          status: 'uncertain',
          note:
              'no create response arrived for this id; it was found by listing the table and it '
              'will be deleted with the rest',
        );
      }
    } on NinoxFailure catch (failure) {
      findings.add(
        'the read-side check after the lost create failed too ($failure): the table may hold a '
        'record this run created, and it will be listed as an untracked id at the end rather than '
        'deleted on a guess',
      );
    }
  }

  // ---------------------------------------------------------------------------------------------
  // Cleanup, verification, results
  // ---------------------------------------------------------------------------------------------

  /// Deletes every record this run created, and only those.
  ///
  /// Idempotent: it is called from the run body's `finally` and again from `tearDownAll`, and each
  /// id is deleted once. The port has no delete and this change does not add one, so the call is
  /// made with this file's own client, on the same endpoint the adapter uses.
  Future<void> deleteCreated() async {
    for (final id in createdRecordIds.reversed.toList()) {
      if (deletedRecordIds.contains(id)) continue;
      await _deleteOne(id);
    }
  }

  Future<void> _deleteOne(String id) async {
    // The ids-created guard, as close to the call as it can be: a delete is a write, and the only
    // records this run may delete are the ones whose create it recorded. A pre-existing record is
    // never a candidate, whatever a listing says.
    if (!createdRecordIds.contains(id) || preexistingRecordIds.contains(id)) {
      failedDeletes.add({
        'id': id,
        'reason': 'refused: this run did not create it, or it was in the table before the run',
      });
      return;
    }
    final base = NinoxEndpoint.cloud.baseUri;
    final uri = base.replace(
      pathSegments: [
        ...base.pathSegments,
        'teams',
        _teamId,
        'databases',
        _databaseId,
        'tables',
        _tableId,
        'records',
        id,
      ],
    );
    final http.Response response;
    try {
      response = await deleteClient
          .delete(uri, headers: {'Authorization': 'Bearer $token'})
          .timeout(const Duration(seconds: 60));
    } on Exception catch (error) {
      failedDeletes.add({
        'id': id,
        'reason': 'the delete did not complete: ${_redact(error.toString())}',
      });
      return;
    }
    if (response.statusCode == 200 || response.statusCode == 204) {
      deletedRecordIds.add(id);
      _addStep(
        'delete',
        recordId: RecordId(id),
        status: '${response.statusCode}',
      );
      return;
    }
    failedDeletes.add({
      'id': id,
      'status': response.statusCode,
      'reason': _redact(_messageOf(response.body)),
    });
  }

  /// Lists the table again and records what it says about the records that were there before.
  ///
  /// It asserts nothing: it records, and the test asserts on what it recorded, so that the results
  /// file is written even when the verification finds something. Nothing is ever deleted here.
  Future<void> verify() async {
    if (verified) return;
    final now = await _allRecordIds(adapter, ref);
    final missing = preexistingRecordIds.difference(now);
    final left = now.intersection(createdRecordIds.toSet());
    final untracked = now
        .difference(preexistingRecordIds)
        .difference(createdRecordIds.toSet());
    untrackedNewIds = untracked.toList();
    verification = {
      'at': DateTime.now().toUtc().toIso8601String(),
      'preexistingCount': preexistingRecordIds.length,
      'preexistingAllPresent': missing.isEmpty,
      'missingPreexistingIds': missing.toList(),
      'recordsLeftByThisRun': left.toList(),
      'untrackedIdsSeen': untracked.toList(),
    };
    verified = true;
    if (missing.isNotEmpty) {
      findings.add(
        'records that were in the table before the run are gone: ${missing.join(', ')}',
      );
    }
    if (left.isNotEmpty) {
      findings.add(
        'records this run created were not deleted: ${left.join(', ')}',
      );
    }
    if (untracked.isNotEmpty) {
      findings.add(
        'the table holds ids that were not there before the run and that this run did not create: '
        '${untracked.join(', ')} (listed, not deleted)',
      );
    }
  }

  /// Everything the run has to say, for the results file.
  Map<String, Object?> toJson() => {
    't19': {
      'written':
          'written and not run by the lane: these numbers were produced by the machine that '
          'ran it',
      'startedAt': startedAt.toIso8601String(),
      'finishedAt': DateTime.now().toUtc().toIso8601String(),
      'host': NinoxEndpoint.cloud.baseUri.toString(),
      'team': _teamId,
      'database': _databaseId,
      'tableId': _tableId,
      'tableName': resolvedTableName,
      'fields': {'date': dateField, 'number': numberField, 'text': textField},
      'values': {
        'date': _inventedDate,
        'number': _inventedAmount,
        'merged': _mergedAmount,
      },
      'ladderSizesMib': _ladderSizes,
    },
    'caps': budget.toJson(),
    'capRefusals': capRefusals,
    'preexistingRecordIds': preexistingRecordIds.toList(),
    'createdRecordIds': createdRecordIds,
    'deletedRecordIds': deletedRecordIds,
    'failedDeletes': failedDeletes,
    'verification': verification,
    'ladder': {
      'largestSuccessBytes': largestSuccessBytes,
      'stoppedAt': ladderStopReason,
    },
    'halted': haltedReason,
    'steps': steps,
    'findings': findings,
  };

  /// Deletes what is left, verifies, writes the results file and prints the table.
  ///
  /// Called from `tearDownAll`, which runs even when a test failed: the results file and the list of
  /// records to remove by hand are what the orchestrator needs on the way out.
  Future<void> finish() async {
    if (finished) return;
    finished = true;
    await deleteCreated();
    try {
      await verify();
    } on NinoxFailure catch (failure) {
      findings.add('the final listing failed: $failure');
    }

    writeResults();
    printTable();
    deleteClient.close();

    if (failedDeletes.isNotEmpty) {
      stdout.writeln('');
      stdout.writeln(
        'RECORDS THIS RUN COULD NOT DELETE — remove them by hand in $_tableName ($_tableId):',
      );
      for (final failure in failedDeletes) {
        stdout.writeln('  ${failure['id']}: ${failure['reason']}');
      }
    }
  }

  void writeResults() {
    final file = File(resultsPath);
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(toJson()),
    );
  }

  /// The results, on stdout, in the order the run produced them. No credential appears here.
  void printTable() {
    stdout.writeln('');
    stdout.writeln(
      'T1.9 — table $resolvedTableName ($_tableId) of $_databaseId, team $_teamId, '
      '${NinoxEndpoint.cloud.baseUri}',
    );
    stdout.writeln(
      'started ${startedAt.toIso8601String()} · '
      'fields ${dateField ?? '?'}, ${numberField ?? '?'}'
      '${textField == null ? '' : ', ${textField!}'}',
    );
    stdout.writeln(
      '${'step'.padRight(38)}${'record'.padRight(8)}${'bytes'.padLeft(12)}${'ms'.padLeft(8)}'
      '${'MiB/s'.padLeft(8)}  status',
    );
    for (final step in steps) {
      final bytes = step['bytes'];
      final elapsed = step['elapsedMs'];
      final rate = bytes is int && elapsed is int && elapsed > 0
          ? rateMibPerSecond(bytes, elapsed)
          : '';
      stdout.writeln(
        '${_text(step['step']).padRight(38)}'
        '${_text(step['recordId']).padRight(8)}'
        '${_text(bytes).padLeft(12)}'
        '${_text(elapsed).padLeft(8)}'
        '${rate.padLeft(8)}  '
        '${_text(step['status'])}'
        '${step['note'] == null ? '' : ' — ${_text(step['note'])}'}',
      );
    }
    stdout.writeln('');
    stdout.writeln('caps: $budget');
    stdout.writeln(
      'before the run the table held ${preexistingRecordIds.length} records: '
      '${preexistingRecordIds.join(', ')}',
    );
    stdout.writeln(
      'this run created ${createdRecordIds.length} and deleted ${deletedRecordIds.length}: '
      '${createdRecordIds.join(', ')}',
    );
    stdout.writeln(
      'largest size that succeeded: '
      '${largestSuccessBytes == null ? 'none' : '$largestSuccessBytes bytes'}'
      '${ladderStopReason == null ? '' : ' (the ladder stopped: $ladderStopReason)'}',
    );
    stdout.writeln('verification: ${jsonEncode(verification)}');
    stdout.writeln(
      findings.isEmpty
          ? 'findings: none'
          : 'findings:\n  ${findings.join('\n  ')}',
    );
    stdout.writeln('results written to $resultsPath');
  }

  void _addStep(
    String step, {
    RecordId? recordId,
    int? bytes,
    int? elapsedMs,
    String status = 'ok',
    String? note,
  }) {
    final entry = <String, Object?>{'step': step, 'status': status};
    if (recordId != null) entry['recordId'] = recordId.value;
    if (bytes != null) entry['bytes'] = bytes;
    if (elapsedMs != null) entry['elapsedMs'] = elapsedMs;
    if (note != null) entry['note'] = _redact(note);
    steps.add(entry);
  }

  void _skipStep(String label, String reason) {
    _addStep(label, status: 'skipped', note: reason);
  }

  /// The invented payload: the two fields the scope names, plus a text field when the schema has
  /// one. The text carries a non-ASCII character on purpose — the product owner's own field names
  /// do, and an encoding fault is worth meeting here rather than in a real send.
  Map<String, Object?> _inventedValues(String label) {
    final fields = <String, Object?>{
      dateField!: _inventedDate,
      numberField!: _inventedAmount,
    };
    final text = textField;
    if (text != null) {
      fields[text] = 'T1.9 synthetic — $label — disposable';
    }
    return fields;
  }

  String describeTarget() =>
      'T1.9: writing to $resolvedTableName ($_tableId) of $_databaseId, team $_teamId, '
      'fields ${dateField ?? '?'}, ${numberField ?? '?'}'
      '${textField == null ? '' : ', ${textField!}'}';
}

/// Refuses the run when a literal in this file does not resolve to what it names.
void _refuseUnless(bool condition, String message) {
  if (!condition) {
    throw StateError(
      'T1.9 refuses to run: $message. Nothing was created, updated, attached or deleted: this '
      'check is made with GET requests only.',
    );
  }
}

/// Walks the table's pages and returns every record id in it.
Future<Set<String>> _allRecordIds(
  ClassicNinoxAdapter adapter,
  TableRef ref,
) async {
  final ids = <String>{};
  for (var page = 0; page < _maxPages; page++) {
    final records = await adapter.listRecords(
      ref,
      page: page,
      perPage: _pageSize,
    );
    for (final record in records) {
      ids.add(record.id.value);
    }
    if (records.length < _pageSize) return ids;
  }
  throw StateError(
    'the table has more than ${_maxPages * _pageSize} records: this run cannot say which ids were '
    'there before it, so it refuses to write',
  );
}

String _text(Object? value) => value == null ? '' : '$value';

/// Removes the token from anything this file is about to print or write down.
///
/// Nothing here is supposed to carry it — it travels in one header — but a server that echoes an
/// `Authorization` header in an error body, or a transport error that quotes the request, would
/// otherwise put it into a file. The token appears nowhere in the results.
String _redact(String text) {
  final token = Platform.environment[_tokenVariable];
  final safe = token == null || token.isEmpty
      ? text
      : text.replaceAll(token, '***');
  return safe.length <= 300 ? safe : '${safe.substring(0, 300)}…';
}

/// The `message` of the API's small error object, bounded and redacted.
String _messageOf(String body) {
  try {
    final Object? decoded = jsonDecode(body);
    if (decoded is Map && decoded['message'] is String) {
      return _redact(decoded['message'] as String);
    }
  } on FormatException {
    return 'the body was not JSON';
  }
  return 'no message in the body';
}
