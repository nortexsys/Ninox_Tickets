import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperdrop/adapters/ocr/mlkit_ocr_text_source.dart';
import 'package:paperdrop/adapters/ocr/ocr_text_source.dart';
import 'package:paperdrop/adapters/ocr/page_rasterizer.dart';
import 'package:paperdrop/adapters/ocr/render_passes.dart';
import 'package:paperdrop/adapters/ocr/text_recognizer_backend.dart';
import 'package:paperdrop_core/paperdrop_core.dart';
import 'package:path/path.dart' as p;

import '../../tool/ocr_fakes.dart';
import '../../tool/synthetic_documents.dart';

/// The port's implementation, without a device (`implement-photo-route`,
/// design §4: "Host side (CI)").
///
/// **What this proves.** Everything design §4 asks the host to cover: that the
/// engine's pixel boxes become Core's integer milli-points with a top-left
/// origin, that a page with no word has no text layer, that the passes are read
/// in design §3's order and under its ids, that a pass which throws is dropped
/// while the others are returned, that the input file is left byte-for-byte as
/// it was, and that the render buffers are deleted whether the call succeeded
/// or failed.
///
/// **Why the engine and the renderer are fakes.** ML Kit is an Android library
/// and PDFium is a native one: neither is a host test's to run. They sit behind
/// `TextRecognizerBackend` and `OcrPageRasterizer` (design §4) precisely so
/// that everything above them — the conversions, the pass list, the cache files
/// — is exercised here, and what needs the device is exercised by
/// `app/integration_test/ocr_eval_test.dart` with the real engine.
///
/// **What never enters the repository.** The documents are written by the test
/// itself, from invented text (`syntheticPdf`); the private corpus is not read,
/// copied or named here.
void main() {
  late Directory work;
  late Directory cache;

  setUp(() {
    work = Directory.systemTemp.createTempSync('paperdrop-ocr-test');
    cache = Directory(p.join(work.path, 'cache'))..createSync();
  });

  tearDown(() {
    if (work.existsSync()) {
      work.deleteSync(recursive: true);
    }
  });

  /// The directory a render buffer lives in while a call is running.
  Directory buffers() =>
      Directory(p.join(cache.path, MlKitOcrTextSource.bufferDirectoryName));

  /// A source over fakes, with the cache directory the test owns.
  MlKitOcrTextSource sourceWith({
    required OcrPageRasterizer rasterizer,
    required TextRecognizerBackend Function() backend,
    List<OcrRenderPass> passes = ocrRenderPasses,
    void Function(String passId, Duration elapsed)? onPassRecognised,
    void Function(String passId, Object error)? onPassDropped,
  }) => MlKitOcrTextSource(
    passes: passes,
    rasterizer: rasterizer,
    backend: backend,
    cacheDirectory: () async => cache,
    onPassRecognised: onPassRecognised,
    onPassDropped: onPassDropped,
  );

  group('the pixel-to-milli-point conversion', () {
    test('a known box becomes exact integer milli-points', () {
      // A 720 x 1000 point page rendered at 144 dpi is 1440 x 2000 pixels:
      // one pixel is exactly half a point on both axes, so every expectation
      // below is an integer that can be written down.
      final TextPage page = textPageFromOcrElements(
        index: 0,
        elements: const <OcrElement>[
          OcrElement('Gesamtbetrag', 100, 200, 300, 250),
        ],
        widthPoints: 720,
        heightPoints: 1000,
        widthPixels: 1440,
        heightPixels: 2000,
      );

      expect(page.index, 0);
      expect(page.width, 720000);
      expect(page.height, 1000000);
      final PositionedWord word = page.words.single;
      expect(word.text, 'Gesamtbetrag');
      expect(word.x0, 50000);
      expect(word.x1, 150000);
      expect(word.top, 100000);
      expect(word.bottom, 125000);
      // The units are thousandths of a point: a box 200 pixels wide at half a
      // point per pixel is 100 points, which is 100000 thousandths.
      expect(word.width, 100000);
      expect(word.height, 25000);
    });

    test('the origin is the top left corner, as the render reports it', () {
      final TextPage page = textPageFromOcrElements(
        index: 0,
        elements: const <OcrElement>[
          // The first line of the page: as high as a box can be.
          OcrElement('Erste', 0, 0, 40, 20),
          // The last line of the page: as low as one can be.
          OcrElement('Letzte', 0, 1780, 60, 1800),
        ],
        widthPoints: 720,
        heightPoints: 900,
        widthPixels: 1440,
        heightPixels: 1800,
      );

      final PositionedWord first = page.words.first;
      final PositionedWord last = page.words.last;
      // A word at the top of the image starts at zero, not at the page's
      // height: nothing flips the vertical axis, because a render and Core
      // both measure downwards from the top left.
      expect(first.top, 0);
      expect(first.bottom, 10000);
      expect(last.bottom, 900000);
      expect(last.bottom, page.height);
      expect(first.top, lessThan(last.top));
    });

    test('a fraction of a thousandth rounds to the nearest one', () {
      // The size the passes really produce: an A4 page at 150 dpi, 595.28 by
      // 841.89 points rendered to 1240 by 1754 pixels. The scale is no longer
      // a round number, and the expectations below are the rounded results.
      final TextPage page = textPageFromOcrElements(
        index: 0,
        elements: const <OcrElement>[OcrElement('x', 10, 100, 20, 110)],
        widthPoints: 595.28,
        heightPoints: 841.89,
        widthPixels: 1240,
        heightPixels: 1754,
      );

      expect(page.width, 595280);
      expect(page.height, 841890);
      final PositionedWord word = page.words.single;
      // 10 * 595.28 * 1000 / 1240 = 4800.645…, which rounds up.
      expect(word.x0, 4801);
      // 20 * 595.28 * 1000 / 1240 = 9601.290…, which rounds down.
      expect(word.x1, 9601);
      // 100 * 841.89 * 1000 / 1754 = 47998.28…, which rounds down.
      expect(word.top, 47998);
      // 110 * 841.89 * 1000 / 1754 = 52798.118…, which rounds down too.
      expect(word.bottom, 52798);
    });

    test('an image with no pixel is refused rather than divided by', () {
      expect(
        () => textPageFromOcrElements(
          index: 0,
          elements: const <OcrElement>[],
          widthPoints: 0,
          heightPoints: 0,
          widthPixels: 0,
          heightPixels: 0,
        ),
        throwsArgumentError,
      );
    });
  });

  group('what the engine returns', () {
    test('an empty page is a page with no text layer, not a failure', () {
      final TextPage page = textPageFromOcrElements(
        index: 2,
        elements: const <OcrElement>[],
        widthPoints: 720,
        heightPoints: 1000,
        widthPixels: 1440,
        heightPixels: 2000,
      );

      expect(page.index, 2);
      expect(page.words, isEmpty);
      // The fall-through signal the route selector reads (T2.1).
      expect(page.hasTextLayer, isFalse);
    });

    test('a run of whitespace is not a word, and the order is the engine\'s', () {
      final TextPage page = textPageFromOcrElements(
        index: 0,
        elements: const <OcrElement>[
          OcrElement('1.234,50', 300, 10, 360, 30),
          OcrElement(' ', 360, 10, 380, 30),
          OcrElement('Gesamtbetrag', 10, 10, 300, 30),
          OcrElement('', 10, 40, 20, 60),
          // An element that carries whitespace inside it is not a word either:
          // it is dropped rather than split, because splitting is segmentation
          // and the engine's segmentation is what this layer returns.
          OcrElement('Tomo 8.741', 10, 70, 90, 90),
        ],
        widthPoints: 720,
        heightPoints: 1000,
        widthPixels: 1440,
        heightPixels: 2000,
      );

      expect(page.words.map((PositionedWord word) => word.text), <String>[
        '1.234,50',
        'Gesamtbetrag',
      ]);
      // The value arrived first and stayed first: no sorting happens here.
      expect(page.words.first.x0, greaterThan(page.words.last.x0));
      expect(page.hasTextLayer, isTrue);
    });
  });

  group('the passes', () {
    test('design §3\'s list is read in its order, under its ids', () async {
      final FakeTextRecognizerBackend backend = FakeTextRecognizerBackend();
      final FakeOcrPageRasterizer rasterizer = FakeOcrPageRasterizer();
      final List<String> recognised = <String>[];

      final List<OcrPass> passes = await sourceWith(
        rasterizer: rasterizer,
        backend: () => backend,
        onPassRecognised: (String passId, Duration elapsed) =>
            recognised.add(passId),
      ).recognise(_pdfIn(work).path);

      expect(passes.map((OcrPass pass) => pass.passId), <String>[
        'p1-native',
        'p2-hi',
        'p3-lo',
        'p4-contrast',
      ]);
      expect(recognised, <String>[
        'p1-native',
        'p2-hi',
        'p3-lo',
        'p4-contrast',
      ]);
      expect(rasterizer.renders, <int>[150, 200, 100, 150]);
      // One page per pass, in page order, with the engine's words on it.
      for (final OcrPass pass in passes) {
        expect(pass.pages, hasLength(1));
        expect(pass.pages.single.index, 0);
        expect(pass.pages.single.hasTextLayer, isTrue);
      }
      expect(backend.closes, 1, reason: 'one engine per call, closed once');
      expect(rasterizer.disposed, isTrue);
    });

    test('a pass that throws is dropped, and the others are returned', () async {
      final FakeTextRecognizerBackend backend = FakeTextRecognizerBackend();
      // The render of the 200 dpi pass fails: the page cannot be drawn at that
      // resolution.
      final FakeOcrPageRasterizer rasterizer = FakeOcrPageRasterizer(
        failingDpi: 200,
      );
      final List<String> dropped = <String>[];

      final List<OcrPass> passes = await sourceWith(
        rasterizer: rasterizer,
        backend: () => backend,
        onPassDropped: (String passId, Object error) => dropped.add(passId),
      ).recognise(_pdfIn(work).path);

      expect(passes.map((OcrPass pass) => pass.passId), <String>[
        'p1-native',
        'p3-lo',
        'p4-contrast',
      ]);
      expect(dropped, <String>['p2-hi']);
      // A shorter list is legal; one pass alone is legal too.
      expect(passes, hasLength(3));
    });

    test('one pass alone is returned as one pass', () async {
      final List<OcrPass> passes = await sourceWith(
        rasterizer: FakeOcrPageRasterizer(),
        backend: FakeTextRecognizerBackend.new,
        passes: const <OcrRenderPass>[OcrRenderPass('p2-hi', dpi: 200)],
      ).recognise(_pdfIn(work).path);

      expect(passes, hasLength(1));
      expect(passes.single.passId, 'p2-hi');
    });

    test('a document no pass could read fails as an OcrFailure', () async {
      final FakeOcrPageRasterizer rasterizer = FakeOcrPageRasterizer(
        failsEveryRender: true,
      );

      await expectLater(
        sourceWith(
          rasterizer: rasterizer,
          backend: FakeTextRecognizerBackend.new,
        ).recognise(_pdfIn(work).path),
        throwsA(isA<OcrFailure>()),
      );
      expect(rasterizer.renders, hasLength(4), reason: 'every pass was tried');
    });

    test(
      'an engine that throws for every pass fails as an OcrFailure',
      () async {
        await expectLater(
          sourceWith(
            rasterizer: FakeOcrPageRasterizer(),
            backend: () => FakeTextRecognizerBackend(failing: true),
          ).recognise(_pdfIn(work).path),
          throwsA(isA<OcrFailure>()),
        );
      },
    );

    test(
      'an engine that throws for one page of one pass drops that pass',
      () async {
        // The first call fails, the rest answer: the failure belongs to
        // `p1-native` and the other three passes are still read.
        final List<String> dropped = <String>[];
        final List<OcrPass> passes = await sourceWith(
          rasterizer: FakeOcrPageRasterizer(),
          backend: () => FakeTextRecognizerBackend(failFirstCall: true),
          onPassDropped: (String passId, Object error) => dropped.add(passId),
        ).recognise(_pdfIn(work).path);

        expect(dropped, <String>['p1-native']);
        expect(passes.map((OcrPass pass) => pass.passId), <String>[
          'p2-hi',
          'p3-lo',
          'p4-contrast',
        ]);
      },
    );
  });

  group('the file and the cache', () {
    test('reading a document leaves it byte-for-byte as it was', () async {
      final File document = _pdfIn(work);
      final Uint8List before = document.readAsBytesSync();
      final String sha256Before = sha256.convert(before).toString();

      await sourceWith(
        rasterizer: FakeOcrPageRasterizer(),
        backend: FakeTextRecognizerBackend.new,
      ).recognise(document.path);

      expect(
        sha256.convert(document.readAsBytesSync()).toString(),
        sha256Before,
        reason: 'reading a document must not write to it (ADR-015)',
      );
    });

    test('every render buffer is gone when the call returns', () async {
      await sourceWith(
        rasterizer: FakeOcrPageRasterizer(),
        backend: FakeTextRecognizerBackend.new,
      ).recognise(_pdfIn(work).path);

      expect(buffers().existsSync(), isTrue, reason: 'the buffers lived here');
      expect(
        buffers().listSync(),
        isEmpty,
        reason: 'a render buffer must not outlive the call',
      );
    });

    test('one render at a time is held, not the whole document', () async {
      // The scanner allows a hundred pages: holding every render until the call
      // returns would be tens of megabytes a page. At the moment each page is
      // handed to the engine, the directory holds that one buffer.
      final List<int> held = <int>[];
      await sourceWith(
        rasterizer: FakeOcrPageRasterizer(),
        backend: () => FakeTextRecognizerBackend(
          onRecogniseImage: () => held.add(buffers().listSync().length),
        ),
      ).recognise(_pdfIn(work).path);

      expect(held, <int>[1, 1, 1, 1], reason: 'four passes, one buffer each');
    });

    test('the buffers are gone when a pass failed, and when all did', () async {
      // One pass fails on its render, and the engine then fails for another:
      // both routes out of the loop have to clear what was written.
      await sourceWith(
        rasterizer: FakeOcrPageRasterizer(failingDpi: 100),
        backend: () => FakeTextRecognizerBackend(failSecondCall: true),
      ).recognise(_pdfIn(work).path);
      expect(buffers().listSync(), isEmpty);

      await expectLater(
        sourceWith(
          rasterizer: FakeOcrPageRasterizer(),
          backend: () => FakeTextRecognizerBackend(failing: true),
        ).recognise(_pdfIn(work).path),
        throwsA(isA<OcrFailure>()),
      );
      expect(
        buffers().listSync(),
        isEmpty,
        reason: 'a failed call must not leave a render behind',
      );
    });

    test('the engine is handed the pixels of the render, in RGBA', () async {
      final FakeTextRecognizerBackend backend = FakeTextRecognizerBackend();
      // Two pixels of BGRA, in the order a renderer produces them.
      final FakeOcrPageRasterizer rasterizer = FakeOcrPageRasterizer(
        pixels: Uint8List.fromList(<int>[
          3, 2, 1, 255, //
          6, 5, 4, 255,
        ]),
        width: 2,
        height: 1,
      );

      await sourceWith(
        rasterizer: rasterizer,
        backend: () => backend,
      ).recognise(_pdfIn(work).path);

      // Four passes, so the engine saw four buffers: the three plain ones are
      // the same bytes, the contrast pass is not.
      expect(backend.pixels, hasLength(4));
      expect(backend.pixels.first, <int>[1, 2, 3, 255, 4, 5, 6, 255]);
      expect(backend.pixels[1], backend.pixels.first);
      // The grey pass: a luminance per pixel, stretched to the ends of the
      // range this two-pixel buffer has, and opaque.
      expect(backend.pixels[3], <int>[0, 0, 0, 255, 255, 255, 255, 255]);
      expect(backend.sizes, <List<int>>[
        <int>[2, 1],
        <int>[2, 1],
        <int>[2, 1],
        <int>[2, 1],
      ]);
    });

    test(
      'a file that is neither a PDF nor an image fails as an OcrFailure',
      () async {
        final File other = File(p.join(work.path, 'notes.txt'))
          ..writeAsStringSync('this is not a document of any route');

        await expectLater(
          sourceWith(
            rasterizer: FakeOcrPageRasterizer(),
            backend: FakeTextRecognizerBackend.new,
          ).recognise(other.path),
          throwsA(
            isA<OcrFailure>().having(
              (OcrFailure failure) => failure.reason,
              'reason',
              contains('neither a PDF nor a PNG or JPEG'),
            ),
          ),
        );
      },
    );

    test('a file that is not there fails as an OcrFailure', () async {
      await expectLater(
        sourceWith(
          rasterizer: FakeOcrPageRasterizer(),
          backend: FakeTextRecognizerBackend.new,
        ).recognise(p.join(work.path, 'nothing-here.pdf')),
        throwsA(isA<OcrFailure>()),
      );
    });

    test('a document that cannot be opened fails as an OcrFailure', () async {
      // A file whose first bytes are a PDF's marker, so the route is the
      // renderer's — and the renderer is what reports that it cannot read it.
      final File marked = File(p.join(work.path, 'broken.pdf'))
        ..writeAsBytesSync(<int>[...'%PDF-1.4'.codeUnits, 0x0A]);

      await expectLater(
        sourceWith(
          rasterizer: FailingOcrPageRasterizer(),
          backend: FakeTextRecognizerBackend.new,
        ).recognise(marked.path),
        throwsA(isA<OcrFailure>()),
      );
    });
  });

  group('an image', () {
    test('is read as it is, in the one pass that adds no scaling', () async {
      final FakeTextRecognizerBackend backend = FakeTextRecognizerBackend(
        fileElements: const <OcrElement>[
          OcrElement('Gesamtbetrag', 10, 20, 110, 40),
        ],
      );
      final File image = _pngIn(work, width: 800, height: 1200);

      final List<OcrPass> passes = await sourceWith(
        rasterizer: FailingOcrPageRasterizer(),
        backend: () => backend,
      ).recognise(image.path);

      expect(passes, hasLength(1));
      expect(passes.single.passId, MlKitOcrTextSource.imagePassId);
      expect(backend.files, <String>[image.path]);
      expect(backend.pixels, isEmpty, reason: 'an image is not rendered');
      // Its pixel size is taken as points at 72 dpi (design §1): one pixel is
      // one point, so a box is its own size in milli-points.
      final TextPage page = passes.single.pages.single;
      expect(page.width, 800000);
      expect(page.height, 1200000);
      final PositionedWord word = page.words.single;
      expect(word.x0, 10000);
      expect(word.x1, 110000);
      expect(word.top, 20000);
      expect(word.bottom, 40000);
      // No render, so no render buffer: the cache directory is not even made.
      expect(buffers().existsSync(), isFalse);
    });

    test('a JPEG is recognised from its header too', () async {
      final FakeTextRecognizerBackend backend = FakeTextRecognizerBackend();
      final File image = _jpegIn(work, width: 300, height: 400);

      final List<OcrPass> passes = await sourceWith(
        rasterizer: FailingOcrPageRasterizer(),
        backend: () => backend,
      ).recognise(image.path);

      expect(passes.single.pages.single.width, 300000);
      expect(passes.single.pages.single.height, 400000);
    });

    test(
      'an image whose header cannot be read fails as an OcrFailure',
      () async {
        // A PNG's signature, and then nothing: the size is not in the file.
        final File image = File(p.join(work.path, 'truncated.png'))
          ..writeAsBytesSync(<int>[
            0x89,
            0x50,
            0x4E,
            0x47,
            0x0D,
            0x0A,
            0x1A,
            0x0A,
          ]);

        await expectLater(
          sourceWith(
            rasterizer: FailingOcrPageRasterizer(),
            backend: FakeTextRecognizerBackend.new,
          ).recognise(image.path),
          throwsA(isA<OcrFailure>()),
        );
      },
    );
  });
}

