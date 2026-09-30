/// The dictionary matcher.
///
/// Requirement served: `countries-languages` ·
/// `document-dictionaries-are-separate-from-interface-language` and
/// `extraction-pipeline` · `multilingual-label-dictionaries` (the lookup
/// half). The matcher consults every language's seeds regardless of any
/// interface language; it never reads a locale.
library;

import '../model/canonical_document.dart';
import 'labels.dart';
import 'negative.dart';

/// One dictionary match in a line.
class TermMatch {
  /// The term exactly as stored in the dictionary.
  final String term;

  /// The label kind for a positive match, or `null` for a negative match.
  final LabelKind? kind;

  /// The surcharge hint for a negative match, or `null`.
  final SurchargeLabel? surchargeHint;

  /// The ISO 639-1 language code of the dictionary term that matched.
  final String language;

  /// The start index of the match in the original line.
  final int start;

  /// The end index of the match in the original line.
  final int end;

  /// Creates a term match.
  const TermMatch({
    required this.term,
    required this.kind,
    required this.surchargeHint,
    required this.language,
    required this.start,
    required this.end,
  });

  /// Whether this is a negative-context match.
  bool get isNegative => kind == null;

  /// A value-only string form.
  @override
  String toString() =>
      'TermMatch($term, ${kind ?? 'negative'}, $language, $start-$end)';

  /// Value equality on every field.
  @override
  bool operator ==(Object other) =>
      other is TermMatch &&
      other.term == term &&
      other.kind == kind &&
      other.surchargeHint == surchargeHint &&
      other.language == language &&
      other.start == start &&
      other.end == end;

  @override
  int get hashCode =>
      Object.hash(term, kind, surchargeHint, language, start, end);
}

/// Finds every dictionary term in [line].
///
/// Matching is case-insensitive with Unicode-aware lower-casing, whitespace
/// runs are collapsed, and only whole words match: `tip` does not match inside
/// `tipo`, `HT` does not match inside `HTTP`, and `Tomo` does not match inside
/// `Tomorrow`. A longer term wins over a shorter one at the same position
/// (`TOTAL A PAGAR` over `TOTAL`).
List<TermMatch> findTerms(String line) {
  final normalizedLine = _normalizeLine(line);
  final entries = <_Entry>[
    for (final label in labelTerms)
      for (final language in label.languages)
        _Entry(
          _normalizeTerm(label.term),
          label.term,
          label.kind,
          null,
          language,
        ),
    for (final negative in negativeTerms)
      for (final language in negative.languages)
        _Entry(
          _normalizeTerm(negative.term),
          negative.term,
          null,
          negative.surchargeHint,
          language,
        ),
  ];
  entries.sort(_compareEntries);

  final matches = <TermMatch>[];
  for (final entry in entries) {
    var index = 0;
    while (index < normalizedLine.text.length) {
      final found = normalizedLine.text.indexOf(entry.normalized, index);
      if (found < 0) {
        break;
      }

      final end = found + entry.normalized.length;
      if (_isWordBoundary(normalizedLine.text, found, end)) {
        final start = normalizedLine.startMap[found];
        final originalEnd = normalizedLine.endMap[end - 1];
        final longerAtSameStart = matches.any(
          (match) =>
              match.start == start &&
              (match.end - match.start) > (originalEnd - start),
        );
        if (!longerAtSameStart) {
          matches.add(
            TermMatch(
              term: entry.raw,
              kind: entry.kind,
              surchargeHint: entry.surchargeHint,
              language: entry.language,
              start: start,
              end: originalEnd,
            ),
          );
        }
      }

      index = found + entry.normalized.length;
    }
  }

  matches.sort(_compareMatches);
  return matches;
}

class _Entry {
  final String normalized;
  final String raw;
  final LabelKind? kind;
  final SurchargeLabel? surchargeHint;
  final String language;

  const _Entry(
    this.normalized,
    this.raw,
    this.kind,
    this.surchargeHint,
    this.language,
  );
}

class _NormalizedLine {
  final String text;
  final List<int> startMap;
  final List<int> endMap;

  const _NormalizedLine(this.text, this.startMap, this.endMap);
}

_NormalizedLine _normalizeLine(String line) {
  final buffer = StringBuffer();
  final starts = <int>[];
  final ends = <int>[];
  var i = 0;
  while (i < line.length) {
    final code = line.codeUnitAt(i);
    if (_isWhitespaceCode(code)) {
      final start = i;
      while (i < line.length && _isWhitespaceCode(line.codeUnitAt(i))) {
        i++;
      }
      buffer.write(' ');
      starts.add(start);
      ends.add(i);
    } else {
      buffer.write(line[i]);
      starts.add(i);
      ends.add(i + 1);
      i++;
    }
  }
  return _NormalizedLine(buffer.toString().toLowerCase(), starts, ends);
}

String _normalizeTerm(String term) =>
    term.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

bool _isWhitespaceCode(int code) =>
    code == 0x20 || code == 0x09 || code == 0x0A || code == 0x0D;

bool _isWordCode(int code) =>
    (code >= 0x30 && code <= 0x39) ||
    (code >= 0x41 && code <= 0x5A) ||
    (code >= 0x61 && code <= 0x7A) ||
    code >= 0x80;

bool _isWordBoundary(String text, int start, int end) {
  final beforeOk = start == 0 || !_isWordCode(text.codeUnitAt(start - 1));
  final afterOk = end >= text.length || !_isWordCode(text.codeUnitAt(end));
  return beforeOk && afterOk;
}

int _compareEntries(_Entry left, _Entry right) {
  final byLength = right.normalized.length.compareTo(left.normalized.length);
  if (byLength != 0) {
    return byLength;
  }
  final byText = left.normalized.compareTo(right.normalized);
  if (byText != 0) {
    return byText;
  }
  final byRaw = left.raw.compareTo(right.raw);
  if (byRaw != 0) {
    return byRaw;
  }
  final byLanguage = left.language.compareTo(right.language);
  if (byLanguage != 0) {
    return byLanguage;
  }
  final byKind = _kindIndex(left.kind).compareTo(_kindIndex(right.kind));
  if (byKind != 0) {
    return byKind;
  }
  return _hintIndex(left.surchargeHint)
      .compareTo(_hintIndex(right.surchargeHint));
}

int _compareMatches(TermMatch left, TermMatch right) {
  final byStart = left.start.compareTo(right.start);
  if (byStart != 0) {
    return byStart;
  }
  final byLength = (right.end - right.start).compareTo(left.end - left.start);
  if (byLength != 0) {
    return byLength;
  }
  final byTerm = left.term.compareTo(right.term);
  if (byTerm != 0) {
    return byTerm;
  }
  final byLanguage = left.language.compareTo(right.language);
  if (byLanguage != 0) {
    return byLanguage;
  }
  return _kindIndex(left.kind).compareTo(_kindIndex(right.kind));
}

int _kindIndex(LabelKind? kind) => kind?.index ?? -1;

int _hintIndex(SurchargeLabel? hint) => hint?.index ?? -1;
