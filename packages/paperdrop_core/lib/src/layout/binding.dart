/// Binding a label to the value nearest it in the visual layout.
///
/// Requirement served: `extraction-pipeline` ·
/// `positional-pdf-text-extraction` — a label binds the value nearest it in
/// the document's visual layout, never the value nearest in extraction order.
library;

import '../countries/country_table.dart';
import '../dictionaries/lookup.dart';
import '../format/date.dart';
import '../format/decimal.dart';
import '../model/calendar_date.dart';
import '../money/money.dart';
import 'lines.dart';
import 'positioned_word.dart';
import 'text_page.dart';

/// The fixed vertical reach below a label's line, in label-line heights, that
/// [bindLabel] searches for a value on the line below.
///
/// Design §3 of `implement-validation-and-extraction-core` calls this an
/// implementation constant; beyond it the answer is "nothing".
const int maxLabelValueLineDistanceInHeights = 1;

/// The kind of value a label can bind.
enum ValueKind {
  /// A printed amount, parsed under the document's decimal convention.
  amount,

  /// A printed date, parsed under the document's date order.
  date,

  /// A document number, taken as the printed text.
  documentNumber,
}

/// A label occurrence: a [TermMatch] mapped back to the words it covers.
class LabelOccurrence {
  /// The dictionary match this occurrence came from.
  final TermMatch match;

  /// The words the [match] covers, on one visual line.
  final List<PositionedWord> words;

  /// Creates a label occurrence.
  LabelOccurrence(this.match, List<PositionedWord> wordList)
    : words = List.unmodifiable(wordList) {
    if (words.isEmpty) {
      throw ArgumentError.value(wordList, 'wordList', 'must not be empty');
    }
  }

  /// A value-only string form naming the term.
  @override
  String toString() => 'LabelOccurrence(${match.term})';

  /// Value equality on the match and words.
  @override
  bool operator ==(Object other) =>
      other is LabelOccurrence &&
      other.match == match &&
      _listEquals(other.words, words);

  @override
  int get hashCode => Object.hash(match, Object.hashAll(words));
}

/// A value bound to a label occurrence.
///
/// Exactly one of [amount], [date] or [documentNumber] is set, matching
/// [kind].
class LabelBinding {
  /// The kind of value that was bound.
  final ValueKind kind;

  /// The bound amount, when [kind] is [ValueKind.amount].
  final Money? amount;

  /// The bound date, when [kind] is [ValueKind.date].
  final CalendarDate? date;

  /// The bound document number, when [kind] is [ValueKind.documentNumber].
  final String? documentNumber;

  /// The words that carried the bound value.
  final List<PositionedWord> words;

  /// The index of the page the value was read from.
  final int pageIndex;

  LabelBinding._({
    required this.kind,
    required this.amount,
    required this.date,
    required this.documentNumber,
    required List<PositionedWord> words,
    required this.pageIndex,
  }) : words = List.unmodifiable(words);

  /// A value-only string form naming the kind and value.
  @override
  String toString() {
    final Object? value = switch (kind) {
      ValueKind.amount => amount,
      ValueKind.date => date,
      ValueKind.documentNumber => documentNumber,
    };
    return 'LabelBinding($kind, $value)';
  }

  /// Value equality on the kind, bound value, words and page index.
  @override
  bool operator ==(Object other) =>
      other is LabelBinding &&
      other.kind == kind &&
      other.amount == amount &&
      other.date == date &&
      other.documentNumber == documentNumber &&
      other.pageIndex == pageIndex &&
      _listEquals(other.words, words);

  @override
  int get hashCode => Object.hash(
    kind,
    amount,
    date,
    documentNumber,
    pageIndex,
    Object.hashAll(words),
  );
}

