import 'dart:io';
import 'dart:typed_data';

import 'package:paperdrop_core/paperdrop_core.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'image_decoder.dart';
import 'image_header.dart';
import 'image_passes.dart';
import 'mlkit_text_recognizer.dart';
import 'ocr_text_source.dart';
import 'page_rasterizer.dart';
import 'pdfrx_page_rasterizer.dart';
import 'pixels.dart';
import 'render_passes.dart';
import 'text_recognizer_backend.dart';

/// The photo route's recognition: ML Kit's Latin text recognition over the
/// pages of a document (`implement-photo-route`, design §1–§4).
///
/// **What it does.** A file arrives — the PDF the platform's document scanner
/// produced (T1.13), or a scanned PDF the invoice route fell through from —
/// and for every pass of [passes] it renders the document's pages, hands each
/// render to the engine, and returns the engine's own elements as Core's
/// [TextPage]: integer thousandths of a point, top-left origin, the same units
/// the invoice route's text layer produces. Which pass wins is not decided
/// here.
///
/// **Read-only.** No path of this class writes to the input: the file is opened
/// for reading, rendered in memory, and never saved, re-flattened or
/// re-compressed (ADR-015, `received-files-are-attached-byte-for-byte`). The
/// only writes it makes are the render buffers below.
///
/// **The render buffers.** Each render is held in the application's cache
/// directory, under [bufferDirectoryName], for the length of one recognition
/// and is deleted before the call returns — including when the call fails and
/// including when one pass fails: the `finally` that deletes them is the same
/// one that closes the document and the engine. The bytes handed to the engine
/// are read back from that buffer, so a render has exactly one home and nothing
/// is left behind. Each buffer is deleted as soon as its own page's recognition
/// is over, so the directory holds one render at a time and not the document's
/// worth of them. A caller can therefore assert that the directory holds no
/// file once `recognise` has returned, whichever way it returned.
///
/// **What it does not do.** It merges no pass into another, averages nothing,
/// takes no maximum, sorts no word, parses no amount and binds no label. It
/// also adds no stage of its own beyond design §3's four renders.
///
/// **An image instead of a PDF.** A file whose first bytes are a PNG or a JPEG
/// is read in the passes of [imagePasses]: the file as the engine reads it, and
/// the image decoded to another size or grey-stretched
/// (`implement-photo-passes`, design §2). Its page's size is the image's own
/// pixel size taken as points at 72 dpi (design §1) — the size the file's
/// header declares, wherever in the file that header sits: a camera's JPEG
/// carries tens of kilobytes of EXIF ahead of its frame header (the file
/// measured on a real device on 2026-10-16 puts it at byte 82084), and
/// `image_header.dart` walks the file's segments to reach it rather than
/// reading a prefix. A file that declares a quarter-turn EXIF orientation is
/// shown — and decoded, and read, and measured here — with its sides exchanged
/// ([displayedImageSize]); every pass of that photograph converts its boxes
/// with that one size, which is what makes them comparable
/// (design §4).
///
/// **Where the image path stops.** The size is what the header and the
/// orientation tag say. A photograph's passes are variations of the image
/// itself and nothing here decides which of them is the better reading, nor
/// crops, straightens or binarises anything: the platform's scanner already
/// produced the document that is read (FR-CAP-002, `platform-document-scanner`),
/// and the decision about which passes are worth keeping belongs to the
/// screening T2.5 and the product owner, not to this layer.
class MlKitOcrTextSource implements OcrTextSource {
  /// Creates the source.
  ///
  /// Every collaborator has a default and can be replaced: [passes] and
  /// [imagePasses] for a test that needs a shorter list, [rasterizer],
  /// [imageDecoder], [backend] and [cacheDirectory] for a host test that has
  /// neither the native renderer nor the platform, and the two callbacks for
  /// the evaluation harness, which reports the timings of design §3 and the
  /// passes that were dropped.
  MlKitOcrTextSource({
    this.passes = ocrRenderPasses,
    this.imagePasses = ocrImagePasses,
    OcrPageRasterizer? rasterizer,
    OcrImageDecoder? imageDecoder,
    TextRecognizerBackend Function()? backend,
    Future<Directory> Function()? cacheDirectory,
    this.onPassRecognised,
    this.onPassDropped,
  }) : _rasterizer = rasterizer ?? const PdfrxPageRasterizer(),
       _imageDecoder = imageDecoder ?? const PlatformImageDecoder(),
       _openBackend = backend ?? MlKitTextRecognizer.new,
       _cacheDirectory = cacheDirectory ?? getApplicationCacheDirectory;

