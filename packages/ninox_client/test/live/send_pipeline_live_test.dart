/// T1.11, the live **send** run — **written, and not run by the lane**.
///
/// This file is the code the orchestrator runs on the product owner's machine, with the approval of
/// 2026-10-17 (proposal, change `verify-live-send-pipeline`): table `EF` of the test base
/// `jd1m8n8l4j7i`, invented values and a synthetic PDF. The lane that wrote it had no token, made
/// no call against Ninox and claims **no measured result**: every number this file produces is
/// produced on the machine that runs it, and is written to
/// `test/live/out/send_pipeline_results.json` and printed to stdout so that it can be read without
/// this file.
///
/// ## What it shows
///
/// `SendPipeline.send` (T1.11) has been proved against `FakeNinoxPort` and never against a real
/// Ninox. The M1 demo is "send with read-back", so this run drives **the pipeline itself** — not the
/// adapter directly — through the real `ClassicNinoxAdapter` and checks the three requirements that
/// make a send a send:
///
/// * `ninox-send/create-attach-read-back` (FR-SND-001): the send reaches `Sent`, and the read-back
///   carries the record the send reports — the record's identifier, and the values as **stored**,
///   so a default or a formula that overrode a submitted value becomes visible rather than staying
///   in the request;
/// * `ninox-send/payload-shape` (FR-SND-002, ADR-004): the payload is keyed by the destination's
///   current field names, the date goes as `YYYY-MM-DD` and comes back as the same day, and the
///   amount goes as an **integer** and comes back as the same integer, with no float crossing the
///   boundary in either direction;
/// * `ninox-send/attachment-upload` (FR-SND-003): the document is attached to the record and read
///   back with its name, its size and its content type matching what was uploaded.
///
/// The order of the calls is recorded too, because the requirement's own scenario is about order: a
/// create, then an attachment to the created record, then a read of that record.
///
/// ## What it deliberately does not do
///
/// * **No duplicate.** A second send of an identical request with a different `docId` is not run:
///   duplicate handling is T2.3 (change design §2.3).
/// * **No `uncertain` and no reconciliation.** Those need an injected failure; the fake port covers
///   them (`test/send/send_pipeline_reconciliation_test.dart`). If a real create does come back
///   uncertain, the run reports it as a finding, adopts what appeared read-side so that it leaves
///   no orphan behind, and does not decide anything.
/// * **No product change.** If the run exposes a defect in the pipeline, it is reported, not fixed
///   here (proposal, *out of scope*). The runner reads the outcome by counts and statuses.
/// * **No other table.** `EF` is the only table touched, and nothing reads `EF`'s existing records
///   beyond recording their identifiers.
///
/// ## The bounds it stays inside (change design §1, the contract approved on 2026-10-08)
///
/// * **Team `qCq3JS7q7ptoap8Yg`, database `jd1m8n8l4j7i`, table `EF` are literals below**, never read
///   from the environment. They are resolved with **GET requests** before the first write, and the
///   file refuses to run when any of them fails to resolve or when the table's name is not the one
///   this file names. The production-database variable of `AGENTS.md` §1.4 is never named here, let
///   alone read.
/// * **The records that were already there are never touched.** Their identifiers are recorded
///   before the first write (`preexistingRecordIds`); the run deletes **only** ids it created
///   (enforced closest to the call, in `_deleteOne`), and at the end it lists the table again and
///   reports every pre-existing id that is missing and every id of its own that is still there.
/// * **Invented values and a generated document only.** The values are the synthetic constants of
///   `send_pipeline_support.dart`, and the attachment is a PDF built in this process by
///   `syntheticPdf` — never a corpus file, never a real document, no value that identifies a person.
/// * **Hard caps, enforced before each call** by the [WriteBudget] the port wrapper consults: at
///   most **3 records created**, one attachment of at most **1 MiB**, and therefore at most 1 MiB of
///   bytes uploaded in total. A cap does not report afterwards that it was passed: it throws before
///   the call it guards, and the run stops there.
///
/// ## What the product owner approves, and where it is written down
///
/// The payload is not improvised at run time, so it can be read — and approved — before the run: its
/// **two keys** are the current names of the date and the amount the approved T1.9 contract names
/// (`Fecha`, `Importe`), its **values** are the invented constants of `send_pipeline_support.dart`,
/// its **document** is generated in this process at 64 KiB, and its **caps** are the three constants
/// above. Nothing else about it varies with the environment, and the same shape is printed by
/// `setUpAll` before the first write and recorded in the results file, so the orchestrator can match
/// what was approved against what ran.
///
/// ## The guard
///
/// The same opt-in guard as `write_limits_test.dart` and `order_desc_check_test.dart`, and with more
/// at stake, because this file writes: it refuses to run unless `PAPERDROP_LIVE_NINOX=1` **and** a
/// token is in `NINOX_API_KEY`, read here, in this file, and asked twice — as each test's `skip:`
/// and again inside each body, because `--run-skipped` overrides a load-time skip. The token is
/// never printed, never written down and never quoted in a failure. The orchestrator runs it with:
///
///     PAPERDROP_LIVE_NINOX=1 dart test packages/ninox_client/test/live/send_pipeline_live_test.dart --run-skipped
///
/// (on Windows: `set PAPERDROP_LIVE_NINOX=1 && dart test packages/ninox_client/test/live/send_pipeline_live_test.dart --run-skipped`).
/// Naming the file runs this run alone; `-t live` runs the read-only GAP-023 check as well.
///
/// ## Cleanup
///
/// Deletion of the run's own records happens in **two** places: in the `finally` of the send body,
/// so that an unexpected throw — a 5xx, a dropped connection, a bug in this file — cannot leave a
/// record behind, and again in `tearDownAll`, which also writes the results file, prints the table
/// and reports any record it could not delete, with its id, for the product owner to remove by hand.
/// The two passes are **serialised**, a delete that answers 404 for an id this run created counts as
/// already gone rather than as a failure, and the verification re-lists, bounded, before it calls a
/// record left — all three are the lessons of the 2026-10-08 T1.9 run, and `t19_support.dart` holds
/// the helpers that carry them.
///
/// ## Why the timeout is stated here
///
/// `package:test`'s default timeout is 30 seconds **per test**, and the 2026-10-08 run showed what a
/// runner that abandons a body mid-write does: the abandoned body keeps running, so its `finally`
/// and `tearDownAll` both deleted at once. This run is one create, one attachment of 64 KiB and two
/// reads, which is seconds on a real network; the ten minutes below are generous on purpose so that
/// the runner never abandons a body that is still writing to the product owner's table.
///
/// ## What it does not add to the product
///
/// Nothing: the records are deleted with this file's own `http.Client`, because the port has no
/// delete and this change does not add one. The port wrapper and the assertions are this file's,
/// and the pipeline is called exactly as the app calls it.
@Tags(['live'])
@Timeout(Duration(minutes: 10))
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:ninox_client/ninox_client.dart';
import 'package:test/test.dart';

