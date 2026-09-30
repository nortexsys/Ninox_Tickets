/// Decimal convention and printed-amount inference.
///
/// Requirement served: `countries-languages` · `format-inference`. Inference
/// returns `null` when the document's own evidence does not decide; there is
/// never a default convention hidden in this file.
library;

import '../money/currency.dart';
import '../money/money.dart';

/// The decimal separator convention used by a printed amount.
enum DecimalConvention {
  /// The decimal separator is a comma (`1.234,56`).
  commaDecimal,

  /// The decimal separator is a dot (`1,234.56`).
  dotDecimal,
}

/// Infers the decimal convention from the document's own printed amounts.
///
/// A separator followed by exactly three digits and then the other separator
/// decides (`1.234,56` is comma-decimal, `1,234.56` is dot-decimal). A single
/// separator followed by exactly two digits at the end decides in favour of
/// that separator being the decimal one. A lone separator followed by exactly
/// three digits decides nothing. Contradictory evidence within one document
/// returns `null`, and no evidence returns `null`.
DecimalConvention? inferDecimalConvention(Iterable<String> printedAmounts) {
  DecimalConvention? decision;
  for (final printed in printedAmounts) {
    final evidence = _conventionFromAmount(printed);
    if (evidence == null) {
      continue;
    }
    if (decision == null) {
      decision = evidence;
    } else if (decision != evidence) {
      return null;
    }
  }
  return decision;
}

/// Parses a printed amount under [convention] and [currency].
///
/// The grouping separator of [convention] is stripped, spaces used as grouping
/// are stripped as well, the decimal separator is turned into `.`, and the
/// result is handed to [Money.parseDecimal]. Its rejections stand: more
/// fractional digits than the currency exponent return `null`, never a rounded
/// amount. A leading or trailing `-` is a negative amount.
Money? parsePrintedAmount(
  String printed,
  DecimalConvention convention,
  CurrencyCode currency,
) {
  final text = printed.trim();
  if (text.isEmpty) {
    return null;
  }

  var negative = false;
  var body = text;
  if (body.startsWith('-')) {
    negative = true;
    body = body.substring(1);
  } else if (body.endsWith('-')) {
    negative = true;
    body = body.substring(0, body.length - 1);
  }

  if (body.contains('-')) {
    return null;
  }

  body = body.replaceAll(' ', '');
  if (body.isEmpty) {
    return null;
  }

  final groupingSeparator = convention == DecimalConvention.commaDecimal
      ? '.'
      : ',';
  final decimalSeparator = convention == DecimalConvention.commaDecimal
      ? ','
      : '.';

  body = body.replaceAll(groupingSeparator, '');
  body = body.replaceAll(decimalSeparator, '.');
  if (negative) {
    body = '-$body';
  }

  try {
    return Money.parseDecimal(body, currency);
  } on FormatException {
    return null;
  } on MoneyRangeError {
    return null;
  }
}

DecimalConvention? _conventionFromAmount(String printed) {
  var text = printed.trim();
  if (text.startsWith('-') || text.endsWith('-')) {
    text = text.replaceAll('-', '');
  }
  text = text.replaceAll(' ', '');
  if (text.isEmpty) {
    return null;
  }

  final dotIndex = text.indexOf('.');
  final commaIndex = text.indexOf(',');
  final hasDot = dotIndex >= 0;
  final hasComma = commaIndex >= 0;

  if (hasDot && hasComma) {
    final first = dotIndex < commaIndex ? dotIndex : commaIndex;
    final second = dotIndex < commaIndex ? commaIndex : dotIndex;
    if (second - first == 4 && _isDigits(text.substring(first + 1, second))) {
      return text[second] == ','
          ? DecimalConvention.commaDecimal
          : DecimalConvention.dotDecimal;
    }
    return null;
  }

  if (hasDot && !hasComma) {
    if (text.indexOf('.') != text.lastIndexOf('.')) {
      return null;
    }
    final last = text.lastIndexOf('.');
    if (last == text.length - 3 && _isDigits(text.substring(last + 1))) {
      return DecimalConvention.dotDecimal;
    }
    return null;
  }

  if (hasComma && !hasDot) {
    if (text.indexOf(',') != text.lastIndexOf(',')) {
      return null;
    }
    final last = text.lastIndexOf(',');
    if (last == text.length - 3 && _isDigits(text.substring(last + 1))) {
      return DecimalConvention.commaDecimal;
    }
    return null;
  }

  return null;
}

bool _isDigits(String text) {
  if (text.isEmpty) {
    return false;
  }
  for (var i = 0; i < text.length; i++) {
    final code = text.codeUnitAt(i);
    if (code < 0x30 || code > 0x39) {
      return false;
    }
  }
  return true;
}
