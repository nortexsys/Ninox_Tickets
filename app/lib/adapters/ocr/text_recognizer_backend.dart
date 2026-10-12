/// The engine behind the photo route's port (`implement-photo-route`,
/// design §4).
///
/// **Why it exists.** `MlKitOcrTextSource` is the port's implementation and the
/// engine is one of its parts; this interface is the seam between them. Above
/// it sit the pass list, the cache files and Core's units — everything design §4
/// wants proved — and under it sits the only code in the application that names
/// a recognition engine. The tests fake this interface, so the port is exercised
/// without a device and without ML Kit.
///
/// **What it may not do.** It segments nothing itself: what the engine calls an
/// element is what it returns, with the box the engine reported and in the
/// engine's order. It merges no elements, splits none and drops none — a run of
/// whitespace the engine reports as an element arrives here like any other, and
/// the decision about it (design §1: a word carries no whitespace) is the
/// port's, not the backend's.
library;

import 'dart:typed_data';

/// One run of text the engine found, as the engine reported it.
///
/// The box is in **pixels of the image the engine was handed**, with the origin
/// at the image's top-left corner, which is the coordinate space ML Kit reports
/// in. Turning pixels into Core's milli-points needs the image's size in points
/// and is therefore the port's job and not this type's.
class OcrElement {
  /// Creates an element with its [text] and the pixel [left], [top], [right]
  /// and [bottom] of its box.
  const OcrElement(this.text, this.left, this.top, this.right, this.bottom);

  /// The element's text, exactly as the engine returned it.
  final String text;

  /// The left edge of the element's box, in pixels.
  final int left;

  /// The top edge of the element's box, in pixels.
  final int top;

  /// The right edge of the element's box, in pixels.
  final int right;

  /// The bottom edge of the element's box, in pixels.
  final int bottom;

  @override
  String toString() => 'OcrElement($text, $left, $top, $right, $bottom)';

  /// Value equality on every field.
  @override
  bool operator ==(Object other) =>
      other is OcrElement &&
      other.text == text &&
      other.left == left &&
      other.top == top &&
      other.right == right &&
      other.bottom == bottom;

  @override
  int get hashCode => Object.hash(text, left, top, right, bottom);
}

/// A text-recognition engine the port can use.
///
/// One instance is opened per `recognise` call and closed when the call ends,
/// including when it ends in a failure: the engine holds native resources that
/// no later call may be left holding.
abstract interface class TextRecognizerBackend {
  /// Recognises the pixels of one image and returns the engine's elements.
  ///
  /// [pixels] is the image's raw bytes, four per pixel, in the order the
  /// platform's bitmap input reads: red, green, blue, then alpha. [width] and
  /// [height] are the image's size in pixels, which is also the space the
  /// returned boxes are in.
  ///
  /// A page the engine finds no text on answers with no element, not with an
  /// error: an empty answer is an answer.
  Future<List<OcrElement>> recogniseImage({
    required Uint8List pixels,
    required int width,
    required int height,
  });

  /// Recognises the image file at [path] and returns the engine's elements.
  ///
  /// The engine opens and reads the file itself, so this call is what an image
  /// that cannot be read as it is uses: the file is never re-encoded on the way
  /// in. The returned boxes are in the image's own pixels.
  Future<List<OcrElement>> recogniseFile(String path);

  /// Releases the engine's resources. It is safe to call once per instance.
  Future<void> close();
}
