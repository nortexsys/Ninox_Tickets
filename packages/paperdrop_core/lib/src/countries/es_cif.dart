/// The Spanish CIF check digit.
///
/// Requirement served: `countries-languages` ·
/// `three-spanish-formats-are-three-algorithms`. This file shares no code with
/// the NIF or NIE algorithms.
library;

import '../checks/check_result.dart';

const String _cifControlLetters = 'JABCDEFGHI';
const String _letterControlIssuers = 'NPQRSW';

final RegExp _cifShape = RegExp(r'^[ABCDEFGHJNPQRSUVW][0-9]{7}[0-9A-J]$');

/// Validates a normalised `ES_CIF` (issuing letter + 7 digits + control).
///
/// The weighted sum multiplies the digits in odd positions (1st, 3rd, 5th and
/// 7th) by two and sums the digits of each product; even positions are added as
/// printed. The control is `(10 - sum mod 10) mod 10`. For issuing letters
/// `N P Q R S W` the control must be the corresponding letter of
/// `JABCDEFGHI`; for every other issuing letter it must be the digit.
///
/// A malformed input is [CheckResult.invalid], never an exception.
CheckResult isValidEsCif(String normalised) {
  if (!_cifShape.hasMatch(normalised)) {
    return CheckResult.invalid;
  }

  final issuingLetter = normalised.substring(0, 1);
  final digits = normalised.substring(1, 8);

  var sum = 0;
  for (var i = 0; i < digits.length; i++) {
    final digit = digits.codeUnitAt(i) - 0x30;
    if ((i + 1).isOdd) {
      final product = digit * 2;
      sum += (product ~/ 10) + (product % 10);
    } else {
      sum += digit;
    }
  }

  final controlValue = (10 - (sum % 10)) % 10;
  final actualControl = normalised.substring(8);

  final expectedControl = _letterControlIssuers.contains(issuingLetter)
      ? _cifControlLetters[controlValue]
      : '$controlValue';

  return actualControl == expectedControl
      ? CheckResult.valid
      : CheckResult.invalid;
}
