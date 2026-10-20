/// The extraction step, wired to a document's stored state (design §2, T2.1; tasks
/// 2.1–2.3, task 2.1 of `implement-country-detection` with design §3–§4, and tasks 3.1–3.2 of
/// `adopt-app-cust-readers` with design §3–§4 of that change).
///
/// Requirement served: `document-history` · `document-states` (FR-HIS-002) for the two
/// transitions it drives and the reason code a failure stores; `countries-languages` ·
/// `country-is-an-input` (DEC-022) for the country of a **photographed** document, which is the
/// caller's argument and never a detection result; `countries-languages` ·
/// `deterministic-country-detection` (FR-CTR-001) for the country of every other route, which is
/// still read out of the document; `countries-languages` · `universal-core` (FR-CTR-002) for the
/// document no row governs, which is still read and still goes to review;
/// `extraction-pipeline` · `currency-is-read-from-the-document` for what the photo route's
/// currency is; `extraction-pipeline` · `second-read-on-the-users-request` (DEC-024) for the
/// second read it offers on request; and `extraction-pipeline`'s routes for what it hands to
/// Core.
///
/// **What [extract] does, in this order.** One stored document goes from `pending` to
/// `reviewing`:
///
/// 1. the entry is read from the store, moved to `extracting` by
///    `document_machine.transition` and written back, *before* either port runs — so a
///    document is never in `pending` while its pages are being read, and a process that
///    dies mid-extraction leaves a state that says what was happening;
/// 2. `ExtractionRouter` picks the route and reads the passes;
/// 3. the country in force is settled, and *which* rule settles it is the route's
///    (`_countryOf`): on the **photo route** it is [extract]'s `country` argument — the
///    settings default, or the value the review screen holds for that ticket — and
///    `detectCountryAcrossPasses` is not called at all, so no evidence printed on the image can
///    change it (DEC-022). On **every other route** nothing changes: `detectCountryAcrossPasses`
///    asks Core's `detectCountry` about every pass that holds words and requires their answers to
///    agree (design §3), a `Detected` row governs the reading, and an `Undetected` document is
///    read by the universal core — no row, no rate gate, no identifier check;
/// 4. Core's `extractDocument` turns the passes into one `CanonicalDocument`, with the
///    stored document's own SHA-256 as its `sourceHash` and the route's label in its
///    `recognitionEngine`;
/// 5. the entry is moved to `reviewing` with the document attached, or to `failed` with a
///    reason code when the route could not read the document at all.
///
/// **An undetected country is not a failure** (design §4, accepted by the product owner):
/// the document is read by the universal core, `needsReview` is set by Core, and the reason
/// — `noEvidence`, `conflictingEvidence` or `countryWithoutRow` — is recorded *inside* the
/// engine metadata of the stored values, beside the route:
/// `pdf-text/pdfrx 2.6.5 [country=noEvidence]`. Never a `failureReason`: a reason there
/// means the route could not read the document, and this document was read.
///
/// **A photographed ticket whose country has no row** is read by nobody (GAP-036, closed by the
/// product owner on 2026-10-19): Core's photo route produces no value at all, no decimal
/// convention, date order, rate set, currency or label vocabulary is assumed in a row's place, and
/// the ticket's fields are filled by hand. That case is not a failure either — the document was
/// read as far as it can be read — and its reason is Core's own `reviewReason`
/// (`ReviewReason.countryWithoutRow`), so nothing is appended to the engine metadata: what a
/// history entry records about the country in force on the photo route is left as GAP-034 leaves
/// it, undecided, and is not invented here.
///
/// **The currency of the photo route** is the country row's, recorded with the country setting as
/// its origin and shown green by DEC-023. It is not a reading, and the route runs no stage that
/// could fail to read it.
///
/// **Every state change goes through the machine.** Nothing here assigns a state: each
/// change is a `transition` call, so `allowedTransitions` decides what this step may do
/// and an entry that is not `pending` is refused by the machine's own `StateError`.
/// Nothing is written before that refusal, because the first write follows the first
/// transition. [reRead] is the one operation here that moves no state: a second read of a
/// document under review is not a state of the document (`second-read-on-the-users-request`).
///
/// **What it does not set.** `confidence` stays `null`: it is what validation produces,
/// and validation is not this change's step — the entry's own field says *null until
/// validation has run*. `values` is the canonical document, whose `recognitionEngine`
/// names the route that produced it and, when no row applies, why none does.
///
/// **What it does not catch.** A `HistoryStoreFailure` — no entry, an overtaken revision,
/// a file system that refused — travels to the caller: it is the store refusing, not the
/// document failing, and the two must not be confused. Only an [ExtractionFailure]
/// becomes the stored state `failed`; on [reRead] it travels to the caller and changes nothing.
library;

