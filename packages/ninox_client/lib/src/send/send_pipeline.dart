/// The send: create, attach, read back — and the matrix that says what to do when a step fails.
///
/// This is T1.11. It is pure Dart over [NinoxPort]: no Flutter, no HTTP, no clock of its own, and
/// no policy of its own about what a value means. Its whole job is **sequencing**, which is where
/// the expensive failures live:
///
/// * a create whose response was lost is **never** retried into a duplicate — it is reconciled
///   read-side (`ninox-send/reconciliation-of-an-uncertain-create`, FR-SND-005, ADR-013);
/// * an HTTP 500 is **not** an outage: the schema is refreshed, the request is retried **once**, and
///   what is reported is a mapping error (`ninox-send/the-retry-matrix`, FR-SND-004);
/// * a record created without its document is **incomplete, not done**, and its attachment is
///   retried alone (`ninox-send/attachment-upload`, `ninox-send/updates-are-merges`, FR-SND-008);
/// * and what the user is shown is the **read-back**, never what was sent
///   (`ninox-send/create-attach-read-back`, FR-SND-001).
///
/// **The reconciliation's one input the pipeline has to learn.** A candidate record is one whose
/// `createdAt` is inside the window **and** whose `createdBy` is the token's own user (design §4).
/// The port offers no "who am I" call, so the pipeline learns the user from the audit key of a
/// record it has created — the read-back of a completed send. Until it has read one back, it cannot
/// apply that filter, and design §4 is explicit that the check is then **not skipped**: the result
/// is [Uncertain], with what it read for the user to look at. It is only ever learned from a record
/// this pipeline created, never from a candidate the user chose.
library;

import '../errors.dart';
import '../model.dart';
import '../port.dart';
import 'send_journal.dart';
import 'send_outcome.dart';
import 'send_request.dart';

/// The clock the pipeline reads, injected so that the reconciliation window is testable.
///
/// It is read once per reconciliation, to compare against the candidates' `createdAt`; nothing else
/// in the pipeline depends on the time (there is no timeout of its own — the port's HTTP client
/// has one).
typedef Clock = DateTime Function();

/// The sleeper the backoff uses, injected so that a test does not wait.
///
/// The pipeline sleeps between the attempts of a step that **cannot duplicate a record** and for
/// nothing else: no wait ever precedes a create.
typedef Sleeper = Future<void> Function(Duration);

/// The instant, in UTC. The default [Clock].
DateTime _utcNow() => DateTime.now().toUtc();

/// The real sleeper. The default [Sleeper].
Future<void> _realSleep(Duration duration) => Future<void>.delayed(duration);

/// Why a send stopped without its document confirmed.
const String _attachmentFailed =
    'the document could not be attached within the bounded attempts';
const String _readBackFailed =
    'the record could not be read back within the bounded attempts';
const String _filesUnreadable =
    "the record's files could not be read within the bounded attempts";
const String _attachmentNotStored =
    'the read-back does not carry the document that was uploaded';

/// The send pipeline (T1.11): the sequence, the retry matrix and the reconciliation.
///
/// It is built over a [NinoxPort] and three injected collaborators — a [SendJournal], a [Clock] and
/// a [Sleeper] — plus an optional `refreshSchema` (the *refresh the schema* step of the 500 row, a
/// callback because reading a schema is the wizard's, T1.10) and the two bounds of the design's
/// matrix. It touches no environment variable and holds no credential: the port carries the token
/// in one header, and this class never sees it.
///
/// **What it returns, and what it never does.** Every method returns a [SendOutcome] and classifies
/// every [NinoxFailure] the port can throw, including the ones its caller cannot: a lost create,
/// a 500 that is a mapping error, a 401 that is not worth sleeping for. It never retries a create by
/// itself, never decides a value, never writes a field the caller did not map, and never reports a
/// send as [Sent] without a read-back that carries the document.
///
/// **Failures of the injected collaborators propagate.** A [SendJournal] that throws, a [Clock] or
/// a `refreshSchema` that throws is the caller's own code and is not turned into an outcome: the
/// pipeline classifies the port, not itself.
final class SendPipeline {
  /// Builds a pipeline over one port.
  ///
  /// [reconcileWindow] bounds how old a record may be to be a candidate of an uncertain create
  /// (design §4), and [attachmentAttempts] is the **total** number of attempts — not the number of
  /// retries — of a step that cannot duplicate a record, so four attempts sleep 1 s, 2 s and 4 s.
  /// Both are validated here rather than trusted: a bound of zero attempts would silently skip the
  /// step it is meant to bound.
  factory SendPipeline(
    NinoxPort port, {
    SendJournal journal = const NoopSendJournal(),
    Clock clock = _utcNow,
    Sleeper sleep = _realSleep,
    Future<void> Function()? refreshSchema,
    Duration reconcileWindow = const Duration(minutes: 2),
    int attachmentAttempts = 4,
  }) => SendPipeline._(
    port,
    journal,
    clock,
    sleep,
    refreshSchema,
    reconcileWindow,
    attachmentAttempts,
  );

