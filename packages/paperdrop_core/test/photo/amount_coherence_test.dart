// Coherence rules applied to the photo route after the two ported readers
// have chosen their amounts.
//
// Every sample here is synthetic. No real receipt, no real name, no real
// fiscal identifier: these are strings and figures invented to look like what
// a Spanish printer emits (EJEMPLO S.L.-style), and the expectations are the
// rules from the change proposal.

import 'package:paperdrop_core/paperdrop_core.dart';
import 'package:test/test.dart';

void main() {
  Receipt receipt({
    double? net,
    double? vat,
    double? gross,
    double? rate,
    String netOrigin = 'read',
    String vatOrigin = 'read',
    String grossOrigin = 'read',
  }) {
    return Receipt(
      rawText: 'EJEMPLO S.L.',
      dateIso: null,
      dateOrigin: 'none',
      net: ReceiptValue(net, net == null ? 'none' : netOrigin),
      vat: ReceiptValue(vat, vat == null ? 'none' : vatOrigin),
      gross: ReceiptValue(gross, gross == null ? 'none' : grossOrigin),
      rate: rate,
      totalCandidates: const <double>[],
    );
  }

  group('applyAmountCoherenceRules', () {
    test('rule 1: gross, net and tax all equal keeps the gross only', () {
      final result = applyAmountCoherenceRules(
        labelled: receipt(net: 21, vat: 21, gross: 21),
        arithmetic: receipt(net: 100, vat: 21, gross: 121),
      );

      expect(result.net.has, isFalse);
      expect(result.vat.has, isFalse);
      expect(result.gross.has, isTrue);
      expect(result.gross.amount, 21);
      expect(result.gross.source, PhotoAmountSource.labelled);
    });

    test('rule 2: a net amount equal to a printed rate is dropped', () {
      final result = applyAmountCoherenceRules(
        labelled: receipt(net: 21, vat: 2.10, gross: 23.10, rate: 21),
        arithmetic: receipt(net: 84.273, vat: 17.697, gross: 101.97, rate: 21),
      );

      expect(result.net.has, isFalse);
      expect(result.vat.has, isTrue);
      expect(result.vat.amount, closeTo(2.10, 1e-9));
      expect(result.gross.has, isTrue);
      expect(result.gross.amount, closeTo(23.10, 1e-9));
    });

    test('rule 2: a tax amount equal to a printed rate is dropped', () {
      final result = applyAmountCoherenceRules(
        labelled: receipt(net: 100, vat: 21, gross: 121, rate: 21),
        arithmetic: receipt(net: 100, vat: 21, gross: 121, rate: 21),
      );

      expect(result.net.has, isTrue);
      expect(result.net.amount, 100);
      expect(result.vat.has, isFalse);
      expect(result.gross.has, isTrue);
      expect(result.gross.amount, 121);
    });

    test('rule 3: a tax amount equal to the gross is dropped', () {
      final result = applyAmountCoherenceRules(
        labelled: receipt(net: 100, vat: 121, gross: 121),
        arithmetic: receipt(net: 100, vat: 21, gross: 121),
      );

      expect(result.net.has, isTrue);
      expect(result.net.amount, 100);
      expect(result.vat.has, isFalse);
      expect(result.gross.has, isTrue);
      expect(result.gross.amount, 121);
    });

    test(
      'rule 4: an inconsistent labelled triple prefers the arithmetic triple',
      () {
        final result = applyAmountCoherenceRules(
          labelled: receipt(net: 100, vat: 10, gross: 121),
          arithmetic: receipt(net: 100, vat: 21, gross: 121),
        );

        expect(result.net.has, isTrue);
        expect(result.net.amount, 100);
        expect(result.net.source, PhotoAmountSource.arithmetic);
        expect(result.vat.has, isTrue);
        expect(result.vat.amount, 21);
        expect(result.vat.source, PhotoAmountSource.arithmetic);
        expect(result.gross.has, isTrue);
        expect(result.gross.amount, 121);
        expect(result.gross.source, PhotoAmountSource.arithmetic);
      },
    );

    test('rule 4: a consistent labelled triple keeps the labelled amounts', () {
      final result = applyAmountCoherenceRules(
        labelled: receipt(net: 100, vat: 21, gross: 121),
        arithmetic: receipt(net: 200, vat: 42, gross: 242),
      );

      expect(result.net.has, isTrue);
      expect(result.net.amount, 100);
      expect(result.net.source, PhotoAmountSource.labelled);
      expect(result.vat.has, isTrue);
      expect(result.vat.amount, 21);
      expect(result.vat.source, PhotoAmountSource.labelled);
      expect(result.gross.has, isTrue);
      expect(result.gross.amount, 121);
      expect(result.gross.source, PhotoAmountSource.labelled);
    });

    test('a base equal to the gross is kept when no tax is read', () {
      final result = applyAmountCoherenceRules(
        labelled: receipt(net: 12.50, gross: 12.50),
        arithmetic: receipt(net: 12.50),
      );

      expect(result.net.has, isTrue);
      expect(result.net.amount, 12.50);
      expect(result.vat.has, isFalse);
      expect(result.gross.has, isTrue);
      expect(result.gross.amount, 12.50);
    });

    test('a dropped value is absent, never guessed', () {
      final result = applyAmountCoherenceRules(
        labelled: receipt(net: 21, vat: 21, gross: 21),
        arithmetic: receipt(net: 100, vat: 21, gross: 121),
      );

      expect(result.net.has, isFalse);
      expect(result.net.amount, isNull);
      expect(result.vat.has, isFalse);
      expect(result.vat.amount, isNull);
      expect(result.gross.has, isTrue);
      expect(result.gross.amount, 21);
    });
  });
}