import 'package:paperdrop/features/extraction/extraction_failure.dart';
import 'package:paperdrop/features/extraction/extraction_router.dart';
import 'package:paperdrop/features/extraction/pass_country_detection.dart';
import 'package:paperdrop/history/document_machine.dart';
import 'package:paperdrop/history/history_entry.dart';
import 'package:paperdrop/history/history_store.dart';
import 'package:paperdrop/intake/intake_result.dart';
import 'package:paperdrop_core/paperdrop_core.dart';

/// What one extraction did to one document (design §2).
///
/// Either answer carries the entry **as it was stored**, which is the state the machine
/// put it in and the revision that write produced — the same entry a screen shows after
/// it, and not a second copy of it.
sealed class ExtractionOutcome {
  /// Creates an outcome carrying the stored [entry].
  const ExtractionOutcome(this.entry);

  /// The entry as it was written: `reviewing` when the document was read, `failed` when
  /// it could not be.
  final HistoryEntry entry;
}

/// The document was read: its values are stored and the entry is `reviewing`.
///
/// The document was read whether or not a country row governs it: an [Undetected]
/// document is read by the universal core and still reaches review (design §4), and a
/// photographed ticket whose country has no row reaches review with its fields to be filled by
/// hand (GAP-036).
final class ExtractionCompleted extends ExtractionOutcome {
  /// Binds the stored [entry] to the document that was extracted from it and to the
  /// [detection] that governed the reading.
  const ExtractionCompleted({
    required HistoryEntry entry,
    required this.document,
    required this.detection,
  }) : super(entry);

  /// The canonical document that was stored in [ExtractionOutcome.entry].
  final CanonicalDocument document;

  /// The country of the document: the row that governs the reading, or the reason no row applies.
  ///
  /// **On the photo route nothing was detected** (DEC-022): the country is the caller's input, so
  /// a row in force is reported as a [Detected] with no evidence kind — no evidence decided it —
  /// and a country without a row as [UndetectedReason.countryWithoutRow]. On every other route it
  /// is the answer the passes agreed on (design §3), carrying evidence *kinds* and never text from
  /// the document. Either way the reason of an [Undetected] answer is in the stored metadata too
  /// (on the photo route, in the document's own `reviewReason`), so a screen that opens the entry
  /// later finds it; this field is the same answer for the caller that has just run the
  /// extraction.
  final CountryDetection detection;

  /// The row in force for the ticket, or `null` when the country has no row.
  ///
  /// It is the row the reading used and the row the review screen shows; a `null` here is the
  /// country-without-a-row case whose warning the screen owes the user (GAP-036).
  CountryRow? get country => switch (detection) {
    Detected(:final CountryRow row) => row,
    Undetected() => null,
  };
}

/// The document could not be read: the entry is `failed` and carries the route's
/// [failure].
final class ExtractionRefused extends ExtractionOutcome {
  /// Binds the stored [entry] to the [failure] that ended the extraction.
  const ExtractionRefused({required HistoryEntry entry, required this.failure})
    : super(entry);

  /// Why the route could not read the document.
  final ExtractionFailure failure;
}

/// Runs the extraction of one stored document and moves its entry through the machine.
///
/// The store is the real one on the device and a temporary folder in a test
/// (`FileHistoryStore`), the router is built over the two adapters on the device and over
/// fakes in a test, and nothing in this class needs a device: Core's `extractDocument` is
/// pure and the ports are the only things that touch a file.
class ExtractionService {
  /// Creates the step over [store], [router] and the table its countries come from.
  ///
  /// No country row is held here: it arrives with each call
  /// (`countries-languages` · `country-is-an-input`), because the country of a photographed
  /// ticket is a setting and a value of that ticket, and not something this service could
  /// remember for it. [table] is the launch table unless a caller has one of its own (ES and DE
  /// are the only rows that exist).
  ExtractionService({
    required this.store,
    required this.router,
    CountryTable? table,
  }) : table = table ?? CountryTable.launch;

  /// Where the entry is read from and written back to.
  final HistoryStore store;

  /// How a document's route is chosen and its pages read.
  final ExtractionRouter router;

  /// The table the photo route's row and every detected country are resolved in.
  final CountryTable table;

