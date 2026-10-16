import 'dart:io';
import 'dart:typed_data';

import 'package:paperdrop/adapters/ocr/image_decoder.dart';
import 'package:paperdrop/adapters/ocr/image_header.dart';
import 'package:paperdrop/adapters/ocr/ocr_text_source.dart';
import 'package:paperdrop/adapters/ocr/page_rasterizer.dart';
import 'package:paperdrop/adapters/ocr/text_recognizer_backend.dart';

/// What the photo route's tests replace (`implement-photo-route`, design §4:
/// "the engine is behind a small internal interface, faked in tests").
///
/// **Why they are here.** Two host test files need them: the adapter's own
/// (`test/adapters/ocr/mlkit_ocr_text_source_test.dart`), which exercises the
/// passes, the cache files and the conversion without a device, and the
/// renderer's (`test/adapters/ocr/pdfrx_page_rasterizer_test.dart`), which runs
/// the real PDFium and replaces only what no host can run — the Android
/// engine.
///
/// **What they never do.** They write no document and touch no file of the
/// private corpus: a fake renderer answers with the buffer the test handed it,
/// and a fake decoder answers with a buffer of the size it was asked for.

/// A renderer that hands back one small page per pass and records what it was
/// asked for.
class FakeOcrPageRasterizer implements OcrPageRasterizer {
  FakeOcrPageRasterizer({
    this.failingDpi,
    this.failsEveryRender = false,
    Uint8List? pixels,
    this.width = 2,
    this.height = 1,
    this.pageCount = 1,
  }) : pixels = pixels ?? Uint8List.fromList(<int>[3, 2, 1, 255, 6, 5, 4, 255]);

  /// A resolution whose render throws.
  final int? failingDpi;

  /// Whether every render throws, which leaves a document no pass could read.
  final bool failsEveryRender;

  /// The BGRA bytes of every render.
  final Uint8List pixels;

  /// The pixel width of every render.
  final int width;

  /// The pixel height of every render.
  final int height;

  /// How many pages the document says it has.
  final int pageCount;

  /// The resolutions renders were asked for, in order.
  final List<int> renders = <int>[];

  /// Whether the document was disposed.
  bool disposed = false;

  @override
  Future<OcrRasterDocument> open(String path) async =>
      FakeOcrRasterDocument(this);
}

/// One page of [FakeOcrPageRasterizer].
class FakeOcrRasterDocument implements OcrRasterDocument {
  /// Creates the page of [rasterizer].
  FakeOcrRasterDocument(this.rasterizer);

  /// The renderer this page belongs to.
  final FakeOcrPageRasterizer rasterizer;

  @override
  int get pageCount => rasterizer.pageCount;

  @override
  Future<RasterImage> render({required int index, required int dpi}) async {
    rasterizer.renders.add(dpi);
    if (rasterizer.failsEveryRender || dpi == rasterizer.failingDpi) {
      throw OcrFailure('the page could not be rendered at $dpi dpi');
    }
    return RasterImage(
      width: rasterizer.width,
      height: rasterizer.height,
      widthPoints: 2,
      heightPoints: 1,
      pixels: rasterizer.pixels,
    );
  }

  @override
  Future<void> dispose() async {
    rasterizer.disposed = true;
  }
}

/// A renderer that cannot open anything.
class FailingOcrPageRasterizer implements OcrPageRasterizer {
  @override
  Future<OcrRasterDocument> open(String path) async =>
      throw const OcrFailure('the document could not be opened');
}

/// The engine, replaced: it answers what the test decided and records what it
/// was handed.
class FakeTextRecognizerBackend implements TextRecognizerBackend {
  /// Creates the engine with the elements it answers with.
  FakeTextRecognizerBackend({
    this.elements = const <OcrElement>[OcrElement('Gesamtbetrag', 0, 0, 1, 1)],
    this.fileElements,
    this.elementsFor,
    this.failing = false,
    this.failFirstCall = false,
    this.failSecondCall = false,
    this.failForSize,
    this.onRecogniseImage,
  });

  /// Called at the start of every [recogniseImage], for a test that has to see
  /// the world at the moment of the call.
  final void Function()? onRecogniseImage;

  /// What a recognition of pixels answers.
  final List<OcrElement> elements;

