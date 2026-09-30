/// Date order and printed-date inference.
///
/// Requirement served: `countries-languages` · `format-inference`. The enum is
/// defined here so the country table can declare each row's date order; the
/// inference and parsing functions are added with the format-inference task.
library;

/// The order of day, month and year components in a printed date.
enum DateOrder {
  /// Day, month, year.
  dmy,

  /// Month, day, year.
  mdy,

  /// Year, month, day.
  ymd,
}
