import 'dart:io';

import 'package:paperdrop_core/paperdrop_core.dart';
import 'package:test/test.dart';

void main() {
  final eur = CurrencyCode.parse('EUR')!;
  final rate = RateBp(2100);

  group('sumMatchesTotal', () {
    test('accepts an exact sum in minor units', () {
      expect(
        sumMatchesTotal(Money(10000, eur), Money(2100, eur), Money(12100, eur)),
        isTrue,
      );
    });

    test('rejects a sum off by one minor unit', () {
      expect(
        sumMatchesTotal(Money(10000, eur), Money(2100, eur), Money(12101, eur)),
        isFalse,
      );
      expect(
        sumMatchesTotal(Money(10000, eur), Money(2100, eur), Money(12099, eur)),
        isFalse,
      );
    });
  });

  group('taxWithinTolerance', () {
    test('accepts the exact product', () {
      expect(
        taxWithinTolerance(Money(2100, eur), Money(10000, eur), rate),
        isTrue,
      );
    });

    test('a tax one minor unit off passes', () {
      expect(
        taxWithinTolerance(Money(2099, eur), Money(10000, eur), rate),
        isTrue,
      );
      expect(
        taxWithinTolerance(Money(2101, eur), Money(10000, eur), rate),
        isTrue,
      );
    });

    test('a tax two minor units off fails', () {
      expect(
        taxWithinTolerance(Money(2098, eur), Money(10000, eur), rate),
        isFalse,
      );
      expect(
        taxWithinTolerance(Money(2102, eur), Money(10000, eur), rate),
        isFalse,
      );
    });
  });

  test('the one tolerance appears once, in taxWithinTolerance', () async {
    var lib = Directory('lib');
    if (!await lib.exists()) {
      lib = Directory('packages/paperdrop_core/lib');
    }

    final findings = <String>[];
    await for (final entity in lib.list(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }

      final source = await entity.readAsString();
      final count = 'difference <= BigInt.from(10000)'
          .allMatches(source)
          .length;
      for (var i = 0; i < count; i++) {
        findings.add(entity.path);
      }
    }

    expect(findings, hasLength(1));
    expect(
      findings.single,
      contains('confidence${Platform.pathSeparator}redundancy.dart'),
    );
  });
}
