/// A page of positioned words from a PDF text layer.
///
/// Width, height and word coordinates are integer thousandths of a PDF point,
/// top-left origin. The field names are pdfplumber's so the reference
/// extraction, the harness and the model agree without a mapping.
///
/// Requirement served: `extraction-pipeline` ·
/// `positional-pdf-text-extraction` — layout reasoning consumes pages of
/// word-level coordinates, and [hasTextLayer] is the fall-through signal for
/// the OCR route.
library;

import 'positioned_word.dart';

/// One page of a PDF text layer, as positioned words.
///
/// Width, height and word coordinates are integer thousandths of a PDF point,
/// top-left origin. A page's words may arrive in any order; layout reasoning
/// sorts them and never depends on the arrival order.
class TextPage {
  /// The zero-based page index.
  final int index;

  /// The page width, in [MilliPoint].
  final MilliPoint width;

  /// The page height, in [MilliPoint].
  final MilliPoint height;

  /// The words on this page, in the order they arrived.
  final List<PositionedWord> words;

  /// Creates a page with the given [index], [width], [height] and [words].
  ///
  /// [hasTextLayer] is not a constructor argument: it is derived from
  /// [words], so a caller cannot set it inconsistently.
  TextPage(this.index, this.width, this.height, List<PositionedWord> words)
    : words = List.unmodifiable(words) {
    if (index < 0) {
      throw ArgumentError.value(index, 'index', 'must not be negative');
    }
  }

  /// Whether this page has a text layer.
  ///
  /// A page with no words has no text layer; the decision to fall through to
  /// OCR belongs to the route selector, not to this type.
  bool get hasTextLayer => words.isNotEmpty;

  /// A value-only string form naming the page and its word count.
  @override
  String toString() => 'TextPage($index, ${words.length} words)';

  /// Value equality on index, width, height and words.
  @override
  bool operator ==(Object other) {
    if (other is! TextPage) {
      return false;
    }
    return other.index == index &&
        other.width == width &&
        other.height == height &&
        _listEquals(other.words, words);
  }

  @override
  int get hashCode => Object.hash(index, width, height, Object.hashAll(words));
}

bool _listEquals(List<PositionedWord> left, List<PositionedWord> right) {
  if (left.length != right.length) {
    return false;
  }
  for (var i = 0; i < left.length; i++) {
    if (left[i] != right[i]) {
      return false;
    }
  }
  return true;
}
