import 'package:paperdrop_core/paperdrop_core.dart';
import 'package:test/test.dart';

// Regression structure: a total label and its value are printed on different
// text lines, and a registry-volume reference sits next to the label in
// extraction order but visually on another row. The binder must follow the
// visual layout, never the extraction order. This file names no document.
void main() {
  final eur = CurrencyCode.parse('EUR')!;
  final es = CountryTable.es;

  PositionedWord word(String text, int x0, int x1, int top, int bottom) =>
      PositionedWord(text, x0, x1, top, bottom);

  test('the value below binds, never the volume next in extraction order', () {
    final total = word('TOTAL', 100, 180, 100, 120);
    final tomo = word('Tomo', 100, 160, 40, 60);
    final volume = word('8.741', 170, 250, 40, 60);
    final value = word('742,42', 100, 180, 140, 160);

    final page = TextPage(0, 300000, 300000, [total, tomo, volume, value]);
    final match = findTerms('TOTAL')
        .firstWhere((TermMatch term) => term.term == 'TOTAL');

    final binding = bindLabel(
      LabelOccurrence(match, [total]),
      page,
      ValueKind.amount,
      es,
    );

    expect(binding, isNotNull);
    expect(binding!.amount, Money(74242, eur));
    expect(binding.words.single.text, isNot('8.741'));
  });
}
