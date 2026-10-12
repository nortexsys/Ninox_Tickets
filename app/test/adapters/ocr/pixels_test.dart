import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:paperdrop/adapters/ocr/pixels.dart';

/// The two byte conversions of the passes (`implement-photo-route`,
/// design §3).
///
/// **What this proves.** That a renderer's BGRA bytes reach the engine in the
/// order the engine's bitmap input reads, with the alpha untouched, and that
/// design §3's contrast pass does what it says: every pixel becomes one grey
/// level, the darkest of this buffer becomes black, the lightest becomes white,
/// a buffer with no range is left alone, and a rendered page comes back opaque.
///
/// **Written out by hand.** Every expectation below is a number this test
/// states, not one the implementation produced: the luminances are the
/// standard's weights, so a change to them fails here rather than passing
/// unnoticed.
void main() {
  test('the channels are swapped and the alpha is kept', () {
    expect(
      rgbaFromBgra(
        Uint8List.fromList(<int>[
          3, 2, 1, 255, // one pixel: B, G, R, A
          30, 20, 10, 128,
        ]),
      ),
      <int>[1, 2, 3, 255, 10, 20, 30, 128],
    );
  });

  test('a buffer of no pixel answers with no pixel', () {
    expect(rgbaFromBgra(Uint8List(0)), isEmpty);
    expect(greyContrastStretchRgba(Uint8List(0)), isEmpty);
    expect(
      greyContrastStretchRgba(Uint8List.fromList(<int>[1, 2, 3])),
      isEmpty,
      reason: 'three bytes are not a pixel',
    );
  });

  test('grey levels are the luminance of each pixel', () {
    // The three pure channels of one buffer, in BGRA order: red, green, blue.
    // Their luminances are 299 * 255 / 1000 = 76, 587 * 255 / 1000 = 149 and
    // 114 * 255 / 1000 = 29 — green carries most of the brightness, blue almost
    // none. The buffer's range is 29 to 149, so the stretch is
    // `(level - 29) * 255 / 120`: red becomes (76 - 29) * 255 / 120 = 99, green
    // becomes 255, blue becomes 0.
    final Uint8List grey = greyContrastStretchRgba(
      Uint8List.fromList(<int>[
        0, 0, 255, 255, // red
        0, 255, 0, 255, // green
        255, 0, 0, 255, // blue
      ]),
    );

    expect(grey, <int>[
      99, 99, 99, 255, // the red pixel
      255, 255, 255, 255, // the green pixel: the lightest, so it becomes white
      0, 0, 0, 255, // the blue pixel: the darkest, so it becomes black
    ]);
  });

  test('white paper and black letters keep their ends', () {
    final Uint8List grey = greyContrastStretchRgba(
      Uint8List.fromList(<int>[
        255, 255, 255, 255, // white
        200, 200, 200, 255, // light grey paper
        10, 10, 10, 255, // dark grey letters
      ]),
    );

    expect(grey.sublist(0, 4), <int>[255, 255, 255, 255]);
    // (200 - 10) * 255 / 245 = 197: the paper's own level is stretched with the
    // others and not left where it was.
    expect(grey.sublist(4, 8), <int>[197, 197, 197, 255]);
    expect(grey.sublist(8, 12), <int>[0, 0, 0, 255]);
  });

  test('a buffer of one level is left as it is', () {
    // There is no range to stretch: dividing by it would be an invention.
    expect(
      greyContrastStretchRgba(
        Uint8List.fromList(<int>[90, 90, 90, 255, 90, 90, 90, 255]),
      ),
      <int>[90, 90, 90, 255, 90, 90, 90, 255],
    );
  });
}
