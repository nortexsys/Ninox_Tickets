import 'dart:io';

import 'package:paperdrop_core/paperdrop_core.dart';
import 'package:test/test.dart';

void main() {
  // Lines of design §3 (implement-validation-and-extraction-core). No spec
  // scenario owns the line model itself; the binding scenarios below consume
  // it, so these proofs are untagged and name the design section here.
  group('groupIntoLines', () {
    test('gives identical lines for several shuffled word orders', () {
      final label = PositionedWord('TOTAL', 100, 180, 100, 120);
      final value = PositionedWord('742,42', 100, 180, 140, 160);
      final volume = PositionedWord('8.741', 200, 260, 140, 160);

      final orders = <List<PositionedWord>>[
        [label, value, volume],
        [volume, label, value],
        [value, volume, label],
        [label, volume, value],
      ];

      List<LayoutLine>? expected;
      for (final order in orders) {
        final lines = groupIntoLines(TextPage(0, 1000, 2000, order));
        expected ??= lines;
        expect(lines, expected);
      }

      expect(expected, hasLength(2));
      expect(expected!.first.text, 'TOTAL');
      expect(expected.last.text, '742,42 8.741');
    });

    test('a word overlapping by less than half the shorter height '
        'starts a new line', () {
      final first = PositionedWord('a', 0, 10, 0, 20);
      final second = PositionedWord('b', 0, 10, 18, 38);

      final lines = groupIntoLines(TextPage(0, 1000, 1000, [first, second]));

      expect(lines, hasLength(2));
      expect(lines.first.text, 'a');
      expect(lines.last.text, 'b');
    });

    test('a word overlapping by at least half the shorter height joins', () {
      final first = PositionedWord('a', 0, 10, 0, 20);
      final second = PositionedWord('b', 0, 10, 10, 30);

      final lines = groupIntoLines(TextPage(0, 1000, 1000, [first, second]));

      expect(lines, hasLength(1));
      expect(lines.single.text, 'a b');
    });

    test('orders words of a line by x0 and lines by top', () {
      final lowerRight = PositionedWord('c', 30, 40, 20, 30);
      final lowerLeft = PositionedWord('b', 0, 10, 20, 30);
      final upper = PositionedWord('a', 0, 10, 0, 10);

      final lines = groupIntoLines(
        TextPage(0, 1000, 1000, [lowerRight, upper, lowerLeft]),
      );

      expect(lines.map((LayoutLine line) => line.text), ['a', 'b c']);
    });

    test('exposes text, bounding box and page index', () {
      final line = LayoutLine(3, [
        PositionedWord('b', 30, 40, 20, 30),
        PositionedWord('a', 0, 10, 10, 22),
      ]);

      expect(line.pageIndex, 3);
      expect(line.words.map((PositionedWord word) => word.text), ['a', 'b']);
      expect(line.text, 'a b');
      expect(line.x0, 0);
      expect(line.x1, 40);
      expect(line.top, 10);
      expect(line.bottom, 30);
      expect(line.width, 40);
      expect(line.height, 20);
    });

    test('the half-height rule lives in one place', () async {
      var file = File('lib/src/layout/lines.dart');
      if (!await file.exists()) {
        file = File('packages/paperdrop_core/lib/src/layout/lines.dart');
      }
      final source = await file.readAsString();

      expect(
        'return 2 * overlap >= shorterHeight;'.allMatches(source),
        hasLength(1),
      );
    });
  });
}
