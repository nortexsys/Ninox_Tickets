import 'dart:typed_data';

import 'package:pdfrx/pdfrx.dart';

import 'ocr_text_source.dart';
import 'page_rasterizer.dart';

/// Page rendering through **PDFium**, the engine Chrome renders PDFs with,
/// behind the Flutter binding `pdfrx` (`implement-photo-route`, design §1 and
/// §3; ADR-015).
///
/// **The same engine as the invoice route.** `PdfrxTextSource` reads a PDF's
/// text layer with PDFium; this renderer draws the very same pages with it.
/// That is the point of the render-and-ocr fallback: a scanned PDF has no text
/// layer, so its pages become images here and go to the engine, and the words
/// that come back are Core's positioned words like any others.
///
/// **Read-only.** `PdfDocument.openFile` opens the file for reading and the
/// document is disposed without being written back; nothing here saves,
/// re-flattens or re-compresses (ADR-015), and the source file stays
/// byte-for-byte what it was.
///
/// **The render is copied.** PDFium's buffer is native memory that `dispose`
/// frees, and `PdfImage.pixels` is a view over it: the copy the caller gets is
/// taken before the image is disposed, so a pass can hold its buffer for as
/// long as it needs and cannot read freed memory.
class PdfrxPageRasterizer implements OcrPageRasterizer {
  /// Creates the renderer.
  const PdfrxPageRasterizer();

  @override
  Future<OcrRasterDocument> open(String path) async {
    // Sets up the plugin's asset and cache access and loads the native engine.
    // It is a no-op after the first call, so a caller does not have to know it
    // is needed.
    await pdfrxFlutterInitialize();

    final PdfDocument document;
    try {
      document = await PdfDocument.openFile(path);
    } catch (error) {
      throw OcrFailure('the document could not be opened', error);
    }
    return _PdfrxDocument(document);
  }
}

class _PdfrxDocument implements OcrRasterDocument {
  _PdfrxDocument(this._document);

  final PdfDocument _document;

  @override
  int get pageCount => _document.pages.length;

  @override
  Future<RasterImage> render({required int index, required int dpi}) async {
    if (index < 0 || index >= pageCount) {
      throw OcrFailure('the document has no page $index');
    }
    final PdfPage page = _document.pages[index];
    // The page's size in points is what the resolution scales: PDF points are
    // 1/72 inch, so a page at [dpi] is `points * dpi / 72` pixels on each side.
    final double scale = dpi / 72;
    final int width = (page.width * scale).round();
    final int height = (page.height * scale).round();

    final PdfImage? image;
    try {
      image = await page.render(
        fullWidth: width.toDouble(),
        fullHeight: height.toDouble(),
      );
    } catch (error) {
      throw OcrFailure('page $index could not be rendered', error);
    }
    if (image == null) {
      throw OcrFailure('page $index could not be rendered');
    }
    try {
      return RasterImage(
        // The image's own size is the authority, not the size that was asked
        // for: PDFium rounds the scaled page itself.
        width: image.width,
        height: image.height,
        widthPoints: page.width,
        heightPoints: page.height,
        pixels: Uint8List.fromList(image.pixels),
      );
    } finally {
      image.dispose();
    }
  }

  @override
  Future<void> dispose() async {
    await _document.dispose();
  }
}
