/// The two-stage matcher (design §5).
///
/// Requirement served: FR-WIZ-006 (`setup-wizard/two-stage-matching-with-a-strict-threshold`) in full
/// and FR-WIZ-005's *pre-filled proposal* half (`setup-wizard/pre-filled-proposals`): what the mapping
/// step opens with is this file's answer.
///
/// **Stage one is a hard filter and runs first.** A core field is only ever scored against the fields
/// of the right Ninox type ([typeCandidates]); a date is never weighed against a non-date, an amount
/// never against a non-number. The filter is separate from the score on purpose — a test replaces the
/// score with one that throws and proves a wrong-typed field never reaches it.
///
/// **Stage two is the score against the field's own synonyms**, and the maximum over them is what a
/// candidate is worth. The synonyms are `paperdrop_core`'s `labelTerms`, taken by `LabelKind` and
/// across **every** language, so a German table is matched whatever the interface language is
/// (`countries-languages/document-dictionaries-are-separate-from-interface-language`). This file adds
/// no term of its own: where Annex C has one, it is used; where it has none, the field's own canonical
/// name is the whole of the comparison.
///
/// **Then the threshold and the margin, which are implementation constants and not a requirement.**
/// A core field is proposed only if its best candidate scores at least [proposalThreshold] **and**
/// beats the best alternative still open to it by at least [proposalMargin]. Below either bar the
/// field is left **unmapped** — deliberately, and in exactly the failure mode the functional names: a
/// mediocre suggestion a user confirms without reading it. Leaving `doc_date` unmapped looks worse and
/// behaves better. No requirement states the numbers and no test pins them: the tests assert outcomes
/// on named fixtures, and the two are re-examined on the first real tables of the demo.
///
/// **A field is proposed for at most one core field.** The highest score is placed first; a core field
/// that loses its best candidate to another one may take its next, but only if that one clears both
/// bars as well — otherwise it is left for the user to map deliberately or not at all.
///
/// **The one input type is `NinoxTable`.** Not a schema, not a list of names, not a map: the tables
/// the port returned, with the fields `.../tables` carries. A formula field cannot be a candidate at
/// any stage because it is not in that input at all, and there is no filter here for something that
/// never arrives — and no second request either (`table-listing-returns-the-schema`, DEC-005,
/// GAP-022).
library;

import 'package:ninox_client/ninox_client.dart';
import 'package:paperdrop_core/paperdrop_core.dart'
    show LabelKind, LabelTerm, labelTerms;

import '../destination.dart';
import 'similarity.dart';
import 'type_rules.dart';

/// The score a candidate name is worth for a core field, as one function.
///
/// It is a parameter and not a direct call so that a test can hand in a score that **throws**: the
/// proof that the type filter runs before any similarity is computed (design §5).
typedef Similarity = double Function(
  String candidateName,
  Iterable<String> synonyms,
);

/// The score a candidate must reach before it may be proposed at all.
///
/// Design §5's named starting point; the value itself is not a requirement and no test pins it. It
/// lives in this file and nowhere else.
const double proposalThreshold = 0.85;

/// How far ahead of the next candidate the best one must be.
///
/// Design §5's named starting point, beside [proposalThreshold] and by the same rules. Two plausible
/// candidates within this of each other are an **ambiguity**, and an ambiguity is a non-suggestion:
/// the field is left unmapped rather than offered a coin toss.
const double proposalMargin = 0.05;

/// One core field's proposal: the field the mapping step pre-fills, or nothing.
final class FieldProposal {
  /// Binds a core field to the candidate proposed for it, or to none.
  const FieldProposal({required this.coreField, this.ninoxField});

  /// The core field this proposal is about.
  final CoreField coreField;

  /// The Ninox field the matcher would pre-fill, or `null` when nothing cleared the threshold and
  /// the margin. `null` is a **result**, not an absence: the field is shown as unmapped the moment
  /// the screen connects it, and the user maps it deliberately or not at all.
  final NinoxField? ninoxField;

  /// Whether a candidate was proposed for this field.
  bool get isProposed => ninoxField != null;

  @override
  String toString() => ninoxField == null
      ? 'FieldProposal(${coreField.wireName}: unmapped)'
      : 'FieldProposal(${coreField.wireName} -> ${ninoxField!.name})';

  @override
  bool operator ==(Object other) =>
      other is FieldProposal &&
      other.coreField == coreField &&
      other.ninoxField == ninoxField;

  @override
  int get hashCode => Object.hash(coreField, ninoxField);
}

