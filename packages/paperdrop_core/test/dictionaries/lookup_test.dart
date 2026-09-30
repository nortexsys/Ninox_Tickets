import 'package:paperdrop_core/paperdrop_core.dart';
import 'package:test/test.dart';

void main() {
  group('whole-word matching', () {
    test('tip does not match inside tipo', () {
      final matches = findTerms('tipo');
      expect(matches.where((match) => match.term == 'tip'), isEmpty);
    });

    test('HT does not match inside HTTP', () {
      final matches = findTerms('HTTP');
      expect(matches.where((match) => match.term == 'HT'), isEmpty);
    });

    test('Tomo does not match inside Tomorrow', () {
      final matches = findTerms('Tomorrow');
      expect(matches.where((match) => match.term == 'Tomo'), isEmpty);
    });
  });

  group('longest match', () {
    test('TOTAL A PAGAR wins over TOTAL at the same position', () {
      final matches = findTerms('TOTAL A PAGAR');

      expect(matches.map((match) => match.term), contains('TOTAL A PAGAR'));
      expect(matches.map((match) => match.term), isNot(contains('TOTAL')));
      expect(
        matches.firstWhere((match) => match.term == 'TOTAL A PAGAR').kind,
        LabelKind.total,
      );
    });
  });

  group('multilingual labels', () {
    // Scenario: labels bind regardless of interface language. This test proves
    // the lookup half only; binding a label to a value is FR-EXT-014's
    // application rule (T1.5-T1.6), so the test is untagged.
    test('Total à payer and Zu zahlen are both found as total', () {
      final french = findTerms('Total à payer');
      expect(
        french.where(
          (match) => match.kind == LabelKind.total && match.language == 'fr',
        ),
        isNotEmpty,
      );

      final german = findTerms('Zu zahlen');
      expect(
        german.where(
          (match) => match.kind == LabelKind.total && match.language == 'de',
        ),
        isNotEmpty,
      );
    });

    test('commission is tagged in English and French', () {
      final matches = findTerms('commission');
      final languages = matches
          .where((match) => match.term == 'commission')
          .map((match) => match.language)
          .toSet();
      expect(languages, containsAll(<String>['en', 'fr']));
    });
  });

  group('negative-context lookup', () {
    test('DCC carries the dccMarkup hint', () {
      final match = findTerms('DCC').single;
      expect(match.kind, isNull);
      expect(match.isNegative, isTrue);
      expect(match.surchargeHint, SurchargeLabel.dccMarkup);
      expect(match.language, 'en');
    });

    test('propina and tip carry the tip hint', () {
      final propina = findTerms('propina').single;
      expect(propina.surchargeHint, SurchargeLabel.tip);
      expect(propina.language, 'es');

      final tip = findTerms('tip').single;
      expect(tip.surchargeHint, SurchargeLabel.tip);
      expect(tip.language, 'en');
    });

    test('service charge carries the serviceCharge hint', () {
      final match = findTerms('service charge').single;
      expect(match.surchargeHint, SurchargeLabel.serviceCharge);
    });
  });

  group('normalisation of the input line', () {
    test('matching is case-insensitive and collapses whitespace runs', () {
      final matches = findTerms('  TOTAL   A PAGAR ');
      expect(matches.map((match) => match.term), contains('TOTAL A PAGAR'));
      expect(
        matches.firstWhere((match) => match.term == 'TOTAL A PAGAR').start,
        2,
      );
    });
  });
}
