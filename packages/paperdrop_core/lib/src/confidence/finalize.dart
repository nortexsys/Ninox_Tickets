/// The destination's absent setting, applied at the write boundary.
///
/// Requirement served: `validation-confidence` · `absent-is-not-zero` — the
/// core holds an absent value distinctly from `Present(0)` and never decides
/// whether "not printed" means empty or zero; the destination's per-field
/// setting does, and the default is empty.
library;

import '../model/confidence.dart';
import '../model/field_value.dart';
import '../model/provenance.dart';

/// What a destination field writes for a value that was not printed.
enum AbsentPolicy {
  /// Write nothing. This is the default.
  empty,

  /// Write the field's zero value.
  zero,
}

/// Applies the destination's [policy] to [value].
///
/// A [Present], [Edited] or [NotInXml] value is returned unchanged. An
/// [Absent] value stays absent under [AbsentPolicy.empty] and becomes
/// `Present(zero)` only under [AbsentPolicy.zero].
FieldValue<T> finalize<T>(
  FieldValue<T> value, {
  required T zero,
  AbsentPolicy policy = AbsentPolicy.empty,
}) {
  return switch (value) {
    Absent<T>() when policy == AbsentPolicy.zero => Present<T>(
      zero,
      Provenance.read,
      ConfidenceState.amber,
    ),
    _ => value,
  };
}