  /// The one constructor: the public factory above decides the defaults, this one validates and
  /// holds them.
  SendPipeline._(
    this._port,
    this._journal,
    this._clock,
    this._sleep,
    this._refreshSchema,
    this._reconcileWindow,
    this._attachmentAttempts,
  ) {
    if (_attachmentAttempts < 1) {
      throw ArgumentError.value(
        _attachmentAttempts,
        'attachmentAttempts',
        'at least one attempt is needed',
      );
    }
    if (_reconcileWindow.isNegative) {
      throw ArgumentError.value(
        _reconcileWindow,
        'reconcileWindow',
        'the window cannot be negative',
      );
    }
  }

  final NinoxPort _port;
  final SendJournal _journal;
  final Clock _clock;
  final Sleeper _sleep;
  final Future<void> Function()? _refreshSchema;
  final Duration _reconcileWindow;
  final int _attachmentAttempts;

  /// The token's own user, learned from the audit key of a record this pipeline created, and never
  /// guessed. `null` until then, which makes a reconciliation ask rather than assume.
  String? _tokenUser;

  /// Sends one document: create, attach, read back (FR-SND-001..003).
  ///
  /// The three steps happen in this order and no other, and the outcome is classified by the
  /// matrix: [Queued] when nothing left the device, [Failed] when the user has to act, [Uncertain]
  /// when the app will not guess, [Incomplete] when the record exists without the document, and
  /// [Sent] — with the read-back, never with what was sent — when it is done.
  ///
  /// A create that is retried is retried **only** after a reconciliation found nothing
  /// (`ninox-send/the-retry-matrix` scenario *a timed-out create is not retried*, FR-SND-005): the
  /// pipeline never re-POSTs an uncertain create directly.
  Future<SendOutcome> send(SendRequest r) async {
    try {
      final RecordId created = await _create(r, reconcileOnUncertain: true);
      return await _attachAndReadBack(r, created, fromOwnCreate: true);
    } on _Ended catch (ended) {
      return ended.outcome;
    }
  }

  /// Retries the attachment alone, against a record that already exists (FR-SND-008, design §3).
  ///
  /// This is the whole of the matrix's *record created, attachment failed* row and of
  /// `updates-are-merges` scenario *retrying an attachment changes nothing but the attachment*: the
  /// record is **not** re-created, no mapped value is touched, and nothing but the file endpoints
  /// and the read-back is called. It is what an [Incomplete] outcome is resumed with.
  Future<SendOutcome> resume(SendRequest r, RecordId created) async {
    try {
      await _journal.record(r.docId, SendStep.created, recordId: created);
      return await _attachAndReadBack(r, created, fromOwnCreate: false);
    } on _Ended catch (ended) {
      return ended.outcome;
    }
  }

  /// Continues with the record the user chose among an [Uncertain] outcome's candidates.
  ///
  /// The app does not decide (`ninox-send/reconciliation-of-an-uncertain-create` scenario
  /// *ambiguity is surfaced rather than guessed*): it asks, and the chosen record continues the
  /// flow at the attachment step. No create and no listing is issued, and the choice is **not**
  /// taken as evidence of who the token's user is.
  Future<SendOutcome> adopt(SendRequest r, RecordId chosen) async {
    try {
      await _journal.record(r.docId, SendStep.created, recordId: chosen);
      return await _attachAndReadBack(r, chosen, fromOwnCreate: false);
    } on _Ended catch (ended) {
      return ended.outcome;
    }
  }

  /// Creates the record because the user said none of the candidates is it.
  ///
  /// This is the user's answer to [Uncertain], and it is the **only** path on which the pipeline
  /// creates a record without reconciling first — the decision is the user's, not the app's. A
  /// create that is itself uncertain ends in [Uncertain] with no candidates rather than in a second
  /// reconciliation: the app has already asked, and asking again in a loop is not asking.
  Future<SendOutcome> createAnyway(SendRequest r) async {
    try {
      final RecordId created = await _create(r, reconcileOnUncertain: false);
      return await _attachAndReadBack(r, created, fromOwnCreate: true);
    } on _Ended catch (ended) {
      return ended.outcome;
    }
  }

