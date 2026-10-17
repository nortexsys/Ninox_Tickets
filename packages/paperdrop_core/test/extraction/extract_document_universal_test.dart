import 'package:paperdrop_core/paperdrop_core.dart';
import 'package:test/test.dart';

void main() {
  final chf = CurrencyCode.parse('CHF')!;
  final table = CountryTable.launch;

  PositionedWord word(String text, int x0, int x1, int top, int bottom) =>
      PositionedWord(text, x0, x1, top, bottom);

  TextPage noRowInvoicePage() => TextPage(0, 300000, 300000, <PositionedWord>[
    word('BASE', 100000, 120000, 100000, 120000),
    word('1.000,00', 130000, 200000, 100000, 120000),
    word('IVA', 100000, 120000, 140000, 160000),
    word('250,00', 130000, 200000, 140000, 160000),
    word('25', 100000, 110000, 180000, 200000),
    word('%', 115000, 125000, 180000, 200000),
    word('FECHA', 100000, 120000, 220000, 240000),
    word('13.08.2026', 130000, 220000, 220000, 240000),
    word('CHF', 200000, 220000, 260000, 280000),
  ]);

  test('[countries-languages/universal-core] a no-row document extracts '
      'amounts and dates and never applies a rate gate', () {
    final document = extractDocument(
      passes: <ExtractionPass>[
        ExtractionPass(
          passId: 'text',
          routeLabel: 'pdf-text',
          pages: <TextPage>[noRowInvoicePage()],
        ),
      ],
      country: null,
      table: table,
      sourceHash: 'h',
    );

    // The printed 25 % rate is illegal for every launch row; the universal
    // core still admits it, so the missing gross total is derived from the
    // printed base and tax. The read base and tax still confirm each other
    // through `base × rate ≈ tax`, so they reach green on the text layer.
    expect(
      document.grossTotal,
      Present<Money>(
        Money(125000, chf),
        Provenance.derived,
        ConfidenceState.amber,
      ),
    );
    expect(
      document.netTotal,
      Present<Money>(
        Money(100000, chf),
        Provenance.read,
        ConfidenceState.green,
      ),
    );
    expect(
      document.taxTotal,
      Present<Money>(Money(25000, chf), Provenance.read, ConfidenceState.green),
    );
    expect(
      document.docDate,
      Present<CalendarDate>(
        CalendarDate(2026, 8, 13),
        Provenance.read,
        ConfidenceState.amber,
      ),
    );
    expect(
      document.currency,
      Present<CurrencyCode>(chf, Provenance.read, ConfidenceState.amber),
    );
    expect(document.taxSlots, isEmpty);
    expect(document.needsReview, isTrue);
  });

  test('an undetected document still needs review even when the universal '
      'core arithmetic agrees', () {
    final document = extractDocument(
      passes: <ExtractionPass>[
        for (var i = 0; i < 4; i++)
          ExtractionPass(
            passId: 'pass-$i',
            routeLabel: 'pdf-ocr',
            pages: <TextPage>[noRowInvoicePage()],
          ),
      ],
      country: null,
      table: table,
      sourceHash: 'h',
    );

    expect(
      document.netTotal,
      Present<Money>(
        Money(100000, chf),
        Provenance.read,
        ConfidenceState.amber,
      ),
    );
    expect(document.needsReview, isTrue);
  });
}
