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
/// really carries the structure that failed, on the two pages the rule's two
/// branches need: page 1 puts the total on the label's own line, to the right,
/// decoupled from it in the content stream, with the registry volume on the line
/// below; page 2 puts the total on the line below and the volume next to the
/// label in the stream but one row above it. The pages' own operators are read
/// here, so the fixture cannot drift from what this test claims about it.
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

  test('page 1 decouples the label from the total and puts the volume on the '
      'line below', () {
    final PlacedTexts page = placedPages(bytes)[0];
    final List<PlacedText> placed = page.entries;
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

  test('page 2 puts the total on the line below and the volume out of reach', () {
    final PlacedTexts page = placedPages(bytes)[1];
    final List<PlacedText> placed = page.entries;
    final int label = _indexOf(placed, 'Gesamtbetrag');
    final int volume = _indexOf(placed, 'Tomo 8.741');
    final int total = _indexOf(placed, '1.234,50');

    // Nothing shares the label's line, so the rule's first branch — the words to
    // its right — has nothing to bind.
    expect(
      placed.where((PlacedText item) => item.y == placed[label].y),
      hasLength(1),
    );

    // The volume is the next text object in the stream and the row *above* the
    // label: nearer in extraction order than the total is, and somewhere the
    // layout rule never looks.
    expect(volume, label + 1);
    expect(placed[volume].y, greaterThan(placed[label].y));

    // The total is on the line below, overlapping the label horizontally — the
    // only shape the second branch can bind — and one line step away, not two:
    // the rule reaches no further down than one label-line height, and a line of
    // 10-point text is under 10 points tall.
    expect(placed[total].y, lessThan(placed[label].y));
    expect(placed[total].x, placed[label].x);
    expect(placed[label].y - placed[total].y, inInclusiveRange(10, 20));
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

/// The text objects of one page, in the order they were written.
class PlacedTexts {
  const PlacedTexts(this.entries);

  final List<PlacedText> entries;
}

/// Every text object of [pdf], page by page, in the order it was written.
///
/// The fixture's content streams are uncompressed on purpose, so that a test can
/// read the pages' own operators instead of trusting a second file that says
/// what they are. It is deliberately small: it understands the two operators the
/// generator writes and nothing else, and it fails on a fixture whose shape it
/// does not know.
List<PlacedTexts> placedPages(Uint8List pdf) {
  final String source = latin1.decode(pdf);
  final List<PlacedTexts> pages = <PlacedTexts>[];
  // The stream a page's content is written into. The `endstream` that closes it
  // also ends in `stream`, and is not one of them.
  for (final RegExpMatch stream in RegExp(
    r'(?<!end)stream\n',
  ).allMatches(source)) {
    final int end = source.indexOf('endstream', stream.end);
    expect(end, greaterThan(stream.end), reason: 'a stream is not closed');
    final List<PlacedText> placed = <PlacedText>[];
    for (final RegExpMatch match in RegExp(
      r'BT\s+/F1\s+[\d.]+\s+Tf\s+([\d.]+)\s+([\d.]+)\s+Td\s+\((.*?)\)\s*Tj\s+ET',
    ).allMatches(source.substring(stream.end, end))) {
      placed.add(
        PlacedText(
          match.group(3)!,
          double.parse(match.group(1)!),
          double.parse(match.group(2)!),
        ),
      );
    }
    pages.add(PlacedTexts(placed));
  }
  expect(
    pages,
    hasLength(2),
    reason: 'the fixture is two pages, one for each branch of the rule',
  );
  expect(
    pages.every((PlacedTexts page) => page.entries.isNotEmpty),
    isTrue,
    reason: 'the fixture\'s text objects were not recognised',
  );
  return pages;
}

int _indexOf(List<PlacedText> placed, String text) {
  final int index = placed.indexWhere((PlacedText item) => item.text == text);
  expect(index, isNonNegative, reason: '$text is not in the fixture');
  return index;
}
