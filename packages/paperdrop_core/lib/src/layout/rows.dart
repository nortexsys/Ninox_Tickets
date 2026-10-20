/// Rebuilding visual rows from positioned lines, ported from the PO's App
/// Cust prototype (`ocr.dart`) over Core's [LayoutLine] model.
///
/// ML Kit returns the label column and the value column as separate lines, so
/// a parser that only sees text cannot associate them. The lines carry
/// bounding boxes, so rows are rebuilt from geometry, and it is the rebuilt
/// rows that the photo readers are handed.
library;

import 'lines.dart';

/// Two lines belong to the same visual row when their vertical centres are
/// close relative to the height of the text. The factor is deliberately under
/// one half of a line height plus a little, so that two genuinely different
/// rows a line apart are never merged.
const double kRowTolerance = 0.6;

/// Rebuilds visual rows from [lines] and returns them as text.
///
/// The incoming order does not matter: lines are sorted by vertical centre,
/// then within a row by the left edge.
String rowsToText(Iterable<LayoutLine> lines) {
  final source = [...lines];
  if (source.isEmpty) {
    return '';
  }

  final sorted = <LayoutLine>[...source]
    ..sort((a, b) => _centreY(a).compareTo(_centreY(b)));

  final rows = <List<LayoutLine>>[];
  for (final line in sorted) {
    if (rows.isNotEmpty) {
      final current = rows.last;
      final heights = current.map((l) => l.height).where((h) => h > 0).toList();
      final height = heights.isEmpty
          ? 12.0
          : heights.reduce((a, b) => a + b) / heights.length;
      final centre =
          current.map(_centreY).reduce((a, b) => a + b) / current.length;
      if ((_centreY(line) - centre).abs() <= height * kRowTolerance) {
        current.add(line);
        continue;
      }
    }
    rows.add(<LayoutLine>[line]);
  }

  final buffer = StringBuffer();
  for (final row in rows) {
    row.sort((a, b) => a.x0.compareTo(b.x0));
    final text = row
        .map((l) => l.text.trim())
        .where((t) => t.isNotEmpty)
        .join('  ');
    if (text.isNotEmpty) {
      buffer.writeln(text);
    }
  }
  return buffer.toString();
}

double _centreY(LayoutLine line) => (line.top + line.bottom) / 2;
