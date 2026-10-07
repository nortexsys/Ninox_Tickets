import 'package:paperdrop_core/paperdrop_core.dart';
import 'package:test/test.dart';

void main() {
  group('resolvePrintedDate', () {
    test('[validation-confidence/date-coherence-and-ambiguity] '
        'an unambiguous date is read', () {
      final reading = resolvePrintedDate('27.08.2026');

      expect(
        reading,
        UnambiguousDate(CalendarDate(2026, 8, 27), DateOrder.dmy),
      );
      expect(dateConfidence(reading), ConfidenceState.amber);
    });

    test('[validation-confidence/date-coherence-and-ambiguity] '
        'an undecidable date is flagged, not assumed', () {
      final reading = resolvePrintedDate('03/04/2026');

      expect(reading, AmbiguousDate('03/04/2026'));
      expect(reading, isNot(isA<UnambiguousDate>()));
      expect(dateConfidence(reading), ConfidenceState.amber);
    });

    test('[validation-confidence/date-coherence-and-ambiguity] '
        'coherence is checked', () {
      final reading = resolvePrintedDate('31.02.2026');

      expect(reading, IncoherentDate('31.02.2026'));
      expect(reading, isNot(isA<UnambiguousDate>()));
      expect(dateConfidence(reading), ConfidenceState.amber);
    });
  });
}
