// The row rebuild, ported from the PO's App Cust prototype (`ocr_test.dart`)
// over Core's positioned words and visual lines.

import 'package:paperdrop_core/paperdrop_core.dart';
import 'package:test/test.dart';

void main() {
  final spain = ReceiptReaderFormat.fromCountryRow(CountryTable.es);

  LayoutLine line(String text, int left, int top, int right, int bottom) {
    final parts = text.split(' ');
    final words = <PositionedWord>[];
    final span = right - left;
    for (var i = 0; i < parts.length; i++) {
      words.add(
        PositionedWord(
          parts[i],
          left + (span * i / parts.length).round(),
          left + (span * (i + 1) / parts.length).round(),
          top,
          bottom,
        ),
      );
    }
    return LayoutLine(0, words);
  }

  /// label at (40, top) and its amount at (400, top) — the same visual row.
  List<LayoutLine> twoColumnTicket() {
    const labels = <String>[
      'FECHA: 12/03/2026',
      'BASE IMPONIBLE',
      'IVA 10%',
      'TOTAL',
    ];
    const values = <double>[0, 25.50, 2.55, 28.05];

    final out = <LayoutLine>[];
    for (var i = 0; i < labels.length; i++) {
      final top = 100 + i * 40;
      out.add(line(labels[i], 40, top, 260, top + 24));
      if (values[i] > 0) {
        final text = values[i].toStringAsFixed(2).replaceAll('.', ',');
        out.add(line(text, 400, top, 500, top + 24));
      }
    }
    // ML Kit hands them over grouped by block, not by row: all labels, then all
    // amounts. The rebuild must not depend on the incoming order.
    out.sort((a, b) => a.x0.compareTo(b.x0));
    return out;
  }

  test('rebuilds the visual rows when label and value are separate lines', () {
    final text = rowsToText(twoColumnTicket());
    final lines = text.trim().split('\n');
    expect(lines[1], contains('BASE IMPONIBLE'));
    expect(lines[1], contains('25,50'));
    expect(lines[2], contains('IVA 10%'));
    expect(lines[2], contains('2,55'));
    expect(lines[3], contains('TOTAL'));
    expect(lines[3], contains('28,05'));
  });

  test('the parser then reads the ticket it could not read before', () {
    final r = parseReceipt(rowsToText(twoColumnTicket()), spain);
    expect(r.dateIso, '2026-03-12');
    expect(r.net.value, 25.50);
    expect(r.vat.value, 2.55);
    expect(r.gross.value, 28.05);
    expect(r.rate, 10);
    expect(r.reconciles, isTrue);
  });

  test('keeps genuinely different rows apart', () {
    final lines = <LayoutLine>[
      line('LINEA UNO', 10, 0, 100, 20),
      line('LINEA DOS', 10, 40, 100, 60),
      line('LINEA TRES', 10, 80, 100, 100),
    ];
    expect(rowsToText(lines).trim().split('\n'), hasLength(3));
  });

  test('sorts within a row left to right, whatever order it arrived in', () {
    final lines = <LayoutLine>[
      line('VALOR', 400, 10, 500, 34),
      line('ROTULO', 40, 10, 200, 34),
    ];
    expect(rowsToText(lines).trim(), 'ROTULO  VALOR');
  });

  test('an empty page gives empty text, not a crash', () {
    expect(rowsToText(const <LayoutLine>[]), '');
  });
}
