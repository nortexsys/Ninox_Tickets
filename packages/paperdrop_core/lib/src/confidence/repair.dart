/// Repair to the only consistent value.
///
/// Requirement served: `validation-confidence` ·
/// `repair-to-the-only-consistent-value` — a reading that fails a check digit
/// is repaired only when exactly one single-character substitution from the
/// named confusion table makes it pass, and is then tagged `repaired`.
library;

import '../checks/check_result.dart';
import '../model/provenance.dart';

/// A single-character confusion pair: `printed` may have been read where
/// `intended` belongs, and the reverse.
typedef RepairConfusion = (String, String);

/// The confusion pairs Annex D.2 names.
///
/// D.2's worked example is the `5`/`S` pair: a printed `5` whose issuer value
/// is `S`.
const List<RepairConfusion> repairConfusionPairs = <RepairConfusion>[
  ('5', 'S'),
];

/// The outcome of attempting a repair.
class RepairOutcome {
  /// The value after repair, or the original reading when nothing is repaired.
  final String value;

  /// [Provenance.repaired] when exactly one repair was applied, otherwise
  /// [Provenance.read] because the original reading stands.
  final Provenance provenance;

  /// Creates a repair outcome.
  const RepairOutcome(this.value, this.provenance);

  /// A value-only string form.
  @override
  String toString() => 'RepairOutcome($value, ${provenance.wireName})';

  /// Value equality on the value and provenance.
  @override
  bool operator ==(Object other) =>
      other is RepairOutcome &&
      other.value == value &&
      other.provenance == provenance;

  @override
  int get hashCode => Object.hash(value, provenance);
}

/// Repairs [raw] against [validator] using [repairConfusionPairs].
///
/// Every single-character substitution from each pair is tried in both
/// directions. If exactly one substituted value passes [validator], that value
/// is returned with [Provenance.repaired]; two admissible repairs means none.
RepairOutcome repairIdentifier(
  String raw,
  CheckResult Function(String) validator,
) {
  if (validator(raw) == CheckResult.valid) {
    return RepairOutcome(raw, Provenance.read);
  }

  final candidates = <String>{};
  for (final (first, second) in repairConfusionPairs) {
    _addSubstitutions(candidates, raw, first, second);
    _addSubstitutions(candidates, raw, second, first);
  }

  final passing = candidates
      .where((String candidate) => validator(candidate) == CheckResult.valid)
      .toList();

  if (passing.length == 1) {
    return RepairOutcome(passing.single, Provenance.repaired);
  }
  return RepairOutcome(raw, Provenance.read);
}

void _addSubstitutions(Set<String> out, String raw, String from, String to) {
  for (var i = 0; i < raw.length; i++) {
    if (raw[i] == from) {
      out.add(raw.substring(0, i) + to + raw.substring(i + 1));
    }
  }
}