  /// The create step of the matrix (design §3).
  ///
  /// [reconcileOnUncertain] is `false` on the two paths where the user has already answered —
  /// [createAnyway], and the create that follows a reconciliation which found nothing. On every
  /// other path an uncertain create enters the reconciliation.
  Future<RecordId> _create(
    SendRequest r, {
    required bool reconcileOnUncertain,
  }) async {
    await _journal.record(r.docId, SendStep.sending);
    var refreshed = false;
    while (true) {
      try {
        final RecordId created = await _port.createRecord(
          r.ref,
          r.fieldsByName,
        );
        await _journal.record(r.docId, SendStep.created, recordId: created);
        return created;
      } on CreateOutcomeUncertain {
        // The POST may have landed. Never a blind retry: reconcile, or ask.
        if (reconcileOnUncertain) {
          return _reconcileThenCreate(r);
        }
        await _uncertainStep(r, const <NinoxRecord>[]);
      } on UnexpectedResponse {
        // The adapter cannot say what happened, and a 2xx without an identifier is this type: the
        // record may exist. The safe side costs one reconciliation read (design §8 of the change
        // that introduced the port), the other side costs a duplicate.
        if (reconcileOnUncertain) {
          return _reconcileThenCreate(r);
        }
        await _uncertainStep(r, const <NinoxRecord>[]);
      } on Unauthorized catch (failure) {
        await _failedStep(r, SendFailureKind.auth, failure);
      } on NotFound catch (failure) {
        await _failedStep(r, SendFailureKind.destinationGone, failure);
      } on RateLimited catch (failure) {
        // A rate-limited create is a server failure and is not retried (design §3): a create is
        // never a step to sleep on, and only a lost response sends the flow to the reconciliation.
        await _failedStep(r, SendFailureKind.server, failure);
      } on ServerError catch (failure) {
        // A 500 here is usually a bad, formula or read-only field name. Refresh the schema, retry
        // exactly once, then call it what it is: a mapping error, never an outage.
        if (refreshed) {
          await _failedStep(r, SendFailureKind.mapping, failure);
        } else {
          refreshed = true;
          await _refresh();
        }
      } on TransportFailure catch (_) {
        // Nothing left the device. The send is not lost and not failed: it is queued.
        await _journal.record(r.docId, SendStep.queued);
        throw const _Ended(Queued());
      }
    }
  }

  /// The reconciliation of an uncertain create, and the one create it may be followed by
  /// (`ninox-send/reconciliation-of-an-uncertain-create`).
  ///
  /// Zero candidates means no record of ours is there, so one create follows — never a loop: a
  /// second uncertain create ends in [Uncertain] with no candidates.
  Future<RecordId> _reconcileThenCreate(SendRequest r) async {
    await _journal.record(r.docId, SendStep.uncertain);
    final RecordId? adopted = await _reconcile(r);
    if (adopted != null) {
      await _journal.record(r.docId, SendStep.created, recordId: adopted);
      return adopted;
    }
    return _create(r, reconcileOnUncertain: false);
  }

  /// Reads the destination's recent records and weighs them (design §4). Returns the record to
  /// adopt, or `null` when nothing matched and creating one is therefore right.
  ///
  /// The listing is sorted and filtered **locally**: `?order=` and `?desc=` are accepted by the API
  /// and unverified, so nothing here trusts them (GAP-023, `ninox-send/reconciliation-of-an-uncertain-create`).
  Future<RecordId?> _reconcile(SendRequest r) async {
    final DateTime attemptedAt = _clock();
    final List<NinoxRecord> fetched = await _listRecent(r);
    final ({RecordId? adopt, List<NinoxRecord>? ask}) weighed = _weigh(
      r,
      fetched,
      attemptedAt,
    );
    final RecordId? adopted = weighed.adopt;
    if (adopted != null) return adopted;
    final List<NinoxRecord>? ask = weighed.ask;
    if (ask != null) {
      await _uncertainStep(r, ask);
    }
    return null;
  }

