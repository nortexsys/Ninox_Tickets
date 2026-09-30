/// Date order and printed-date inference.
///
/// Requirement served: `countries-languages` · `format-inference` and
/// `validation-confidence` · `date-coherence-and-ambiguity` on the format side
/// only: an undecided date order is returned as `null` so the caller can flag
/// it. There is never a default order hidden in this file.
library;

import '../model/calendar_date.dart';

/// The order of day, month and year components in a printed date.
enum DateOrder {
  /// Day, month, year.
  dmy,

  /// Month, day, year.
  mdy,

  /// Year, month, day.
  ymd,
}

final RegExp _datePattern = RegExp(r'^([0-9]+)([./-])([0-9]+)\2([0-9]+)$');

/// Infers the date order from the document's own printed dates.
///
/// Four leading digits mean [DateOrder.ymd]. Otherwise a first component
/// greater than 12 means [DateOrder.dmy], and a second component greater than
/// 12 means [DateOrder.mdy]. Contradictory evidence, and evidence that decides
/// nothing, return `null`.
DateOrder? inferDateOrder(Iterable<String> printedDates) {
  DateOrder? decision;
  for (final printed in printedDates) {
    final parts = _split(printed);
    if (parts == null) {
      continue;
    }

    final first = int.parse(parts[0]);
    final second = int.parse(parts[1]);

    DateOrder? evidence;
    if (parts[0].length == 4) {
      evidence = DateOrder.ymd;
    } else if (first > 12 && second <= 12) {
      evidence = DateOrder.dmy;
    } else if (second > 12 && first <= 12) {
      evidence = DateOrder.mdy;
    }

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

/// Parses a printed date under [order] into a [CalendarDate].
///
/// The separators `.`, `/` and `-` are accepted, but the same separator must
/// be used for all three components. A two-digit year returns `null` (the spec
/// gives no pivot rule), as does an invalid calendar date.
CalendarDate? parsePrintedDate(String printed, DateOrder order) {
  final text = printed.trim();
  final match = _datePattern.firstMatch(text);
  if (match == null) {
    return null;
  }

  final first = match.group(1)!;
  final second = match.group(3)!;
  final third = match.group(4)!;

  final String yearText;
  final int month;
  final int day;
  switch (order) {
    case DateOrder.dmy:
      yearText = third;
      month = int.parse(second);
      day = int.parse(first);
    case DateOrder.mdy:
      yearText = third;
      month = int.parse(first);
      day = int.parse(second);
    case DateOrder.ymd:
      yearText = first;
      month = int.parse(second);
      day = int.parse(third);
  }

  if (yearText.length != 4) {
    return null;
  }

  try {
    return CalendarDate(int.parse(yearText), month, day);
  } on ArgumentError {
    return null;
  }
}

List<String>? _split(String printed) {
  final text = printed.trim();
  final match = _datePattern.firstMatch(text);
  if (match == null) {
    return null;
  }
  return <String>[match.group(1)!, match.group(3)!, match.group(4)!];
}
