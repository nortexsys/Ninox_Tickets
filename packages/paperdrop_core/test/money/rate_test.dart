import 'package:paperdrop_core/paperdrop_core.dart';
import 'package:test/test.dart';

void main() {
  group('RateBp.parsePercent', () {
    test('parses percent text into basis points', () {
      expect(RateBp.parsePercent('21').bp, 2100);
      expect(RateBp.parsePercent('5.5').bp, 550);
      expect(RateBp.parsePercent('2.75').bp, 275);
    });

    test('rejects more than two fractional digits', () {
      expect(() => RateBp.parsePercent('5.555'), throwsFormatException);
    });

    test('rejects a rate above 100 percent', () {
      expect(() => RateBp.parsePercent('100.01'), throwsArgumentError);
      expect(() => RateBp(10001), throwsArgumentError);
    });

    test('rejects negative, locale and non-canonical text', () {
      for (final text in <String>[
        '-1',
        '5,5',
        '5.5%',
        '',
        '.5',
        '5.',
        '1.2.3',
      ]) {
        expect(() => RateBp.parsePercent(text), throwsFormatException);
      }
    });
  });

  test('RateBp is bounded to 0..10000 basis points', () {
    expect(RateBp(0).bp, 0);
    expect(RateBp(10000).bp, 10000);
    expect(() => RateBp(-1), throwsArgumentError);
  });

  test('RateBp has value equality and a value-only toString', () {
    expect(RateBp(2100), equals(RateBp(2100)));
    expect(RateBp(2100).hashCode, RateBp(2100).hashCode);
    expect(RateBp(2100).toString(), '2100');
  });
}
