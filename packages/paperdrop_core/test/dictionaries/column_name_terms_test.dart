import 'package:paperdrop_core/paperdrop_core.dart';
import 'package:test/test.dart';

void main() {
  final es = CountryTable.es;

  PositionedWord word(String text, int x0, int x1, int top, int bottom) =>
      PositionedWord(text, x0, x1, top, bottom);

  group('columnNameTerms', () {
    test('[setup-wizard/two-stage-matching-with-a-strict-threshold] '
        'a German table receives its proposals: the column synonym list holds '
        'the five terms of design', () {
      expect(columnNameTerms, hasLength(5));
      expect(
        columnNameTerms.map((term) => term.term).toSet(),
        containsAll(<String>[
          'Betrag',
          'Supplier',
          'Tax',
          'IMPORTE LIQUIDO',
          'Belegdatum',
        ]),
      );

      final betrag = columnNameTerms.singleWhere(
        (term) => term.term == 'Betrag',
      );
      expect(betrag.kind, LabelKind.total);
      expect(betrag.languages, {'de'});

      final supplier = columnNameTerms.singleWhere(
        (term) => term.term == 'Supplier',
      );
      expect(supplier.kind, LabelKind.supplier);
      expect(supplier.languages, {'en'});

      final tax = columnNameTerms.singleWhere((term) => term.term == 'Tax');
      expect(tax.kind, LabelKind.tax);
      expect(tax.languages, {'en'});
    });

    test('columnNameTerms holds every extraction extension term', () {
      for (final term in labelTermsExtension) {
        expect(columnNameTerms, contains(term));
      }
    });

    test('findTerms does not read the wizard-only column names', () {
      expect(
        findTerms('Betrag').map((match) => match.term),
        isNot(contains('Betrag')),
      );
      expect(
        findTerms('Supplier').map((match) => match.term),
        isNot(contains('Supplier')),
      );

      final taxInvoice = findTerms('Tax Invoice');
      expect(taxInvoice.map((match) => match.term), isNot(contains('Tax')));
      expect(taxInvoice.where((match) => match.kind == LabelKind.tax), isEmpty);
    });

    test('[extraction-pipeline/multilingual-label-dictionaries] '
        'extraction over Tax Invoice or Betrag binds nothing from them', () {
      final page = TextPage(0, 200000, 300000, [
        word('Tax', 100000, 115000, 100000, 120000),
        word('Invoice', 120000, 150000, 100000, 120000),
        word('16,76', 155000, 185000, 100000, 120000),
        word('Betrag', 100000, 130000, 140000, 160000),
        word('80,00', 135000, 165000, 140000, 160000),
      ]);

      final operands = readOperands([page], es);

      expect(operands.taxes, isEmpty);
      expect(operands.gross, isEmpty);
      expect(operands.bases, isEmpty);
    });
  });
}
