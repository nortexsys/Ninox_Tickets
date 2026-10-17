import 'package:paperdrop_core/paperdrop_core.dart';
import 'package:test/test.dart';

void main() {
  final eur = CurrencyCode.parse('EUR')!;
  final es = CountryTable.es;
  final table = CountryTable.launch;

  PositionedWord word(String text, int x0, int x1, int top, int bottom) =>
      PositionedWord(text, x0, x1, top, bottom);

  TextPage invoicePage(
    int index, {
    String total = '121,00',
    String base = '100,00',
    String tax = '21,00',
    String rate = '21',
    bool includeBase = true,
    bool includeTax = true,
    bool includeRate = true,
  }) {
    return TextPage(index, 300000, 300000, <PositionedWord>[
      word('TOTAL', 100000, 120000, 100000, 120000),
      word(total, 130000, 200000, 100000, 120000),
      if (includeBase) word('BASE', 100000, 120000, 140000, 160000),
      if (includeBase) word(base, 130000, 200000, 140000, 160000),
      if (includeTax) word('IVA', 100000, 120000, 180000, 200000),
      if (includeTax) word(tax, 130000, 200000, 180000, 200000),
      if (includeRate) word(rate, 100000, 110000, 220000, 240000),
      if (includeRate) word('%', 115000, 125000, 220000, 240000),
      word('EUR', 200000, 220000, 260000, 280000),
    ]);
  }

  ExtractionPass pass(String id, String route, TextPage page) =>
      ExtractionPass(passId: id, routeLabel: route, pages: [page]);

  group('text-layer confidence', () {
    test(
      '[validation-confidence/three-confidence-strengths] '
      'the same reading stays amber when it came from optical recognition',
      () {
        final document = extractDocument(
          passes: <ExtractionPass>[pass('ocr', 'pdf-ocr', invoicePage(0))],
          country: es,
          table: table,
          sourceHash: 'h',
        );

        expect(
          document.grossTotal,
          Present<Money>(
            Money(12100, eur),
            Provenance.read,
            ConfidenceState.amber,
          ),
        );
        expect(
          document.netTotal,
          Present<Money>(
            Money(10000, eur),
            Provenance.read,
            ConfidenceState.amber,
          ),
        );
        expect(
          document.taxTotal,
          Present<Money>(
            Money(2100, eur),
            Provenance.read,
            ConfidenceState.amber,
          ),
        );
        expect(document.needsReview, isTrue);
      },
    );

    test('[validation-confidence/three-confidence-strengths] '
        'a text-layer reading with no checkable identity stays amber', () {
      final document = extractDocument(
        passes: <ExtractionPass>[
          pass(
            'text',
            'pdf-text',
            invoicePage(
              0,
              includeBase: false,
              includeTax: false,
              includeRate: false,
            ),
          ),
        ],
        country: es,
        table: table,
        sourceHash: 'h',
      );

      expect(
        document.grossTotal,
        Present<Money>(
          Money(12100, eur),
          Provenance.read,
          ConfidenceState.amber,
        ),
      );
      expect(document.netTotal, const Absent<Money>());
      expect(document.taxTotal, const Absent<Money>());
      expect(document.needsReview, isTrue);
    });

    test('[validation-confidence/three-confidence-strengths] '
        'a derived operand still blocks green on a text-layer reading', () {
      final document = extractDocument(
        passes: <ExtractionPass>[
          pass('text', 'pdf-text', invoicePage(0, includeBase: false)),
        ],
        country: es,
        table: table,
        sourceHash: 'h',
      );

      // The base is derived from total - tax; the read total and read tax
      // cannot be confirmed through an identity with a derived operand.
      expect(
        document.netTotal,
        Present<Money>(
          Money(10000, eur),
          Provenance.derived,
          ConfidenceState.amber,
        ),
      );
      expect(
        document.grossTotal,
        Present<Money>(
          Money(12100, eur),
          Provenance.read,
          ConfidenceState.amber,
        ),
      );
      expect(
        document.taxTotal,
        Present<Money>(
          Money(2100, eur),
          Provenance.read,
          ConfidenceState.amber,
        ),
      );
      expect(document.needsReview, isTrue);
    });

    test('[validation-confidence/three-confidence-strengths] '
        'a failed arithmetic check still lowers a text-layer reading', () {
      final document = extractDocument(
        passes: <ExtractionPass>[
          pass('text', 'pdf-text', invoicePage(0, total: '121,01')),
        ],
        country: es,
        table: table,
        sourceHash: 'h',
      );

      expect(
        document.grossTotal,
        Present<Money>(Money(12101, eur), Provenance.read, ConfidenceState.red),
      );
      expect(
        document.netTotal,
        Present<Money>(Money(10000, eur), Provenance.read, ConfidenceState.red),
      );
      expect(
        document.taxTotal,
        Present<Money>(Money(2100, eur), Provenance.read, ConfidenceState.red),
      );
      expect(document.needsReview, isTrue);
    });

    test('[extraction-pipeline/consensus-by-majority] '
        'a text-layer reading passes consensus alone', () {
      final document = extractDocument(
        passes: <ExtractionPass>[pass('text', 'pdf-text', invoicePage(0))],
        country: es,
        table: table,
        sourceHash: 'h',
      );

      expect(
        document.grossTotal,
        Present<Money>(
          Money(12100, eur),
          Provenance.read,
          ConfidenceState.green,
        ),
      );
      expect(
        document.netTotal,
        Present<Money>(
          Money(10000, eur),
          Provenance.read,
          ConfidenceState.green,
        ),
      );
      expect(
        document.taxTotal,
        Present<Money>(
          Money(2100, eur),
          Provenance.read,
          ConfidenceState.green,
        ),
      );
      // The single text-layer currency is present but not green, so the
      // document-level rule still asks for review.
      expect(document.needsReview, isTrue);
    });

    test('[extraction-pipeline/consensus-by-majority] '
        'an OCR reading still needs agreement between passes', () {
      final document = extractDocument(
        passes: <ExtractionPass>[pass('photo', 'photo-ocr', invoicePage(0))],
        country: es,
        table: table,
        sourceHash: 'h',
      );

      expect(
        document.grossTotal,
        Present<Money>(
          Money(12100, eur),
          Provenance.read,
          ConfidenceState.amber,
        ),
      );
      expect(document.needsReview, isTrue);
    });

    test('pdf-mixed never qualifies as a text-layer reading', () {
      final document = extractDocument(
        passes: <ExtractionPass>[pass('mixed', 'pdf-mixed', invoicePage(0))],
        country: es,
        table: table,
        sourceHash: 'h',
      );

      expect(
        document.grossTotal,
        Present<Money>(
          Money(12100, eur),
          Provenance.read,
          ConfidenceState.amber,
        ),
      );
      expect(
        document.netTotal,
        Present<Money>(
          Money(10000, eur),
          Provenance.read,
          ConfidenceState.amber,
        ),
      );
      expect(
        document.taxTotal,
        Present<Money>(
          Money(2100, eur),
          Provenance.read,
          ConfidenceState.amber,
        ),
      );
      expect(document.needsReview, isTrue);
    });
  });
}
