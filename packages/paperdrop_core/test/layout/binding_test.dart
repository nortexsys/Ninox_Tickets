import 'package:paperdrop_core/paperdrop_core.dart';
import 'package:test/test.dart';

void main() {
  final eur = CurrencyCode.parse('EUR')!;
  final es = CountryTable.es;

  TermMatch totalMatchFor(String line) =>
      findTerms(line).firstWhere((TermMatch match) => match.term == 'TOTAL');
  LabelOccurrence occurrenceFor(TermMatch match, PositionedWord word) =>
      LabelOccurrence(match, [word]);

  group('bindLabel', () {
    test('[extraction-pipeline/positional-pdf-text-extraction] '
        'a label on another line still binds its value', () {
      // Synthetic reproduction of the structure the binding rule exists to
      // prevent: a total label on one row, its amount on the row below, and
      // a registry-volume reference ("Tomo 8.741") sitting next to the
      // label in extraction order but visually on another row. No document
      // and no supplier are named.
      final total = PositionedWord('TOTAL', 100, 180, 100, 120);
      final tomo = PositionedWord('Tomo', 100, 160, 40, 60);
      final volume = PositionedWord('8.741', 170, 250, 40, 60);
      final value = PositionedWord('742,42', 100, 180, 140, 160);

      final label = occurrenceFor(totalMatchFor('TOTAL'), total);

      for (final order in permutations([total, tomo, volume, value])) {
        final page = TextPage(0, 200000, 200000, order);
        final binding = bindLabel(label, page, ValueKind.amount, es);

        expect(
          binding,
          isNotNull,
          reason: 'order: ${order.map((PositionedWord w) => w.text)}',
        );
        expect(binding!.kind, ValueKind.amount);
        expect(binding.amount, Money(74242, eur));
        expect(binding.words.single.text, '742,42');
        expect(binding.words.single.text, isNot('8.741'));
      }
    });

    test('[extraction-pipeline/positional-pdf-text-extraction] '
        'a registry volume is not bound to a total label', () {
      // A second synthetic structure: the volume reference sits on the
      // label's own line, to the right of a closer valid amount. The
      // nearest valid amount wins, never the volume, for every word order.
      final total = PositionedWord('TOTAL', 100, 180, 100, 120);
      final amount = PositionedWord('742,42', 190, 250, 100, 120);
      final volume = PositionedWord('8.741', 260, 330, 100, 120);

      final label = occurrenceFor(totalMatchFor('TOTAL'), total);

      for (final order in permutations([total, amount, volume])) {
        final page = TextPage(0, 200000, 200000, order);
        final binding = bindLabel(label, page, ValueKind.amount, es);

        expect(binding, isNotNull);
        expect(binding!.amount, Money(74242, eur));
        expect(binding.words.single.text, '742,42');
      }
    });

    test('a label with no candidate returns nothing', () {
      final total = PositionedWord('TOTAL', 100, 180, 100, 120);
      final other = PositionedWord('nada', 100, 160, 140, 160);

      final page = TextPage(0, 200000, 200000, [total, other]);
      final label = occurrenceFor(totalMatchFor('TOTAL'), total);

      expect(bindLabel(label, page, ValueKind.amount, es), isNull);
    });

    test('a date binds on the line below under the document date order', () {
      final labelWord = PositionedWord('FECHA', 100, 160, 100, 120);
      final dateWord = PositionedWord('01/01/2026', 100, 200, 140, 160);
      final page = TextPage(0, 200000, 200000, [labelWord, dateWord]);
      final match = TermMatch(
        term: 'FECHA',
        kind: LabelKind.date,
        surchargeHint: null,
        language: 'es',
        start: 0,
        end: 5,
      );

      final binding = bindLabel(
        occurrenceFor(match, labelWord),
        page,
        ValueKind.date,
        es,
      );

      expect(binding, isNotNull);
      expect(binding!.kind, ValueKind.date);
      expect(binding.date, CalendarDate(2026, 1, 1));
    });

    test('a document number binds as the printed text', () {
      final labelWord = PositionedWord('FACTURA', 100, 180, 100, 120);
      final numberWord = PositionedWord('A-2026-001', 100, 220, 140, 160);
      final page = TextPage(0, 200000, 200000, [labelWord, numberWord]);
      final match = TermMatch(
        term: 'FACTURA',
        kind: LabelKind.docNumber,
        surchargeHint: null,
        language: 'es',
        start: 0,
        end: 7,
      );

      final binding = bindLabel(
        occurrenceFor(match, labelWord),
        page,
        ValueKind.documentNumber,
        es,
      );

      expect(binding, isNotNull);
      expect(binding!.kind, ValueKind.documentNumber);
      expect(binding.documentNumber, 'A-2026-001');
    });
  });
}

List<List<T>> permutations<T>(List<T> items) {
  if (items.length <= 1) {
    return [items];
  }
  final result = <List<T>>[];
  for (var i = 0; i < items.length; i++) {
    final rest = [...items]..removeAt(i);
    for (final perm in permutations(rest)) {
      result.add([items[i], ...perm]);
    }
  }
  return result;
}
