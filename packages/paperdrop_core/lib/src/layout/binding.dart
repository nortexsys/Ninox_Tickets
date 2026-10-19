/// Binding a label to the value nearest it in the visual layout.
///
/// Requirement served: `extraction-pipeline` ·
/// `positional-pdf-text-extraction` — a label binds the value nearest it in
/// the document's visual layout, never the value nearest in extraction order.
library;

import '../countries/country_table.dart';
import '../dictionaries/lookup.dart';
import '../extraction/extraction_trace.dart';
import '../format/date.dart';
import '../format/decimal.dart';
import '../model/calendar_date.dart';
import '../money/currency.dart';
import '../money/money.dart';
import 'lines.dart';
import 'positioned_word.dart';
import 'text_page.dart';

/// The fixed vertical reach below a label's line, in label-line heights, that
/// [bindLabel] searches for a value on the line below.
///
/// Design §3 of `implement-validation-and-extraction-core` calls this an
/// implementation constant; beyond it the answer is "nothing". Two line
/// heights covers a label row separated from its value by a small gutter
/// (for example a supplier block's `DATOS DEL EMISOR` header above the name
/// line).
const int maxLabelValueLineDistanceInHeights = 2;

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
/// [kind]. [sameLine] records whether the value sat on the label's own visual
/// line; a same-line value is nearer than a value on the line below.
class LabelBinding {
  /// The kind of value that was bound.
  final ValueKind kind;

  /// The bound amount, when [kind] is [ValueKind.amount].
  final Money? amount;

  /// The bound date, when [kind] is [ValueKind.date].
  final CalendarDate? date;

  /// The bound document number, when [kind] is [ValueKind.documentNumber].
  final String? documentNumber;

  /// Whether the bound value sat on the label's own visual line.
  final bool sameLine;

  /// The words that carried the bound value.
  final List<PositionedWord> words;

  /// The index of the page the value was read from.
  final int pageIndex;

