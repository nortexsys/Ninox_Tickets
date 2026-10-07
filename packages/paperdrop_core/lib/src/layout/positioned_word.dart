/// A positioned word on a PDF text-layer page.
///
/// Coordinates are integer thousandths of a PDF point, top-left origin. The
/// field names are pdfplumber's so the reference extraction, the harness and
/// the model agree without a mapping.
///
/// Requirement served: `extraction-pipeline` ·
/// `positional-pdf-text-extraction` — the binding rule is written against
/// these word-level coordinates, never against extraction order.
library;

/// A coordinate or distance on a PDF text-layer page.
///
/// The unit is one thousandth of a PDF point, measured from the top-left
/// corner of the page. A library reports positions to a hundredth of a point
/// at best, so `(points * 1000).round()` loses nothing the comparison can see.
typedef MilliPoint = int;

/// One positioned word on a PDF text-layer page.
///
/// Coordinates are integer thousandths of a PDF point, top-left origin. A
/// word is exactly one token: [text] is non-empty and contains no whitespace.
class PositionedWord {
  /// The word text, non-empty and without whitespace.
  final String text;

  /// The left edge of the word, in [MilliPoint].
  final MilliPoint x0;

  /// The right edge of the word, in [MilliPoint]; never before [x0].
  final MilliPoint x1;

  /// The top edge of the word, in [MilliPoint].
  final MilliPoint top;

  /// The bottom edge of the word, in [MilliPoint]; never before [top].
  final MilliPoint bottom;

  /// Creates a positioned word with the given text and bounding box.
  PositionedWord(this.text, this.x0, this.x1, this.top, this.bottom) {
    if (text.isEmpty) {
      throw ArgumentError.value(text, 'text', 'must not be empty');
    }
    if (_containsWhitespace(text)) {
      throw ArgumentError.value(
        text,
        'text',
        'must be a single word without whitespace',
      );
    }
    if (x0 > x1) {
      throw ArgumentError.value(x0, 'x0', 'must not exceed x1');
    }
    if (top > bottom) {
      throw ArgumentError.value(top, 'top', 'must not exceed bottom');
    }
  }

  static final RegExp _whitespace = RegExp(r'\s');

  static bool _containsWhitespace(String text) => _whitespace.hasMatch(text);

  /// The horizontal extent of the word, in milli-points.
  MilliPoint get width => x1 - x0;

  /// The vertical extent of the word, in milli-points.
  MilliPoint get height => bottom - top;

  /// A value-only string form.
  @override
  String toString() => 'PositionedWord($text, $x0, $x1, $top, $bottom)';

  /// Value equality on every field.
  @override
  bool operator ==(Object other) =>
      other is PositionedWord &&
      other.text == text &&
      other.x0 == x0 &&
      other.x1 == x1 &&
      other.top == top &&
      other.bottom == bottom;

  @override
  int get hashCode => Object.hash(text, x0, x1, top, bottom);
}