  /// What a recognition of a file answers, when it is not [elements].
  final List<OcrElement>? fileElements;

  /// What a recognition of pixels answers when the answer depends on the size
  /// the engine was handed — which is how a test says "the same word is at the
  /// same place of the picture" without an engine.
  final List<OcrElement> Function(int width, int height)? elementsFor;

  /// Whether every recognition throws.
  final bool failing;

  /// Whether the first recognition throws, and the rest answer.
  final bool failFirstCall;

  /// Whether the second recognition throws, and the rest answer.
  final bool failSecondCall;

  /// A pixel size whose recognition throws, and the rest answer.
  final ImagePixelSize? failForSize;

  /// The buffers handed to [recogniseImage], in order.
  final List<Uint8List> pixels = <Uint8List>[];

  /// The sizes the buffers were handed with, in order.
  final List<List<int>> sizes = <List<int>>[];

  /// The paths handed to [recogniseFile], in order.
  final List<String> files = <String>[];

  /// How many times the engine was closed.
  int closes = 0;

  var _calls = 0;

  @override
  Future<List<OcrElement>> recogniseImage({
    required Uint8List pixels,
    required int width,
    required int height,
  }) async {
    _calls++;
    onRecogniseImage?.call();
    this.pixels.add(pixels);
    sizes.add(<int>[width, height]);
    if (failing ||
        (failFirstCall && _calls == 1) ||
        (failSecondCall && _calls == 2) ||
        (failForSize != null && failForSize == ImagePixelSize(width, height))) {
      throw const OcrFailure('the engine could not read the image');
    }
    return elementsFor?.call(width, height) ?? elements;
  }

  @override
  Future<List<OcrElement>> recogniseFile(String path) async {
    _calls++;
    files.add(path);
    if (failing) {
      throw const OcrFailure('the engine could not read the file');
    }
    return fileElements ?? elements;
  }

  @override
  Future<void> close() async {
    closes++;
  }
}

/// The image decoder, replaced: it answers a buffer of the size it was asked
/// for and records what it was asked for.
///
/// It is a fake and not the platform's decoder because the pass list, the drop
/// of a failed pass and the geometry are what the adapter's own tests are
/// about: what the platform's decoder does with a real file is
/// `test/adapters/ocr/image_decoder_test.dart`'s, which decodes a photograph
/// the test writes from bytes.
class FakeOcrImageDecoder implements OcrImageDecoder {
  /// Creates a decoder that answers [nativeSize] when it is asked for no target
  /// and the target it was asked for otherwise, in the grey level [grey], and
  /// that throws for [failingTarget] when it is set.
  FakeOcrImageDecoder({
    this.nativeSize = const ImagePixelSize(2, 1),
    this.grey = 200,
    this.failingTarget,
    this.failsEveryTarget = false,
  });

  /// The size an image is decoded to when no target is asked for.
  final ImagePixelSize nativeSize;

  /// The grey level of every pixel of every buffer this decoder answers with.
  final int grey;

  /// A target whose decode throws, and the others answer.
  final ImagePixelSize? failingTarget;

  /// Whether every decode throws, which leaves a photograph no pass could read.
  final bool failsEveryTarget;

  /// The files this decoder was asked to decode, in order.
  final List<String> files = <String>[];

  /// The targets it was asked for, in order.
  final List<ImagePixelSize> targets = <ImagePixelSize>[];

  @override
  Future<DecodedImage> decode(
    File file, {
    required int? targetWidth,
    required int? targetHeight,
  }) async {
    files.add(file.path);
    final ImagePixelSize size = targetWidth == null || targetHeight == null
        ? nativeSize
        : ImagePixelSize(targetWidth, targetHeight);
    targets.add(size);
    if (failsEveryTarget || size == failingTarget) {
      throw const OcrFailure('the image could not be decoded');
    }
    final Uint8List pixels = Uint8List(size.width * size.height * 4);
    for (var i = 0; i < pixels.length; i += 4) {
      pixels[i] = grey;
      pixels[i + 1] = grey;
      pixels[i + 2] = grey;
      pixels[i + 3] = 255;
    }
    return DecodedImage(width: size.width, height: size.height, pixels: pixels);
  }
}