import '../fixture_files.dart';
import 'send_pipeline_support.dart';
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

/// The disposable table the product owner created for the live runs.
const String _tableId = 'EF';

/// Its name, checked against the listing before anything is written: if the id resolves to another
/// table, this file refuses to run rather than write into the wrong one.
const String _tableName = 'Paperdrop_test';

/// The size of the synthetic document: 64 KiB, comfortably inside the 1 MiB attachment cap, and
/// large enough that the upload is a real multipart request rather than a rounding error.
const int _documentBytes = 64 * 1024;

/// The most records this run may create (change design §1).
///
/// One send creates one record; three leaves room for the retry matrix's *retry exactly once* after
/// a 500 and for a create that is reconciled and followed by one more, and nothing beyond that.
const int _maxRecordsCreated = 3;

/// The most bytes one attachment may carry (change design §1).
const int _maxAttachmentBytes = mebibyte;

/// The page the listing is walked in. 100 is the API's own default, stated so that paging is
/// deliberate rather than accidental.
const int _pageSize = 100;

/// The most pages [_allRecordIds] will walk before it refuses to write: 2,000 records. A table
/// bigger than that makes "the ids that were here before" an unreliable statement, and this run
/// does not write when it cannot make it.
const int _maxPages = 20;

/// The results file, inside the git-ignored `test/live/out/`.
const String _resultsFileName = 'send_pipeline_results.json';

