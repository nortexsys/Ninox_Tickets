/// The hard type filter: the first stage, before any similarity is computed (design §5).
///
/// Requirement served: FR-WIZ-006 (`setup-wizard/two-stage-matching-with-a-strict-threshold`) — *a
/// date is never proposed against a non-date field, nor an amount against a non-number field* — and
/// FR-WIZ-005 with it, because a proposal the filter cannot make is a field the user maps by hand.
///
/// **Two tables of data, and no logic beyond them.** The first says what kind of value each mappable
/// core field carries; the second says which Ninox field type names that kind may bind. Both are
/// `const` and both are read by the same one-line predicate, so a row can be argued about in review
/// instead of being buried in a branch.
///
/// **Where the Ninox type names come from.** The `ninox` skill's `references/schema-and-fields.md`
/// lists the `type` values it observed across a whole subscription: `number`, `string`, `date`,
/// `boolean`, `choice`, `multi`, `ref`, `rev`, `phone`, `email`, `html`, `link`, `location`,
/// `timeinterval` and `icon`. Three of them are what the kinds below bind, and the file says why
/// each of the other twelve is **not** bound. A type this file does not list — a choice field, and
/// anything a later Ninox version adds — is never a candidate, which is the direction the strict
/// threshold wants: an unmapped field is a question, a wrong proposal is a wrong write.
///
/// **What is deliberately absent.** There is no filter for formula or read-only fields, and there is
/// no second request. A formula field is not a candidate **because the mapping step is only ever
/// given what `.../tables` returned**, and that endpoint omits formula fields altogether
/// (DEC-005, GAP-022, `docs/Plan/SPIKE_GAP-022_schema_formula_fields.md` §3); read-only has no
/// marker anywhere, so the app cannot claim to exclude it in advance
/// (`destinations-mapping/formula-and-read-only-fields-are-not-mapping-candidates`). Nothing here
/// reads a database schema or builds a URL.
library;

import 'package:ninox_client/ninox_client.dart';

import '../destination.dart';

/// The kind of value a mappable core field carries (design §5: *target kinds in the MVP are
/// `string`, `number` and `date`*).
///
/// `choice` and per-slot tax fields are R1: `destinations-mapping/choice-fields-offer-the-existing-options`
/// and GAP-005 are out of this change by construction, which is why there is no kind for them.
enum TargetKind {
  /// Text: a supplier's name, a document number, an identifier, a currency code.
  string,

  /// A number: a total, a tax amount, a net amount.
  number,

  /// A calendar date: the document's date.
  date,
}

/// The Ninox field type names each target kind may bind (design §5).
///
/// Read from the `ninox` skill's reference, `references/schema-and-fields.md`. One type per kind,
/// and the reason is in the skill's own table:
///
/// * `string` — *"Yes. Send a string."*
/// * `number` — *"Yes. See the money convention; never send a float across the boundary."* The
///   canonical model's amounts are integers of minor units, and the send pipeline owns that
///   conversion; this filter only decides whether the mapping *may* exist.
/// * `date` — *"Yes. A `YYYY-MM-DD` string is stored verbatim."*
///
/// The twelve the skill also lists are **not** bound, each for a stated reason:
///
/// * `choice` and `multi` are writable, but the MVP maps no choice field (design §5, plan §4.5), so
///   offering one would be R1's feature arriving early;
/// * `boolean` is writable and no core field is a boolean;
/// * `ref` points at another table and `rev` is the reverse half of a relation: neither is a value
///   the canonical model carries, and the skill marks `rev` *"Probably not"* writable;
/// * `phone`, `email`, `html`, `link`, `location`, `timeinterval` and `icon` are the skill's
///   *"Treat as unverified"* row: the accepted representation is not established, so binding a core
///   field to one of them would be a guess. **Reported to the orchestrator**: a real table that types
///   a supplier name as `email`, or the document date as `timeinterval`, will not be proposed.
const Map<TargetKind, Set<String>> ninoxTypesByTargetKind =
    <TargetKind, Set<String>>{
      TargetKind.string: <String>{'string'},
      TargetKind.number: <String>{'number'},
      TargetKind.date: <String>{'date'},
    };

/// The kind of each mappable core field (design §5, `FR-WIZ-005`'s six plus the two the design adds).
///
/// A date is a date, an amount is a number, and a name, an identifier, a document number and a
/// currency are text. The map covers every value of [CoreField] — a test asserts that, because a
/// core field missing from it would silently have *no* candidates at all.
const Map<CoreField, TargetKind> targetKindByCoreField =
    <CoreField, TargetKind>{
      CoreField.docDate: TargetKind.date,
      CoreField.supplierName: TargetKind.string,
      CoreField.supplierTaxId: TargetKind.string,
      CoreField.docNumber: TargetKind.string,
      CoreField.grossTotal: TargetKind.number,
      CoreField.netTotal: TargetKind.number,
      CoreField.taxTotal: TargetKind.number,
      CoreField.currency: TargetKind.string,
    };

/// Whether [candidate] may bind [coreField] at all, by its Ninox type name alone.
///
/// This is the hard filter of the first stage: it reads the type name the endpoint returned and
/// answers yes or no. It never looks at the candidate's **name** — that is the second stage's, and
/// keeping the two apart is what makes *"the type filter runs before similarity"* checkable.
bool isTypeCandidate(CoreField coreField, NinoxField candidate) =>
    ninoxTypesByTargetKind[targetKindByCoreField[coreField]]!.contains(
      candidate.type,
    );

/// The fields of [table] that pass the hard type filter for [coreField].
///
/// The order is the order the port returned, so a proposal and the picker beside it (dispatch 3.3)
/// present the user's own table in the user's own order.
List<NinoxField> typeCandidates(CoreField coreField, NinoxTable table) =>
    <NinoxField>[
      for (final NinoxField candidate in table.fields)
        if (isTypeCandidate(coreField, candidate)) candidate,
    ];
