import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperdrop/adapters/ocr/mlkit_ocr_text_source.dart';
import 'package:paperdrop/adapters/ocr/ocr_text_source.dart';
import 'package:paperdrop/adapters/ocr/page_rasterizer.dart';
import 'package:paperdrop/adapters/ocr/pdfrx_page_rasterizer.dart';
import 'package:path/path.dart' as p;

import '../../tool/ocr_fakes.dart';
import '../../tool/pdfrx_host.dart';
import '../../tool/synthetic_documents.dart';

/// The renderer over a real PDFium (`implement-photo-route`, task 1.3).
///
/// **What this proves.** That PDFium opens a document through this application,
/// that a page really is rendered to the pixels the passes ask for — the
/// resolution arithmetic of design §3, the page's own size in points, and a
/// buffer of four bytes per pixel — and that rendering **leaves the file
/// byte-for-byte what it was** (ADR-015,
/// `received-files-are-attached-byte-for-byte`, and the scenario "the source
/// file survives rendering" of `render-and-ocr-fallback`), proved with a
/// SHA-256 taken before and after and never by inspection.
///
/// **Why it can run here.** PDFium is a native library, and the plugin's build
/// hook links it for the machine `flutter test` runs on as well as for Android.
/// The only thing the host lacks is the platform channel `path_provider`
/// answers on a phone, so the test answers it (`mockPathProviderCacheDirectory`)
/// — the engine, the parsing and the render are the same code that runs on the
/// device.
///
/// **What never enters the repository.** The document is written by this test
/// from invented text (`syntheticPdf`); the private corpus is not read, copied
/// or named here.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory work;
  late File document;

  setUpAll(() {
    work = Directory.systemTemp.createTempSync('paperdrop-ocr-render');
    mockPathProviderCacheDirectory(work);
    // 595 x 842 points, the page `syntheticPdf` writes: the geometry is known,
    // so what the renderer reports can be checked against it instead of against
    // itself.
    document = File(p.join(work.path, 'paperdrop-ocr-source.pdf'))
      ..writeAsBytesSync(syntheticPdf(text: 'Gesamtbetrag 1.234,50'));
  });

  tearDownAll(() {
    if (work.existsSync()) {
      work.deleteSync(recursive: true);
    }
  });

  test('a page is rendered at the resolution the pass asks for', () async {
    const PdfrxPageRasterizer rasterizer = PdfrxPageRasterizer();
    final Uint8List before = document.readAsBytesSync();

    final OcrRasterDocument opened = await rasterizer.open(document.path);
    try {
      expect(opened.pageCount, 1);

      final RasterImage native = await opened.render(index: 0, dpi: 150);
      // 1/72 inch per point: a 595 point page at 150 dpi is 1239.58 pixels,
      // which the renderer rounds to 1240; 842 points is 1754.17, rounded to
      // 1754.
      expect(native.width, 1240);
      expect(native.height, 1754);
      expect(native.widthPoints, closeTo(595, 1));
      expect(native.heightPoints, closeTo(842, 1));
      // Four bytes per pixel: what the engine is handed, and what the
      // conversion to Core's units counts.
      expect(native.pixels, hasLength(native.width * native.height * 4));
      // A page of white paper with black text on it is neither: the render has
      // both light and dark pixels, which is what a recognition can read.
      expect(
        native.pixels.where((int byte) => byte < 40).length,
        greaterThan(0),
      );
      expect(
        native.pixels.where((int byte) => byte > 215).length,
        greaterThan(0),
      );

      final RasterImage small = await opened.render(index: 0, dpi: 100);
      expect(small.width, 826, reason: '595 * 100 / 72 = 826.4');
      expect(small.height, 1169, reason: '842 * 100 / 72 = 1169.4');
      expect(small.pixels, hasLength(small.width * small.height * 4));

      final RasterImage large = await opened.render(index: 0, dpi: 200);
      expect(large.width, 1653, reason: '595 * 200 / 72 = 1652.8');
      expect(large.height, 2339, reason: '842 * 200 / 72 = 2338.9');
    } finally {
      await opened.dispose();
    }

    // Read-only: the bytes after the renders are the bytes before them.
    expect(
      sha256.convert(document.readAsBytesSync()).toString(),
      sha256.convert(before).toString(),
      reason: 'rendering a document must not write to it',
    );
  });

  test('a file that cannot be opened fails as an OcrFailure', () async {
    final File notAPdf = File(p.join(work.path, 'paperdrop-ocr-not-a.pdf'))
      ..writeAsStringSync('not a PDF at all');

    await expectLater(
      const PdfrxPageRasterizer().open(notAPdf.path),
      throwsA(isA<OcrFailure>()),
    );
  });

  test('a page the document does not have fails as an OcrFailure', () async {
    final OcrRasterDocument opened = await const PdfrxPageRasterizer().open(
      document.path,
    );
    try {
      await expectLater(
        opened.render(index: 7, dpi: 150),
        throwsA(isA<OcrFailure>()),
      );
    } finally {
      await opened.dispose();
    }
  });

  test('the passes render for real, and leave no buffer behind', () async {
    // The whole photo route with PDFium under it and only the Android engine
    // replaced: four renders of one real page, each handed to the engine, and
    // the cache directory empty when the call has returned.
    final Directory cache = Directory(p.join(work.path, 'cache'))..createSync();
    final Directory buffers = Directory(
      p.join(cache.path, MlKitOcrTextSource.bufferDirectoryName),
    );
    final FakeTextRecognizerBackend engine = FakeTextRecognizerBackend();
    final Uint8List before = document.readAsBytesSync();

    final List<OcrPass> passes = await MlKitOcrTextSource(
      rasterizer: const PdfrxPageRasterizer(),
      backend: () => engine,
      cacheDirectory: () async => cache,
    ).recognise(document.path);

    expect(passes.map((OcrPass pass) => pass.passId), <String>[
      'p1-native',
      'p2-hi',
      'p3-lo',
      'p4-contrast',
    ]);
    // The engine was handed one render per pass, of the size each pass asks
    // for: 150, 200, 100 and 150 dpi of a 595 x 842 point page.
    expect(engine.sizes, <List<int>>[
      <int>[1240, 1754],
      <int>[1653, 2339],
      <int>[826, 1169],
      <int>[1240, 1754],
    ]);
    for (final Uint8List pixels in engine.pixels) {
      expect(pixels, isNotEmpty);
    }
    // One page per pass, and the engine's element on it, in Core's units.
    expect(passes.first.pages.single.width, 595000);
    expect(passes.first.pages.single.words.single.text, 'Gesamtbetrag');
    expect(engine.closes, 1);

    expect(buffers.existsSync(), isTrue, reason: 'the renders lived here');
    expect(
      buffers.listSync(),
      isEmpty,
      reason: 'a render buffer must not outlive the call',
    );
    expect(
      sha256.convert(document.readAsBytesSync()).toString(),
      sha256.convert(before).toString(),
      reason: 'rendering for recognition must not write to the document',
    );
  });
}