  /// Extracts [document] and moves its entry from `pending` to `reviewing` or `failed`.
  ///
  /// The entry is read from the store by [IntakeResult.docId], so the state this step
  /// starts from is the stored one and not a caller's copy of it; a caller holding an
  /// entry that has been overtaken then gets the store's own `staleRevision` refusal
  /// rather than a silent overwrite.
  ///
  /// [document] and the entry must be about the same document, which is asserted by their
  /// hashes: `DocumentIntake` wrote the entry's `documentHash` and the intake's `sha256`
  /// over the same bytes (FR-CAP-005), and a mismatch means the caller paired an intake
  /// with another document's entry — a defect, not a document that failed.
  ///
  /// [country] is the country in force for the ticket, and **on the photo route it is the only
  /// one** (`countries-languages` · `country-is-an-input`): the settings default, or the value the
  /// review screen holds for that ticket, resolved to a row by the caller. `null` means the
  /// country has no row — never a request to detect one — and on the photo route it produces a
  /// ticket with no read at all and its fields to be filled by hand (GAP-036). The other routes
  /// keep their own rule and ignore it: their country is the document's own evidence, which is
  /// what `deterministic-country-detection` still asks of them.
  ///
  /// **A photo caller states it.** The parameter is not required only because one caller in
  /// `validation/release_checklist` reads a PDF and must keep compiling as it stands; a photo route
  /// that was given nothing reads nothing, so nothing is read under a country nobody named — which
  /// is the safe half of *never detect on the photo route*, and it is visible on the ticket rather
  /// than hidden in a value.
  ///
  /// Throws a [HistoryStoreFailure] when the document has no entry or the store refuses a
  /// write, and a [StateError] from the machine when the entry is not in `pending` (or is
  /// no longer there).
  Future<ExtractionOutcome> extract(
    IntakeResult document, {
    CountryRow? country,
  }) async {
    final HistoryEntry pending = await store.get(document.docId);
    if (pending.documentHash != document.sha256) {
      throw ArgumentError.value(
        document.docId,
        'document',
        'the intake is not the document this entry holds: the entry was stored '
            'with another copy',
      );
    }

    final HistoryEntry extracting = transition(
      pending,
      DocumentState.extracting,
    );
    await store.update(document.docId, extracting);

    final RoutedExtraction routed;
    try {
      routed = await router.route(document);
    } on ExtractionFailure catch (failure) {
      return _refuse(document, extracting, failure);
    }

    final _ExtractionReading reading = _read(
      routed: routed,
      document: document,
      country: country,
    );
    final HistoryEntry reviewing = transition(
      extracting,
      DocumentState.reviewing,
      values: reading.document,
    );
    await store.update(document.docId, reviewing);
    return ExtractionCompleted(
      entry: reviewing,
      document: reading.document,
      detection: reading.detection,
    );
  }

  /// Reads [document] a second time, on the user's request (DEC-024).
  ///
  /// Requirement served: `extraction-pipeline` · `second-read-on-the-users-request` — the second
  /// read works on the document **already captured** (no new capture, no new file), runs the route
  /// again so that its further recognition passes are new candidate readings, and hands them to
  /// the same extraction, consensus and confidence rules as the first read. Nothing here caps,
  /// widens or re-colours anything: `validation-confidence` does not change because a second read
  /// happened, and a value the arithmetic reader derived still confirms nothing.
  ///
  /// **It moves no state and writes nothing.** The entry is `reviewing` because a person is
  /// looking at it, and a second look at the same document is not a state of the document
  /// (`document-states`); the values it produces are the review screen's until a save sends them.
  /// The store is therefore not touched, no revision is bumped, and the file is only read
  /// (ADR-015).
  ///
  /// **It does not merge.** What may be replaced and what may not is `review-screen`'s
  /// `user-edits-are-authoritative` and that screen's own merge
  /// (`features/review/review_field.dart`): a value the user edited or typed keeps the user's
  /// value whatever this answers, so this method answers a whole reading and decides nothing
  /// about the fields on screen.
  ///
  /// **It fails as the first read does.** An [ExtractionFailure] travels to the caller, which
  /// keeps the values already on screen and stops saying that the read is running.
  ///
  /// [country] is the country now in force for the ticket — after a country change on the review
  /// screen, the new one — because the second read reads the document under it
  /// (`countries-languages` · `country-is-an-input`).
  Future<CanonicalDocument> reRead(
    IntakeResult document, {
    required CountryRow? country,
  }) async {
    final RoutedExtraction routed = await router.route(document);
    return _read(routed: routed, document: document, country: country).document;
  }

