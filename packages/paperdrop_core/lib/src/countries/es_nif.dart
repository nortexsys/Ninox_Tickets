/// The Spanish NIF check digit.
///
/// Requirement served: `countries-languages` ·
/// `three-spanish-formats-are-three-algorithms`. This file shares no code with
/// the NIE or CIF algorithms; the mod-23 letter table below is its own copy.
library;

import '../checks/check_result.dart';

const String _nifLetters = 'TRWAGMYFPDXBNJZSQVHLCKE';

final RegExp _nifShape = RegExp(r'^[0-9]{8}[A-Z]$');

/// Validates a normalised `ES_NIF` (8 digits + letter).
///
/// The letter is the numeric part modulo 23 over
/// `TRWAGMYFPDXBNJZSQVHLCKE`. A malformed input is [CheckResult.invalid],
/// never an exception.
CheckResult isValidEsNif(String normalised) {
  if (!_nifShape.hasMatch(normalised)) {
    return CheckResult.invalid;
  }

  final numericPart = int.parse(normalised.substring(0, 8));
  final expectedLetter = _nifLetters[numericPart % 23];
  final actualLetter = normalised.substring(8);

  return actualLetter == expectedLetter
      ? CheckResult.valid
      : CheckResult.invalid;
}
