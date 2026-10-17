/// The duplicate criteria of FR-DUP-001, checked read-side against local history.
///
/// Requirement served: `document-history/duplicate-criteria` — a document is flagged as a duplicate
/// when its hash matches an earlier send, **or** when supplier, date and total together match one,
/// and the check runs against local history before a save. Design §2 of
/// `implement-history-retry-duplicates` settles the rest.
///
/// **Why read-side.** `destinations-mapping/never-write-an-unmapped-field` forbids relying on a
/// marker field in the user's table, so a write-side check would have nothing to rely on
/// (`duplicate-criteria` · *the check is read-side and cannot use a marker field*). Everything here
/// reads the store and one method writes a local flag; no field of a Ninox record is ever involved
/// and no marker field is assumed to exist (ADR-013).
///
/// **What a duplicate is.** Not a state: DEC-016 keeps `duplicateFlagged` beside the state the
/// document already holds, so a `sent` document that is captured again still reads `sent`. The
/// notice, the link to the existing record and the permission to proceed belong to `review-screen`;
/// this file owns the criteria and the flag they produce.
///
/// **Content, not similarity.** The second criterion is exact on all three of supplier, date and
/// total: the supplier name after normalisation, the document date, and the gross total **in the
/// candidate's currency**. Two documents from one supplier on one day with different totals do not
/// match (`duplicate-criteria` · *two documents from one supplier on one day do not match*), and no
/// fuzzy matching, no edit distance and no tolerance exists in this change.
library;

import 'package:paperdrop_core/paperdrop_core.dart'
    show CalendarDate, CanonicalDocument, Edited, FieldValue, Money, Present;

import 'history_entry.dart';
import 'history_store.dart';

/// Which of the two criteria of `duplicate-criteria` a match hit.
enum DuplicateCriterion {
  /// The same document, by SHA-256: the same file captured twice
  /// (`duplicate-criteria` · *the same file captured twice matches on hash*).
  hash,

  /// Supplier, date and total together: two photographs of one receipt
  /// (`duplicate-criteria` · *two photographs of one receipt match on their content*).
  content,
}

/// A document that matched an earlier send, and why.
final class DuplicateMatch {
  /// Binds the earlier document to the criterion that found it.
  const DuplicateMatch({required this.docId, required this.criterion});

  /// The identifier of the earlier document that matched: `review-screen` links to it and the user
  /// decides what to do about it (FR-DUP-002, FR-REV-007).
  final String docId;

  /// Which criterion hit. A document that hits both reports [DuplicateCriterion.hash], because the
  /// hash is the stronger evidence: it is the same bytes, not the same receipt.
  final DuplicateCriterion criterion;

  @override
  bool operator ==(Object other) =>
      other is DuplicateMatch &&
      other.docId == docId &&
      other.criterion == criterion;

  @override
  int get hashCode => Object.hash(docId, criterion);

  @override
  String toString() => 'DuplicateMatch($docId, ${criterion.name})';
}

/// The document about to be saved, in the three terms the criteria compare.
///
/// It is the candidate and not a history entry: the check runs **before** a save, when the document
/// has a hash and its extracted values but no entry of its own yet. [docId] is the candidate's own
/// identifier — a document is never a duplicate of itself, so its own entry is skipped.
final class DuplicateCandidate {
  /// Builds a candidate from the three content values and the hash, each possibly unknown.
  ///
  /// A `null` supplier, date or total is a value the extraction did not produce (it is `absent` or
  /// `not_in_xml`), and a criterion that needs it cannot hit: an unknown total is not the same as
  /// any other total, so the content criterion simply does not fire.
  const DuplicateCandidate({
    required this.docId,
    required this.documentHash,
    this.supplier,
    this.docDate,
    this.total,
  });

  /// Builds the candidate of a document from its hash and its extracted values.
  ///
  /// The three content values are read from the canonical document the review screen is showing —
  /// `supplierName`, `docDate` and `grossTotal` — through the core's own field values, so a value
  /// the user edited is the one compared (the edited value is the value sent,
  /// `review-screen/user-edits-are-authoritative`) and a value that was never read is `null`.
  factory DuplicateCandidate.fromDocument({
    required String docId,
    required String documentHash,
    required CanonicalDocument values,
  }) => DuplicateCandidate(
    docId: docId,
    documentHash: documentHash,
    supplier: _valueOf<String>(values.supplierName),
    docDate: _valueOf<CalendarDate>(values.docDate),
    total: _valueOf<Money>(values.grossTotal),
  );

  /// The identifier of the document about to be saved: its own entry never matches it.
  final String docId;

  /// The SHA-256 of the document as stored, from `DocumentIntake` (FR-CAP-005).
  final String documentHash;

  /// The supplier as it was read or edited, or `null` when nothing was read.
  final String? supplier;

  /// The document date, or `null` when nothing was read.
  final CalendarDate? docDate;

  /// The gross total, currency included, or `null` when nothing was read.
  final Money? total;

  @override
  String toString() =>
      'DuplicateCandidate($docId, '
      '${supplier == null ? 'no supplier' : 'supplier'}, '
      '${docDate == null ? 'no date' : 'date'}, '
      '${total == null ? 'no total' : 'total'})';
}

