/// Negative-context suppression with an influence radius.
///
/// Requirement served: `extraction-pipeline` ·
/// `negative-context-suppresses-non-tax-figures` — a figure inside the
/// influence radius of a negative dictionary term is excluded from the tax,
/// base and total roles, and a surcharge-like figure is captured as a
/// [Surcharge] with the label the dictionary hints.
library;

import '../countries/country_table.dart';
import '../dictionaries/lookup.dart';
import '../format/decimal.dart';
import '../layout/lines.dart';
import '../layout/positioned_word.dart';
import '../layout/text_page.dart';
import '../model/canonical_document.dart';
import '../model/confidence.dart';
import '../model/field_value.dart';
import '../model/provenance.dart';
import '../money/money.dart';
import 'operands.dart';

/// The influence radius of a negative term, in milli-points.
///
/// Design §4 of `implement-validation-and-extraction-core` calls this an
/// implementation constant. It lives in one place here; [applyNegativeContext]
/// accepts an override so a test can move it and watch the outcome change.
const int negativeInfluenceRadiusMilliPoints = 30000;

/// The outcome of negative-context suppression.
class NegativeContextResult {
  /// The operands that survive suppression.
  final ReadOperands kept;

  /// Surcharge-like amounts captured from figures near negative terms.
  final List<Surcharge> surcharges;

  /// The operands that were suppressed, for the tests.
  final List<ReadOperand> suppressed;

  /// Creates a negative-context result.
  const NegativeContextResult({
    required this.kept,
    required this.surcharges,
    required this.suppressed,
  });

  /// A value-only string form.
  @override
  String toString() =>
      'NegativeContextResult(kept: ${kept.operands.length}, '
      'surcharges: ${surcharges.length}, suppressed: ${suppressed.length})';

  /// Value equality on the three lists.
  @override
  bool operator ==(Object other) =>
      other is NegativeContextResult &&
      other.kept == kept &&
      _surchargeListEquals(other.surcharges, surcharges) &&
      _operandListEquals(other.suppressed, suppressed);

  @override
  int get hashCode =>
      Object.hash(kept, Object.hashAll(surcharges), Object.hashAll(suppressed));
}

/// Applies negative-context suppression to [operands].
///
/// A figure whose words lie within [radiusMilliPoints] of a negative term is
/// excluded from the tax, base, total and rate roles. When that term carries a
/// surcharge hint, the nearest non-rate amount near the term is captured as a
/// [Surcharge] instead of being left as a tax candidate.
NegativeContextResult applyNegativeContext({
  required ReadOperands operands,
  required Iterable<TextPage> pages,
  required CountryRow country,
  int radiusMilliPoints = negativeInfluenceRadiusMilliPoints,
}) {
  final terms = _negativeTerms(pages);

  final kept = <ReadOperand>[];
  final suppressed = <ReadOperand>[];
  for (final operand in operands.operands) {
    if (_withinRadiusOfAnyTerm(operand.words, terms, radiusMilliPoints)) {
      suppressed.add(operand);
    } else {
      kept.add(operand);
    }
  }

  final surcharges = _captureSurcharges(
    terms,
    pages,
    country,
    radiusMilliPoints,
  );

  return NegativeContextResult(
    kept: ReadOperands(kept),
    surcharges: surcharges,
    suppressed: suppressed,
  );
}

class _NegativeTerm {
  final List<PositionedWord> words;
  final SurchargeLabel? surchargeHint;

  const _NegativeTerm(this.words, this.surchargeHint);
}

class _CapturedAmount {
  final Money money;
  final List<PositionedWord> words;

  const _CapturedAmount(this.money, this.words);
}

List<_NegativeTerm> _negativeTerms(Iterable<TextPage> pages) {
  final terms = <_NegativeTerm>[];
  for (final page in pages) {
    final lines = groupIntoLines(page);
    for (final line in lines) {
      for (final match in findTerms(line.text)) {
        if (!match.isNegative) {
          continue;
        }
        final words = _wordsCoveredBy(line, match);
        if (words.isEmpty) {
          continue;
        }
        terms.add(_NegativeTerm(words, match.surchargeHint));
      }
    }
  }
  return terms;
}