  /// The passes of a PDF, in the order they are read (design §3).
  final List<OcrRenderPass> passes;

  /// The passes of an image, in the order they are read
  /// (`implement-photo-passes`, design §2).
  ///
  /// A list of its own and not the page list: a page is rendered at a
  /// resolution and a photograph is decoded to a size, and the two are
  /// different variations of different things. Both are injectable, so a test
  /// can hand the source a list of one pass and read what it does.
  final List<OcrImagePass> imagePasses;

  /// Called once per pass that was read, with how long it took.
  ///
  /// The port carries no timing: the evaluation harness needs it (design §4
  /// reports milliseconds per pass), and only this class knows where one pass's
  /// work ends and the next begins. Nothing in the application passes it.
  final void Function(String passId, Duration elapsed)? onPassRecognised;

  /// Called once per pass that threw, with what threw.
  ///
  /// A failed pass is dropped from the result — design §3 allows a list shorter
  /// than the constant — and this is where it is recorded rather than lost. The
  /// harness writes it into the document's JSON; nothing in the application
  /// passes it.
  final void Function(String passId, Object error)? onPassDropped;

  /// The directory under the cache directory that a render lives in.
  static const String bufferDirectoryName = 'ocr-render';

  /// The id the first pass of a photograph is reported under.
  ///
  /// It is `p1-native` — the pass that adds no scaling, because it hands the
  /// engine the file itself — and it comes from [ocrImagePasses] rather than
  /// being written again here: a caller that needs "the pass a photograph is
  /// read under first" reads the list, and a rename of that pass is one edit.
  static String get imagePassId => ocrImagePasses.first.passId;

  /// The library and the version behind the port, in the `tool` format the
  /// evaluation harness writes (design §4).
  static const String toolName = MlKitTextRecognizer.toolName;

  /// How many bytes of a file are read to tell whether it is a PDF.
  ///
  /// `%PDF-`, the five bytes every PDF starts with, and all this class reads of
  /// a file to identify it. An image is not identified from a prefix here: a
  /// PNG's size is in its own twenty-four bytes of header, and a JPEG's frame
  /// header sits behind application segments whose lengths only a walk reaches,
  /// so the file is read by `image_header.dart`, four bytes of segment header at
  /// a time, and never whole. The file itself is never read whole here either:
  /// the renderer and the engine read what they need.
  static const int _pdfMarkerBytes = 5;

  final OcrPageRasterizer _rasterizer;
  final OcrImageDecoder _imageDecoder;
  final TextRecognizerBackend Function() _openBackend;
  final Future<Directory> Function() _cacheDirectory;

  @override
  Future<List<OcrPass>> recognise(String path) async {
    final File input = File(path);
    final Uint8List head; // the file's first bytes
    final bool isPdf; // and what they say it is
    final ImagePixelSize? size; // an image's size, when it is one
    final int? orientation; // and the orientation its EXIF declares, if any
    try {
      head = _headOf(input);
      isPdf = looksLikePdf(head);
      size = isPdf ? null : imagePixelSizeIn(input);
      orientation = isPdf ? null : imageExifOrientationIn(input);
    } on FileSystemException catch (error) {
      throw OcrFailure('the file could not be read', error);
    }

    if (isPdf) {
      return _recogniseDocument(path);
    }
    if (size == null) {
      throw const OcrFailure(
        'the file is neither a PDF nor a PNG or JPEG image',
      );
    }
    return _recogniseImage(path, size, orientation);
  }

