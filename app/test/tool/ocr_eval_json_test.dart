import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:paperdrop/adapters/ocr/ocr_text_source.dart';
import 'package:paperdrop_core/paperdrop_core.dart';

import 'ocr_eval_json.dart';

/// The JSON writer of the photo route's harness (`implement-photo-route`,
/// task 1.6, and `flutter test` stays green without a device).
///
/// **What this proves.** That a document's passes become one file of design §4's
/// shape, with the keys whoever compares the passes reads: the pass id and its
/// milliseconds, the pages in page order, the words in the reference schema's
/// four numbers, the two hashes, and the passes that were dropped named with
/// what threw. It parses the written text back and checks every key by name, so
/// a rename fails here rather than in T2.5.
///
/// **Where it stops.** It writes and reads back its own text. It does not check
/// that the numbers are true of a document — only the engine reading a document
/// can do that, and that belongs to `app/integration_test/`.
void main() {
  final OcrPass first = OcrPass('p1-native', <TextPage>[
    TextPage(0, 595280, 841890, <PositionedWord>[
      // 42.5 / 108.75, and a box from 118.5 down to 130.25, in points: Core
      // holds them in thousandths, the schema is in points, and the writer
      // divides.
      PositionedWord('Gesamtbetrag', 42500, 108750, 118500, 130250),
      PositionedWord('1.234,50', 320000, 366250, 128000, 138000),
    ]),
  ]);

  test('one document becomes one file of design §4\'s shape', () {
    final String written = ocrEvalDocumentJson(
      docId: 'synthetic-01',
      tool: 'google_mlkit_text_recognition 0.17.1',
      sha256Before: 'a' * 64,
      sha256After: 'a' * 64,
      passes: <OcrPass>[
        first,
        OcrPass('p3-lo', <TextPage>[
          TextPage(0, 595280, 841890, <PositionedWord>[]),
        ]),
      ],
      msPerPass: <String, int>{'p1-native': 812, 'p3-lo': 430},
      droppedPasses: const <OcrDroppedPass>[
        OcrDroppedPass('p2-hi', 'OcrFailure: page 0 could not be rendered'),
      ],
    );

    final Map<String, Object?> json =
        jsonDecode(written) as Map<String, Object?>;
    expect(json.keys.toList(), <String>[
      'doc_id',
      'tool',
      'sha256',
      'sha256_after',
      'passes',
      'dropped_passes',
    ]);
    expect(json['doc_id'], 'synthetic-01');
    expect(json['tool'], 'google_mlkit_text_recognition 0.17.1');
    expect(json['sha256'], 'a' * 64);
    expect(json['sha256_after'], 'a' * 64);

    final List<Object?> passes = json['passes']! as List<Object?>;
    expect(passes, hasLength(2));
    final Map<String, Object?> only = passes.first! as Map<String, Object?>;
    expect(only.keys.toList(), <String>['pass_id', 'ms', 'pages']);
    expect(only['pass_id'], 'p1-native');
    expect(only['ms'], 812);

    final Map<String, Object?> second = passes.last! as Map<String, Object?>;
    expect(second['pass_id'], 'p3-lo');
    expect(second['ms'], 430);

    final Map<String, Object?> page =
        (only['pages']! as List<Object?>).single! as Map<String, Object?>;
    expect(page.keys.toList(), <String>['index', 'width', 'height', 'words']);
    expect(page['index'], 0);
    // A thousandth of a point is not a point: 595280 is 595.28.
    expect(page['width'], 595.28);
    expect(page['height'], 841.89);

    final List<Object?> words = page['words']! as List<Object?>;
    expect(words, hasLength(2));
    final Map<String, Object?> word = words.first! as Map<String, Object?>;
    expect(word.keys.toList(), <String>['text', 'x0', 'x1', 'top', 'bottom']);
    expect(word['text'], 'Gesamtbetrag');
    expect(word['x0'], 42.5);
    expect(word['x1'], 108.75);
    expect(word['top'], 118.5);
    expect(word['bottom'], 130.25);

    // An empty page is written as an empty word list, not left out: a pass that
    // found nothing is a reading, and consensus needs to know it happened.
    final Map<String, Object?> emptyPage =
        (second['pages']! as List<Object?>).single! as Map<String, Object?>;
    expect(emptyPage['words'], isEmpty);

    final List<Object?> dropped = json['dropped_passes']! as List<Object?>;
    expect(dropped, hasLength(1));
    final Map<String, Object?> failure =
        dropped.single! as Map<String, Object?>;
    expect(failure.keys.toList(), <String>['pass_id', 'error']);
    expect(failure['pass_id'], 'p2-hi');
    expect(failure['error'], contains('could not be rendered'));
  });

  test('a pass that was not timed is written as untimed, not as zero', () {
    final String written = ocrEvalDocumentJson(
      docId: 'synthetic-02',
      tool: 'tool',
      sha256Before: 'b' * 64,
      sha256After: 'b' * 64,
      passes: <OcrPass>[first],
      msPerPass: const <String, int>{},
      droppedPasses: const <OcrDroppedPass>[],
    );

    final Map<String, Object?> json =
        jsonDecode(written) as Map<String, Object?>;
    final Map<String, Object?> pass =
        (json['passes']! as List<Object?>).single! as Map<String, Object?>;
    expect(pass['ms'], -1);
    expect(json['dropped_passes'], isEmpty);
  });

  test('the file name names the document and says what it holds', () {
    expect(
      ocrEvalJsonFileName(docId: 'photo-synthetic-01'),
      'photo-synthetic-01.mlkit-ocr.json',
    );
  });

  group('the summary of a document', () {
    /// A pass of one page of [words], at [width] by [height] thousandths.
    OcrPass passOf(
      String passId,
      List<String> words, {
      int width = 595280,
      int height = 841890,
    }) => OcrPass(passId, <TextPage>[
      TextPage(0, width, height, <PositionedWord>[
        for (var index = 0; index < words.length; index++)
          PositionedWord(words[index], index, index, index + 10, index + 20),
      ]),
    ]);

    String summaryOf({
      required List<OcrPass> passes,
      Map<String, int> msPerPass = const <String, int>{},
      List<OcrDroppedPass> droppedPasses = const <OcrDroppedPass>[],
      String? sha256Before,
      String? sha256After,
    }) => ocrEvalSummaryJson(
      docId: 'photo-synthetic-01',
      tool: 'google_mlkit_text_recognition 0.17.1',
      // A hash-shaped value, built and not written out: a literal of sixty
      // four hex-looking characters is what the privacy check looks for.
      sha256Before: sha256Before ?? 'a' * 64,
      sha256After: sha256After ?? sha256Before ?? 'a' * 64,
      passes: passes,
      msPerPass: msPerPass,
      droppedPasses: droppedPasses,
    );

    test('it holds numbers and pass ids, and not one word of the document', () {
      final String written = summaryOf(
        passes: <OcrPass>[
          passOf('p1-native', <String>['Gesamtbetrag', '1.234,50']),
          passOf('p3-lo', <String>['Gesamtbetrag', 'Beispiel']),
        ],
        msPerPass: <String, int>{'p1-native': 812, 'p3-lo': 430},
        droppedPasses: const <OcrDroppedPass>[
          OcrDroppedPass('p4-hi', 'OcrFailure: the image could not be decoded'),
        ],
      );

      // The document's own words, in any case, are not in the file — nor is
      // whatever threw, which can carry a path or a file name of its own.
      for (final String word in <String>[
        'Gesamtbetrag',
        'gesamtbetrag',
        '1.234,50',
        'Beispiel',
      ]) {
        expect(written, isNot(contains(word)));
      }
      expect(written, isNot(contains('could not be decoded')));

      final Map<String, Object?> json =
          jsonDecode(written) as Map<String, Object?>;
      expect(json.keys.toList(), <String>[
        'doc_id',
        'tool',
        'sha256_changed',
        'passes',
        'agreement',
        'distinct_page_sizes',
        'dropped_pass_ids',
      ]);
      expect(json['doc_id'], 'photo-synthetic-01');
      expect(json['tool'], 'google_mlkit_text_recognition 0.17.1');
      expect(json['sha256_changed'], 0);
      expect(json['distinct_page_sizes'], 1);
      expect(json['dropped_pass_ids'], <Object?>['p4-hi']);
    });

    test('it counts the words of each pass and what two passes share', () {
      final String written = summaryOf(
        // Four readings of one page: the two words, one of them, both, and the
        // same two in another case with punctuation around one of them.
        passes: <OcrPass>[
          passOf('p1-native', <String>['Gesamtbetrag', '1.234,50']),
          passOf('p2-contrast', <String>['1.234,50']),
          passOf('p3-lo', <String>['GESAMTBETRAG', '(1.234,50)']),
          passOf('p4-hi', <String>[]),
        ],
        msPerPass: <String, int>{'p1-native': 812},
      );

      final Map<String, Object?> json =
          jsonDecode(written) as Map<String, Object?>;
      final List<Object?> passes = json['passes']! as List<Object?>;
      expect(passes, hasLength(4));
      expect(
        passes
            .map((Object? pass) => (pass! as Map<String, Object?>)['words'])
            .toList(),
        <Object?>[2, 1, 2, 0],
      );
      expect((passes.first! as Map<String, Object?>)['ms'], 812);
      // A pass that was not timed is untimed and not a pass that took no time.
      expect((passes[1]! as Map<String, Object?>)['ms'], -1);
      // The words of the pass that read nothing are counted as none, and its
      // page is still reported: a pass that found nothing is a reading.
      expect(
        ((passes.last! as Map<String, Object?>)['pages']! as List<Object?>)
            .single,
        <String, Object?>{
          'index': 0,
          'width': 595.28,
          'height': 841.89,
          'words': 0,
        },
      );

      // Six pairs of four passes, and every one of them a share and its counts.
      final List<Object?> agreements = json['agreement']! as List<Object?>;
      expect(agreements, hasLength(6));
      final Map<String, Object?> firstPair =
          agreements.first! as Map<String, Object?>;
      expect(firstPair.keys.toList(), <String>[
        'first_pass_id',
        'second_pass_id',
        'first_words',
        'second_words',
        'shared_words',
        'share',
      ]);
      expect(firstPair['first_pass_id'], 'p1-native');
      expect(firstPair['second_pass_id'], 'p2-contrast');
      expect(firstPair['shared_words'], 1);
      expect(firstPair['share'], 0.5);
      // The case-folded, punctuation-stripped pair agrees on both words.
      final Map<String, Object?> between = agreements
          .map((Object? pair) => pair! as Map<String, Object?>)
          .firstWhere(
            (Map<String, Object?> pair) =>
                pair['first_pass_id'] == 'p1-native' &&
                pair['second_pass_id'] == 'p3-lo',
          );
      expect(between['shared_words'], 2);
      expect(between['share'], 1.0);
    });

    test('a document whose passes measured different pages says so', () {
      final Map<String, Object?> json = jsonDecode(
        summaryOf(
          passes: <OcrPass>[
            passOf('p1-native', <String>['a']),
            // The same page, converted with another size: the defect
            // design §4 makes the harness look for, as a number.
            passOf('p3-lo', <String>['a'], width: 600000, height: 800000),
          ],
        ),
      ) as Map<String, Object?>;

      expect(json['distinct_page_sizes'], 2);
    });

    test('a file that was changed while it was read says so', () {
      final Map<String, Object?> json = jsonDecode(
        summaryOf(
          passes: <OcrPass>[
            passOf('p1-native', <String>['a']),
          ],
          sha256After: 'b' * 64,
        ),
      ) as Map<String, Object?>;

      expect(json['sha256_changed'], 1);
      // One pass has no pair to compare with, and its own counts are there.
      expect(json['agreement'], isEmpty);
    });

    test('the summary file name says what it holds and names the document', () {
      expect(
        ocrEvalSummaryFileName(docId: 'photo-synthetic-01'),
        'photo-synthetic-01.mlkit-ocr-summary.json',
      );
    });
  });
}
