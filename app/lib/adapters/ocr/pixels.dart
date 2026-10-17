/// The byte-level conversions the OCR passes need
/// (`implement-photo-route`, design §3, and `implement-photo-passes`, §2).
///
/// **Why it exists.** The renderer hands back bytes in its own order and the
/// recognition engine reads bytes in another; the contrast pass of design §3 —
/// and of design §2, for a photograph that is decoded rather than rendered —
/// asks for grey-scale with a contrast stretch, which is arithmetic on those
/// bytes and no library is involved. Every function here is pure and is tested
/// on the host with buffers whose expected output is written out by hand.
///
/// **Its limits.** This is the whole of the arithmetic: a channel swap, a
/// luminance, a stretch between the darkest and the lightest pixel of one
/// buffer. Nothing here reads a document, decodes a format or writes anything
/// anywhere, and nothing here re-encodes a file: the bytes of the input
/// document are never touched, and a render is never written back to it. The
/// document the platform's scanner produced is used as it is (FR-CAP-002,
/// FR-CAP-004); what these functions build is a copy of one image's bytes, held
/// for the length of one recognition and then dropped.
library;

import 'dart:typed_data';

/// Converts a renderer's **BGRA** bytes to the **RGBA** bytes the recognition
/// engine's bitmap input reads.
///
/// The alpha channel is carried over unchanged: a rendered page is opaque, and
/// a channel this layer does not have to understand is not worth touching.
///
/// Four bytes are one pixel, and a buffer that ends mid-pixel ends there: what
/// comes back holds one pixel per whole pixel of what went in.
Uint8List rgbaFromBgra(Uint8List bgra) {
  final int pixels = _wholePixels(bgra);
  final Uint8List rgba = Uint8List(pixels * 4);
  for (var i = 0; i < rgba.length; i += 4) {
    rgba[i] = bgra[i + 2];
    rgba[i + 1] = bgra[i + 1];
    rgba[i + 2] = bgra[i];
    rgba[i + 3] = bgra[i + 3];
  }
  return rgba;
}

/// Grey-scale with a contrast stretch: design §3's `p4-contrast` render of a
/// page, and design §2's `p2-contrast` reading of a photograph.
///
/// Every pixel becomes one grey level, its luminance, and the levels are then
/// stretched so that the darkest pixel of this buffer becomes 0 and the
/// lightest becomes 255. The stretch is what the pass is for: a photograph of a
/// page is rarely black on white, and where the paper is grey the letters sit
/// closer to it — the reading the other three passes may miss is more likely to
/// be found where the levels of this image have been spread over the full
/// range.
///
/// A buffer whose pixels all have the same luminance is left as it is: there is
/// no range to stretch, and dividing by it would be an invention. A buffer of
/// no pixel answers with no pixel.
///
/// The input is the renderer's **BGRA** — what a rendered page is — and the
/// result is in RGBA, ready for the engine: the alpha of every pixel is 255,
/// because a rendered page is opaque.
Uint8List greyContrastStretchRgba(Uint8List bgra) =>
    _greyContrastStretch(bgra, redAt: 2, greenAt: 1, blueAt: 0);

/// The same stretch for a buffer that is already **RGBA**: the reading design
/// §2 gives a photograph that is decoded rather than rendered.
///
/// The two functions are one arithmetic read at two orders — a renderer hands
/// back blue first and the platform's image decoder hands back red first — and
/// that is the whole difference between them. The result is RGBA either way, so
/// what the engine is handed does not depend on which of the two produced it.
Uint8List greyContrastStretchFromRgba(Uint8List rgba) =>
    _greyContrastStretch(rgba, redAt: 0, greenAt: 1, blueAt: 2);

/// Grey-scale and stretch one buffer, whose channels sit at the given offsets
/// of every pixel.
Uint8List _greyContrastStretch(
  Uint8List bytes, {
  required int redAt,
  required int greenAt,
  required int blueAt,
}) {
  final int pixels = _wholePixels(bytes);
  final Uint8List rgba = Uint8List(pixels * 4);
  if (pixels == 0) {
    return rgba;
  }

  int levelOf(int pixel) => _luminance(
    bytes[pixel + redAt],
    bytes[pixel + greenAt],
    bytes[pixel + blueAt],
  );

  int lowest = 255;
  int highest = 0;
  for (var pixel = 0; pixel < pixels * 4; pixel += 4) {
    final int level = levelOf(pixel);
    if (level < lowest) {
      lowest = level;
    }
    if (level > highest) {
      highest = level;
    }
  }

  final int span = highest - lowest;
  for (var pixel = 0; pixel < pixels * 4; pixel += 4) {
    final int level = levelOf(pixel);
    final int stretched = span == 0 ? level : ((level - lowest) * 255) ~/ span;
    rgba[pixel] = stretched;
    rgba[pixel + 1] = stretched;
    rgba[pixel + 2] = stretched;
    rgba[pixel + 3] = 255;
  }
  return rgba;
}

/// How many whole pixels a buffer holds.
int _wholePixels(Uint8List bytes) => bytes.length ~/ 4;

/// The luminance of one pixel, on the 0..255 range, from its red, green and
/// blue channels.
///
/// The weights are the ones the video standard everyone uses gives: a green
/// pixel carries most of the brightness, a blue one almost none. Whether a
/// better weighting would read a photographed page better is a question for the
/// screening (T2.5) and not one this layer answers.
int _luminance(int red, int green, int blue) =>
    (299 * red + 587 * green + 114 * blue) ~/ 1000;