  /// A PDF: every pass, over every page, through the renderer.
  Future<List<OcrPass>> _recogniseDocument(String path) async {
    final Directory buffers = await _bufferDirectory();
    final List<String> written = <String>[];
    final OcrRasterDocument document = await _rasterizer.open(path);
    TextRecognizerBackend? backend;
    try {
      final TextRecognizerBackend engine = backend = _openBackend();
      final List<OcrPass> passes = <OcrPass>[];
      for (final OcrRenderPass pass in this.passes) {
        final Stopwatch stopwatch = Stopwatch()..start();
        try {
          final List<TextPage> pages = <TextPage>[];
          for (var index = 0; index < document.pageCount; index++) {
            final RasterImage raster = await document.render(
              index: index,
              dpi: pass.dpi,
            );
            final Uint8List rgba = pass.greyContrast
                ? greyContrastStretchRgba(raster.pixels)
                : rgbaFromBgra(raster.pixels);
            final File buffer = File(
              p.join(buffers.path, '${pass.passId}-page$index.rgba'),
            );
            written.add(buffer.path);
            final List<OcrElement> elements;
            try {
              buffer.writeAsBytesSync(rgba);
              // The buffer's only reader: what the engine is handed is what
              // lives in the cache directory and nothing else.
              elements = await engine.recogniseImage(
                pixels: buffer.readAsBytesSync(),
                width: raster.width,
                height: raster.height,
              );
            } finally {
              // Deleted as soon as this page's recognition is over, and not
              // only when the call returns: a document of a hundred pages
              // (the scanner's own page limit) would otherwise hold a hundred
              // renders at once, each of them tens of megabytes. The buffer
              // directory holds one render at a time, and none when the call
              // has returned — including when it ended in a failure.
              _deleteBuffer(buffer);
            }
            pages.add(
              textPageFromOcrElements(
                index: index,
                elements: elements,
                widthPoints: raster.widthPoints,
                heightPoints: raster.heightPoints,
                widthPixels: raster.width,
                heightPixels: raster.height,
              ),
            );
          }
          stopwatch.stop();
          passes.add(OcrPass(pass.passId, pages));
          onPassRecognised?.call(pass.passId, stopwatch.elapsed);
        } catch (error) {
          // Dropped and reported (design §3). The remaining passes still run:
          // one unusable rendering must not cost the document its others.
          onPassDropped?.call(pass.passId, error);
        }
      }
      if (passes.isEmpty) {
        throw OcrFailure(
          'no pass of ${this.passes.length} could read the document',
        );
      }
      return List<OcrPass>.unmodifiable(passes);
    } finally {
      _clearBuffers(written);
      await backend?.close();
      await document.dispose();
    }
  }

  /// A PNG or a JPEG: every pass of [imagePasses], one reading each.
  ///
  /// [storedSize] is the size the file's frame header declares and
  /// [exifOrientation] the orientation its EXIF declares (null when it declares
  /// none). The picture is *shown* at [displayedImageSize] of the two, and that
  /// size — in points at 72 dpi, design §1 — is the page every pass of this
  /// photograph converts its boxes with. One page size for all the passes is
  /// what makes the same word land in the same coordinates in each of them
  /// (design §4): a pass that is read from a smaller image has fewer pixels to
  /// report a box in, and the same page to report it against.
  ///
  /// The pass that reads the file as it is ([OcrImagePass.readsTheFileAsItIs])
  /// hands the engine the path; every other pass decodes the file with
  /// [_imageDecoder] to the size its own scale asks for, grey-stretches it when
  /// it says so, and hands the engine those pixels. Nothing is written to the
  /// cache directory here: a decoded image is not a render of anything, it lives
  /// in memory for its own pass and is dropped when the pass ends, and writing
  /// tens of megabytes per pass to flash would be work this route does not need.
  ///
  /// A pass that throws is dropped and reported, exactly as for a PDF, and the
  /// passes after it still run. A photograph no pass could read fails as an
  /// [OcrFailure].
  Future<List<OcrPass>> _recogniseImage(
    String path,
    ImagePixelSize storedSize,
    int? exifOrientation,
  ) async {
    final ImagePixelSize displayed = displayedImageSize(
      storedSize,
      exifOrientation,
    );
    final File input = File(path);
    final TextRecognizerBackend backend = _openBackend();
    try {
      final List<OcrPass> passes = <OcrPass>[];
      for (final OcrImagePass pass in imagePasses) {
        final Stopwatch stopwatch = Stopwatch()..start();
        try {
          final List<OcrElement> elements;
          final int widthPixels;
          final int heightPixels;
          final ImagePixelSize? target = pass.decodeTargetFor(displayed);
          if (target == null) {
            elements = await backend.recogniseFile(path);
            widthPixels = displayed.width;
            heightPixels = displayed.height;
          } else {
            final DecodedImage decoded = await _imageDecoder.decode(
              input,
              targetWidth: target.width,
              targetHeight: target.height,
            );
            elements = await backend.recogniseImage(
              pixels: pass.greyContrast
                  ? greyContrastStretchFromRgba(decoded.pixels)
                  : decoded.pixels,
              width: decoded.width,
              height: decoded.height,
            );
            widthPixels = decoded.width;
            heightPixels = decoded.height;
          }
          stopwatch.stop();
          passes.add(
            OcrPass(pass.passId, <TextPage>[
              textPageFromOcrElements(
                index: 0,
                elements: elements,
                // Design §1: for a bare image, its pixel size taken as points
                // at 72 dpi — the size it is displayed at, for every pass.
                widthPoints: displayed.width.toDouble(),
                heightPoints: displayed.height.toDouble(),
                widthPixels: widthPixels,
                heightPixels: heightPixels,
              ),
            ]),
          );
          onPassRecognised?.call(pass.passId, stopwatch.elapsed);
        } catch (error) {
          // Dropped and reported (design §2). One unusable reading must not
          // cost the photograph its others.
          onPassDropped?.call(pass.passId, error);
        }
      }
      if (passes.isEmpty) {
        throw OcrFailure(
          'no pass of ${imagePasses.length} could read the image',
        );
      }
      return List<OcrPass>.unmodifiable(passes);
    } finally {
      await backend.close();
    }
  }

