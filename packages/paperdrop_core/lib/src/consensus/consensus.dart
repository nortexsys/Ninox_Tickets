/// Consensus by majority over candidate readings.
///
/// Requirement served: `extraction-pipeline` · `consensus-by-majority` — the
/// value a majority of passes agree on wins, a single outlier never overrides
/// the agreement, and no code path takes a maximum across passes.
library;

import '../model/provenance.dart';

/// One pass's reading of a candidate value.
class Reading<T> {
  /// The value this pass read.
  final T value;

  /// The identifier of the pass that produced [value].
  final String passId;

  /// The provenance of the reading.
  final Provenance provenance;

  /// Creates a reading.
  const Reading(this.value, this.passId, this.provenance);

  /// A value-only string form.
  @override
  String toString() => 'Reading($value, $passId, ${provenance.wireName})';

  /// Value equality on the value, pass id and provenance.
  @override
  bool operator ==(Object other) =>
      other is Reading<T> &&
      other.value == value &&
      other.passId == passId &&
      other.provenance == provenance;

  @override
  int get hashCode => Object.hash(value, passId, provenance);
}

/// The outcome of resolving several readings.
sealed class ConsensusResult<T> {
  /// Creates a consensus result. The sealed subclasses are the public cases.
  const ConsensusResult();
}

/// Several passes agreed on [value]: it had [votes] of [of] readings.
final class Agreed<T> extends ConsensusResult<T> {
  /// The value with the strictly most votes, at least two.
  final T value;

  /// The number of readings that carried [value].
  final int votes;

  /// The total number of readings considered.
  final int of;

  /// Creates an agreed result.
  const Agreed(this.value, this.votes, this.of);

  /// A value-only string form.
  @override
  String toString() => 'Agreed($value, $votes of $of)';

  /// Value equality on value, votes and of.
  @override
  bool operator ==(Object other) =>
      other is Agreed<T> &&
      other.value == value &&
      other.votes == votes &&
      other.of == of;

  @override
  int get hashCode => Object.hash(value, votes, of);
}

/// No value had a strict majority of at least two readings.
final class NoConsensus<T> extends ConsensusResult<T> {
  /// Creates a no-consensus result.
  const NoConsensus();

  /// A value-only string form.
  @override
  String toString() => 'NoConsensus()';

  /// No-consensus values are equal for the same value type.
  @override
  bool operator ==(Object other) => other is NoConsensus<T>;

  @override
  int get hashCode => T.hashCode;
}

/// Exactly one pass read anything; that pass's value is kept alone.
///
/// A [Single] is deliberately not an [Agreed]: downstream confidence treats it
/// as amber at most, never as majority agreement.
final class Single<T> extends ConsensusResult<T> {
  /// The only value read.
  final T value;

  /// Creates a single-reading result.
  const Single(this.value);

  /// A value-only string form.
  @override
  String toString() => 'Single($value)';

  /// Value equality on the single value.
  @override
  bool operator ==(Object other) => other is Single<T> && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

/// Resolves [readings] by majority of exact value equality.
///
/// [readings] contains only the passes that read something; a pass that read
/// nothing contributes no [Reading]. The value with the strictly most votes
/// wins when it has at least two. A tie is [NoConsensus]; exactly one reading
/// is [Single] and is never treated as agreed.
ConsensusResult<T> resolveConsensus<T>(List<Reading<T>> readings) {
  if (readings.isEmpty) {
    return NoConsensus<T>();
  }
  if (readings.length == 1) {
    return Single<T>(readings.single.value);
  }

  final counts = <T, int>{};
  for (final reading in readings) {
    counts[reading.value] = (counts[reading.value] ?? 0) + 1;
  }

  var leadingCount = 0;
  T? leadingValue;
  var tied = false;

  for (final entry in counts.entries) {
    if (entry.value > leadingCount) {
      leadingCount = entry.value;
      leadingValue = entry.key;
      tied = false;
    } else if (entry.value == leadingCount) {
      tied = true;
    }
  }

  if (leadingCount < 2 || tied || leadingValue == null) {
    return NoConsensus<T>();
  }

  return Agreed<T>(leadingValue, leadingCount, readings.length);
}
