/// Grouping positioned words into visual lines.
///
/// Requirement served: `extraction-pipeline` ·
/// `positional-pdf-text-extraction` — the line model is the visual layout the
/// binding rule reasons over, independent of the order words arrived in.
library;

import 'positioned_word.dart';
import 'text_page.dart';

/// A visual line of [PositionedWord]s on one [TextPage].
///
/// Words are ordered by `x0` and lines are ordered by `top`; neither order is
/// the extraction order. Gaps between words are not interpreted: [text] joins
/// the words with one space.
class LayoutLine {
  /// The index of the page this line belongs to.
  final int pageIndex;

  /// The words on this line, ordered by `x0`.
  final List<PositionedWord> words;

  /// Creates a line from [wordList], ordered by `x0`.
  LayoutLine(this.pageIndex, List<PositionedWord> wordList)
    : words = _sortedByX0(wordList) {
    if (words.isEmpty) {
      throw ArgumentError.value(wordList, 'wordList', 'must not be empty');
    }
  }

  /// The line text: words joined by one space. Gaps are not interpreted.
  String get text => words.map((PositionedWord word) => word.text).join(' ');

  /// The bounding box's left edge, in milli-points.
  MilliPoint get x0 => _minX(words);

  /// The bounding box's right edge, in milli-points.
  MilliPoint get x1 => _maxX1(words);

  /// The bounding box's top edge, in milli-points.
  MilliPoint get top => _minTop(words);

  /// The bounding box's bottom edge, in milli-points.
  MilliPoint get bottom => _maxBottom(words);

  /// The bounding box's width, in milli-points.
  MilliPoint get width => x1 - x0;

  /// The bounding box's height, in milli-points.
  MilliPoint get height => bottom - top;

  /// A value-only string form.
  @override
  String toString() => 'LayoutLine(page $pageIndex, "$text")';

  /// Value equality on the page index and words.
  @override
  bool operator ==(Object other) {
    if (other is! LayoutLine) {
      return false;
    }
    return other.pageIndex == pageIndex && _listEquals(other.words, words);
  }

  @override
  int get hashCode => Object.hash(pageIndex, Object.hashAll(words));
}

/// Groups [page]'s words into visual lines.
///
/// The arrival order of [TextPage.words] is ignored: words are sorted by
/// `top`, then `x0`. A word joins the current line when its vertical interval
/// overlaps the line's by at least half of the shorter of the two heights,
/// in integer arithmetic: `2 * overlap >= min(heightA, heightB)`. Words of a
/// line are ordered by `x0` and lines are ordered by their `top`.
List<LayoutLine> groupIntoLines(TextPage page) {
  final sorted = [...page.words]..sort(_byTopThenX0);

  final lines = <LayoutLine>[];
  var current = <PositionedWord>[];
  var currentTop = 0;
  var currentBottom = 0;

  for (final word in sorted) {
    if (current.isEmpty) {
      current.add(word);
      currentTop = word.top;
      currentBottom = word.bottom;
      continue;
    }

    if (_joinsLine(word, currentTop, currentBottom)) {
      current.add(word);
      if (word.top < currentTop) {
        currentTop = word.top;
      }
      if (word.bottom > currentBottom) {
        currentBottom = word.bottom;
      }
    } else {
      lines.add(LayoutLine(page.index, current));
      current = [word];
      currentTop = word.top;
      currentBottom = word.bottom;
    }
  }

  if (current.isNotEmpty) {
    lines.add(LayoutLine(page.index, current));
  }

  lines.sort(_byTopThenX0ForLines);
  return lines;
}

/// Whether [word] joins a line spanning [lineTop]..[lineBottom].
///
/// The half-height rule lives in this one place (design §3): a word joins the
/// line when `2 * overlap >= min(word.height, line.height)`, computed without
/// division or rounding.
bool _joinsLine(
  PositionedWord word,
  MilliPoint lineTop,
  MilliPoint lineBottom,
) {
  final lineHeight = lineBottom - lineTop;
  final wordHeight = word.bottom - word.top;
  final overlap = _verticalOverlap(word.top, word.bottom, lineTop, lineBottom);
  final shorterHeight = wordHeight < lineHeight ? wordHeight : lineHeight;
  return 2 * overlap >= shorterHeight;
}

int _verticalOverlap(
  MilliPoint topA,
  MilliPoint bottomA,
  MilliPoint topB,
  MilliPoint bottomB,
) {
  final overlapTop = topA > topB ? topA : topB;
  final overlapBottom = bottomA < bottomB ? bottomA : bottomB;
  final overlap = overlapBottom - overlapTop;
  return overlap > 0 ? overlap : 0;
}

int _minX(List<PositionedWord> list) => list
    .map((PositionedWord word) => word.x0)
    .reduce((int a, int b) => a < b ? a : b);

int _maxX1(List<PositionedWord> list) => list
    .map((PositionedWord word) => word.x1)
    .reduce((int a, int b) => a > b ? a : b);

int _minTop(List<PositionedWord> list) => list
    .map((PositionedWord word) => word.top)
    .reduce((int a, int b) => a < b ? a : b);

int _maxBottom(List<PositionedWord> list) => list
    .map((PositionedWord word) => word.bottom)
    .reduce((int a, int b) => a > b ? a : b);

List<PositionedWord> _sortedByX0(List<PositionedWord> wordList) {
  final sorted = [...wordList];
  sorted.sort(_byX0);
  return List.unmodifiable(sorted);
}

int _byX0(PositionedWord left, PositionedWord right) =>
    left.x0.compareTo(right.x0);

int _byTopThenX0(PositionedWord left, PositionedWord right) {
  final byTop = left.top.compareTo(right.top);
  if (byTop != 0) {
    return byTop;
  }
  return left.x0.compareTo(right.x0);
}

int _byTopThenX0ForLines(LayoutLine left, LayoutLine right) {
  final byTop = left.top.compareTo(right.top);
  if (byTop != 0) {
    return byTop;
  }
  return left.x0.compareTo(right.x0);
}

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