bool _withinRadiusOfAnyTerm(
  List<PositionedWord> operandWords,
  List<_NegativeTerm> terms,
  int radius,
) {
  for (final term in terms) {
    if (_withinRadius(operandWords, term.words, radius)) {
      return true;
    }
  }
  return false;
}

List<Surcharge> _captureSurcharges(
  List<_NegativeTerm> terms,
  Iterable<TextPage> pages,
  CountryRow country,
  int radius,
) {
  final surcharges = <Surcharge>[];
  final usedWordLists = <List<PositionedWord>>[];

  for (final term in terms) {
    final hint = term.surchargeHint;
    if (hint == null) {
      continue;
    }

    final captured = _nearestAmount(term.words, pages, country, radius);
    if (captured == null) {
      continue;
    }
    if (_alreadyCaptured(usedWordLists, captured.words)) {
      continue;
    }

    usedWordLists.add(captured.words);
    surcharges.add(
      Surcharge(
        label: hint,
        amount: Present<Money>(
          captured.money,
          Provenance.read,
          ConfidenceState.amber,
        ),
      ),
    );
  }

  return surcharges;
}

_CapturedAmount? _nearestAmount(
  List<PositionedWord> termWords,
  Iterable<TextPage> pages,
  CountryRow country,
  int radius,
) {
  final radiusSquared = radius * radius;
  _CapturedAmount? best;
  var bestDistance = 0;

  for (final page in pages) {
    final lines = groupIntoLines(page);
    for (final line in lines) {
      final words = line.words;
      for (var i = 0; i < words.length; i++) {
        if (_isRateToken(words, i)) {
          continue;
        }

        final word = words[i];
        final money = parsePrintedAmount(
          word.text,
          country.decimalConvention,
          country.currency,
        );
        if (money == null) {
          continue;
        }

        final distance = _minBoxDistanceSquared(termWords, word);
        if (distance > radiusSquared) {
          continue;
        }
        if (best == null || distance < bestDistance) {
          best = _CapturedAmount(money, [word]);
          bestDistance = distance;
        }
      }
    }
  }

  return best;
}

bool _isRateToken(List<PositionedWord> words, int index) {
  final text = words[index].text;
  if (text.endsWith('%') || text == '%') {
    return true;
  }
  return index + 1 < words.length && words[index + 1].text == '%';
}

List<PositionedWord> _wordsCoveredBy(LayoutLine line, TermMatch match) {
  final covered = <PositionedWord>[];
  var cursor = 0;
  for (final word in line.words) {
    final start = cursor;
    final end = cursor + word.text.length;
    if (start < match.end && end > match.start) {
      covered.add(word);
    }
    cursor = end + 1;
  }
  return covered;
}

bool _withinRadius(
  List<PositionedWord> left,
  List<PositionedWord> right,
  int radius,
) {
  final radiusSquared = radius * radius;
  for (final leftWord in left) {
    for (final rightWord in right) {
      if (_boxDistanceSquared(leftWord, rightWord) <= radiusSquared) {
        return true;
      }
    }
  }
  return false;
}

int _minBoxDistanceSquared(List<PositionedWord> left, PositionedWord right) {
  var best = 0;
  for (var i = 0; i < left.length; i++) {
    final distance = _boxDistanceSquared(left[i], right);
    if (i == 0 || distance < best) {
      best = distance;
    }
  }
  return best;
}

int _boxDistanceSquared(PositionedWord left, PositionedWord right) {
  final dx = _edgeDistance(left.x0, left.x1, right.x0, right.x1);
  final dy = _edgeDistance(left.top, left.bottom, right.top, right.bottom);
  return dx * dx + dy * dy;
}

int _edgeDistance(int left0, int left1, int right0, int right1) {
  if (left1 < right0) {
    return right0 - left1;
  }
  if (right1 < left0) {
    return left0 - right1;
  }
  return 0;
}

bool _alreadyCaptured(
  List<List<PositionedWord>> used,
  List<PositionedWord> words,
) {
  return used.any(
    (List<PositionedWord> existing) => _wordListEquals(existing, words),
  );
}

bool _wordListEquals(List<PositionedWord> left, List<PositionedWord> right) {
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

bool _surchargeListEquals(List<Surcharge> left, List<Surcharge> right) {
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