/// The synonyms a core field is compared with (design §5's table).
///
/// The dictionary is `paperdrop_core`'s Annex C seeds, by [LabelKind] and across every language; this
/// function adds no term of its own.
///
/// **The two gaps.** Annex C has no term for a tax identifier or for a currency, and no `LabelKind`
/// exists for them, so `supplier_tax_id` and `currency` are compared **only** with their own
/// canonical name (`supplier_tax_id`, `currency`). Normalisation turns the wire name's underscore
/// into a word break, so `supplier_tax_id` and `supplier tax id` are one string to the matcher. The
/// lane reports the gap to the orchestrator rather than inventing a term
/// (design §5, task 4.3's dictionary-gap note).
Iterable<String> synonymsOf(CoreField coreField) => switch (coreField) {
  CoreField.docDate => _termsOf(LabelKind.date),
  CoreField.supplierName => _termsOf(LabelKind.supplier),
  CoreField.docNumber => _termsOf(LabelKind.docNumber),
  CoreField.grossTotal => _termsOf(LabelKind.total),
  CoreField.netTotal => _termsOf(LabelKind.base),
  CoreField.taxTotal => _termsOf(LabelKind.tax),
  CoreField.supplierTaxId => <String>[CoreField.supplierTaxId.wireName],
  CoreField.currency => <String>[CoreField.currency.wireName],
};

/// Every term of Annex C that labels [kind], in the order the dictionary prints them and in every
/// language it records for them.
List<String> _termsOf(LabelKind kind) => <String>[
  for (final LabelTerm term in labelTerms)
    if (term.kind == kind) term.term,
];

/// The matcher: stage one, stage two, then the threshold and the margin (design §5).
///
/// Returns one [FieldProposal] per mappable core field, in the canonical order of [CoreField] — the
/// order `review-screen` names them — so a caller never has to sort or match up what it is given.
///
/// It makes no request, reads no clock and holds no state: the same table always gives the same
/// answer, which is what lets the mapping step's tests and the matcher's fixtures agree.
List<FieldProposal> proposeMappings(
  NinoxTable table, {
  Similarity similarity = bestSimilarity,
}) {
  // Stage one — the hard type filter, before any similarity is computed.
  final List<_Scored> scored = <_Scored>[];
  for (final CoreField coreField in CoreField.values) {
    final Iterable<String> synonyms = synonymsOf(coreField);
    for (final NinoxField candidate in typeCandidates(coreField, table)) {
      // Stage two — the score against the field's own synonyms, and the threshold.
      final double score = similarity(candidate.name, synonyms);
      if (score >= proposalThreshold) {
        scored.add(_Scored(coreField, candidate, score));
      }
    }
  }

  // Highest score first; an equal score keeps the canonical field order, and an equal one of those
  // keeps the order the port returned the table's fields in.
  scored.sort((_Scored left, _Scored right) {
    final int byScore = right.score.compareTo(left.score);
    if (byScore != 0) {
      return byScore;
    }
    final int byField = CoreField.values
        .indexOf(left.coreField)
        .compareTo(CoreField.values.indexOf(right.coreField));
    if (byField != 0) {
      return byField;
    }
    return _positionIn(
      table,
      left.candidate,
    ).compareTo(_positionIn(table, right.candidate));
  });

  final Map<CoreField, NinoxField> proposed = <CoreField, NinoxField>{};
  final Set<String> taken = <String>{};
  for (final _Scored candidate in scored) {
    if (proposed.containsKey(candidate.coreField) ||
        taken.contains(candidate.candidate.id)) {
      continue;
    }
    if (candidate.score - _bestAlternative(candidate, scored, taken) <
        proposalMargin) {
      // An ambiguity, or a candidate too close to the next one: no suggestion is made, and the field
      // stays for the user.
      continue;
    }
    proposed[candidate.coreField] = candidate.candidate;
    taken.add(candidate.candidate.id);
  }

  return <FieldProposal>[
    for (final CoreField coreField in CoreField.values)
      FieldProposal(coreField: coreField, ninoxField: proposed[coreField]),
  ];
}

/// The best score still open to [candidate]'s core field, or 0 when it has no other candidate.
///
/// "Still open" is the point: a field another core field already took is not an alternative any more,
/// and a term that was filtered out by type was never one at all.
double _bestAlternative(
  _Scored candidate,
  List<_Scored> scored,
  Set<String> taken,
) {
  double best = 0;
  for (final _Scored other in scored) {
    if (other.coreField != candidate.coreField ||
        other.candidate.id == candidate.candidate.id ||
        taken.contains(other.candidate.id)) {
      continue;
    }
    best = best > other.score ? best : other.score;
  }
  return best;
}

/// The index of [field] in its table, so that an equal score keeps the port's own order.
int _positionIn(NinoxTable table, NinoxField field) {
  for (int index = 0; index < table.fields.length; index++) {
    if (table.fields[index].id == field.id) {
      return index;
    }
  }
  return table.fields.length;
}

/// One scored candidate: a core field, a Ninox field of the right type, and what it scored.
final class _Scored {
  const _Scored(this.coreField, this.candidate, this.score);

  final CoreField coreField;
  final NinoxField candidate;
  final double score;
}
