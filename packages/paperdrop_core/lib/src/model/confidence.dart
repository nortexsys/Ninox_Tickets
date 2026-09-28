/// The confidence state a field value carries.
///
/// Requirement served: FR-EXT-011 (`provenance-on-every-value`) — the model
/// holds the state; the rules that assign it are specified separately (T1.7).
library;

/// The three confidence states of Funcional §6.2.2.
enum ConfidenceState {
  /// Confirmed by redundancy between independently read values.
  green,

  /// Read, and either check-digit-consistent, repaired or un-cross-checked.
  amber,

  /// Not read at all, or read and rejected by a constraint.
  red;

  /// Serialises this state by its name.
  String toJson() => name;

  /// Reads a state from its name.
  static ConfidenceState fromJson(Object? json) {
    if (json is! String) {
      throw FormatException('confidence state JSON must be a string');
    }

    for (final value in values) {
      if (value.name == json) {
        return value;
      }
    }

    throw FormatException('unknown confidence state: $json');
  }
}
