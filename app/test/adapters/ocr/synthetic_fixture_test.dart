import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// The photo route's committed fixture, against the generator's own claims
/// (`implement-photo-route`, design §4: "One synthetic public fixture only").
///
/// **What this proves, here.** That the file the device run is smoke-tested with
/// is the file the script beside it writes: one A4 page of text objects, with
/// every invented line on it, each label on the left of its line and its value
/// to the right of it on the same line — so that a harness which wrote nothing,
/// or wrote words without a binder-friendly layout, is visible from the
/// fixture's own bytes and not only from a device's run.
///
/// **Where it stops.** It reads the page's operators; it does not render them.
/// Whether the rendered page is legible to the engine, and what the engine
/// reads on it, is what the device run measures (task 2.2) — that is the whole
/// point of pushing this fixture to the S22 before the corpus follows.
///
/// **What never enters the repository.** Every line is invented (see the
/// generator). The private corpus is not read, copied or named here, and the
/// fixture is not a regression of a real document: the photo route's failures
/// are the engine's, and they are measured on the corpus, never reproduced.
void main() {
  late Uint8List fixture;

  setUpAll(() {
    final File file = File(
      p.join(
        Directory.current.path,
        'test',
        'fixtures',
        'ocr',
        'synthetic_invoice.pdf',
      ),
    );
    expect(
      file.existsSync(),
      isTrue,
      reason:
          'the fixture is committed; regenerate it with '
          '`python app/test/fixtures/ocr/make_synthetic_invoice.py`',
    );
    fixture = file.readAsBytesSync();
  });

  test('it is one A4 page of text objects, and no image', () {
    final String pdf = ascii.decode(fixture, allowInvalid: true);
    expect(pdf, startsWith('%PDF-1.4'));
    // One page object, under a page tree of one kid.
    expect('/Type /Page '.allMatches(pdf), hasLength(1));
    expect(pdf, contains('/Type /Pages'));
    expect(pdf, contains('/MediaBox [0 0 595.28 841.89]'));
    expect(pdf, contains('/Count 1'));
    // No image anywhere: this page is drawn, not photographed, and it is the
    // renderer that turns it into the image the engine reads.
    expect(pdf, isNot(contains('/Subtype /Image')));
    expect(pdf, isNot(contains('/XObject')));
  });

  test('the invented lines are the ones the generator writes, in order', () {
    final List<_Placed> placed = _placedTexts(fixture);

    expect(placed.map((_Placed text) => text.text), <String>[
      'Beispiel Lieferant GmbH',
      'Musterstrasse 12, 10115 Beispielstadt',
      'Rechnungsnummer 2026-0001',
      'Rechnungsdatum 2026-10-02',
      'Position 1  Beratung',
      '500,00',
      'Position 2  Material',
      '390,00',
      'Nettobetrag',
      '890,00',
      'Umsatzsteuer 19 Prozent',
      '169,10',
      'Gesamtbetrag',
      '1.059,10',
      'Zahlungsziel 14 Tage',
      'Seite 1 von 1',
    ]);
  });

  test('every label has its value on its own line, to the right of it', () {
    final List<_Placed> placed = _placedTexts(fixture);

    for (final List<String> pair in <List<String>>[
      <String>['Nettobetrag', '890,00'],
      <String>['Umsatzsteuer 19 Prozent', '169,10'],
      <String>['Gesamtbetrag', '1.059,10'],
    ]) {
      final _Placed label = placed.firstWhere(
        (_Placed text) => text.text == pair.first,
      );
      final _Placed value = placed.firstWhere(
        (_Placed text) => text.text == pair.last,
      );
      expect(value.y, label.y, reason: '${pair.last} shares its label\'s line');
      expect(
        value.x,
        greaterThan(label.x),
        reason: '${pair.last} sits to the right of its label',
      );
      // The layout rule reaches a value on the label's own line and no further
      // down than one line height; the fixture must not make that impossible.
      expect(value.y - label.y, 0);
    }
  });

  test('the page is A4 in points, which is what the passes scale', () {
    final List<_Placed> placed = _placedTexts(fixture);

    // Every text object sits inside the page: a line outside the MediaBox would
    // be cut off by the renderer before the engine ever saw it.
    for (final _Placed text in placed) {
      expect(text.x, greaterThanOrEqualTo(0));
      expect(text.y, greaterThanOrEqualTo(0));
      expect(text.x, lessThanOrEqualTo(595.28));
      expect(text.y, lessThanOrEqualTo(841.89));
    }
    expect(placed.first.y, greaterThan(placed.last.y));
  });
}

/// One text object of the fixture's page, as it is written into the stream.
class _Placed {
  const _Placed(this.text, this.x, this.y);

  final String text;
  final double x;
  final double y;
}

/// Every `BT … Tj ET` object of the fixture, in the order the stream holds
/// them.
///
/// It reads the operators the generator writes and nothing else: a fixture that
/// stopped being that shape would be found here rather than by a device.
final RegExp _textObject = RegExp(
  r'BT /F1 (\d+) Tf ([\d.]+) ([\d.]+) Td \((.*?)\) Tj ET',
);

List<_Placed> _placedTexts(Uint8List pdf) {
  final String content = ascii.decode(pdf, allowInvalid: true);
  return <_Placed>[
    for (final RegExpMatch match in _textObject.allMatches(content))
      _Placed(
        match.group(4)!,
        double.parse(match.group(2)!),
        double.parse(match.group(3)!),
      ),
  ];
}
