import 'package:paperdrop_core/paperdrop_core.dart';
import 'package:test/test.dart';

void main() {
  final eur = CurrencyCode.parse('EUR')!;
  final es = CountryTable.es;
  final de = CountryTable.de;

  PositionedWord word(String text, int x0, int x1, int top, int bottom) =>
      PositionedWord(text, x0, x1, top, bottom);

  group('labelTermsExtension', () {
    test(
      'the DEC-014 extension sits beside, not inside, the Annex C seeds',
      () {
        final seeds = labelTerms.map((term) => term.term).toSet();
        expect(seeds, isNot(contains('IMPORTE LIQUIDO')));
        expect(seeds, isNot(contains('Belegdatum')));

        expect(labelTermsExtension, hasLength(2));
        expect(
          labelTermsExtension
              .where((term) => term.term == 'IMPORTE LIQUIDO')
              .single,
          LabelTerm(LabelKind.total, 'IMPORTE LIQUIDO', {'es'}),
        );
        expect(
          labelTermsExtension.where((term) => term.term == 'Belegdatum').single,
          LabelTerm(LabelKind.date, 'Belegdatum', {'de'}),
        );
      },
    );

    test('findTerms consults the extension after the Annex C seeds', () {
      final total = findTerms('IMPORTE LIQUIDO').single;
      expect(total.kind, LabelKind.total);
      expect(total.language, 'es');

      final date = findTerms('Belegdatum').single;
      expect(date.kind, LabelKind.date);
      expect(date.language, 'de');
    });

    test('the accented spelling IMPORTE LÍQUIDO matches the stored term', () {
      final matches = findTerms('IMPORTE LÍQUIDO');
      final match = matches.where((match) => match.term == 'IMPORTE LIQUIDO');

      expect(match, hasLength(1));
      expect(match.single.kind, LabelKind.total);
      expect(match.single.language, 'es');
    });

    test('[extraction-pipeline/multilingual-label-dictionaries] '
        'labels bind regardless of interface language: both DEC-014 extension '
        'terms bind a value on a synthetic page', () {
      final totalPage = TextPage(0, 200000, 300000, [
        word('IMPORTE', 100000, 120000, 100000, 120000),
        word('LIQUIDO', 125000, 145000, 100000, 120000),
        word('742,42', 150000, 180000, 100000, 120000),
      ]);

      final operands = readOperands([totalPage], es);
      expect(operands.gross, hasLength(1));
      expect(operands.gross.single.amount, Money(74242, eur));
      expect(operands.gross.single.words.single.text, '742,42');

      final datePage = TextPage(0, 200000, 300000, [
        word('Belegdatum', 100000, 130000, 100000, 120000),
        word('01.10.2026', 135000, 170000, 100000, 120000),
      ]);
      final dateMatch = findTerms('Belegdatum').single;
      final dateBinding = bindLabel(
        LabelOccurrence(dateMatch, [datePage.words.first]),
        datePage,
        ValueKind.date,
        de,
      );

      expect(dateBinding, isNotNull);
      expect(dateBinding!.kind, ValueKind.date);
      expect(dateBinding.date, CalendarDate(2026, 10, 1));
    });

    test('no extension term collides with a negative-context term', () {
      final negativeNormalised = negativeTerms
          .map((term) => _normaliseForComparison(term.term))
          .toSet();

      for (final term in labelTermsExtension) {
        expect(
          negativeNormalised,
          isNot(contains(_normaliseForComparison(term.term))),
          reason: '${term.term} collides with a negative-context term',
        );
      }
    });
  });
}

/// The same case/diacritic/whitespace folding the lookup applies, small enough
/// for a test to reproduce without reaching into the matcher's private code.
String _normaliseForComparison(String text) {
  const folded = <String, String>{
    'á': 'a',
    'à': 'a',
    'â': 'a',
    'ä': 'a',
    'ã': 'a',
    'å': 'a',
    'é': 'e',
    'è': 'e',
    'ê': 'e',
    'ë': 'e',
    'í': 'i',
    'ì': 'i',
    'î': 'i',
    'ï': 'i',
    'ó': 'o',
    'ò': 'o',
    'ô': 'o',
    'ö': 'o',
    'õ': 'o',
    'ú': 'u',
    'ù': 'u',
    'û': 'u',
    'ü': 'u',
    'ñ': 'n',
    'ç': 'c',
    'ý': 'y',
    'ÿ': 'y',
  };

  final buffer = StringBuffer();
  for (final rune in text.toLowerCase().runes) {
    final character = String.fromCharCode(rune);
    buffer.write(folded[character] ?? character);
  }
  return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}