/// A PDF of the shape the intake already writes for its tests, with invented
/// text on it. The fakes never open it: what the file is for is the
/// identification at the front of `recognise`, and the hash the read-only test
/// takes.
File _pdfIn(Directory work) =>
    File(p.join(work.path, 'scan.pdf'))
      ..writeAsBytesSync(syntheticPdf(text: 'Gesamtbetrag 1.234,50'));

/// A PNG of [width] by [height] pixels: a real signature and a real `IHDR`,
/// and no image data at all, because nothing here decodes one.
File _pngIn(Directory work, {required int width, required int height}) {
  final Uint8List bytes = Uint8List(24);
  bytes.setAll(0, <int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
  bytes.setAll(12, <int>[0x49, 0x48, 0x44, 0x52]); // IHDR
  bytes[16] = (width >> 24) & 0xFF;
  bytes[17] = (width >> 16) & 0xFF;
  bytes[18] = (width >> 8) & 0xFF;
  bytes[19] = width & 0xFF;
  bytes[20] = (height >> 24) & 0xFF;
  bytes[21] = (height >> 16) & 0xFF;
  bytes[22] = (height >> 8) & 0xFF;
  bytes[23] = height & 0xFF;
  return File(p.join(work.path, 'photo.png'))..writeAsBytesSync(bytes);
}

/// A JPEG of [width] by [height] pixels: start of image, one application
/// segment to be skipped, and the frame header that carries the size.
File _jpegIn(Directory work, {required int width, required int height}) {
  final List<int> bytes = <int>[
    0xFF, 0xD8, // start of image
    0xFF, 0xE0, 0x00, 0x10, // an application segment, sixteen bytes long
    ...List<int>.filled(14, 0x00), // its payload
    0xFF, 0xC0, 0x00, 0x11, 0x08, // frame header, baseline
    (height >> 8) & 0xFF, height & 0xFF, //
    (width >> 8) & 0xFF, width & 0xFF,
    0x03, 0x01, 0x11, 0x00, 0x02, 0x11, 0x01, 0x03, 0x11, 0x01,
  ];
  return File(p.join(work.path, 'photo.jpg'))..writeAsBytesSync(bytes);
}
