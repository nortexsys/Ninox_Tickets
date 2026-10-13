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
}
