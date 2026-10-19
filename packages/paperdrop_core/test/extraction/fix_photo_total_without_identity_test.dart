import 'package:paperdrop_core/paperdrop_core.dart';
import 'package:test/test.dart';

/// Synthetic cases for `fix-photo-total-without-identity`.
///
/// The pages are built from the masked shapes of the change proposal, never
/// from a corpus document or photograph: a single labelled total with no
/// breakdown, a colon total, a base/IVA/total block, tendered and change
/// lines, a one-digit near-miss across four passes, and two universal-core
/// dates.
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

  TextPage totalOnlyPage({String total = '12,50', bool withCurrency = true}) {
    return page(<PositionedWord>[
      word('TOTAL', 100000, 120000, 100000, 120000),
      word(total, 130000, 170000, 100000, 120000),
      if (withCurrency) word('EUR', 180000, 200000, 100000, 120000),
    ]);
  }

  group('a printed total with no breakdown', () {
    test('[validation-confidence/three-confidence-strengths] '
        'a labelled total with no identity is read and stays amber '
        '(photo, Spain row)', () {
      final document = extractDocument(
        passes: <ExtractionPass>[
          photoPass('p1-native', totalOnlyPage(total: '12,50')),
        ],
        country: es,
        table: table,
        sourceHash: 'h',
      );

      expect(
        document.grossTotal,
        Present<Money>(
          Money(1250, eur),
          Provenance.read,
          ConfidenceState.amber,
        ),
      );
      expect(document.netTotal, const Absent<Money>());
      expect(document.taxTotal, const Absent<Money>());
      expect(document.taxSlots, hasLength(4));
      expect(
        document.taxSlots.every(
          (TaxSlot slot) =>
              slot.rate is Absent<RateBp> &&
              slot.base is Absent<Money> &&
              slot.amount is Absent<Money>,
        ),
        isTrue,
      );
      expect(document.needsReview, isTrue);
    });

    test('[validation-confidence/three-confidence-strengths] '
        'a labelled total with no identity is read and stays amber '
        '(photo, universal core)', () {
      final document = extractDocument(
        passes: <ExtractionPass>[
          photoPass('p1-native', totalOnlyPage(total: '12,50')),
        ],
        country: null,
        table: table,
        sourceHash: 'h',
      );

      expect(
        document.grossTotal,
        Present<Money>(
          Money(1250, eur),
          Provenance.read,
          ConfidenceState.amber,
        ),
      );
      expect(document.netTotal, const Absent<Money>());
      expect(document.taxTotal, const Absent<Money>());
      expect(document.taxSlots, isEmpty);
      expect(document.needsReview, isTrue);
    });

    test('[extraction-pipeline/negative-context-suppresses-non-tax-figures] '
        'a colon total with no breakdown is read, not the tendered or change '
        'line', () {
      final textPage = page(<PositionedWord>[
        word('TOTAL:', 100000, 120000, 100000, 120000),
        word('12,50', 130000, 170000, 100000, 120000),
        word('EUR', 180000, 200000, 100000, 120000),
        word('ENTREGADO', 100000, 140000, 160000, 180000),
        word('20,00', 150000, 190000, 160000, 180000),
        word('CAMBIO', 100000, 130000, 220000, 240000),
        word('7,50', 150000, 190000, 220000, 240000),
      ]);

      final document = extractDocument(
        passes: <ExtractionPass>[photoPass('p1-native', textPage)],
        country: es,
        table: table,
        sourceHash: 'h',
      );

      expect(
        document.grossTotal,
        Present<Money>(
          Money(1250, eur),
          Provenance.read,
          ConfidenceState.amber,
        ),
      );
      expect(document.netTotal, const Absent<Money>());
      expect(document.taxTotal, const Absent<Money>());
      expect(document.surcharges, isEmpty);
      expect(document.needsReview, isTrue);
    });
  });

  group('majority across photo passes', () {
    test('[extraction-pipeline/consensus-by-majority] '
        'three agreeing passes beat one near-miss total and the total is not '
        'dropped for lack of an identity', () {
      final trace = CollectingTrace();
      final document = extractDocument(
        passes: <ExtractionPass>[
          for (var i = 0; i < 3; i++)
            photoPass('p$i', totalOnlyPage(total: '12,50')),
          photoPass('p-near-miss', totalOnlyPage(total: '12,58')),
        ],
        country: es,
        table: table,
        sourceHash: 'h',
        trace: trace,
      );

      expect(
        document.grossTotal,
        Present<Money>(
          Money(1250, eur),
          Provenance.read,
          ConfidenceState.amber,
        ),
      );
      expect(document.netTotal, const Absent<Money>());
      expect(document.taxTotal, const Absent<Money>());
      expect(
        trace.stages['gross_total'],
        isNot(contains(ExtractionStage.noMajority)),
      );
      expect(
        trace.stages['gross_total'],
        contains(ExtractionStage.confidenceCapped),
      );
      expect(document.needsReview, isTrue);
    });
  });

  group('universal-core date order', () {
    test('[countries-languages/format-inference] '
        'a day greater than twelve resolves the order with no country row', () {
      final document = extractDocument(
        passes: <ExtractionPass>[
          photoPass(
            'p1-native',
            page(<PositionedWord>[
              word('FECHA', 100000, 120000, 100000, 120000),
              word('28/09/2026', 130000, 220000, 100000, 120000),
              word('TOTAL', 100000, 120000, 160000, 180000),
              word('12,50', 130000, 170000, 160000, 180000),
              word('EUR', 180000, 200000, 160000, 180000),
            ]),
          ),
        ],
        country: null,
        table: table,
        sourceHash: 'h',
      );

      expect(
        document.docDate,
        Present<CalendarDate>(
          CalendarDate(2026, 9, 28),
          Provenance.read,
          ConfidenceState.amber,
        ),
      );
    });

    test('[validation-confidence/date-coherence-and-ambiguity] '
        'an undecidable date is not assumed with no country row', () {
      final trace = CollectingTrace();
      final document = extractDocument(
        passes: <ExtractionPass>[
          photoPass(
            'p1-native',
            page(<PositionedWord>[
              word('FECHA', 100000, 120000, 100000, 120000),
              word('05/06/2026', 130000, 220000, 100000, 120000),
              word('TOTAL', 100000, 120000, 160000, 180000),
              word('12,50', 130000, 170000, 160000, 180000),
              word('EUR', 180000, 200000, 160000, 180000),
            ]),
          ),
        ],
        country: null,
        table: table,
        sourceHash: 'h',
        trace: trace,
      );

      expect(document.docDate, const Absent<CalendarDate>());
      expect(
        trace.stages['doc_date'],
        contains(ExtractionStage.valueNotParsed),
      );
    });

    test('[countries-languages/launch-rows] '
        'the same ambiguous digits are read under the Spanish row', () {
      final document = extractDocument(
        passes: <ExtractionPass>[
          photoPass(
            'p1-native',
            page(<PositionedWord>[
              word('FECHA', 100000, 120000, 100000, 120000),
              word('05/06/2026', 130000, 220000, 100000, 120000),
              word('TOTAL', 100000, 120000, 160000, 180000),
              word('12,50', 130000, 170000, 160000, 180000),
              word('EUR', 180000, 200000, 160000, 180000),
            ]),
          ),
        ],
        country: es,
        table: table,
        sourceHash: 'h',
      );

      expect(
        document.docDate,
        Present<CalendarDate>(
          CalendarDate(2026, 6, 5),
          Provenance.read,
          ConfidenceState.amber,
        ),
      );
    });
  });

  group('no regression', () {
    test('[validation-confidence/three-confidence-strengths] '
        'a text-layer receipt with several rates and a matching identity is '
        'still read and confirmed', () {
      final textPage = page(<PositionedWord>[
        word('TOTAL', 100000, 120000, 100000, 120000),
        word('131,00', 130000, 170000, 100000, 120000),
        word('BASE', 100000, 120000, 160000, 180000),
        word('100,00', 130000, 170000, 160000, 180000),
        word('IVA', 100000, 120000, 220000, 240000),
        word('10%', 130000, 150000, 220000, 240000),
        word('10,00', 160000, 190000, 220000, 240000),
        word('IVA', 100000, 120000, 280000, 300000),
        word('21%', 130000, 150000, 280000, 300000),
        word('21,00', 160000, 190000, 280000, 300000),
        word('IVA', 100000, 120000, 340000, 360000),
        word('31,00', 130000, 170000, 340000, 360000),
        word('EUR', 200000, 220000, 400000, 420000),
      ]);

      final document = extractDocument(
        passes: <ExtractionPass>[
          ExtractionPass(
            passId: 'text',
            routeLabel: 'pdf-text/pdfrx 2.6.5',
            pages: <TextPage>[textPage],
          ),
        ],
        country: es,
        table: table,
        sourceHash: 'h',
      );

      expect(
        document.grossTotal,
        Present<Money>(
          Money(13100, eur),
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
          Money(3100, eur),
          Provenance.read,
          ConfidenceState.green,
        ),
      );
      expect(document.taxSlots, hasLength(4));
      expect(
        document.taxSlots[0].rate,
        Present<RateBp>(RateBp(1000), Provenance.read, ConfidenceState.amber),
      );
      expect(
        document.taxSlots[1].rate,
        Present<RateBp>(RateBp(2100), Provenance.read, ConfidenceState.amber),
      );
    });
  });
}