/// Checks a document against local history, and writes the flag the answer produces.
///
/// It reads [HistoryStore.list], which reports a document whose `entry.json` cannot be read and goes
/// on with the rest (design §5.1): an unreadable entry is **skipped, never fatal**, because a
/// corrupt file elsewhere in the history must not stop a save (`duplicate-criteria` — the check may
/// not become a reason a document cannot be stored).
final class DuplicateChecker {
  /// Binds the checker to the history it reads.
  const DuplicateChecker(this.store);

  /// Where the earlier sends are.
  final HistoryStore store;

  /// Whether [candidate] matches an earlier send, and which entry and criterion it matched.
  ///
  /// Only `sent` entries are considered: the criterion is *an earlier send*, and a document still in
  /// `reviewing` or `failed` has not reached Ninox, so flagging against it would tell the user their
  /// new document duplicates something that may never be there. The candidate's own entry is
  /// skipped for the same reason a document is not a duplicate of itself.
  ///
  /// The hash criterion is checked first and wins when both hit: same bytes is stronger evidence
  /// than the same supplier, date and total.
  Future<DuplicateMatch?> check(DuplicateCandidate candidate) async {
    final HistoryListing listing = await store.list();
    final String? supplier = normaliseSupplier(candidate.supplier);
    DuplicateMatch? byHash;
    DuplicateMatch? byContent;

    for (final HistoryEntry entry in listing.entries) {
      if (entry.docId == candidate.docId || entry.state != DocumentState.sent) {
        continue;
      }
      if (byHash == null && entry.documentHash == candidate.documentHash) {
        byHash = DuplicateMatch(
          docId: entry.docId,
          criterion: DuplicateCriterion.hash,
        );
        break; // The hash is the stronger criterion; nothing can beat it.
      }
      if (byContent == null &&
          _sameContent(entry, candidate, supplier: supplier)) {
        byContent = DuplicateMatch(
          docId: entry.docId,
          criterion: DuplicateCriterion.content,
        );
      }
    }

    return byHash ?? byContent;
  }

  /// Sets [HistoryEntry.duplicateFlagged] on the stored entry of [docId], and answers what is stored.
  ///
  /// The state is **not** changed (DEC-016) and the revision is bumped, because the flag is a change
  /// the entry has had and the store refuses a write that is not newer than what it holds. An entry
  /// that is already flagged is returned as it is: there is nothing to change, so nothing is
  /// written and the revision does not climb on every load.
  ///
  /// Throws what [HistoryStore.get] throws when the document has no entry, and
  /// [HistoryStoreFailureCode.staleRevision] when another write got there first — the second flag
  /// on the same document is refused rather than lost, which is the store's job and not this
  /// method's.
  Future<HistoryEntry> markDuplicate(String docId) async {
    final HistoryEntry stored = await store.get(docId);
    if (stored.duplicateFlagged) {
      return stored;
    }
    final HistoryEntry flagged = stored.withDuplicateFlag();
    await store.update(docId, flagged);
    return flagged;
  }

  @override
  String toString() => 'DuplicateChecker(${store.runtimeType})';
}

/// [supplier] as the content criterion compares it, or `null` when nothing is left to compare.
///
/// Case-folded and whitespace-collapsed (design §2): `ACME  Ibérica, S.L.` and `acme ibérica, s.l.`
/// are one supplier, because the two photographs of a receipt are recognised by two different
/// passes and the same name comes out spaced differently. Nothing else — no accent folding, no
/// punctuation stripping, no fuzzy matching — because a name this app decided was "close enough"
/// would be a duplicate the user never got to see.
///
/// An empty result is `null`: a supplier that normalises to nothing identifies nothing, and matching
/// two such documents would flag every unreadable receipt as a duplicate of every other.
String? normaliseSupplier(String? supplier) {
  if (supplier == null) {
    return null;
  }
  final String collapsed = supplier.trim().replaceAll(_whitespace, ' ');
  return collapsed.isEmpty ? null : collapsed.toLowerCase();
}

/// Whitespace as the normalisation collapses it: runs of spaces, tabs and newlines alike.
final RegExp _whitespace = RegExp(r'\s+');

/// Whether [entry] matches the candidate on supplier, date **and** total together.
///
/// All three must be known on both sides and all three must be equal; a criterion that is missing on
/// either side is not a match. The total is compared as a [Money], which carries its currency: the
/// same minor units in another currency are another total, not the same one.
bool _sameContent(
  HistoryEntry entry,
  DuplicateCandidate candidate, {
  required String? supplier,
}) {
  final String? earlierSupplier = normaliseSupplier(
    _valueOf<String>(entry.values?.supplierName),
  );
  final CalendarDate? earlierDate = _valueOf<CalendarDate>(
    entry.values?.docDate,
  );
  final Money? earlierTotal = _valueOf<Money>(entry.values?.grossTotal);

  if (supplier == null ||
      earlierSupplier == null ||
      candidate.docDate == null ||
      earlierDate == null ||
      candidate.total == null ||
      earlierTotal == null) {
    return false;
  }
  return earlierSupplier == supplier &&
      earlierDate == candidate.docDate &&
      earlierTotal == candidate.total;
}

/// The value of [field] when it carries one, or `null` when nothing was read.
///
/// [Present] is a value the extraction produced and [Edited] one the user typed; both are values the
/// document has. [Absent] and `NotInXml` are the two ways of not having one, and neither is zero nor
/// equal to another document's nothing.
T? _valueOf<T>(FieldValue<T>? field) => switch (field) {
  Present<T>(value: final T value) => value,
  Edited<T>(value: final T value) => value,
  _ => null,
};
