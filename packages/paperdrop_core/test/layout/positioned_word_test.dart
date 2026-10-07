import 'package:paperdrop_core/paperdrop_core.dart';
import 'package:test/test.dart';

void main() {
  // The positioned-word contract of design §2
  // (implement-validation-and-extraction-core): integer thousandths of a
  // point, top-left origin, `hasTextLayer` derived from `words`, and every
  // stated invariant enforced. No spec scenario owns this contract, so these
  // proofs are untagged and name the design section here.
  group('PositionedWord', () {
    test('accepts a word box in milli-points', () {
      final word = PositionedWord('TOTAL', 100, 180, 40, 60);

      expect(word.text, 'TOTAL');
      expect(word.x0, 100);
      expect(word.x1, 180);
      expect(word.top, 40);
      expect(word.bottom, 60);
      expect(word.width, 80);
      expect(word.height, 20);
    });

    test('rejects a word whose x0 exceeds x1', () {
      expect(
        () => PositionedWord('TOTAL', 180, 100, 40, 60),
        throwsArgumentError,
      );
    });

    test('rejects a word whose top exceeds bottom', () {
      expect(
        () => PositionedWord('TOTAL', 100, 180, 60, 40),
        throwsArgumentError,
      );
    });

    test('rejects an empty word', () {
      expect(() => PositionedWord('', 100, 180, 40, 60), throwsArgumentError);
    });

    test('rejects a word containing whitespace', () {
      expect(
        () => PositionedWord('TOTAL A', 100, 180, 40, 60),
        throwsArgumentError,
      );
      expect(
        () => PositionedWord('TOTAL\tA', 100, 180, 40, 60),
        throwsArgumentError,
      );
    });

    test('has value equality on every field', () {
      expect(
        PositionedWord('TOTAL', 100, 180, 40, 60),
        PositionedWord('TOTAL', 100, 180, 40, 60),
      );
      expect(
        PositionedWord('TOTAL', 100, 180, 40, 60),
        isNot(PositionedWord('TOTAL', 101, 180, 40, 60)),
      );
    });
  });

  group('TextPage', () {
    test('builds a page with words in any order', () {
      final first = PositionedWord('a', 10, 20, 0, 10);
      final second = PositionedWord('b', 30, 40, 20, 30);

      final page = TextPage(0, 1000, 2000, [second, first]);

      expect(page.index, 0);
      expect(page.width, 1000);
      expect(page.height, 2000);
      expect(page.words, [second, first]);
      expect(page.hasTextLayer, isTrue);
    });

    test('derives hasTextLayer as false exactly when words is empty', () {
      expect(TextPage(0, 1000, 2000, []).hasTextLayer, isFalse);
      expect(
        TextPage(0, 1000, 2000, [
          PositionedWord('a', 0, 10, 0, 10),
        ]).hasTextLayer,
        isTrue,
      );
    });

    test('rejects a negative page index', () {
      expect(() => TextPage(-1, 1000, 2000, []), throwsArgumentError);
    });

    test('copies words into an unmodifiable list', () {
      final page = TextPage(0, 1000, 2000, [PositionedWord('a', 0, 10, 0, 10)]);

      expect(
        () => page.words.add(PositionedWord('b', 0, 10, 0, 10)),
        throwsUnsupportedError,
      );
    });
  });
}
