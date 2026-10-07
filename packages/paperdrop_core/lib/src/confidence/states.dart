/// Confidence state assignment.
///
/// Requirement served: `validation-confidence` ·
/// `three-confidence-strengths`,
/// `a-check-confirms-only-if-every-operand-was-read`,
/// `what-never-reaches-green` and
/// `currency-carries-its-own-confidence-state`. The numeric recognition score
/// is stored separately and never influences the state.
library;

import '../model/confidence.dart';
import '../model/field_value.dart';
import '../model/provenance.dart';
import '../money/currency.dart';
import '../money/money.dart';

/// The kind of field a state is assigned to.
enum FieldKind {
  /// A money amount.
  amount,

  /// The document currency.
  currency,

  /// A tax identifier.
  taxId,

  /// A document number.
  docNumber,

  /// A supplier name.
  supplierName,

  /// Any other field.
  other,
}

/// The result of evaluating a redundancy check over its operands.
enum CheckOutcome {
  /// No check was evaluated.
  none,

  /// The check passed and every operand may confirm.
  passed,

  /// The arithmetic passed but a `derived` operand made it non-confirmatory.
  nonConfirmatory,

  /// The check failed.
  failed,
}

/// Evaluates a redundancy check from its arithmetic result and operands.
///
/// A check confirms only when [arithmeticPassed] is true and every [operands]
/// provenance [Provenance.mayConfirm]s.
CheckOutcome checkOutcome({
  required bool arithmeticPassed,
  required List<Provenance> operands,
}) {
  if (!arithmeticPassed) {
    return CheckOutcome.failed;
  }
  return operands.every((Provenance provenance) => provenance.mayConfirm)
      ? CheckOutcome.passed
      : CheckOutcome.nonConfirmatory;
}

/// Assigns the confidence state for a field.
///
/// [score] is stored on the value but is deliberately never read: no state is
/// computed from a numeric recognition score. `doc_number` and, in the MVP,
/// `supplier_name` are never green.
ConfidenceState assignConfidence({
  required FieldKind kind,
  CheckOutcome check = CheckOutcome.none,
  bool repaired = false,
  bool checkDigitConsistent = false,
  int score = 0,
}) {
  if (kind == FieldKind.docNumber || kind == FieldKind.supplierName) {
    return ConfidenceState.amber;
  }

  if (check == CheckOutcome.passed) {
    return ConfidenceState.green;
  }
  if (check == CheckOutcome.failed) {
    return ConfidenceState.red;
  }

  // A non-confirmatory check, a repaired value, a check-digit-consistent
  // identifier, and an amount with nothing to cross against are all amber.
  return ConfidenceState.amber;
}

/// Suppresses every amount when [currency] is not sustained.
///
/// A sustained currency is a [Present] currency; any other currency state
/// turns each amount into [Absent], independently of the amount's own state.
List<FieldValue<Money>> applyCurrencyGate(
  FieldValue<CurrencyCode> currency,
  List<FieldValue<Money>> amounts,
) {
  final sustained = currency is Present<CurrencyCode>;
  return <FieldValue<Money>>[
    for (final amount in amounts)
      if (sustained) amount else const Absent<Money>(),
  ];
}
