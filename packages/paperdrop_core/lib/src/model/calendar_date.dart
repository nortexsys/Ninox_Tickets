/// A `YYYY-MM-DD` document date value type, without a time zone.
///
/// Requirement served: FR-EXT-011 (`provenance-on-every-value`) — the canonical
/// model holds `doc_date` as a value type. A document date has no time zone,
/// and `DateTime` invites one.
library;

class CalendarDate {
  /// The year, from 1 to 9999.
  final int year;

  /// The month, from 1 to 12.
  final int month;

  /// The day of the month, validated against [month] and [year].
  final int day;

  CalendarDate(this.year, this.month, this.day) {
    if (year < 1 || year > 9999) {
      throw ArgumentError.value(year, 'year', 'must be between 1 and 9999');
    }
    if (month < 1 || month > 12) {
      throw ArgumentError.value(month, 'month', 'must be between 1 and 12');
    }
    if (day < 1 || day > _daysInMonth(year, month)) {
      throw ArgumentError.value(
        day,
        'day',
        'must be valid for month $month of year $year',
      );
    }
  }

  static final RegExp _pattern = RegExp(r'^([0-9]{4})-([0-9]{2})-([0-9]{2})$');

  /// Parses the canonical `YYYY-MM-DD` text form.
  static CalendarDate parse(String text) {
    final match = _pattern.firstMatch(text);
    if (match == null) {
      throw FormatException('not a YYYY-MM-DD date: $text');
    }

    return CalendarDate(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    );
  }

  static bool _isLeapYear(int year) =>
      (year % 4 == 0 && year % 100 != 0) || year % 400 == 0;

  static int _daysInMonth(int year, int month) {
    if (month == 2) {
      return _isLeapYear(year) ? 29 : 28;
    }
    if (month == 4 || month == 6 || month == 9 || month == 11) {
      return 30;
    }
    return 31;
  }

  /// Serialises this date as its `YYYY-MM-DD` text form.
  String toJson() => toString();

  /// Reads a date from its `YYYY-MM-DD` text form.
  static CalendarDate fromJson(Object? json) {
    if (json is! String) {
      throw FormatException('calendar date JSON must be a string');
    }
    return parse(json);
  }

  @override
  String toString() =>
      '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';

  @override
  bool operator ==(Object other) =>
      other is CalendarDate &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);
}
