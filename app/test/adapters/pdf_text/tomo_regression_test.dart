import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:paperdrop/adapters/pdf_text/pdfrx_text_source.dart';
import 'package:path/path.dart' as p;

/// The synthetic regression of the failure ADR-011 exists for
/// (`close-adr-011-pdf-text-route`, design §5, task 1.4).
///
/// **What it proves, here.** That the committed fixture
/// (`test/fixtures/pdf/tomo_regression.pdf`, written by the script beside it)
/// really carries the structure that failed: a label and its value decoupled in
/// the content stream, with a registry volume `Tomo 8.741` written immediately
/// after the label and on the line below it, and the total written much later
/// but **on the label's own line, to the right**. The page's own operators are
/// read here, so the fixture cannot drift from what this test claims about it.
///
/// **What it cannot prove here.** Reading that page needs PDFium, and what needs
/// the native library lives in `app/integration_test/`
/// (`pdfrx_text_source_test.dart`, and the binding through Core in
/// `tomo_binding_test.dart`), where the orchestrator runs it.
///
/// **What never enters the repository.** The fixture is invented end to end
/// (see its generator). The private corpus is not read, copied or named here;
/// the document that failed, PRO1013-26, is not reproduced — only the structure
/// of the failure.
void main() {
  late File fixture;
  late Uint8List bytes;

  setUpAll(() {
    fixture = File(
      p.join(
        Directory.current.path,
        'test',
        'fixtures',
        'pdf',
        'tomo_regression.pdf',
      ),
    );
    expect(
      fixture.existsSync(),
      isTrue,
      reason:
          'the fixture is committed; regenerate it with '
          '`python app/test/fixtures/pdf/make_tomo_regression.py`',
    );
    bytes = fixture.readAsBytesSync();
  });

  test('the fixture decouples the label from the total and puts the volume '
      'between them', () {
    final List<PlacedText> placed = placedTexts(bytes);
    final int label = _indexOf(placed, 'Gesamtbetrag');
    final int volume = _indexOf(placed, 'Tomo 8.741');
    final int total = _indexOf(placed, '1.234,50');
    final int net = _indexOf(placed, '890,00');

    // Extraction order: the volume follows the label at once, the total comes
    // much later, after the rest of the page. This is the decoupling that made
    // a plain-text parser read the label and its value on different lines and
    // fall back to the nearest number in the stream.
    expect(volume, label + 1);
    expect(total, greaterThan(net));
    // The total is not the next text object either: the rest of the page stands
    // between the volume and it.
    expect(total - volume, greaterThanOrEqualTo(3));

    // Visual layout: the total shares the label's line and sits to its right.
    expect(placed[total].y, placed[label].y);
    expect(placed[total].x, greaterThan(placed[label].x));

    // The volume is on another line — the nearest one below the label, which is
    // where the second branch of the association rule would look. The fixture
    // therefore fails a naive extractor twice over: in stream order and in the
    // one-line-down fallback.
    expect(placed[volume].y, isNot(placed[label].y));
    expect(placed[volume].y, lessThan(placed[label].y));
    expect(placed[label].y - placed[volume].y, lessThan(30));
    expect(placed[volume].x, placed[label].x);
  });

  test('the library the fixture is read with is the one that ships', () {
    expect(
      PdfrxTextSource.toolName,
      'pdfrx 2.6.5',
      reason:
          'ADR-011 closed in favour of candidate B on 2026-10-07, and candidate '
          'A left the build with its code',
    );
  });
}

/// One text object of a content stream, in PDF coordinates.
class PlacedText {
  const PlacedText(this.text, this.x, this.y);

  final String text;
  final double x;
  final double y;

  @override
  String toString() => '$text at $x/$y';
}

/// Every `BT … Td (text) Tj … ET` of [pdf], in the order it was written.
///
/// The fixture's content stream is uncompressed on purpose, so that a test can
/// read the page's own operators instead of trusting a second file that says
/// what they are. It is deliberately small: it understands the two operators the
/// generator writes and nothing else, and it says so by failing on a fixture
/// whose shape it does not know.
List<PlacedText> placedTexts(Uint8List pdf) {
  final String source = latin1.decode(pdf);
  final RegExpMatch? first = RegExp(r'stream\n').firstMatch(source);
  expect(first, isNotNull, reason: 'the fixture has no content stream');
  final int start = first!.end;
  final int end = source.indexOf('endstream', start);
  expect(end, greaterThan(start));

  final List<PlacedText> placed = <PlacedText>[];
  for (final RegExpMatch match in RegExp(
    r'BT\s+/F1\s+[\d.]+\s+Tf\s+([\d.]+)\s+([\d.]+)\s+Td\s+\((.*?)\)\s*Tj\s+ET',
  ).allMatches(source.substring(start, end))) {
    placed.add(
      PlacedText(
        match.group(3)!,
        double.parse(match.group(1)!),
        double.parse(match.group(2)!),
      ),
    );
  }
  expect(
    placed,
    isNotEmpty,
    reason: 'the fixture\'s text objects were not recognised',
  );
  return placed;
}

int _indexOf(List<PlacedText> placed, String text) {
  final int index = placed.indexWhere((PlacedText item) => item.text == text);
  expect(index, isNonNegative, reason: '$text is not in the fixture');
  return index;
}
