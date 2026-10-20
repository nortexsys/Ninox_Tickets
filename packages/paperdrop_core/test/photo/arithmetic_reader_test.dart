// The vocabulary-free arithmetic reader, ported from the PO's App Cust
// prototype. Samples are synthetic; the arithmetic shapes are the prototype's.

import 'package:paperdrop_core/paperdrop_core.dart';
import 'package:test/test.dart';

void main() {
  final spain = ReceiptReaderFormat.fromCountryRow(CountryTable.es);

  test('reads a breakdown from nothing but the printed arithmetic', () {
    final r = parseReceiptArithmetic(
      'FECHA: 01/01/2026\n'
      '84,273  17,697  101,97\n'
      '21,00%\n',
      spain,
    );

    expect(r.dateIso, '2026-01-01');
    expect(r.net.value, closeTo(84.273, 0.0001));
    expect(r.vat.value, closeTo(17.697, 0.0001));
    expect(r.gross.value, closeTo(101.97, 0.0001));
    expect(r.rate, 21);
    expect(r.net.isRead, isTrue);
  });

  test(
    'a single figure with no rate keeps the prototype single-figure rule',
    () {
      final r = parseReceiptArithmetic(
        'FECHA: 01/01/2026\nTOTAL 20,25\n',
        spain,
      );

      expect(r.dateIso, '2026-01-01');
      expect(r.net.value, 20.25);
      expect(r.net.origin, contains('proposed'));
      expect(r.vat.has, isFalse);
      expect(r.gross.has, isFalse);
      expect(r.rate, isNull);
    },
  );

  test('a single figure keeps the prototype single-figure rule', () {
    final r = parseReceiptArithmetic('TOTAL 12,10\n', spain);

    expect(r.net.value, 12.10);
    expect(r.net.origin, contains('proposed'));
    expect(r.gross.has, isFalse);
    expect(r.vat.has, isFalse);
  });

  test('0 % is left out of the search', () {
    final r = parseReceiptArithmetic('0%  12,00  0,00  12,00\n', spain);

    expect(r.net.has, isFalse);
    expect(r.vat.has, isFalse);
    expect(r.reconciles, isNull);
  });
}
