// Photo-route wiring for the amount coherence rules.
//
// Every page here is synthetic. No real receipt, no real name, no real
// fiscal identifier: the words are invented EJEMPLO S.L.-style text, and the
// expectations are the rules from the change proposal.

import 'package:paperdrop_core/paperdrop_core.dart';
import 'package:test/test.dart';

void main() {
  final eur = CurrencyCode.parse('EUR')!;
  final es = CountryTable.es;
  final table = CountryTable.launch;

  PositionedWord word(String text, int x0, int x1, int top, int bottom) =>
      PositionedWord(text, x0, x1, top, bottom);

  TextPage page(List<PositionedWord> words) =>
      TextPage(0, 300000, 300000, words);

  ExtractionPass photoPass(String id, TextPage textPage) => ExtractionPass(
    passId: id,
    routeLabel: 'photo-ocr/google_mlkit_text_recognition 0.17.1',
    pages: <TextPage>[textPage],
  );

  CanonicalDocument extractPhoto(TextPage textPage) => extractDocument(
    passes: <ExtractionPass>[photoPass('p1', textPage)],
    country: es,
    table: table,
    sourceHash: 'h',
  );

  group('photo route amount coherence', () {
    test('rule 1 drops net and tax when all three amounts are equal', () {
      final document = extractPhoto(
        page(<PositionedWord>[
          word('BASE', 100000, 120000, 100000, 120000),
          word('21,00', 130000, 170000, 100000, 120000),
          word('IVA', 100000, 120000, 140000, 160000),
          word('21,00', 130000, 170000, 140000, 160000),
          word('TOTAL', 100000, 120000, 180000, 200000),
          word('21,00', 130000, 170000, 180000, 200000),
        ]),
      );

      expect(
        document.grossTotal,
        Present<Money>(
          Money(2100, eur),
          Provenance.read,
          ConfidenceState.amber,
        ),
      );
      expect(document.netTotal, const Absent<Money>());
      expect(document.taxTotal, const Absent<Money>());
      expect(document.needsReview, isTrue);
    });

    test('rule 2 drops a tax equal to the printed rate', () {
      final document = extractPhoto(
        page(<PositionedWord>[
          word('BASE', 100000, 120000, 100000, 120000),
          word('100,00', 130000, 170000, 100000, 120000),
          word('IVA', 100000, 120000, 140000, 160000),
          word('21%', 130000, 150000, 140000, 160000),
          word('IVA', 100000, 120000, 180000, 200000),
          word('21,00', 130000, 170000, 180000, 200000),
          word('TOTAL', 100000, 120000, 220000, 240000),
          word('121,00', 130000, 170000, 220000, 240000),
        ]),
      );

      expect(
        document.netTotal,
        Present<Money>(
          Money(10000, eur),
          Provenance.read,
          ConfidenceState.amber,
        ),
      );
      expect(document.taxTotal, const Absent<Money>());
      expect(
        document.grossTotal,
        Present<Money>(
          Money(12100, eur),
          Provenance.read,
          ConfidenceState.amber,
        ),
      );
    });

    test('rule 3 drops a tax equal to the gross', () {
      final document = extractPhoto(
        page(<PositionedWord>[
          word('BASE', 100000, 120000, 100000, 120000),
          word('100,00', 130000, 170000, 100000, 120000),
          word('IVA', 100000, 120000, 140000, 160000),
          word('121,00', 130000, 170000, 140000, 160000),
          word('TOTAL', 100000, 120000, 180000, 200000),
          word('121,00', 130000, 170000, 180000, 200000),
        ]),
      );

      expect(
        document.netTotal,
        Present<Money>(
          Money(10000, eur),
          Provenance.read,
          ConfidenceState.amber,
        ),
      );
      expect(document.taxTotal, const Absent<Money>());
      expect(
        document.grossTotal,
        Present<Money>(
          Money(12100, eur),
          Provenance.read,
          ConfidenceState.amber,
        ),
      );
    });

    test(
      'rule 4 prefers the arithmetic triple when the labels do not add up',
      () {
        final document = extractPhoto(
          page(<PositionedWord>[
            word('BASE', 100000, 120000, 100000, 120000),
            word('100,00', 130000, 170000, 100000, 120000),
            word('IVA', 100000, 120000, 140000, 160000),
            word('10,00', 130000, 170000, 140000, 160000),
            word('TOTAL', 100000, 120000, 180000, 200000),
            word('121,00', 130000, 170000, 180000, 200000),
            word('IVA', 100000, 120000, 220000, 240000),
            word('21%', 130000, 150000, 220000, 240000),
            word('21,00', 160000, 190000, 220000, 240000),
          ]),
        );

        expect(
          document.netTotal,
          Present<Money>(
            Money(10000, eur),
            Provenance.derived,
            ConfidenceState.amber,
          ),
        );
        expect(
          document.taxTotal,
          Present<Money>(
            Money(2100, eur),
            Provenance.derived,
            ConfidenceState.amber,
          ),
        );
        expect(
          document.grossTotal,
          Present<Money>(
            Money(12100, eur),
            Provenance.derived,
            ConfidenceState.amber,
          ),
        );
      },
    );
  });
}
