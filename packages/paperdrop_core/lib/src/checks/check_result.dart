/// The verdict of a check-digit or identifier validator.
///
/// Requirement served: FR-VAL-005 (`check-digit-validators`) — a validator
/// returns a verdict, not a bool, so the confidence rules of a later task can
/// tell "checked and valid" from "not checkable".
library;

/// The result of validating a value against a check-digit algorithm.
enum CheckResult {
  /// The value matches the algorithm.
  valid,

  /// The value does not match the algorithm.
  invalid,

  /// The value's type has no reliable algorithm, so nothing was checked.
  notChecked,
}
