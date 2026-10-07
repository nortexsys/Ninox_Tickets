/// The legal-rate gate before any derivation.
///
/// Requirement served: `extraction-pipeline` ·
/// `legal-rate-gate-before-derivation` — a printed rate is admitted only when
/// the detected country's legal set contains it, and a rejected rate is
/// discarded rather than used.
library;

import '../countries/country_table.dart';
import '../money/rate.dart';
import 'operands.dart';

/// Whether [rate] is admitted for [country].
///
/// The gate delegates to [CountryRow.isLegalRate]; no rate is ever assumed.
bool admitPrintedRate(RateBp rate, CountryRow country) =>
    country.isLegalRate(rate);

/// The outcome of gating printed rate operands.
class RateGateResult {
  /// The rate operands admitted by the country's legal set.
  final List<ReadOperand> admitted;

  /// The rate operands discarded; they take no part in any later step.
  final List<ReadOperand> discarded;

  /// Creates a rate-gate result.
  const RateGateResult({required this.admitted, required this.discarded});

  /// A value-only string form naming both counts.
  @override
  String toString() =>
      'RateGateResult(admitted: ${admitted.length}, '
      'discarded: ${discarded.length})';

  /// Value equality on both lists.
  @override
  bool operator ==(Object other) =>
      other is RateGateResult &&
      _operandListEquals(other.admitted, admitted) &&
      _operandListEquals(other.discarded, discarded);

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(admitted), Object.hashAll(discarded));
}

/// Splits printed rate operands into admitted and discarded for [country].
///
/// A discarded rate takes no part in any later step.
RateGateResult gatePrintedRates(
  Iterable<ReadOperand> rates,
  CountryRow country,
) {
  final admitted = <ReadOperand>[];
  final discarded = <ReadOperand>[];

  for (final operand in rates) {
    final rate = operand.rate;
    if (rate != null && country.isLegalRate(rate)) {
      admitted.add(operand);
    } else {
      discarded.add(operand);
    }
  }

  return RateGateResult(
    admitted: List.unmodifiable(admitted),
    discarded: List.unmodifiable(discarded),
  );
}

bool _operandListEquals(List<ReadOperand> left, List<ReadOperand> right) {
  if (left.length != right.length) {
    return false;
  }
  for (var i = 0; i < left.length; i++) {
    if (left[i] != right[i]) {
      return false;
    }
  }
  return true;
}
