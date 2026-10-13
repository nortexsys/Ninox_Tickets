import 'package:paperdrop_core/paperdrop_core.dart';
import 'package:test/test.dart';

void main() {
  final table = CountryTable.launch;

  PositionedWord word(String text, int x0, int x1, int top, int bottom) =>
      PositionedWord(text, x0, x1, top, bottom);

  TextPage page(int index, List<PositionedWord> words) =>
      TextPage(index, 300000, 300000, words);

  group('detectCountry', () {
    test('[countries-languages/deterministic-country-detection] '
        'a Spanish ticket is detected from its CIF', () {
      final pages = <TextPage>[
        page(0, <PositionedWord>[
          word('B12345678', 100000, 180000, 100000, 120000),
        ]),
      ];

      final detection = detectCountry(pages: pages, table: table);

      expect(
        detection,
        Detected(
          row: CountryTable.es,
          evidence: const <CountryEvidenceKind>[CountryEvidenceKind.taxId],
        ),
      );
    });

    test('[countries-languages/deterministic-country-detection] '
        'a German invoice is detected from its DE VAT identifier', () {
      final pages = <TextPage>[
        page(0, <PositionedWord>[
          word('DE987654321', 100000, 200000, 100000, 120000),
        ]),
      ];

      final detection = detectCountry(pages: pages, table: table);

      expect(
        detection,
        Detected(
          row: CountryTable.de,
          evidence: const <CountryEvidenceKind>[CountryEvidenceKind.taxId],
        ),
      );
    });

    test('a customer foreign id plus an issuer id is broken by the issuer '
        'country name', () {
      final pages = <TextPage>[
        page(0, <PositionedWord>[
          word('B12345678', 100000, 180000, 100000, 120000),
          word('Deutschland', 100000, 180000, 140000, 160000),
          word('10115', 190000, 230000, 140000, 160000),
          word('DE987654321', 100000, 200000, 180000, 200000),
        ]),
      ];

      final detection = detectCountry(pages: pages, table: table);

      expect(
        detection,
        Detected(
          row: CountryTable.de,
          evidence: const <CountryEvidenceKind>[
            CountryEvidenceKind.taxId,
            CountryEvidenceKind.countryName,
          ],
        ),
      );
    });

    test('two ids with no tiebreak are conflicting', () {
      final pages = <TextPage>[
        page(0, <PositionedWord>[
          word('B12345678', 100000, 180000, 100000, 120000),
          word('DE987654321', 100000, 200000, 180000, 200000),
        ]),
      ];

      final detection = detectCountry(pages: pages, table: table);

      expect(
        detection,
        const Undetected(reason: UndetectedReason.conflictingEvidence),
      );
    });

    test('passes that disagree are conflicting evidence', () {
      final spanishPass = page(0, <PositionedWord>[
        word('B12345678', 100000, 180000, 100000, 120000),
      ]);
      final germanPass = page(1, <PositionedWord>[
        word('DE987654321', 100000, 200000, 100000, 120000),
      ]);

      final detection = detectCountry(
        pages: <TextPage>[spanishPass, germanPass],
        table: table,
      );

      expect(
        detection,
        const Undetected(reason: UndetectedReason.conflictingEvidence),
      );
    });

    test('a country name adjacent to a postal code is medium evidence', () {
      final pages = <TextPage>[
        page(0, <PositionedWord>[
          word('España', 100000, 160000, 100000, 120000),
          word('28001', 170000, 210000, 100000, 120000),
        ]),
      ];

      final detection = detectCountry(pages: pages, table: table);

      expect(
        detection,
        Detected(
          row: CountryTable.es,
          evidence: const <CountryEvidenceKind>[
            CountryEvidenceKind.countryName,
          ],
        ),
      );
    });

    test('a country name far from an address is only mentioned', () {
      final pages = <TextPage>[
        page(0, <PositionedWord>[
          word('España', 100000, 160000, 100000, 120000),
          word('ACME', 170000, 210000, 180000, 200000),
        ]),
      ];

      final detection = detectCountry(pages: pages, table: table);

      expect(detection, const Undetected(reason: UndetectedReason.noEvidence));
    });

    test('no evidence is noEvidence', () {
      final pages = <TextPage>[
        page(0, <PositionedWord>[
          word('ACME', 100000, 160000, 100000, 120000),
          word('NORTEX', 170000, 230000, 140000, 160000),
        ]),
      ];

      final detection = detectCountry(pages: pages, table: table);

      expect(detection, const Undetected(reason: UndetectedReason.noEvidence));
    });

    test('a currency no row declares points at a country without a row', () {
      final pages = <TextPage>[
        page(0, <PositionedWord>[
          word('CHE123456789', 100000, 200000, 100000, 120000),
          word('CHF', 210000, 240000, 140000, 160000),
        ]),
      ];

      final detection = detectCountry(pages: pages, table: table);

      expect(
        detection,
        const Undetected(reason: UndetectedReason.countryWithoutRow),
      );
    });

    test('shuffled words give the same answer', () {
      final words = <PositionedWord>[
        word('B12345678', 100000, 180000, 100000, 120000),
        word('13.08.2026', 190000, 250000, 140000, 160000),
        word('1.234,56', 260000, 320000, 180000, 200000),
      ];

      final original = detectCountry(
        pages: <TextPage>[page(0, words)],
        table: table,
      );
      final reversed = detectCountry(
        pages: <TextPage>[page(0, words.reversed.toList())],
        table: table,
      );

      expect(
        original,
        Detected(
          row: CountryTable.es,
          evidence: const <CountryEvidenceKind>[CountryEvidenceKind.taxId],
        ),
      );
      expect(reversed, original);
    });

    test('date and amount formats do not change the detection', () {
      final withFormats = detectCountry(
        pages: <TextPage>[
          page(0, <PositionedWord>[
            word('B12345678', 100000, 180000, 100000, 120000),
            word('13.08.2026', 190000, 250000, 140000, 160000),
            word('1.234,56', 260000, 320000, 180000, 200000),
          ]),
        ],
        table: table,
      );
      final withoutFormats = detectCountry(
        pages: <TextPage>[
          page(0, <PositionedWord>[
            word('B12345678', 100000, 180000, 100000, 120000),
          ]),
        ],
        table: table,
      );

      expect(
        withFormats,
        Detected(
          row: CountryTable.es,
          evidence: const <CountryEvidenceKind>[CountryEvidenceKind.taxId],
        ),
      );
      expect(withFormats, withoutFormats);
    });
  });
}