/// Binds [label] to the value nearest it in [page]'s visual layout.
///
/// Candidates are read under [country]'s document convention, never the
/// interface language. The label's own line is searched first, to the right
/// of the label's last word, nearest first. When that line holds no candidate
/// of [kind], the next line below that overlaps the label horizontally is
/// searched, nearest first in reading order, no further than
/// [maxLabelValueLineDistanceInHeights] label-line heights below. Nothing
/// binds from above the label or from its left.
LabelBinding? bindLabel(
  LabelOccurrence label,
  TextPage page,
  ValueKind kind,
  CountryRow country,
) {
  final lines = groupIntoLines(page);
  final labelLine = _lineContaining(lines, label.words);
  if (labelLine == null) {
    return null;
  }

  final labelLeft = _minX(label.words);
  final labelRight = _maxX1(label.words);

  final sameLine = _bindOnLine(
    _wordsToTheRight(labelLine.words, labelRight),
    kind,
    country,
    page.index,
  );
  if (sameLine != null) {
    return sameLine;
  }

  final maxGap = maxLabelValueLineDistanceInHeights * labelLine.height;
  for (final line in lines) {
    if (line.top <= labelLine.bottom) {
      continue;
    }
    if (line.top - labelLine.bottom > maxGap) {
      break;
    }
    if (!_horizontallyOverlaps(line, labelLeft, labelRight)) {
      continue;
    }

    final below = _bindOnLine(
      _wordsNotLeftOf(line.words, labelLeft),
      kind,
      country,
      page.index,
    );
    if (below != null) {
      return below;
    }
  }

  return null;
}

LayoutLine? _lineContaining(
  List<LayoutLine> lines,
  List<PositionedWord> labelWords,
) {
  for (final line in lines) {
    if (labelWords.every(
      (PositionedWord word) =>
          line.words.any((PositionedWord lineWord) => lineWord == word),
    )) {
      return line;
    }
  }
  return null;
}

List<PositionedWord> _wordsToTheRight(
  List<PositionedWord> words,
  MilliPoint rightEdge,
) {
  final result = words
      .where((PositionedWord word) => word.x0 >= rightEdge)
      .toList();
  result.sort(_byX0);
  return result;
}

List<PositionedWord> _wordsNotLeftOf(
  List<PositionedWord> words,
  MilliPoint leftEdge,
) {
  final result = words
      .where((PositionedWord word) => word.x1 > leftEdge)
      .toList();
  result.sort(_byX0);
  return result;
}

bool _horizontallyOverlaps(
  LayoutLine line,
  MilliPoint left,
  MilliPoint right,
) => line.x1 > left && line.x0 < right;

LabelBinding? _bindOnLine(
  List<PositionedWord> candidates,
  ValueKind kind,
  CountryRow country,
  int pageIndex,
) {
  final ordered = [...candidates]..sort(_byX0);
  for (var start = 0; start < ordered.length; start++) {
    for (var length = 1; start + length <= ordered.length; length++) {
      final run = ordered.sublist(start, start + length);
      final binding = _bindingForRun(run, kind, country, pageIndex);
      if (binding != null) {
        return binding;
      }
    }
  }
  return null;
}

LabelBinding? _bindingForRun(
  List<PositionedWord> run,
  ValueKind kind,
  CountryRow country,
  int pageIndex,
) {
  final text = run.map((PositionedWord word) => word.text).join(' ');
  switch (kind) {
    case ValueKind.amount:
      final money = parsePrintedAmount(
        text,
        country.decimalConvention,
        country.currency,
      );
      if (money == null) {
        return null;
      }
      return LabelBinding._(
        kind: kind,
        amount: money,
        date: null,
        documentNumber: null,
        words: run,
        pageIndex: pageIndex,
      );
    case ValueKind.date:
      final date = parsePrintedDate(text, country.dateOrder);
      if (date == null) {
        return null;
      }
      return LabelBinding._(
        kind: kind,
        amount: null,
        date: date,
        documentNumber: null,
        words: run,
        pageIndex: pageIndex,
      );
    case ValueKind.documentNumber:
      if (text.isEmpty) {
        return null;
      }
      return LabelBinding._(
        kind: kind,
        amount: null,
        date: null,
        documentNumber: text,
        words: run,
        pageIndex: pageIndex,
      );
  }
}

int _minX(List<PositionedWord> list) => list
    .map((PositionedWord word) => word.x0)
    .reduce((int a, int b) => a < b ? a : b);

int _maxX1(List<PositionedWord> list) => list
    .map((PositionedWord word) => word.x1)
    .reduce((int a, int b) => a > b ? a : b);

int _byX0(PositionedWord left, PositionedWord right) =>
    left.x0.compareTo(right.x0);

bool _listEquals(List<PositionedWord> left, List<PositionedWord> right) {
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
