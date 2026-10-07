/// Date coherence and ambiguity.
///
/// Requirement served: `validation-confidence` ·
/// `date-coherence-and-ambiguity` — a printed date is read when the document's
/// own evidence decides the order, flagged ambiguous when it does not, and
/// never silently resolved.
library;

import '../format/date.dart';
import '../model/calendar_date.dart';
import '../model/confidence.dart';

/// The outcome of resolving one printed date.
sealed class DateReading {
  /// Creates a date reading. The sealed subclasses are the public cases.
  const DateReading();
}

/// A date whose order the document's own evidence decided.
final class UnambiguousDate extends DateReading {
  /// The parsed date.
  final CalendarDate date;

  /// The order inferred from the document's own evidence.
  final DateOrder order;

  /// Creates an unambiguous date reading.
  const UnambiguousDate(this.date, this.order);

  /// A value-only string form.
  @override
  String toString() => 'UnambiguousDate($date, $order)';

  /// Value equality on the date and order.
  @override
  bool operator ==(Object other) =>
      other is UnambiguousDate && other.date == date && other.order == order;

  @override
  int get hashCode => Object.hash(date, order);
}

/// A date with no disambiguating evidence between two readings.
final class AmbiguousDate extends DateReading {
  /// The date exactly as printed.
  final String printed;

  /// Creates an ambiguous date reading.
  const AmbiguousDate(this.printed);

  /// A value-only string form.
  @override
  String toString() => 'AmbiguousDate($printed)';

  /// Value equality on the printed text.
  @override
  bool operator ==(Object other) =>
      other is AmbiguousDate && other.printed == printed;

  @override
  int get hashCode => printed.hashCode;
}

/// A date whose inferred order cannot produce a supported calendar date.
final class IncoherentDate extends DateReading {
  /// The date exactly as printed.
  final String printed;

  /// Creates an incoherent date reading.
  const IncoherentDate(this.printed);

  /// A value-only string form.
  @override
  String toString() => 'IncoherentDate($printed)';

  /// Value equality on the printed text.
  @override
  bool operator ==(Object other) =>
      other is IncoherentDate && other.printed == printed;

  @override
  int get hashCode => printed.hashCode;
}

/// Resolves one printed date from the document's own evidence.
///
/// The order is inferred from [printed] alone, exactly as
/// `countries-languages` ships it: a day greater than twelve disambiguates.
/// No disambiguating evidence means [AmbiguousDate], never a silent choice;
/// an inferred order that parses to no supported date means [IncoherentDate].
DateReading resolvePrintedDate(String printed) {
  final order = inferDateOrder([printed]);
  if (order == null) {
    return AmbiguousDate(printed);
  }

  final date = parsePrintedDate(printed, order);
  if (date == null) {
    return IncoherentDate(printed);
  }

  return UnambiguousDate(date, order);
}

/// The confidence state a date reading is presented with.
///
/// A clean date reading is amber: a date has no independent figure to cross
/// against, so it is never green.
ConfidenceState dateConfidence(DateReading reading) => ConfidenceState.amber;
