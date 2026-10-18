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
    bool includeCurrency = true,
  }) {
    return TextPage(index, 300000, 300000, <PositionedWord>[
      word('TOTAL', 100000, 120000, 100000, 120000),
      word(total, 130000, 200000, 100000, 120000),
      word('BASE', 100000, 120000, 140000, 160000),
      word(base, 130000, 200000, 140000, 160000),
      word('IVA', 100000, 120000, 180000, 200000),
      word(tax, 130000, 200000, 180000, 200000),
      word(rate, 100000, 110000, 220000, 240000),
      word('%', 115000, 125000, 220000, 240000),
      if (includeCurrency) word('EUR', 200000, 220000, 260000, 280000),
    ]);
  }

  group('extractDocument', () {
    test('[validation-confidence/three-confidence-strengths] '
        'a text-layer reading with a holding identity is green', () {
      final document = extractDocument(
        passes: <ExtractionPass>[
          ExtractionPass(
            passId: 'text',
            routeLabel: 'pdf-text/pdfrx 2.6.5',
            pages: <TextPage>[invoicePage(0)],
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

    test('[extraction-pipeline/consensus-by-majority] four agreeing passes '
        'reach green and need no review', () {
      final document = extractDocument(
        passes: <ExtractionPass>[
          for (var i = 0; i < 4; i++)
            ExtractionPass(
              passId: 'pass-$i',
              routeLabel: 'pdf-ocr',
              pages: <TextPage>[invoicePage(0)],
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
      expect(document.needsReview, isFalse);
    });

    test('[extraction-pipeline/consensus-by-majority] three agreeing passes '
        'beat one outlier', () {
      final document = extractDocument(
        passes: <ExtractionPass>[
          for (var i = 0; i < 3; i++)
            ExtractionPass(
              passId: 'pass-$i',
              routeLabel: 'pdf-ocr',
              pages: <TextPage>[invoicePage(0)],
            ),
          ExtractionPass(
            passId: 'pass-outlier',
            routeLabel: 'pdf-ocr',
            pages: <TextPage>[invoicePage(1, total: '121,99')],
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
          ConfidenceState.green,
        ),
      );
      expect(document.needsReview, isFalse);
    });

    test('a pass that reads nothing leaves the fields absent', () {
      final document = extractDocument(
        passes: <ExtractionPass>[
          ExtractionPass(
            passId: 'text',
            routeLabel: 'pdf-text/pdfrx 2.6.5',
            pages: <TextPage>[
              TextPage(0, 300000, 300000, <PositionedWord>[
                word('ACME', 100000, 120000, 100000, 120000),
                word('NORTEX', 130000, 160000, 100000, 120000),
              ]),
            ],
          ),
        ],
        country: es,
        table: table,
        sourceHash: 'h',
      );

      expect(document.grossTotal, const Absent<Money>());
      expect(document.netTotal, const Absent<Money>());
      expect(document.taxTotal, const Absent<Money>());
      expect(document.docDate, const Absent<CalendarDate>());
      expect(document.docNumber, const Absent<String>());
      expect(document.supplierName, const Absent<String>());
      expect(document.needsReview, isTrue);
    });

    test('[extraction-pipeline/multi-page-consolidation] totals on page 2 and '
        'a date on page 1 produce one model', () {
      final page0 = TextPage(0, 300000, 300000, <PositionedWord>[
        word('FECHA', 100000, 120000, 100000, 120000),
        word('01/01/2024', 130000, 220000, 100000, 120000),
        word('BASE', 100000, 120000, 140000, 160000),
        word('100,00', 130000, 200000, 140000, 160000),
        word('IVA', 100000, 120000, 180000, 200000),
        word('21,00', 130000, 200000, 180000, 200000),
        word('21', 100000, 110000, 220000, 240000),
        word('%', 115000, 125000, 220000, 240000),
      ]);
      final page1 = TextPage(1, 300000, 300000, <PositionedWord>[
        word('TOTAL', 100000, 120000, 100000, 120000),
        word('121,00', 130000, 200000, 100000, 120000),
      ]);

      final document = extractDocument(
        passes: <ExtractionPass>[
          ExtractionPass(
            passId: 'text',
            routeLabel: 'pdf-text/pdfrx 2.6.5',
            pages: <TextPage>[page1, page0],
          ),
        ],
        country: es,
        table: table,
        sourceHash: 'h',
      );

      expect(
        document.docDate,
        Present<CalendarDate>(
          CalendarDate(2024, 1, 1),
          Provenance.read,
          ConfidenceState.amber,
        ),
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
    });

    test('[extraction-pipeline/multi-page-consolidation] a field with '
        'different values on two pages of one pass yields no reading', () {
      final page0 = TextPage(0, 300000, 300000, <PositionedWord>[
        word('FECHA', 100000, 120000, 100000, 120000),
        word('01/01/2024', 130000, 220000, 100000, 120000),
      ]);
      final page1 = TextPage(1, 300000, 300000, <PositionedWord>[
        word('FECHA', 100000, 120000, 100000, 120000),
        word('02/01/2024', 130000, 220000, 100000, 120000),
      ]);

      final document = extractDocument(
        passes: <ExtractionPass>[
          ExtractionPass(
            passId: 'text',
            routeLabel: 'pdf-text/pdfrx 2.6.5',
            pages: <TextPage>[page0, page1],
          ),
        ],
        country: es,
        table: table,
        sourceHash: 'h',
      );

      expect(document.docDate, const Absent<CalendarDate>());
    });

    test('[extraction-pipeline/pipeline-order-is-fixed] a tax that fails '
        'consensus is not used by the solver', () {
      final document = extractDocument(
        passes: <ExtractionPass>[
          for (var i = 0; i < 2; i++)
            ExtractionPass(
              passId: 'pass-a-$i',
              routeLabel: 'pdf-ocr',
              pages: <TextPage>[invoicePage(0, tax: '21,00')],
            ),
          for (var i = 0; i < 2; i++)
            ExtractionPass(
              passId: 'pass-b-$i',
              routeLabel: 'pdf-ocr',
              pages: <TextPage>[invoicePage(1, tax: '22,00')],
            ),
        ],
        country: es,
        table: table,
        sourceHash: 'h',
      );

      expect(document.taxTotal, const Absent<Money>());
      expect(
        document.netTotal,
        Present<Money>(
          Money(10000, eur),
          Provenance.read,
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
    });

    test(
      '[extraction-pipeline/invoice-route-priority] recognition engine '
      'keeps the full route label and only the route test uses its prefix',
      () {
        final routeLabels = <String>[
          'pdf-text/pdfrx 2.6.5',
          'pdf-ocr/google_mlkit_text_recognition 0.17.1',
          'pdf-mixed/google_mlkit_text_recognition 0.17.1',
          'photo-ocr/google_mlkit_text_recognition 0.17.1',
        ];
        for (final routeLabel in routeLabels) {
          final route = routeLabel.split('/').first;
          final passCount = route == 'pdf-text' ? 1 : 4;
          final document = extractDocument(
            passes: <ExtractionPass>[
              for (var i = 0; i < passCount; i++)
                ExtractionPass(
                  passId: route == 'pdf-text' ? 'text' : 'pass-$i',
                  routeLabel: routeLabel,
                  pages: const <TextPage>[],
                ),
            ],
            country: es,
            table: table,
            sourceHash: 'h',
          );

          expect(document.recognitionEngine, routeLabel);
        }
      },
    );
  });
}
