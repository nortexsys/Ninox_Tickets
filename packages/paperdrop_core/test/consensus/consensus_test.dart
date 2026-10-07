import 'dart:io';

import 'package:paperdrop_core/paperdrop_core.dart';
import 'package:test/test.dart';

void main() {
  final eur = CurrencyCode.parse('EUR')!;

  group('resolveConsensus', () {
    test('[extraction-pipeline/consensus-by-majority] '
        'three agreeing passes beat one outlier', () {
      final agreed = Money(9676, eur); // 96.76
      final outlier = Money(967600, eur); // 9.676,00

      final result = resolveConsensus<Money>([
        Reading<Money>(agreed, 'pass-1', Provenance.read),
        Reading<Money>(agreed, 'pass-2', Provenance.read),
        Reading<Money>(agreed, 'pass-3', Provenance.read),
        Reading<Money>(outlier, 'pass-4', Provenance.read),
      ]);

      expect(result, Agreed<Money>(agreed, 3, 4));
    });

    test('a two-two tie is NoConsensus', () {
      final first = Money(9676, eur);
      final second = Money(1999, eur);

      final result = resolveConsensus<Money>([
        Reading<Money>(first, 'pass-1', Provenance.read),
        Reading<Money>(first, 'pass-2', Provenance.read),
        Reading<Money>(second, 'pass-3', Provenance.read),
        Reading<Money>(second, 'pass-4', Provenance.read),
      ]);

      expect(result, const NoConsensus<Money>());
    });

    test('one pass is Single and never Agreed', () {
      final value = Money(9676, eur);

      final result = resolveConsensus<Money>([
        Reading<Money>(value, 'pass-1', Provenance.read),
      ]);

      expect(result, Single<Money>(value));
      expect(result, isNot(isA<Agreed<Money>>()));
    });

    test('[extraction-pipeline/consensus-by-majority] '
        'a maximum-across-passes implementation fails', () async {
      var directory = Directory('lib/src/consensus');
      if (!await directory.exists()) {
        directory = Directory('packages/paperdrop_core/lib/src/consensus');
      }

      final findings = <String>[];
      await for (final entity in directory.list(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) {
          continue;
        }
        final source = await entity.readAsString();
        if (RegExp(r'\bmax\b').hasMatch(source)) {
          findings.add(entity.path);
        }
      }

      expect(
        findings,
        isEmpty,
        reason: 'consensus code must not take a maximum across passes',
      );
    });
  });
}
