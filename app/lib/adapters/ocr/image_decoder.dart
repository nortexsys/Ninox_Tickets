/// Decoding a photograph to the bytes the recognition engine reads
/// (`implement-photo-passes`, design §2 and §3).
///
/// **Why it exists.** A photograph has no page to render, so the passes of
/// design §2 are variations of the image itself: decoded at another size, or
/// grey-stretched. Both need the image's pixels, and this is the seam that
/// produces them — the decoder under the port, beside `page_rasterizer.dart`
/// which renders the pages of a PDF.
///
/// **Which decoder.** The platform's own, through `dart:ui`: no new dependency
/// is added (design §3, "use what the platform gives"). On Android that is the
/// engine's image decoder over Skia, the same one that decodes any image the
/// application shows.
///
/// **The orientation, measured.** A JPEG declares the picture as it is stored
/// and an EXIF `Orientation` tag saying how to turn it. This decoder **applies
/// that tag**, so the pixels it hands back are the picture as it is displayed
/// and a bitmap passed to ML Kit is upright in the same way the bitmap ML Kit
/// builds itself from the file is — which is what makes the passes of one
/// photograph comparable (design §3). That is not an assumption here:
/// `test/adapters/ocr/image_decoder_test.dart` decodes a two-tone JPEG whose
/// tag turns it a quarter turn round and asserts which half of the picture
/// comes back on top, and the harness asserts on the device that the passes of
/// one photograph agree.
///
/// **Read-only.** The file is opened for reading and its bytes are decoded in
/// memory; nothing is written back to it and no decoded image is saved anywhere
/// (ADR-015, `received-files-are-attached-byte-for-byte`). The bytes exist for
/// the length of one recognition and are dropped with it — there is no cache
/// file for them, because there is nothing to render and nothing to keep, and
/// one photograph's worth of bytes at 1.4x is tens of megabytes that need not
/// be written to flash and read back.
library;

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'ocr_text_source.dart';

/// One image decoded: its size in pixels, and its bytes in the order the
/// recognition engine's bitmap input reads them.
class DecodedImage {
  /// Creates a decoded image of [width] by [height] pixels.
  const DecodedImage({
    required this.width,
    required this.height,
    required this.pixels,
  });

  /// The decoded image's width in pixels.
  final int width;

  /// The decoded image's height in pixels.
  final int height;

  /// The image's bytes: red, green, blue, alpha, row by row from the top left
  /// corner — the order the engine's bitmap input reads and the order Core's
  /// origin needs, so nothing is flipped or swapped on the way.
  final Uint8List pixels;

  @override
  String toString() => 'DecodedImage(${width}x$height, ${pixels.length} bytes)';
}

/// A decoder of image files for the OCR passes.
///
/// **Where it stops.** It decodes and it sizes: it does not improve, crop,
/// straighten, binarise or re-encode anything (`platform-document-scanner`: the
/// app carries no pre-processing of its own, and the photograph the platform
/// scanner produced is used as it is). The scale it is asked for is a
/// recognition input and never a new document.
abstract interface class OcrImageDecoder {
  /// Decodes [file] to [targetWidth] by [targetHeight] pixels, or to the size
  /// the file itself declares when both are null.
  ///
  /// The target is the **displayed** size, in the same space the returned image
  /// is measured in, and both sides are required together or not at all. An
  /// image the decoder cannot read throws: the caller decides whether that
  /// drops one pass or the whole recognition.
  Future<DecodedImage> decode(
    File file, {
    required int? targetWidth,
    required int? targetHeight,
  });
}

/// The decoder the application ships: the platform's, through `dart:ui`.
///
/// One call decodes one file once: the bytes are read from the file (for
/// reading only), the codec is asked for one frame, and the frame's pixels are
/// copied out in straight RGBA. The codec and the frame are released before the
/// call returns, whichever way it returned.
///
/// **One frame.** An animated GIF is a file this route does not accept
/// (`IntakeResult.supportedMediaTypes`: PNG and JPEG), and a codec that held
/// several frames would hand back the first; nothing here loops over frames.
class PlatformImageDecoder implements OcrImageDecoder {
  /// Creates the decoder. It holds nothing between calls.
  const PlatformImageDecoder();

  @override
  Future<DecodedImage> decode(
    File file, {
    required int? targetWidth,
    required int? targetHeight,
  }) async {
    final Uint8List bytes = file.readAsBytesSync(); // read-only
    final ui.Codec codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: targetWidth,
      targetHeight: targetHeight,
    );
    ui.Image? image;
    try {
      final ui.FrameInfo frame = await codec.getNextFrame();
      image = frame.image;
      // Straight RGBA and not the premultiplied `rawRgba`: the engine's bitmap
      // input reads red, green, blue and alpha, and a photograph is opaque so
      // the two forms hold the same bytes — while an image that is not opaque
      // is handed over as it is instead of darkened by its own alpha.
      final ByteData? data = await image.toByteData(
        format: ui.ImageByteFormat.rawStraightRgba,
      );
      if (data == null) {
        throw const OcrFailure('the image could not be decoded');
      }
      return DecodedImage(
        width: image.width,
        height: image.height,
        pixels: Uint8List.fromList(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        ),
      );
    } finally {
      image?.dispose();
      codec.dispose();
    }
  }
}
