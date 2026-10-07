import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:paperdrop_core/paperdrop_core.dart';

import 'pdf_eval_json.dart';

/// The JSON writer of the harness (`close-adr-011-pdf-text-route`, task 1.3:
/// "the JSON writer has a unit test", and `flutter test` stays green without a
/// device).
///
/// **What this proves.** That one document and candidate become one file of
/// design §2's shape, with the keys, the units and the page order the comparison
/// script reads: it parses the written text back and checks every key by name,
/// that Core's thousandths of a point are written as points, and that a word's
/// box keeps its four numbers with the top above the bottom.
///
/// **Where it stops.** It writes and reads back its own text. It does not check
/// that the numbers are true of a document — only the native library reading a
/// document can do that, and that belongs to `app/integration_test/`.
void main() {
  final TextPage page = TextPage(0, 595280, 841890, <PositionedWord>[
    // 42.5 / 108.75, and a box from 118.5 down to 130.25, in points: Core holds
    // them in thousandths, the schema is in points, and the writer divides.
    PositionedWord('Gesamtbetrag', 42500, 108750, 118500, 130250),
    PositionedWord('1.234,50', 320000, 366250, 128000, 138000),
  ]);

  test('a document and a candidate become one file of design §2\'s shape', () {
    final String written = evalDocumentJson(
      docId: 'synthetic-01',
      tool: 'pdfrx 2.6.5',
      sha256Before: 'a' * 64,
      sha256After: 'a' * 64,
      msPerPage: <int>[31],
      pages: <TextPage>[page],
    );

    final Map<String, Object?> json =
        jsonDecode(written) as Map<String, Object?>;
    expect(json.keys.toList(), <String>[
      'doc_id',
      'tool',
      'sha256',
      'sha256_after',
      'ms_per_page',
      'pages',
    ]);
    expect(json['doc_id'], 'synthetic-01');
    expect(json['tool'], 'pdfrx 2.6.5');
    expect(json['sha256'], 'a' * 64);
    expect(json['sha256_after'], 'a' * 64);
    expect(json['ms_per_page'], <Object?>[31]);

    final List<Object?> pages = json['pages']! as List<Object?>;
    expect(pages, hasLength(1));
    final Map<String, Object?> only = pages.single! as Map<String, Object?>;
    expect(only.keys.toList(), <String>['index', 'width', 'height', 'words']);
    expect(only['index'], 0);
    expect(only['width'], 595.28);
    expect(only['height'], 841.89);

    final List<Object?> words = only['words']! as List<Object?>;
    expect(words, hasLength(2));
    final Map<String, Object?> first = words.first! as Map<String, Object?>;
    expect(first.keys.toList(), <String>['text', 'x0', 'x1', 'top', 'bottom']);
    expect(first['text'], 'Gesamtbetrag');
    expect(first['x0'], 42.5);
    expect(first['x1'], 108.75);
    expect(first['top'], 118.5);
    expect(first['bottom'], 130.25);
    // The order of the words is the library's order, which the writer repeats
    // and never sorts: what a word is, and which comes first, is what is being
    // compared (design §2).
    expect((words.last! as Map<String, Object?>)['text'], '1.234,50');
    // A box in points, top-left origin: the top of a word is above its bottom.
    expect((first['top']! as num) < (first['bottom']! as num), isTrue);
  });

  test('a page with no word is written as a page with no word', () {
    final String written = evalDocumentJson(
      docId: 'scanned-01',
      tool: 'pdfrx 2.6.5',
      sha256Before: 'b' * 64,
      sha256After: 'b' * 64,
      msPerPage: <int>[7],
      pages: <TextPage>[TextPage(0, 595280, 841890, const <PositionedWord>[])],
    );

    final Map<String, Object?> json =
        jsonDecode(written) as Map<String, Object?>;
    final List<Object?> pages = json['pages']! as List<Object?>;
    expect((pages.single! as Map<String, Object?>)['words'], isEmpty);
  });

  test('the file name is the one the collection expects', () {
    expect(
      evalJsonFileName(docId: 'synthetic-01', candidateToken: 'pdfrx'),
      'synthetic-01.pdfrx-words.json',
    );
  });
}