  /// The file's first [_pdfMarkerBytes] bytes, which is where a PDF's marker
  /// is.
  ///
  /// The bytes are read and not the name: the intake keeps the name a document
  /// arrived with, and a file called `.pdf` that is not one is no PDF.
  static Uint8List _headOf(File file) {
    final RandomAccessFile handle = file.openSync();
    try {
      return handle.readSync(_pdfMarkerBytes);
    } finally {
      handle.closeSync();
    }
  }

  /// The directory render buffers live in, created if it is not there yet.
  Future<Directory> _bufferDirectory() async {
    final Directory cache = await _cacheDirectory();
    final Directory buffers = Directory(
      p.join(cache.path, bufferDirectoryName),
    );
    if (!buffers.existsSync()) {
      buffers.createSync(recursive: true);
    }
    return buffers;
  }

  /// Removes the render buffers. It runs whichever way the call ended.
  void _clearBuffers(List<String> written) {
    for (final String path in written) {
      _deleteBuffer(File(path));
    }
  }

  /// Removes one render buffer, if it is still there.
  void _deleteBuffer(File buffer) {
    if (buffer.existsSync()) {
      buffer.deleteSync();
    }
  }
}

/// One page of the engine's elements, as Core's [TextPage] (design §1 and §5).
///
/// It is public and pure so that the conversion is unit tested with a known
/// box: no renderer and no engine is needed to read back Core's units.
///
/// [index] is zero-based. [widthPoints] and [heightPoints] are the page's size
/// in points and [widthPixels] and [heightPixels] the image's size in pixels:
/// the engine's boxes are in pixels, and the two together are the scale that
/// turns them into milli-points, with `(pixels * points * 1000 / pixelsTotal)`
/// rounded to the nearest thousandth. The origin needs no correction — a
/// rendered image and Core both measure from the top left corner.
///
/// An element is a word when it carries text and no whitespace, which is what
/// `PositionedWord` states of a word. An element that carries whitespace — the
/// engine reports a run of spaces as an element of its own — is dropped rather
/// than split or trimmed: either would be this adapter segmenting words, and
/// design §1 leaves segmentation to the engine. Dropping loses nothing that
/// could be bound: a run of whitespace is not a value.
///
/// [TextPage.hasTextLayer] is not set here: it is derived from the words, so a
/// page with no word is a page without a text layer, which is the answer the
/// route selector's fall-through reads.
TextPage textPageFromOcrElements({
  required int index,
  required List<OcrElement> elements,
  required double widthPoints,
  required double heightPoints,
  required int widthPixels,
  required int heightPixels,
}) {
  if (widthPixels <= 0 || heightPixels <= 0) {
    throw ArgumentError.value(
      '$widthPixels x $heightPixels',
      'widthPixels',
      'the image must have a pixel',
    );
  }
  final List<PositionedWord> words = <PositionedWord>[];
  for (final OcrElement element in elements) {
    if (!_isWord(element.text)) {
      continue;
    }
    words.add(
      PositionedWord(
        element.text,
        _milli(element.left, widthPoints, widthPixels),
        _milli(element.right, widthPoints, widthPixels),
        _milli(element.top, heightPoints, heightPixels),
        _milli(element.bottom, heightPoints, heightPixels),
      ),
    );
  }
  return TextPage(
    index,
    (widthPoints * 1000).round(),
    (heightPoints * 1000).round(),
    words,
  );
}

bool _isWord(String text) => text.isNotEmpty && !_whitespace.hasMatch(text);

/// The whitespace a word may not carry, which is what `PositionedWord` states
/// of a word and what an element of a run of spaces carries.
final RegExp _whitespace = RegExp(r'\s');

/// Pixels to Core's integer thousandths of a point, on one axis.
int _milli(int pixels, double points, int pixelsTotal) =>
    (pixels * points * 1000 / pixelsTotal).round();
