/// A `HH:MM` document time value type.
///
/// Requirement served: FR-EXT-011 (`provenance-on-every-value`) — the canonical
/// model holds `doc_time` as a small value type, not a `DateTime`.
library;

class DocTime {
  /// The hour, from 0 to 23.
  final int hour;

  /// The minute, from 0 to 59.
  final int minute;

  DocTime(this.hour, this.minute) {
    if (hour < 0 || hour > 23) {
      throw ArgumentError.value(hour, 'hour', 'must be between 0 and 23');
    }
    if (minute < 0 || minute > 59) {
      throw ArgumentError.value(minute, 'minute', 'must be between 0 and 59');
    }
  }

  static final RegExp _pattern = RegExp(r'^([0-9]{2}):([0-9]{2})$');

  /// Parses the canonical `HH:MM` text form.
  static DocTime parse(String text) {
    final match = _pattern.firstMatch(text);
    if (match == null) {
      throw FormatException('not a HH:MM time: $text');
    }

    return DocTime(int.parse(match.group(1)!), int.parse(match.group(2)!));
  }

  /// Serialises this time as its `HH:MM` text form.
  String toJson() => toString();

  /// Reads a time from its `HH:MM` text form.
  static DocTime fromJson(Object? json) {
    if (json is! String) {
      throw FormatException('doc time JSON must be a string');
    }
    return parse(json);
  }

  @override
  String toString() =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  @override
  bool operator ==(Object other) =>
      other is DocTime && other.hour == hour && other.minute == minute;

  @override
  int get hashCode => Object.hash(hour, minute);
}
