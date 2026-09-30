/// EAN-13 check digit validation.
///
/// Requirement served: `countries-languages` · `universal-core`
/// (`the EAN-13 check digit`). The EAN-13 check is part of the universal core
/// and does not depend on the country table.
library;

import 'check_result.dart';

/// Returns [CheckResult.valid] when [input] is a 13-digit EAN-13 whose check
/// digit matches the alternating 1/3 weights over the twelve leading digits.
///
/// A malformed input (wrong length or a non-digit) is [CheckResult.invalid],
/// never an exception.
CheckResult isValidEan13(String input) {
  if (input.length != 13) {
    return CheckResult.invalid;
  }

  for (var i = 0; i < input.length; i++) {
    final code = input.codeUnitAt(i);
    if (code < 0x30 || code > 0x39) {
      return CheckResult.invalid;
    }
  }

  var sum = 0;
  for (var i = 0; i < 12; i++) {
    final digit = input.codeUnitAt(i) - 0x30;
    sum += digit * (i.isEven ? 1 : 3);
  }

  final expectedCheckDigit = (10 - (sum % 10)) % 10;
  final actualCheckDigit = input.codeUnitAt(12) - 0x30;
  return expectedCheckDigit == actualCheckDigit
      ? CheckResult.valid
      : CheckResult.invalid;
}