void main() {
  final token = Platform.environment[_tokenVariable];
  final refusal = _refusal(
    token: token,
    optIn: Platform.environment[_optInVariable],
  );

  group('T1.11 live send on $_tableId', () {
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

    test('one send through the pipeline reaches Sent, and the read-back carries the document', () async {
      if (refusal != null) {
        markTestSkipped(refusal);
        return;
      }
      final run = active!;
      try {
        await run.sendOnce();
      } finally {
        // Cleanup also here, and not only in `tearDownAll`: an unexpected throw must not leave a
        // record behind in the product owner's table. `deleteCreated` is idempotent — it deletes
        // each id once, and only ids this run created.
        await run.deleteCreated();
      }

      final sent = run.sent;
      if (sent == null) {
        fail(
          'the send did not reach Sent: ${run.outcomeSummary}. Everything the run saw is in '
          '${run.resultsPath}',
        );
      }

      // `ninox-send/create-attach-read-back`: the read-back is of the record the send reports, and
      // that record is one this run created — not one that was in the table before it.
      expect(
        sent.readBack.id,
        sent.recordId,
        reason:
            'the record that was read back (${sent.readBack.id.value}) is not the record the send '
            'reports (${sent.recordId.value}): the read-back would not be evidence about it',
      );
      expect(
        run.createdRecordIds,
        contains(sent.recordId.value),
        reason:
            'the record the send reports (${sent.recordId.value}) is not one this run created, so '
            'the run cannot clean it up and has to leave it: ${run.findings.join(' | ')}',
      );

      // FR-SND-001: the read-back is the evidence, and what it stores is what counts.
      final check = run.readBackCheck!;
      expect(
        check.fieldsNotStored,
        isEmpty,
        reason:
            'the read-back does not carry every field that was sent: '
            '${check.fieldsNotStored.join(', ')}',
      );
      expect(
        check.fieldsThatDiffer,
        isEmpty,
        reason:
            'the read-back stores a different value than the one that was sent for '
            '${check.fieldsThatDiffer.join(', ')}. The read-back is the truth: report it, do not '
            'fix it here (change design §2.2, the retry matrix\'s *mapping error*)',
      );

      // FR-SND-003: name, size and content type all three.
      expect(
        check.fileFound,
        isTrue,
        reason:
            'the record lists ${check.fileCount} file(s) and none of them is the document that was '
            'uploaded',
      );
      expect(
        check.sizeMatches,
        isTrue,
        reason: 'the stored attachment is not the size uploaded',
      );
      expect(
        check.contentTypeMatches,
        isTrue,
        reason: 'the stored attachment declares another content type than the one uploaded',
      );

      // The send's own order: a create, then an attachment to the created record, then the reads
      // (`ninox-send/create-attach-read-back`, scenario *the three steps happen in this order*).
      // The positions are asked for rather than the whole log asserted equal, so that a run in
      // which a transient failure cost one extra attempt still shows the order it kept.
      final List<String> calls = run.port.calls;
      expect(
        calls.isEmpty ? null : calls.first,
        'createRecord',
        reason: 'the send did not start with a create: $calls',
      );
      expect(
        calls.indexOf('uploadFile'),
        greaterThan(0),
        reason:
            'the send did not attach the document after creating the record: $calls',
      );
      expect(
        calls.indexOf('readRecord'),
        greaterThan(calls.indexOf('uploadFile')),
        reason: 'the send did not read the record back after attaching: $calls',
      );

      expect(
        run.findings,
        isEmpty,
        reason:
            'the send completed and left findings, all recorded in ${run.resultsPath}: '
            '${run.findings.join(' | ')}',
      );
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
/// The same two checks as the read-only check in this directory, and the same order: the token,
/// because a live call needs one, and an explicit opt-in, because the presence of a token must not
/// be enough for a test that writes. A machine with a token but no opt-in is refused with the opt-in
/// named; a machine with the opt-in but no token is refused with the token named.
String? _refusal({required String? token, required String? optIn}) {
  if (optIn != _optInValue) {
    return 'live tests are opt-in: set $_optInVariable=$_optInValue, and put a token in '
        '$_tokenVariable, to run this send against a real workspace.';
  }
  if (token == null) {
    return '$_tokenVariable is absent: set it, and $_optInVariable=$_optInValue, to run this live '
        'send.';
  }
  return null;
}

/// One execution of the approved run: what it resolved, what it sent, what it measured, what it has
/// to delete.
final class _Run {
  _Run._({
    required this.token,
    required this.adapter,
    required this.port,
    required this.adapterClient,
    required this.deleteClient,
    required this.ref,
    required this.startedAt,
  });

  /// Resolves the target **read-only**, builds the payload and records the ids that are already
  /// there.
  ///
  /// Every call here is a GET. If anything the literals name fails to resolve, or the schema cannot
  /// carry the payload, this throws and no test runs a write: the refusal is the point, not an
  /// inconvenience to work around.
  static Future<_Run> begin({required String token}) async {
    final WriteBudget budget = WriteBudget(
      maxRecords: _maxRecordsCreated,
      maxAttachmentBytes: _maxAttachmentBytes,
      // One attachment is the whole of this run's upload, so the total cap is the same number: a
      // second document could never be legitimately sent here.
      maxTotalBytes: _maxAttachmentBytes,
    );
    final http.Client adapterClient = http.Client();
    final _BudgetedPort port = _BudgetedPort(
      ClassicNinoxAdapter(
        endpoint: NinoxEndpoint.cloud,
        credentials: NinoxCredentials(token),
        client: adapterClient,
        timeout: const Duration(seconds: 180),
      ),
      budget,
    );
    final _Run run = _Run._(
      token: token,
      adapter: port.adapter,
      port: port,
      adapterClient: adapterClient,
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
    run.pipeline = SendPipeline(
      port,
      journal: run.journal,
      refreshSchema: run._refreshSchema,
    );
    return run;
  }

  final String token;
  final ClassicNinoxAdapter adapter;

  /// The adapter, with this run's caps and its call log in front of it.
  final _BudgetedPort port;

  /// The HTTP client the adapter reaches the network through: closed on the way out.
  final http.Client adapterClient;

  final http.Client deleteClient;
  final TableRef ref;
  final DateTime startedAt;

  /// What the pipeline reported, in order: the send's own account of its steps.
  final InMemorySendJournal journal = InMemorySendJournal();

  /// The pipeline under test, wired to the port **after** the target resolved, so that nothing the
  /// resolution read is in the send's call log.
  late final SendPipeline pipeline;

  /// Every id the table held **before** the first write. Nothing in this list is ever deleted.
  late Set<String> preexistingRecordIds;

  final List<String> deletedRecordIds = [];
  final List<Map<String, Object?>> failedDeletes = [];

  /// Ids whose delete answered 404: the record was already gone, which is not a failure.
  final List<String> alreadyGoneIds = [];

  /// How many delete passes ran. One is the normal number; the count is recorded as evidence,
  /// because two overlapping passes are what produced defect 2 of the 2026-10-08 run.
  int deletePasses = 0;

  /// The pass in flight, so that a second call waits instead of competing with it.
  Future<void>? _lastDeletePass;

  final List<Map<String, Object?>> steps = [];
  final List<String> findings = [];

  /// Every time the cap refused a call, with the arithmetic. A run that stayed inside the caps
  /// leaves this empty, and either way it is recorded rather than asserted.
  final List<String> capRefusals = [];

  /// Ids that were not there before the run and that this run did not create. Reported, never
  /// deleted: this run does not remove what it cannot account for.
  List<String> untrackedNewIds = [];

  Map<String, Object?> verification = const {};

  /// How many times the pipeline asked for the schema to be refreshed (the 500 row of the matrix).
  int refreshes = 0;

  String? resolvedTableName;
  int? listedFieldCount;
  int? skippedFormulaFieldCount;

  /// The payload, built from the resolved schema before the first write, and the request it went
  /// out in: the comparison after the send is against **this** map, never a rebuilt one.
  late SendPayload payload;
  SendRequest? request;

  SendOutcome? outcome;
  ReadBackCheck? readBackCheck;

  /// Why the run cannot continue, when it cannot.
  String? haltedReason;

  bool verified = false;
  bool finished = false;

  /// The record ids this run created: the port's, for every create that returned an identifier,
  /// plus anything the run adopted read-side because a create's response was lost.
  List<String> get createdRecordIds => port.createdRecordIds;

  /// The outcome of the send, when it was a `Sent`.
  Sent? get sent {
    final current = outcome;
    return current is Sent ? current : null;
  }

  /// The outcome in one line, for stdout and a failure's reason. No field value appears here.
  String get outcomeSummary {
    final current = outcome;
    if (current == null) return haltedReason ?? 'the send did not run';
    return _summaryOf(current);
  }

  String get resultsPath =>
      '${packageRoot().path}${Platform.pathSeparator}test'
      '${Platform.pathSeparator}live${Platform.pathSeparator}out'
      '${Platform.pathSeparator}$_resultsFileName';

  // ---------------------------------------------------------------------------------------------
  // Resolving the target and the schema, before the first write
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

    // The payload is built here, from the schema as it is now, and a schema that cannot carry it
    // refuses the run before the first write (`buildSendPayload` says what it saw).
    listedFieldCount = table.fields.length;
    skippedFormulaFieldCount =
        table.fields.length - writableFields(table.fields).length;
    payload = buildSendPayload(table.fields);
  }

  /// The matrix's *refresh the schema*: a GET, before the single retry of a 500.
  ///
  /// The payload is not rebuilt after it — the pipeline retries the request it has, exactly as the
  /// app does — so this records that the schema was read again and nothing more.
  Future<void> _refreshSchema() async {
    await port.listTables(_teamId, _databaseId);
    refreshes++;
    _addStep(
      'refresh the schema',
      status: 'ok',
      note:
          'the 500 row of the retry matrix: the tables listing was read again',
    );
  }

  // ---------------------------------------------------------------------------------------------
  // The run
  // ---------------------------------------------------------------------------------------------

  /// Sends one document through the pipeline and records everything it can be judged by.
  Future<void> sendOnce() async {
    final SendPayload payload = this.payload;
    final Uint8List bytes = syntheticPdf(pages: 1, targetBytes: _documentBytes);
    final SendRequest request = SendRequest(
      ref: ref,
      fieldsByName: payload.fieldsByName,
      docId: inventedDocId,
      filename: inventedFilename,
      bytes: bytes,
      contentType: inventedContentType,
    );
    this.request = request;

    // The resolution's GETs are not part of the send: what is recorded from here on is the send's
    // own calls, which is what makes the order of the three steps assertable.
    port.calls.clear();

    final Stopwatch watch = Stopwatch()..start();
    final SendOutcome outcome;
    try {
      outcome = await pipeline.send(request);
    } on WriteBudgetExceeded catch (cap) {
      // A cap refused a call before it was made. The port throws this and the pipeline does not
      // catch it — it is not a [NinoxFailure] and must not be treated as one.
      watch.stop();
      capRefusals.add(cap.message);
      haltedReason =
          'a cap refused a call of the send before it was made: ${cap.message}';
      _addStep(
        'the send',
        status: 'refused by the cap',
        elapsedMs: watch.elapsedMilliseconds,
        note: cap.message,
      );
      return;
    }
    watch.stop();
    this.outcome = outcome;
    _addStep(
      'the send',
      status: outcome.runtimeType.toString(),
      elapsedMs: watch.elapsedMilliseconds,
      note: _summaryOf(outcome),
    );

    _adopt(outcome);
    if (port.lostCreate) await _adoptLostCreate();
    _checkReadBack(outcome, bytes);
  }

  /// Takes the record the outcome reports into this run's cleanup, so that nothing is left behind.
  void _adopt(SendOutcome outcome) {
    switch (outcome) {
      case Sent(recordId: final RecordId id) ||
          Incomplete(recordId: final RecordId id):
        _adoptId(id);
      case Uncertain(candidates: final List<NinoxRecord> candidates):
        // The candidates are listed and never deleted: the run cannot tell which of them it
        // created, so it reports them. If a create's response was lost, `_adoptLostCreate` finds
        // what appeared in the table and adopts that instead, and nothing pre-existing is deleted.
        for (final NinoxRecord candidate in candidates) {
          _addStep(
            'the send: a candidate',
            recordId: candidate.id,
            status: 'uncertain',
            note: 'listed, not deleted: duplicate handling is T2.3',
          );
        }
      case Queued():
        break;
      case Failed():
        break;
    }
  }

  /// Records one record id as this run's own, unless the table had it before the run.
  void _adoptId(RecordId id) {
    if (preexistingRecordIds.contains(id.value)) {
      findings.add(
        'the send reports record ${id.value}, which was in the table before the run: nothing was '
        'deleted for it, and the run did not intend to write to it. Check it by hand',
      );
      return;
    }
    if (createdRecordIds.contains(id.value)) return;
    createdRecordIds.add(id.value);
    _addStep(
      'the record the send reported',
      recordId: id,
      status: 'adopted',
      note:
          'recorded for cleanup: this run created it, and its own create did not return the '
          'identifier',
    );
  }

  /// A create whose response was lost: find it read-side, adopt it, and never retry it.
  ///
  /// ADR-013's discipline applied to this run's own cleanup, exactly as the T1.9 run did it: the
  /// ids that were not in the table before this run are the only candidates, and they are adopted so
  /// that `deleteCreated` removes them. Leaving a record the run created inside the product owner's
  /// table would be the exact outcome this file is written to avoid.
  Future<void> _adoptLostCreate() async {
    findings.add(
      'a create was lost (the response never arrived): the record may exist, so no create was '
      'retried and the table was listed to find it',
    );
    try {
      final Set<String> now = await _allRecordIds(adapter, ref);
      final List<String> appeared = sortedIds(
        now
            .difference(preexistingRecordIds)
            .difference(createdRecordIds.toSet()),
      );
      if (appeared.isEmpty) {
        _addStep(
          'a lost create',
          status: 'uncertain',
          note: 'no id appeared that was not there before, so the POST did not land',
        );
        return;
      }
      for (final String id in appeared) {
        createdRecordIds.add(id);
        // The record exists, so it counts against the record cap: a lost create is still a create.
        port.budget.afterCreate();
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

  /// Compares the read-back with what was sent, and records why a send that is not `Sent` is not.
  void _checkReadBack(SendOutcome outcome, Uint8List bytes) {
    final SendRequest sentRequest = request!;
    switch (outcome) {
      case Sent(
        recordId: final RecordId id,
        readBack: final NinoxRecord readBack,
        files: final List<NinoxFile> files,
      ):
        final ReadBackCheck check = ReadBackCheck.of(
          sent: sentRequest.fieldsByName,
          readBack: readBack,
          files: files,
          filename: sentRequest.filename,
          size: bytes.length,
          contentType: sentRequest.contentType,
          dateField: payload.dateField,
        );
        readBackCheck = check;
        findings.addAll(check.differences);
        _addStep(
          'the read-back',
          recordId: id,
          status: check.allMatch ? 'ok' : 'differs',
          note:
              '${check.checkedFieldCount} value(s) and ${check.fileCount} file(s) compared with '
              'what was sent',
        );
      case Incomplete(reason: final String reason):
        findings.add(
          'the send created a record and did not confirm its document: $reason. The record exists '
          'and is incomplete, never done (FR-SND-003)',
        );
      case Uncertain():
        findings.add(
          'the create ended uncertain: the run does not decide between records, and duplicate '
          'handling is T2.3. Nothing was retried',
        );
      case Queued():
        findings.add(
          'nothing left the device: the send is queued and not sent, so this run measured no send',
        );
      case Failed(
        kind: final SendFailureKind kind,
        failure: final NinoxFailure failure,
      ):
        findings.add(
          'the send failed with ${kind.name}: $failure. Nothing is retried after a terminal '
          'failure',
        );
    }
  }

  // ---------------------------------------------------------------------------------------------
  // Cleanup, verification, results
  // ---------------------------------------------------------------------------------------------

  /// Deletes every record this run created, and only those.
  ///
  /// Idempotent **and serialised**, for the reason the T1.9 run paid for: the send body's `finally`
  /// and `tearDownAll` are two independent call sites, and two overlapping passes produced
  /// seventeen DELETEs for ten ids. A call made while a pass is in flight waits for that pass and
  /// then runs a pass of its own, which finds nothing left to delete.
  Future<void> deleteCreated() {
    final pass = _deleteCreatedPass(_lastDeletePass);
    _lastDeletePass = pass;
    return pass;
  }

  Future<void> _deleteCreatedPass(Future<void>? previous) async {
    await previous;
    deletePasses++;
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
      pathSegments: <String>[
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
    final watch = Stopwatch()..start();
    final http.Response response;
    try {
      response = await deleteClient
          .delete(
            uri,
            headers: <String, String>{'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 60));
    } on Exception catch (error) {
      watch.stop();
      failedDeletes.add({
        'id': id,
        'reason': 'the delete did not complete: ${_redact(error.toString())}',
        'elapsedMs': watch.elapsedMilliseconds,
      });
      return;
    }
    watch.stop();
    switch (deleteOutcome(response.statusCode)) {
      case DeleteOutcome.deleted:
        deletedRecordIds.add(id);
        _addStep(
          'delete',
          recordId: RecordId(id),
          elapsedMs: watch.elapsedMilliseconds,
          status: '${response.statusCode}',
        );
      case DeleteOutcome.alreadyGone:
        // The record is not there, which is what deleting it was for. It counts as deleted, and
        // the evidence that it had already gone is kept.
        deletedRecordIds.add(id);
        alreadyGoneIds.add(id);
        _addStep(
          'delete',
          recordId: RecordId(id),
          elapsedMs: watch.elapsedMilliseconds,
          status: '404',
          note:
              'already gone: this run created the id and it is no longer in the table, so the '
              'delete had already happened',
        );
      case DeleteOutcome.failed:
        failedDeletes.add({
          'id': id,
          'status': response.statusCode,
          'reason': _redact(_messageOf(response.body)),
          'elapsedMs': watch.elapsedMilliseconds,
        });
    }
  }

  /// Lists the table again, re-listing while the answer is not settled, and records what it says.
  ///
  /// It asserts nothing: it records, and the test asserts on what it recorded, so that the results
  /// file is written even when the verification finds something. Nothing is ever deleted here.
  Future<void> verify() async {
    if (verified) return;
    final snapshot = await listUntilSettled(
      list: () => _allRecordIds(adapter, ref),
      preexisting: preexistingRecordIds,
      created: createdRecordIds.toSet(),
    );
    untrackedNewIds = sortedIds(snapshot.untracked);
    verification = <String, Object?>{
      'at': DateTime.now().toUtc().toIso8601String(),
      'preexistingCount': preexistingRecordIds.length,
      ...snapshot.toJson(),
    };
    verified = true;
    if (snapshot.missing.isNotEmpty) {
      findings.add(
        'records that were in the table before the run are gone: '
        '${sortedIds(snapshot.missing).join(', ')}',
      );
    }
    if (snapshot.left.isNotEmpty) {
      findings.add(
        'records this run created were not deleted: '
        '${sortedIds(snapshot.left).join(', ')} (still listed after ${snapshot.attempts} '
        'listings spaced by ${snapshot.waited.inSeconds}s)',
      );
    }
    if (snapshot.untracked.isNotEmpty) {
      findings.add(
        'the table holds ids that were not there before the run and that this run did not create: '
        '${sortedIds(snapshot.untracked).join(', ')} (listed, not deleted)',
      );
    }
  }

  /// Everything the run has to say, for the results file.
  ///
  /// Counts, statuses and timings, plus **field names** — never a field value, and never a stored
  /// value: the file is written on the product owner's machine and is not a record of a record
  /// (change design §2.4). The record identifiers are the exception, because cleanup and the
  /// product owner's own check need them, and the table is disposable.
  Map<String, Object?> toJson() => <String, Object?>{
    't11': <String, Object?>{
      'written':
          'written and not run by the lane: these numbers were produced by the machine that ran '
          'it',
      'startedAt': startedAt.toIso8601String(),
      'finishedAt': DateTime.now().toUtc().toIso8601String(),
      'host': NinoxEndpoint.cloud.baseUri.toString(),
      'team': _teamId,
      'database': _databaseId,
      'tableId': _tableId,
      'tableName': resolvedTableName,
    },
    'schema': <String, Object?>{
      'listedFieldCount': listedFieldCount,
      'formulaFieldsSkipped': skippedFormulaFieldCount,
    },
    'payload': <String, Object?>{
      'fieldCount': payload.fieldCount,
      'keys': payload.keys,
      'dateField': payload.dateField,
      'amountField': payload.amountField,
    },
    'document': <String, Object?>{
      'filename': inventedFilename,
      'bytes': _documentBytes,
      'contentType': inventedContentType,
    },
    'caps': port.budget.toJson(),
    'capRefusals': capRefusals,
    'outcome': outcomeSummary,
    'readBack': readBackCheck?.toJson(),
    'sendCalls': port.calls,
    'journalSteps': <String>[
      for (final SendStep step in journal.stepsOf(inventedDocId)) step.name,
    ],
    'schemaRefreshes': refreshes,
    'halted': haltedReason,
    'preexistingRecordIds': sortedIds(preexistingRecordIds),
    'createdRecordIds': createdRecordIds,
    'deletedRecordIds': deletedRecordIds,
    'alreadyGoneIds': sortedIds(alreadyGoneIds),
    'deletePasses': deletePasses,
    'failedDeletes': failedDeletes,
    'verification': verification,
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
    adapterClient.close();

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
      'T1.11 — table $resolvedTableName ($_tableId) of $_databaseId, team $_teamId, '
      '${NinoxEndpoint.cloud.baseUri}',
    );
    stdout.writeln(
      'started ${startedAt.toIso8601String()} · payload ${payload.keys.join(', ')} · '
      'document $inventedFilename ($_documentBytes bytes, $inventedContentType)',
    );
    stdout.writeln(
      '${'step'.padRight(42)}${'record'.padRight(8)}${'ms'.padLeft(8)}  status',
    );
    for (final step in steps) {
      stdout.writeln(
        '${_text(step['step']).padRight(42)}'
        '${_text(step['recordId']).padRight(8)}'
        '${_text(step['elapsedMs']).padLeft(8)}  '
        '${_text(step['status'])}'
        '${step['note'] == null ? '' : ' — ${_text(step['note'])}'}',
      );
    }
    stdout.writeln('');
    stdout.writeln('caps: ${port.budget}');
    stdout.writeln(
      'before the run the table held ${preexistingRecordIds.length} records: '
      '${sortedIds(preexistingRecordIds).join(', ')}',
    );
    stdout.writeln(
      'this run created ${createdRecordIds.length}, deleted ${deletedRecordIds.length} '
      '(${alreadyGoneIds.length} of them were already gone: their delete answered 404) in '
      '$deletePasses pass(es): ${createdRecordIds.join(', ')}',
    );
    stdout.writeln('the send: $outcomeSummary');
    stdout.writeln('the send\'s calls, in order: ${port.calls.join(' → ')}');
    stdout.writeln(
      'the journal: ${journal.stepsOf(inventedDocId).map((step) => step.name).join(' → ')}',
    );
    stdout.writeln('verification: ${jsonEncode(verification)}');
    stdout.writeln(
      findings.isEmpty
          ? 'findings: none'
          : 'findings:\n  ${findings.join('\n  ')}',
    );
    stdout.writeln('results written to $resultsPath');
  }

  String describeTarget() {
    final skipped = skippedFormulaFieldCount ?? 0;
    return 'T1.11: sending to $resolvedTableName ($_tableId) of $_databaseId, team $_teamId · '
        'schema ${listedFieldCount ?? '?'} fields, $skipped formula field(s) skipped · '
        'payload ${payload.keys.join(', ')} (${payload.fieldCount} field(s), date '
        '${payload.dateField}, amount ${payload.amountField}) · document $inventedFilename '
        '($_documentBytes bytes) · caps: ${port.budget}';
  }

  void _addStep(
    String step, {
    RecordId? recordId,
    int? elapsedMs,
    String status = 'ok',
    String? note,
  }) {
    final entry = <String, Object?>{'step': step, 'status': status};
    if (recordId != null) entry['recordId'] = recordId.value;
    if (elapsedMs != null) entry['elapsedMs'] = elapsedMs;
    if (note != null) entry['note'] = _redact(note);
    steps.add(entry);
  }
}

/// One line about an outcome, with no field value in it.
String _summaryOf(SendOutcome outcome) => switch (outcome) {
  Sent(
    recordId: final RecordId id,
    readBack: final NinoxRecord readBack,
    files: final List<NinoxFile> files,
  ) =>
    'record ${id.value}, ${readBack.fields.length} field(s) and ${files.length} file(s) read back',
  Incomplete(recordId: final RecordId id, reason: final String reason) =>
    'record ${id.value}: $reason',
  Uncertain(candidates: final List<NinoxRecord> candidates) =>
    '${candidates.length} candidate(s), not decided',
  Queued() => 'nothing left the device',
  Failed(
    kind: final SendFailureKind kind,
    failure: final NinoxFailure failure,
  ) =>
    '${kind.name}: $failure',
};

/// The port with this run's caps and its call log in front of it.
///
/// It is **not** a second implementation of the port and not a change to the adapter: it is this
/// run's guard. Two things make it worth the delegation:
///
/// * the caps are enforced **before each call** (change design §1), which is only possible between
///   the pipeline and the adapter — a cap checked around the whole send would report afterwards that
///   it was passed, which is exactly what a cap must never do. So [WriteBudget.beforeCreate] and
///   [WriteBudget.beforeUpload] are consulted here, closest to the call they guard, and a refusal
///   throws [WriteBudgetExceeded] **before** the request is made. That exception is not a
///   [NinoxFailure], so it passes through the pipeline rather than being classified as one, and the
///   run stops where it happened;
/// * the calls are logged, and every identifier a create returned is recorded — which is what the
///   cleanup deletes, and what makes the order of the three steps assertable.
///
/// A [CreateOutcomeUncertain] is recorded and re-thrown unchanged: the pipeline's reconciliation is
/// untouched, and the run only learns that a record may exist so that it can find it afterwards.
final class _BudgetedPort implements NinoxPort {
  _BudgetedPort(this.adapter, this.budget);

  /// The real adapter this run talks through.
  final ClassicNinoxAdapter adapter;

  /// The caps of this run.
  final WriteBudget budget;

  /// The port's calls since the last [calls] were cleared: the names, in order.
  final List<String> calls = [];

  /// Every record identifier a create returned, and every id the run adopted read-side.
  final List<String> createdRecordIds = [];

  /// Whether a create answered that its outcome is unknown (ADR-013).
  bool lostCreate = false;

  // -------------------------------------------------------------------------------------------
  // The two writing calls: each one guarded by the cap that bounds it
  // -------------------------------------------------------------------------------------------

  @override
  Future<RecordId> createRecord(
    TableRef ref,
    Map<String, Object?> fieldsByName,
  ) async {
    budget.beforeCreate();
    calls.add('createRecord');
    final RecordId created;
    try {
      created = await adapter.createRecord(ref, fieldsByName);
    } on CreateOutcomeUncertain {
      // The POST may have landed. Never retried here: the pipeline reconciles, and the run lists
      // the table afterwards so that the record is deleted with the rest.
      lostCreate = true;
      rethrow;
    }
    createdRecordIds.add(created.value);
    budget.afterCreate();
    return created;
  }

  @override
  Future<void> uploadFile(
    TableRef ref,
    RecordId recordId, {
    required String filename,
    required Uint8List bytes,
    required String contentType,
  }) async {
    budget.beforeUpload(bytes.length);
    calls.add('uploadFile');
    await adapter.uploadFile(
      ref,
      recordId,
      filename: filename,
      bytes: bytes,
      contentType: contentType,
    );
    budget.afterUpload(bytes.length);
  }

  // -------------------------------------------------------------------------------------------
  // The reads: logged, and nothing else
  // -------------------------------------------------------------------------------------------

  @override
  Future<List<NinoxTeam>> listTeams() {
    calls.add('listTeams');
    return adapter.listTeams();
  }

  @override
  Future<List<NinoxDatabase>> listDatabases(String teamId) {
    calls.add('listDatabases');
    return adapter.listDatabases(teamId);
  }

  @override
  Future<List<NinoxTable>> listTables(String teamId, String databaseId) {
    calls.add('listTables');
    return adapter.listTables(teamId, databaseId);
  }

  @override
  Future<NinoxRecord> readRecord(TableRef ref, RecordId recordId) {
    calls.add('readRecord');
    return adapter.readRecord(ref, recordId);
  }

  @override
  Future<void> updateRecord(
    TableRef ref,
    RecordId recordId,
    Map<String, Object?> fieldsByName,
  ) {
    // The pipeline never updates the record of a send — a correction is not part of a send — so a
    // call here would be a defect worth seeing rather than a step worth counting.
    calls.add('updateRecord');
    return adapter.updateRecord(ref, recordId, fieldsByName);
  }

  @override
  Future<List<NinoxFile>> listFiles(TableRef ref, RecordId recordId) {
    calls.add('listFiles');
    return adapter.listFiles(ref, recordId);
  }

  @override
  Future<List<NinoxRecord>> listRecords(
    TableRef ref, {
    int? page,
    int? perPage,
    String? order,
    bool? desc,
  }) {
    calls.add('listRecords');
    return adapter.listRecords(
      ref,
      page: page,
      perPage: perPage,
      order: order,
      desc: desc,
    );
  }
}

/// Refuses the run when a literal in this file does not resolve to what it names.
void _refuseUnless(bool condition, String message) {
  if (!condition) {
    throw StateError(
      'T1.11 refuses to run: $message. Nothing was created, attached or deleted: this check is made '
      'with GET requests only.',
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