  /// The decision half of the reconciliation: no port call, no journal write, no state.
  ///
  /// A candidate has `createdAt` inside the window of the attempt, `createdBy` equal to the token's
  /// user, and every mapped field equal to what was sent. Where a check cannot be applied — the
  /// token's user is not known, a record carries no readable `createdAt` — the answer is to ask,
  /// never to skip the check; and where fewer than two fields were mapped there is not enough
  /// evidence to adopt, so the narrowed candidates are handed to the user instead.
  ({RecordId? adopt, List<NinoxRecord>? ask}) _weigh(
    SendRequest r,
    List<NinoxRecord> fetched,
    DateTime attemptedAt,
  ) {
    if (fetched.isEmpty) return (adopt: null, ask: null);
    final String? user = _tokenUser;
    if (user == null) return (adopt: null, ask: fetched);
    final DateTime oldest = attemptedAt.subtract(_reconcileWindow);
    final List<NinoxRecord> inWindow = <NinoxRecord>[];
    for (final NinoxRecord record in fetched) {
      final String? createdAt = record.createdAt;
      final DateTime? created = createdAt == null
          ? null
          : DateTime.tryParse(createdAt);
      if (created == null) return (adopt: null, ask: fetched);
      if (record.createdBy != user) continue;
      if (created.isBefore(oldest) || created.isAfter(attemptedAt)) continue;
      inWindow.add(record);
    }
    if (inWindow.isEmpty) return (adopt: null, ask: null);
    if (r.fieldsByName.length < 2) return (adopt: null, ask: inWindow);
    final List<NinoxRecord> matching = <NinoxRecord>[
      for (final NinoxRecord record in inWindow)
        if (_carriesWhatWasSent(r, record)) record,
    ];
    if (matching.length == 1) return (adopt: matching.single.id, ask: null);
    if (matching.isEmpty) return (adopt: null, ask: null);
    return (adopt: null, ask: matching);
  }

  /// Whether every value that was sent is what the record stores — compared on the mapped fields
  /// only, because a field the caller did not map is none of this pipeline's business.
  ///
  /// The comparison is by value as the port read it: `1999` and `1999.0` are the same amount, and a
  /// list or a nested object — which a JSON payload may carry — is compared by structure, because
  /// `==` on those is identity and a value that never matched would send the pipeline down the path
  /// that writes a duplicate.
  bool _carriesWhatWasSent(SendRequest r, NinoxRecord record) {
    for (final MapEntry<String, Object?> sent in r.fieldsByName.entries) {
      if (!record.fields.containsKey(sent.key)) return false;
      if (!_sameValue(record.fields[sent.key], sent.value)) return false;
    }
    return true;
  }

  /// Two JSON values equal by structure, so that what was sent and what was read back can be
  /// compared without the payload's shape deciding whether a record is the one being looked for.
  bool _sameValue(Object? stored, Object? sent) {
    if (stored is Map<Object?, Object?> && sent is Map<Object?, Object?>) {
      if (stored.length != sent.length) return false;
      for (final MapEntry<Object?, Object?> entry in stored.entries) {
        if (!sent.containsKey(entry.key)) return false;
        if (!_sameValue(entry.value, sent[entry.key])) return false;
      }
      return true;
    }
    if (stored is List<Object?> && sent is List<Object?>) {
      if (stored.length != sent.length) return false;
      for (var index = 0; index < stored.length; index++) {
        if (!_sameValue(stored[index], sent[index])) return false;
      }
      return true;
    }
    return stored == sent;
  }

  /// The reconciliation's read: the destination's most recently created records, bounded.
  Future<List<NinoxRecord>> _listRecent(SendRequest r) => _retrying(
    r,
    () => _port.listRecords(r.ref, perPage: 50),
    onExhausted: () => _uncertainStep(r, const <NinoxRecord>[]),
  );

  /// The attach step and the read-back that follows it (FR-SND-003, design §5).
  ///
  /// The attachment is one multipart call; the read-back is a record read and a files read, and the
  /// attachment must match the upload on **name, size and content type** — a record whose files do
  /// not carry the document is [Incomplete], never [Sent].
  ///
  /// [fromOwnCreate] is true only where **this pipeline** created the record in this call. It is
  /// what the `createdBy` audit key of the read-back means: a record this pipeline created was
  /// created by the token's user, and that is the only way the reconciliation can learn which audit
  /// key is its own. On [resume] and [adopt] the record may be one the user chose, so nothing is
  /// learned from it.
  Future<SendOutcome> _attachAndReadBack(
    SendRequest r,
    RecordId id, {
    required bool fromOwnCreate,
  }) async {
    await _journal.record(r.docId, SendStep.attaching, recordId: id);
    await _retrying(
      r,
      () => _port.uploadFile(
        r.ref,
        id,
        filename: r.filename,
        bytes: r.bytes,
        contentType: r.contentType,
      ),
      onExhausted: () => _incompleteStep(r, id, _attachmentFailed),
    );
    await _journal.record(r.docId, SendStep.attached, recordId: id);
    final NinoxRecord readBack = await _retrying(
      r,
      () => _port.readRecord(r.ref, id),
      onExhausted: () => _incompleteStep(r, id, _readBackFailed),
    );
    if (fromOwnCreate) {
      _tokenUser = readBack.createdBy ?? _tokenUser;
    }
    final List<NinoxFile> files = await _retrying(
      r,
      () => _port.listFiles(r.ref, id),
      onExhausted: () => _incompleteStep(r, id, _filesUnreadable),
    );
    if (!_carriesTheDocument(r, files)) {
      await _incompleteStep(r, id, _attachmentNotStored);
    }
    await _journal.record(r.docId, SendStep.sent, recordId: id);
    return Sent(recordId: id, readBack: readBack, files: files);
  }