  LabelBinding._({
    required this.kind,
    required this.amount,
    required this.date,
    required this.documentNumber,
    required this.sameLine,
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

  /// Value equality on the kind, bound value, words, line origin and page index.
  @override
  bool operator ==(Object other) =>
      other is LabelBinding &&
      other.kind == kind &&
      other.amount == amount &&
      other.date == date &&
      other.documentNumber == documentNumber &&
      other.sameLine == sameLine &&
      other.pageIndex == pageIndex &&
      _listEquals(other.words, words);

  @override
  int get hashCode => Object.hash(
    kind,
    amount,
    date,
    documentNumber,
    sameLine,
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
  CountryRow? country, {
  DecimalConvention? decimalConvention,
  DateOrder? dateOrder,
  CurrencyCode? currency,
  ExtractionTrace? trace,
  String? traceField,
}) {
  final convention = decimalConvention ?? country?.decimalConvention;
  final dateOrderValue = dateOrder ?? country?.dateOrder;
  final currencyCode = currency ?? country?.currency;

  final lines = groupIntoLines(page);
  final labelLine = _lineContaining(lines, label.words);
  if (labelLine == null) {
    _recordBindingFailure(trace, traceField, kind, sawCandidate: false);
    return null;
  }

  final labelLeft = _minX(label.words);
  final labelRight = _maxX1(label.words);
  final traceActive = trace != null && traceField != null;

  final sameLineCandidates = _wordsToTheRight(labelLine.words, labelRight);
  final sameLine = _bindOnLine(
    sameLineCandidates,
    kind,
    convention,
    dateOrderValue,
    currencyCode,
    page.index,
    sameLine: true,
  );
  if (sameLine != null) {
    return sameLine;
  }

  var sawCandidate = traceActive && sameLineCandidates.isNotEmpty;

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

    // A document-number or supplier-name label may sit above a value line
    // that starts left of the label (for example `DATOS DEL EMISOR` above the
    // full `NORTEX DIGITAL, S.L.` line). For those text values the whole line
    // is the candidate; for amount and date columns the right-aligned part
    // keeps the column association.
    final belowCandidates = kind == ValueKind.documentNumber
        ? line.words
        : _wordsNotLeftOf(line.words, labelLeft);
    if (traceActive && belowCandidates.isNotEmpty) {
      sawCandidate = true;
    }
    final below = _bindOnLine(
      belowCandidates,
      kind,
      convention,
      dateOrderValue,
      currencyCode,
      page.index,
      sameLine: false,
    );
    if (below != null) {
      return below;
    }
  }

  _recordBindingFailure(trace, traceField, kind, sawCandidate: sawCandidate);
  return null;
}

void _recordBindingFailure(
  ExtractionTrace? trace,
  String? traceField,
  ValueKind kind, {
  required bool sawCandidate,
}) {
  if (trace == null || traceField == null) {
    return;
  }
  final stage = switch (kind) {
    ValueKind.amount || ValueKind.date =>
      sawCandidate
          ? ExtractionStage.valueNotParsed
          : ExtractionStage.labelFoundNoValue,
    ValueKind.documentNumber => ExtractionStage.labelFoundNoValue,
  };
  trace.record(traceField, stage);
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
  DecimalConvention? decimalConvention,
  DateOrder? dateOrder,
  CurrencyCode? currency,
  int pageIndex, {
  required bool sameLine,
}) {
  final sorted = [...candidates]..sort(_byX0);
  final ordered = kind == ValueKind.amount
      ? _withoutRateTokens(sorted)
      : sorted;

  // A document-number or supplier-name value read from the line below is the
  // whole line, not the first token. On the label's own line the existing
  // nearest-token behaviour stays: `Nº ND-2026-0047` binds `ND-2026-0047`.
  if (kind == ValueKind.documentNumber && !sameLine) {
    final text = ordered.map((PositionedWord word) => word.text).join(' ');
    if (text.isEmpty) {
      return null;
    }
    return LabelBinding._(
      kind: kind,
      amount: null,
      date: null,
      documentNumber: text,
      sameLine: sameLine,
      words: ordered,
      pageIndex: pageIndex,
    );
  }

  for (var start = 0; start < ordered.length; start++) {
    for (var length = 1; start + length <= ordered.length; length++) {
      final run = ordered.sublist(start, start + length);
      final binding = _bindingForRun(
        run,
        kind,
        decimalConvention,
        dateOrder,
        currency,
        pageIndex,
        sameLine: sameLine,
      );
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
  DecimalConvention? decimalConvention,
  DateOrder? dateOrder,
  CurrencyCode? currency,
  int pageIndex, {
  required bool sameLine,
}) {
  final text = run.map((PositionedWord word) => word.text).join(' ');
  switch (kind) {
    case ValueKind.amount:
      if (decimalConvention == null || currency == null) {
        return null;
      }
      final money = parsePrintedAmount(text, decimalConvention, currency);
      if (money == null) {
        return null;
      }
      return LabelBinding._(
        kind: kind,
        amount: money,
        date: null,
        documentNumber: null,
        sameLine: sameLine,
        words: run,
        pageIndex: pageIndex,
      );
    case ValueKind.date:
      if (dateOrder == null) {
        return null;
      }
      final date = parsePrintedDate(text, dateOrder);
      if (date == null) {
        return null;
      }
      return LabelBinding._(
        kind: kind,
        amount: null,
        date: date,
        documentNumber: null,
        sameLine: sameLine,
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
        sameLine: sameLine,
        words: run,
        pageIndex: pageIndex,
      );
  }
}

List<PositionedWord> _withoutRateTokens(List<PositionedWord> words) {
  final result = <PositionedWord>[];
  var i = 0;
  while (i < words.length) {
    final word = words[i];
    if (word.text.endsWith('%') || word.text == '%') {
      i++;
      continue;
    }
    if (i + 1 < words.length && words[i + 1].text == '%') {
      i += 2;
      continue;
    }
    result.add(word);
    i++;
  }
  return result;
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
