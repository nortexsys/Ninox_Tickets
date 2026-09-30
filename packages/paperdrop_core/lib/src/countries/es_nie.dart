/// The Spanish NIE check digit.
///
/// Requirement served: `countries-languages` ·
/// `three-spanish-formats-are-three-algorithms`. This file shares no code with
/// the NIF or CIF algorithms; it has its own copy of the mod-23 letter table.
library;

import '../checks/check_result.dart';

const String _nieLetters = 'TRWAGMYFPDXBNJZSQVHLCKE';

const Map<String, int> _leadingLetterValue = <String, int>{
  'X': 0,
  'Y': 1,
  'Z': 2,
};

final RegExp _nieShape = RegExp(r'^[XYZ][0-9]{7}[A-Z]$');

/// Validates a normalised `ES_NIE` (`X`/`Y`/`Z` + 7 digits + letter).
///
/// The leading letter is replaced by 0, 1 or 2 respectively, then the mod-23
/// letter is applied by this NIE implementation, not the NIF one. A malformed
/// input is [CheckResult.invalid], never an exception.
CheckResult isValidEsNie(String normalised) {
  if (!_nieShape.hasMatch(normalised)) {
    return CheckResult.invalid;
  }

  final leadingValue = _leadingLetterValue[normalised.substring(0, 1)]!;
  final numericPart = int.parse('$leadingValue${normalised.substring(1, 8)}');
  final expectedLetter = _nieLetters[numericPart % 23];
  final actualLetter = normalised.substring(8);

  return actualLetter == expectedLetter
      ? CheckResult.valid
      : CheckResult.invalid;
}
