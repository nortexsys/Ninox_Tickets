import 'dart:io';

import 'package:paperdrop_core/paperdrop_core.dart';
import 'package:test/test.dart';

void main() {
  final es = CountryTable.es;
  final table = CountryTable.launch;

  PositionedWord word(String text, int x0, int x1, int top, int bottom) =>
      PositionedWord(text, x0, x1, top, bottom);

  TextPage page(List<PositionedWord> words) =>
      TextPage(0, 300000, 300000, words);

  ExtractionPass pass(
    String routeLabel,
    List<TextPage> pages, [
    String id = 'p',
  ]) => ExtractionPass(passId: id, routeLabel: routeLabel, pages: pages);

  ({CanonicalDocument document, CollectingTrace trace}) run({
    required List<ExtractionPass> passes,
    required CountryRow? country,
  }) {
    final trace = CollectingTrace();
    final document = extractDocument(
      passes: passes,
      country: country,
      table: table,
      sourceHash: 'h',
      trace: trace,
    );
    return (document: document, trace: trace);
  }

  group('document-level stages', () {
    test('countryDetected and countryUndetected are recorded once', () {
      final detected = run(
        passes: <ExtractionPass>[
          pass('pdf-text/pdfrx 2.6.5', const <TextPage>[]),
        ],
        country: es,
      );
      expect(detected.trace.stages['country'], <ExtractionStage>[
        ExtractionStage.countryDetected,
      ]);

      final undetected = run(
        passes: <ExtractionPass>[
          pass('pdf-text/pdfrx 2.6.5', const <TextPage>[]),
        ],
        country: null,
      );
      expect(undetected.trace.stages['country'], <ExtractionStage>[
        ExtractionStage.countryUndetected,
      ]);
    });

    test('the pass count used is recorded as a closed stage', () {
      final expected = <int, ExtractionStage>{
        1: ExtractionStage.onePass,
        2: ExtractionStage.twoPasses,
        3: ExtractionStage.threePasses,
        4: ExtractionStage.fourPasses,
        5: ExtractionStage.moreThanFourPasses,
      };

      for (final entry in expected.entries) {
        final result = run(
          passes: <ExtractionPass>[
            for (var i = 0; i < entry.key; i++)
              pass('pdf-ocr', const <TextPage>[], 'pass-$i'),
          ],
          country: es,
        );
        expect(result.trace.stages['pass_count'], <ExtractionStage>[
          entry.value,
        ]);
      }
    });
  });

  group('field-loss stages', () {
    test('noLabelOfKind fires when no dictionary label of the kind exists', () {
      final result = run(
        passes: <ExtractionPass>[
          pass('pdf-text/pdfrx 2.6.5', <TextPage>[
            page(<PositionedWord>[
              word('ACME', 100000, 120000, 100000, 120000),
              word('NORTEX', 130000, 160000, 100000, 120000),
            ]),
          ]),
        ],
        country: es,
      );

      for (final field in <String>[
        'gross_total',
        'net_total',
        'tax_total',
        'doc_date',
        'supplier_name',
        'doc_number',
      ]) {
        expect(
          result.trace.stages[field],
          contains(ExtractionStage.noLabelOfKind),
          reason: '$field should record noLabelOfKind',
        );
      }
    });

    test('labelFoundNoValue fires when a label has no candidate value', () {
      final result = run(
        passes: <ExtractionPass>[
          pass('pdf-text/pdfrx 2.6.5', <TextPage>[
            page(<PositionedWord>[
              word('TOTAL', 100000, 120000, 100000, 120000),
            ]),
          ]),
        ],
        country: es,
      );

      expect(
        result.trace.stages['gross_total'],
        contains(ExtractionStage.labelFoundNoValue),
      );
    });

    test('valueNotParsed fires when a candidate is not an amount', () {
      final result = run(
        passes: <ExtractionPass>[
          pass('pdf-text/pdfrx 2.6.5', <TextPage>[
            page(<PositionedWord>[
              word('TOTAL', 100000, 120000, 100000, 120000),
              word('N/A', 130000, 160000, 100000, 120000),
            ]),
          ]),
        ],
        country: es,
      );

      expect(
        result.trace.stages['gross_total'],
        contains(ExtractionStage.valueNotParsed),
      );
    });

    test('negativeContextRejected fires for a suppressed amount candidate', () {
      final result = run(
        passes: <ExtractionPass>[
          pass('pdf-text/pdfrx 2.6.5', <TextPage>[
            page(<PositionedWord>[
              word('TOTAL', 100000, 120000, 100000, 120000),
              word('10,00', 130000, 160000, 100000, 120000),
              word('propina', 170000, 210000, 100000, 120000),
            ]),
          ]),
        ],
        country: es,
      );

      expect(
        result.trace.stages['gross_total'],
        contains(ExtractionStage.negativeContextRejected),
      );
    });

    test(
      'kept candidates that do not add up are read and lowered, not dropped',
      () {
        final result = run(
          passes: <ExtractionPass>[
            pass('pdf-text/pdfrx 2.6.5', <TextPage>[
              page(<PositionedWord>[
                word('TOTAL', 100000, 120000, 100000, 120000),
                word('100,00', 130000, 160000, 100000, 120000),
                word('BASE', 100000, 120000, 140000, 160000),
                word('40,00', 130000, 160000, 140000, 160000),
                word('IVA', 100000, 120000, 180000, 200000),
                word('10,00', 130000, 160000, 180000, 200000),
              ]),
            ]),
          ],
          country: es,
        );

        expect(
          result.document.grossTotal,
          Present<Money>(
            Money(10000, CurrencyCode.parse('EUR')!),
            Provenance.read,
            ConfidenceState.red,
          ),
        );
        expect(
          result.document.netTotal,
          Present<Money>(
            Money(4000, CurrencyCode.parse('EUR')!),
            Provenance.read,
            ConfidenceState.red,
          ),
        );
        expect(
          result.document.taxTotal,
          Present<Money>(
            Money(1000, CurrencyCode.parse('EUR')!),
            Provenance.read,
            ConfidenceState.red,
          ),
        );

        for (final field in <String>['gross_total', 'net_total', 'tax_total']) {
          expect(
            result.trace.stages[field],
            contains(ExtractionStage.confidenceCapped),
            reason: '$field should be kept but lowered',
          );
        }
      },
    );

    test('multipleArithmeticIdentities fires when several triples match', () {
      final result = run(
        passes: <ExtractionPass>[
          pass('pdf-text/pdfrx 2.6.5', <TextPage>[
            page(<PositionedWord>[
              word('TOTAL', 100000, 120000, 100000, 120000),
              word('121,00', 130000, 160000, 100000, 120000),
              word('BASE', 100000, 120000, 140000, 160000),
              word('100,00', 130000, 160000, 140000, 160000),
              word('IVA', 100000, 120000, 180000, 200000),
              word('21,00', 130000, 160000, 180000, 200000),
              word('TOTAL', 100000, 120000, 220000, 240000),
              word('242,00', 130000, 160000, 220000, 240000),
              word('BASE', 100000, 120000, 260000, 280000),
              word('200,00', 130000, 160000, 260000, 280000),
              word('IVA', 100000, 120000, 300000, 320000),
              word('42,00', 130000, 160000, 300000, 320000),
            ]),
          ]),
        ],
        country: es,
      );

      for (final field in <String>['gross_total', 'net_total', 'tax_total']) {
        expect(
          result.trace.stages[field],
          contains(ExtractionStage.multipleArithmeticIdentities),
          reason: '$field should record multipleArithmeticIdentities',
        );
      }
    });

    test(
      'legalRateGateFailed fires when a discarded rate blocks derivation',
      () {
        final result = run(
          passes: <ExtractionPass>[
            pass('pdf-text/pdfrx 2.6.5', <TextPage>[
              page(<PositionedWord>[
                word('BASE', 100000, 120000, 100000, 120000),
                word('100,00', 130000, 160000, 100000, 120000),
                word('IVA', 100000, 120000, 140000, 160000),
                word('25,00', 130000, 160000, 140000, 160000),
                word('25', 100000, 110000, 180000, 200000),
                word('%', 115000, 125000, 180000, 200000),
              ]),
            ]),
          ],
          country: es,
        );

        expect(
          result.trace.stages['gross_total'],
          contains(ExtractionStage.legalRateGateFailed),
          reason: 'the discarded rate still blocks deriving the missing gross',
        );
        expect(result.document.grossTotal, const Absent<Money>());
        expect(
          result.document.netTotal,
          Present<Money>(
            Money(10000, CurrencyCode.parse('EUR')!),
            Provenance.read,
            ConfidenceState.amber,
          ),
        );
        expect(
          result.document.taxTotal,
          Present<Money>(
            Money(2500, CurrencyCode.parse('EUR')!),
            Provenance.read,
            ConfidenceState.amber,
          ),
        );

        for (final field in <String>['net_total', 'tax_total']) {
          expect(
            result.trace.stages[field],
            contains(ExtractionStage.confidenceCapped),
            reason: '$field is read but has no identity to confirm it',
          );
        }
      },
    );

    test('noMajority fires when passes tie on a field', () {
      TextPage invoice(String total) => page(<PositionedWord>[
        word('TOTAL', 100000, 120000, 100000, 120000),
        word(total, 130000, 160000, 100000, 120000),
        word('BASE', 100000, 120000, 140000, 160000),
        word('100,00', 130000, 160000, 140000, 160000),
        word('IVA', 100000, 120000, 180000, 200000),
        word('21,00', 130000, 160000, 180000, 200000),
      ]);

      final result = run(
        passes: <ExtractionPass>[
          for (var i = 0; i < 2; i++)
            pass('pdf-ocr', <TextPage>[invoice('121,00')], 'a-$i'),
          for (var i = 0; i < 2; i++)
            pass('pdf-ocr', <TextPage>[invoice('120,00')], 'b-$i'),
        ],
        country: es,
      );

      expect(
        result.trace.stages['gross_total'],
        contains(ExtractionStage.noMajority),
      );
    });

    test('pagesDisagreed fires when pages of one pass disagree', () {
      final result = run(
        passes: <ExtractionPass>[
          pass('pdf-ocr', <TextPage>[
            page(<PositionedWord>[
              word('TOTAL', 100000, 120000, 100000, 120000),
              word('121,00', 130000, 160000, 100000, 120000),
            ]),
            page(<PositionedWord>[
              word('TOTAL', 100000, 120000, 100000, 120000),
              word('120,00', 130000, 160000, 100000, 120000),
            ]),
          ]),
        ],
        country: es,
      );

      expect(
        result.trace.stages['gross_total'],
        contains(ExtractionStage.pagesDisagreed),
      );
    });

    test('confidenceCapped fires for a single reading without an identity', () {
      final result = run(
        passes: <ExtractionPass>[
          pass('pdf-text/pdfrx 2.6.5', <TextPage>[
            page(<PositionedWord>[
              word('TOTAL', 100000, 120000, 100000, 120000),
              word('121,00', 130000, 160000, 100000, 120000),
            ]),
          ]),
        ],
        country: es,
      );

      expect(result.document.grossTotal, isA<Present<Money>>());
      expect(
        result.trace.stages['gross_total'],
        contains(ExtractionStage.confidenceCapped),
      );
    });

    test('noCurrencyEvidence fires when the document prints no currency', () {
      final result = run(
        passes: <ExtractionPass>[
          pass('pdf-text/pdfrx 2.6.5', <TextPage>[
            page(<PositionedWord>[
              word('TOTAL', 100000, 120000, 100000, 120000),
              word('121,00', 130000, 160000, 100000, 120000),
            ]),
          ]),
        ],
        country: null,
      );

      expect(
        result.trace.stages['currency'],
        contains(ExtractionStage.noCurrencyEvidence),
      );
    });

    test('conflictingCurrencyEvidence fires for two printed currencies', () {
      final result = run(
        passes: <ExtractionPass>[
          pass('pdf-text/pdfrx 2.6.5', <TextPage>[
            page(<PositionedWord>[
              word('EUR', 100000, 120000, 100000, 120000),
              word('USD', 130000, 160000, 100000, 120000),
            ]),
          ]),
        ],
        country: null,
      );

      expect(
        result.trace.stages['currency'],
        contains(ExtractionStage.conflictingCurrencyEvidence),
      );
    });
  });

  group('privacy', () {
    test('no record call in the trace path passes a document value', () {
      final files = <String>[
        'lib/src/extraction/extraction_trace.dart',
        'lib/src/extraction/extract_document.dart',
        'lib/src/layout/binding.dart',
        'lib/src/solver/operands.dart',
      ];
      final forbidden = <String>[
        '.text',
        '.value',
        '.amount',
        '.rate',
        '.words',
        '.documentNumber',
        '.date',
        '.minor',
        '.code',
      ];

      for (final file in files) {
        final source = File(file).readAsStringSync();
        for (final arguments in _recordArguments(source)) {
          for (final fragment in forbidden) {
            expect(
              arguments.contains(fragment),
              isFalse,
              reason: '$file passes a document value to record: $arguments',
            );
          }
        }
      }
    });

    test('a collecting trace holds only enum stage names', () {
      final result = run(
        passes: <ExtractionPass>[
          pass('pdf-text/pdfrx 2.6.5', <TextPage>[
            page(<PositionedWord>[
              word('TOTAL', 100000, 120000, 100000, 120000),
              word('121,00', 130000, 160000, 100000, 120000),
              word('BASE', 100000, 120000, 140000, 160000),
              word('100,00', 130000, 160000, 140000, 160000),
              word('IVA', 100000, 120000, 180000, 200000),
              word('21,00', 130000, 160000, 180000, 200000),
              word('NORTEX', 100000, 140000, 220000, 240000),
            ]),
          ]),
        ],
        country: es,
      );

      final allStages = result.trace.stages.values
          .expand((List<ExtractionStage> stages) => stages)
          .toSet();
      expect(allStages.every(ExtractionStage.values.contains), isTrue);
      expect(result.trace.toString(), isNot(contains('121,00')));
      expect(result.trace.toString(), isNot(contains('NORTEX')));
    });
  });
}

Iterable<String> _recordArguments(String source) sync* {
  final pattern = RegExp(r'(?:trace\.record|_recordTrace)\s*\(');
  for (final match in pattern.allMatches(source)) {
    var depth = 1;
    var end = match.end;
    while (end < source.length && depth > 0) {
      final character = source[end];
      if (character == '(') {
        depth++;
      } else if (character == ')') {
        depth--;
      }
      end++;
    }
    yield source.substring(match.end, end - 1);
  }
}
