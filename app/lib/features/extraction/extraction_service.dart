/// The extraction step, wired to a document's stored state (design §2, T2.1; tasks
/// 2.1–2.3, and task 2.1 of `implement-country-detection` with design §3–§4).
///
/// Requirement served: `document-history` · `document-states` (FR-HIS-002) for the two
/// transitions it drives and the reason code a failure stores;
/// `countries-languages` · `deterministic-country-detection` (FR-CTR-001) for the country
/// it reads out of the document instead of being told; `countries-languages` ·
/// `universal-core` (FR-CTR-002) for the document no row governs, which is still read and
/// still goes to review; and `extraction-pipeline`'s routes for what it hands to Core.
///
/// **What it does, in this order.** One stored document goes from `pending` to
/// `reviewing`:
///
/// 1. the entry is read from the store, moved to `extracting` by
///    `document_machine.transition` and written back, *before* either port runs — so a
///    document is never in `pending` while its pages are being read, and a process that
///    dies mid-extraction leaves a state that says what was happening;
/// 2. `ExtractionRouter` picks the route and reads the passes;
/// 3. `detectCountryAcrossPasses` asks Core's `detectCountry` about every pass that holds
///    words and requires their answers to agree (design §3): a `Detected` row governs the
///    reading, and an `Undetected` document is read by the universal core — no row, no rate
///    gate, no identifier check;
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
/// **Every state change goes through the machine.** Nothing here assigns a state: each
/// change is a `transition` call, so `allowedTransitions` decides what this step may do
/// and an entry that is not `pending` is refused by the machine's own `StateError`.
/// Nothing is written before that refusal, because the first write follows the first
/// transition.
///
/// **What it does not set.** `confidence` stays `null`: it is what validation produces,
/// and validation is not this change's step — the entry's own field says *null until
/// validation has run*. `values` is the canonical document, whose `recognitionEngine`
/// names the route that produced it and, when no row applies, why none does.
///
/// **What it does not catch.** A `HistoryStoreFailure` — no entry, an overtaken revision,
/// a file system that refused — travels to the caller: it is the store refusing, not the
/// document failing, and the two must not be confused. Only an [ExtractionFailure]
/// becomes the stored state `failed`.
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
/// document is read by the universal core and still reaches review (design §4).
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

  /// What the document's own evidence said about its country: the row that governed the
  /// reading, or the reason no row applies.
  ///
  /// It is the answer the passes agreed on (design §3), and it carries evidence *kinds*
  /// and never text from the document. The reason of an [Undetected] answer is in the
  /// stored metadata too, so a screen that opens the entry later finds it; this field is
  /// the same answer for the caller that has just run the extraction.
  final CountryDetection detection;
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
  /// No country row is given: the row that governs a document is the document's own
  /// evidence, read by Core's `detectCountry` over the passes the route produced
  /// (`deterministic-country-detection`; there is no user-facing country setting and the
  /// destination takes no part). [table] is the launch table unless a caller has one of
  /// its own (ES and DE are the only rows that exist).
  ExtractionService({
    required this.store,
    required this.router,
    CountryTable? table,
  }) : table = table ?? CountryTable.launch;

  /// Where the entry is read from and written back to.
  final HistoryStore store;

  /// How a document's route is chosen and its pages read.
  final ExtractionRouter router;

  /// The table the document's country is detected in: the rows, and the tax identifiers,
  /// country names and currencies that name them.
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
  /// A detected country is handed to Core as its row; an undetected one is handed as `null`
  /// and the document is read by the universal core, which is a completed extraction and not
  /// a refusal (design §4). Either way the entry reaches `reviewing`.
  ///
  /// Throws a [HistoryStoreFailure] when the document has no entry or the store refuses a
  /// write, and a [StateError] from the machine when the entry is not in `pending` (or is
  /// no longer there).
  Future<ExtractionOutcome> extract(IntakeResult document) async {
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

    final CountryDetection detection = detectCountryAcrossPasses(
      passes: routed.passes,
      table: table,
    );
    final CanonicalDocument extracted = extractDocument(
      passes: routed.passes,
      country: detection is Detected ? detection.row : null,
      table: table,
      sourceHash: document.sha256,
    );
    final CanonicalDocument values = detection is Undetected
        ? _withCountryReason(extracted, detection.reason)
        : extracted;
    final HistoryEntry reviewing = transition(
      extracting,
      DocumentState.reviewing,
      values: values,
    );
    await store.update(document.docId, reviewing);
    return ExtractionCompleted(
      entry: reviewing,
      document: values,
      detection: detection,
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