  /// One reading of [routed]: the country in force, Core's extraction, and its answer.
  ///
  /// The whole of what a route means for the country lives in [_countryOf], so the first read and
  /// the second read cannot disagree about it.
  _ExtractionReading _read({
    required RoutedExtraction routed,
    required IntakeResult document,
    required CountryRow? country,
  }) {
    final _RoutedCountry countryOf = _countryOf(
      routed: routed,
      country: country,
    );
    final CanonicalDocument extracted = extractDocument(
      passes: routed.passes,
      country: countryOf.row,
      table: table,
      sourceHash: document.sha256,
    );
    final CanonicalDocument values = switch (countryOf.detection) {
      // The reason of an undetected country goes into the engine metadata on every route but the
      // photo route, whose no-row case Core states itself in `reviewReason` (GAP-034: what that
      // entry records about the country in force is not decided, and is not invented here).
      Undetected(:final UndetectedReason reason)
          when routed.route != ExtractionRoute.photoOcr =>
        _withCountryReason(extracted, reason),
      _ => extracted,
    };
    return _ExtractionReading(document: values, detection: countryOf.detection);
  }

  /// The country that governs [routed], and the answer an outcome reports.
  ///
  /// The photo route takes it from the caller and detects nothing (DEC-022); every other route
  /// asks the passes, exactly as before.
  _RoutedCountry _countryOf({
    required RoutedExtraction routed,
    required CountryRow? country,
  }) {
    if (routed.route != ExtractionRoute.photoOcr) {
      final CountryDetection detection = detectCountryAcrossPasses(
        passes: routed.passes,
        table: table,
      );
      return _RoutedCountry(
        row: detection is Detected ? detection.row : null,
        detection: detection,
      );
    }
    final CountryRow? row = country;
    return _RoutedCountry(
      row: row,
      // No evidence decided this country, so no evidence kind is reported — the empty list says
      // exactly that, and the reason of the no-row case is the absence of the row.
      detection: row == null
          ? const Undetected(reason: UndetectedReason.countryWithoutRow)
          : Detected(row: row, evidence: const <CountryEvidenceKind>[]),
    );
  }

  /// The entry, in `failed` with the failure's own code as its reason.
  ///
  /// The reason is [ExtractionFailureCode.code] — a code the entry's own invariant
  /// accepts — and the store interprets no part of it: the wording belongs to the screen
  /// that shows it (T2.2). The document's file and its entry stay where they are: a failed
  /// document keeps its file (`file-retention` · *an unresolved item keeps its file*), and
  /// the machine's own table leaves `failed` reachable from `reviewing` only. Re-running an
  /// extraction over a failed document is the history step's business (T2.3) and is not
  /// this class's: [extract] starts from `pending`, which is what the capture step leaves
  /// behind.
  Future<ExtractionOutcome> _refuse(
    IntakeResult document,
    HistoryEntry extracting,
    ExtractionFailure failure,
  ) async {
    final HistoryEntry failed = transition(
      extracting,
      DocumentState.failed,
      failureReason: failure.code.code,
    );
    await store.update(document.docId, failed);
    return ExtractionRefused(entry: failed, failure: failure);
  }
}

/// One reading of one routed document: the canonical values and the country that produced them.
final class _ExtractionReading {
  /// Binds the [document] to the [detection] that governed it.
  const _ExtractionReading({required this.document, required this.detection});

  /// The canonical values Core produced.
  final CanonicalDocument document;

  /// The country answer of that reading.
  final CountryDetection detection;
}

/// The country a reading runs under: the row, and the answer that says which it is.
final class _RoutedCountry {
  /// Binds the [row] in force to the [detection] reported.
  const _RoutedCountry({required this.row, required this.detection});

  /// The row the reading used, or `null` when the country has none.
  final CountryRow? row;

  /// The answer [ExtractionCompleted.detection] reports.
  final CountryDetection detection;
}

/// [document] with [reason] recorded in its engine metadata (design §4).
///
/// The engine metadata is `CanonicalDocument.recognitionEngine`, and it is the only engine
/// metadata a history entry holds: the entry's own fields are design §5.2's, and the reason
/// of an undetected country is not a `failureReason` — nothing failed. The stored string
/// names the route the values came from and then the reason, `pdf-text/pdfrx 2.6.5
/// [country=noEvidence]`, so the route of FR-EXT-002 is still named and the reason travels
/// with the document; the reason is Core's own [UndetectedReason] name and never text from
/// the document (design §5).
///
/// **Why through JSON.** The model is Core's and immutable, and the app authors no value of
/// it (BR-09): the one field is replaced in the document's own serialised form, so a field
/// the model gains later travels with the copy — a field-by-field rebuild written here could
/// only drop it in silence.
CanonicalDocument _withCountryReason(
  CanonicalDocument document,
  UndetectedReason reason,
) => CanonicalDocument.fromJson(<String, Object?>{
  ...document.toJson(),
  'recognitionEngine': '${document.recognitionEngine} [country=${reason.name}]',
});