  /// Whether the read-back carries the document that was uploaded, on all three of its properties.
  bool _carriesTheDocument(SendRequest r, List<NinoxFile> files) => files.any(
    (NinoxFile file) =>
        file.name == r.filename &&
        file.size == r.bytes.length &&
        file.contentType == r.contentType,
  );

  /// A step that **cannot duplicate a record** — an attachment, a read-back, a listing — run under
  /// the matrix's transient-failure rows (design §3).
  ///
  /// A timeout, a lost connection or a rate limit backs off exponentially (1 s, 2 s, 4 s …) up to
  /// [attachmentAttempts] attempts and then calls [onExhausted]; a 500 or an unreadable response is
  /// retried exactly once after a schema refresh and then reported as a server failure; a 401 and a
  /// 404 are terminal at once, because sleeping would not help either.
  Future<T> _retrying<T>(
    SendRequest r,
    Future<T> Function() call, {
    required Future<Never> Function() onExhausted,
  }) async {
    var attempt = 0;
    var refreshed = false;
    while (true) {
      try {
        return await call();
      } on Unauthorized catch (failure) {
        await _failedStep(r, SendFailureKind.auth, failure);
      } on NotFound catch (failure) {
        await _failedStep(r, SendFailureKind.destinationGone, failure);
      } on ServerError catch (failure) {
        // Not a mapping error here — no field name was sent: a server failure, retried once.
        if (refreshed) {
          await _failedStep(r, SendFailureKind.server, failure);
        } else {
          refreshed = true;
          await _refresh();
        }
      } on UnexpectedResponse catch (failure) {
        if (refreshed) {
          await _failedStep(r, SendFailureKind.server, failure);
        } else {
          refreshed = true;
          await _refresh();
        }
      } on TransportFailure catch (_) {
        await _backOff(++attempt, onExhausted);
      } on RateLimited catch (_) {
        await _backOff(++attempt, onExhausted);
      }
    }
  }

  /// Waits before the next attempt of a safe step, or gives up: `1 s, 2 s, 4 s …` for
  /// [attachmentAttempts] attempts (design §3).
  Future<void> _backOff(
    int attempt,
    Future<Never> Function() onExhausted,
  ) async {
    if (attempt >= _attachmentAttempts) {
      await onExhausted();
    } else {
      await _sleep(Duration(seconds: 1 << (attempt - 1)));
    }
  }

  /// Refreshes the schema, when the caller gave the pipeline a way to: the matrix's 500 row needs
  /// the schema to be re-read before the single retry.
  Future<void> _refresh() async {
    final Future<void> Function()? refresh = _refreshSchema;
    if (refresh != null) {
      await refresh();
    }
  }

  /// Ends the send as `uncertain`, with what the user may choose between.
  Future<Never> _uncertainStep(
    SendRequest r,
    List<NinoxRecord> candidates,
  ) async {
    await _journal.record(r.docId, SendStep.uncertain);
    throw _Ended(Uncertain(candidates: candidates));
  }

  /// Ends the send as incomplete: the record exists, the document is not confirmed in it.
  Future<Never> _incompleteStep(
    SendRequest r,
    RecordId id,
    String reason,
  ) async {
    await _journal.record(r.docId, SendStep.incomplete, recordId: id);
    throw _Ended(Incomplete(recordId: id, reason: reason));
  }

  /// Ends the send at a failure the user has to act on.
  Future<Never> _failedStep(
    SendRequest r,
    SendFailureKind kind,
    NinoxFailure failure,
  ) async {
    await _journal.record(r.docId, SendStep.failed);
    throw _Ended(Failed(kind: kind, failure: failure));
  }
}

/// A step that has already decided the send. Private: it travels from a step to the method that
/// returns the outcome, and never past it.
final class _Ended implements Exception {
  const _Ended(this.outcome);

  final SendOutcome outcome;
}
