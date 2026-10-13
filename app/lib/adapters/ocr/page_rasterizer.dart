/// Rendering a document's pages for recognition (`implement-photo-route`,
/// design §1 and §3).
///
/// **What it is.** The seam between the passes and the renderer: a document is
/// opened once, each of its pages is rendered at the resolution a pass asks
/// for, and each render carries both the pixel size of the image and the size
/// of the page **in points**, which is what turns the engine's pixel boxes into
/// Core's milli-points.
///
/// **Read-only.** Opening and rendering read the file and nothing else
/// (ADR-015, `received-files-are-attached-byte-for-byte`): there is no save, no
/// re-flatten and no re-compress anywhere under this interface, and a caller
/// may hash the file before and after and must find the same bytes.
library;

import 'dart:typed_data';

import 'ocr_text_source.dart';

/// One rendered page.
///
/// The pixels are the renderer's own bytes, four per pixel, in **BGRA** order
/// — the order the platform's renderer produces — with the origin at the top
/// left corner, which is also Core's origin: a render needs no flip. The byte
/// order the recognition engine reads is different, and the conversion between
/// the two is `pixels.dart`'s job.
class RasterImage {
  /// Creates a render of a page of [widthPoints] by [heightPoints] points,
  /// rasterised to [width] by [height] pixels.
  const RasterImage({
    required this.width,
    required this.height,
    required this.widthPoints,
    required this.heightPoints,
    required this.pixels,
  });

  /// The image's width in pixels.
  final int width;

  /// The image's height in pixels.
  final int height;

  /// The page's width in points, as the renderer reports it.
  final double widthPoints;

  /// The page's height in points, as the renderer reports it.
  final double heightPoints;

  /// The image's bytes: blue, green, red, alpha, row by row from the top.
  final Uint8List pixels;

  @override
  String toString() =>
      'RasterImage(${width}x$height px, ${widthPoints}x$heightPoints pt)';
}

/// An open document whose pages can be rendered.
abstract interface class OcrRasterDocument {
  /// How many pages the document has.
  int get pageCount;

  /// Renders page [index] (zero-based) at [dpi] dots per inch.
  ///
  /// Throws an [OcrFailure] for a page the renderer cannot produce. Every call
  /// returns a new buffer; the caller owns it and nothing else frees it.
  Future<RasterImage> render({required int index, required int dpi});

  /// Releases the document. It is called whatever the call that opened it ends
  /// with, including a failure.
  Future<void> dispose();
}

/// A renderer of documents for the OCR passes.
abstract interface class OcrPageRasterizer {
  /// Opens [path] for reading and returns its pages.
  ///
  /// Throws an [OcrFailure] for a file that cannot be opened or is not a
  /// document this renderer reads. Nothing is written back to the file.
  Future<OcrRasterDocument> open(String path);
}
