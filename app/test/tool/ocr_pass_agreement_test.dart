import 'package:flutter_test/flutter_test.dart';
import 'package:paperdrop/adapters/ocr/ocr_text_source.dart';
import 'package:paperdrop_core/paperdrop_core.dart';

import 'ocr_pass_agreement.dart';

/// The numbers the device harness reports (`implement-photo-passes`, design §5
/// and task 1.6).
///
/// **What this proves.** That the words per pass and the share of words two
/// passes agree on are counted as design §5 says: after normalising case and the
/// punctuation around a word, with multiplicity, and with no threshold applied
/// anywhere. It also proves what the numbers are *not*: a pass's words are
/// reduced to a count before anything is written, so no report can carry a
/// document's text — which is why this file can be read by anyone and the
/// detailed JSON cannot.
///
/// **Where it stops.** It reads passes this test builds. What a pass of a real
/// photograph reads is the device run's (task 2.1), and which share is good
/// enough is T2.5's and the product owner's.
void main() {
  /// A pass of one page holding [words], at [width] by [height] thousandths of
  /// a point.
  OcrPass passOf(
    String passId,
    List<String> words, {
    int width = 595280,
    int height = 841890,
  }) => OcrPass(passId, <TextPage>[
    TextPage(0, width, height, <PositionedWord>[
      for (var index = 0; index < words.length; index++)
        PositionedWord(words[index], index, index, index + 1, index + 1),
    ]),
  ]);

  group('normalising one word', () {
    test('case and the punctuation around a word are set aside', () {
      expect(normaliseWord('Gesamtbetrag'), 'gesamtbetrag');
      expect(normaliseWord('GESAMTBETRAG'), 'gesamtbetrag');
      expect(normaliseWord('.Gesamtbetrag,'), 'gesamtbetrag');
      expect(normaliseWord('(1.234,50)'), '1.234,50');
      expect(normaliseWord('"Beispiel"'), 'beispiel');
      expect(normaliseWord('…'), '', reason: 'no word at all is no word');
      expect(normaliseWord('  Betrag.  '), 'betrag');
    });

    test('the punctuation inside a word is kept', () {
      // The engine's segmentation is what is compared: two different amounts
      // must not become the same word.
      expect(normaliseWord('1.234,50'), isNot(normaliseWord('123450')));
      expect(normaliseWord('2026-0001'), '2026-0001');
      expect(normaliseWord('Rechnungs-Nr.'), 'rechnungs-nr');
      expect(normaliseWord('10115 Beispielstadt'), '10115 beispielstadt');
    });

    test('letters outside a-z are letters', () {
      expect(normaliseWord('(Straße)'), 'straße');
      expect(normaliseWord('«Betrag»'), 'betrag');
      expect(normaliseWord('€1.234,50'), '1.234,50');
    });
  });

  test('a pass is counted after normalisation', () {
    expect(
      wordsInPass(passOf('p1-native', <String>['Betrag', '1.234,50', '.'])),
      2,
      reason: 'a run of punctuation is not a word',
    );
    expect(wordsInPass(passOf('p1-native', <String>[])), 0);
  });

  group('the agreement of two passes', () {
    test('every different pair is measured, once', () {
      final List<OcrPassAgreement> agreements = passAgreements(<OcrPass>[
        passOf('p1-native', <String>['a', 'b']),
        passOf('p2-contrast', <String>['a', 'b']),
        passOf('p3-lo', <String>['a']),
        passOf('p4-hi', <String>['b']),
      ]);

      expect(
        agreements
            .map(
              (OcrPassAgreement pair) =>
                  '${pair.firstPassId}|${pair.secondPassId}',
            )
            .toList(),
        <String>[
          'p1-native|p2-contrast',
          'p1-native|p3-lo',
          'p1-native|p4-hi',
          'p2-contrast|p3-lo',
          'p2-contrast|p4-hi',
          'p3-lo|p4-hi',
        ],
      );
      // Two passes that read the same two words share both, whatever order and
      // case they came in.
      expect(agreements.first.share, 1);
      expect(agreements.first.sharedWords, 2);
    });

    test('the share is over the words of the larger pass', () {
      final List<OcrPassAgreement> agreements = passAgreements(<OcrPass>[
        passOf('p1-native', <String>['a', 'b', 'c', 'd']),
        passOf('p3-lo', <String>['a', 'B.', 'x']),
      ]);

      expect(agreements.single.firstWords, 4);
      expect(agreements.single.secondWords, 3);
      expect(agreements.single.sharedWords, 2);
      expect(agreements.single.share, closeTo(0.5, 1e-9));
    });

    test('a word read twice counts once for each pass that read it', () {
      final List<OcrPassAgreement> agreements = passAgreements(<OcrPass>[
        passOf('p1-native', <String>['a', 'a', 'b']),
        passOf('p3-lo', <String>['a', 'b']),
      ]);

      expect(agreements.single.sharedWords, 2);
      expect(agreements.single.share, closeTo(2 / 3, 1e-9));
    });

    test('two passes that read nothing at all agree on all of it', () {
      final List<OcrPassAgreement> agreements = passAgreements(<OcrPass>[
        passOf('p1-native', <String>[]),
        passOf('p3-lo', <String>[]),
      ]);

      expect(agreements.single.share, 1);
      expect(agreements.single.firstWords, 0);
      expect(agreements.single.secondWords, 0);
    });

    test('one pass, and no pass, give no pair', () {
      expect(
        passAgreements(<OcrPass>[
          passOf('p1-native', <String>['a']),
        ]),
        isEmpty,
      );
      expect(passAgreements(<OcrPass>[]), isEmpty);
    });

    test('a pair says what it measured', () {
      expect(
        const OcrPassAgreement(
          firstPassId: 'p1-native',
          secondPassId: 'p3-lo',
          firstWords: 2,
          secondWords: 3,
          sharedWords: 1,
        ).toString(),
        'OcrPassAgreement(p1-native vs p3-lo: 1/2, 3)',
      );
    });
  });

  group('the page sizes of one document', () {
    test('every pass of one document reports the same sizes', () {
      expect(
        distinctPageSizes(<OcrPass>[
          passOf('p1-native', <String>['a']),
          passOf('p2-contrast', <String>['a'], width: 600000, height: 800000),
        ]),
        2,
        reason: 'a pass that measured another page is a different size',
      );
      expect(
        distinctPageSizes(<OcrPass>[
          passOf('p1-native', <String>['a']),
          passOf('p2-contrast', <String>['a']),
          passOf('p3-lo', <String>[]),
        ]),
        1,
      );
    });

    test('no pass at all is no size', () {
      expect(distinctPageSizes(<OcrPass>[]), 0);
    });
  });
}
