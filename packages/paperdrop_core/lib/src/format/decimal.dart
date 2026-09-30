/// Decimal convention and printed-amount inference.
///
/// Requirement served: `countries-languages` · `format-inference`. The enum is
/// defined here so the country table can declare each row's convention; the
/// inference and parsing functions are added with the format-inference task.
library;

/// The decimal separator convention used by a printed amount.
enum DecimalConvention {
  /// The decimal separator is a comma (`1.234,56`).
  commaDecimal,

  /// The decimal separator is a dot (`1,234.56`).
  dotDecimal,
}
