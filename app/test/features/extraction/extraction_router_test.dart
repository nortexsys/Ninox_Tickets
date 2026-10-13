/// The route selector: which of design §2's four routes a document takes, what each route
/// produces, and what a failure of either port becomes (T2.1, tasks 2.1 and 2.2).
///
/// Requirement served: `extraction-pipeline` · `invoice-route-priority` (FR-EXT-002) — a
/// PDF with a text layer takes the text route and no OCR pass runs on it, a PDF with none
/// falls through to recognition, and the route taken is recorded — and
/// `extraction-pipeline` · `consensus-by-majority` (FR-EXT-006) only in that all passes of
/// one extraction reach Core under one label, which is what Core compares readings by.
///
/// **Where it stops.** The ports are fakes, so nothing here proves what PDFium or ML Kit
/// read: that is the device run's (design §4, dispatch C), and the adapters' own
/// conversions are tested beside them.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:paperdrop/adapters/ocr/mlkit_ocr_text_source.dart';
import 'package:paperdrop/adapters/ocr/ocr_text_source.dart';
import 'package:paperdrop/adapters/ocr/render_passes.dart';
import 'package:paperdrop/adapters/pdf_text/pdf_text_source.dart';
import 'package:paperdrop/adapters/pdf_text/pdfrx_text_source.dart';
import 'package:paperdrop/features/extraction/extraction_failure.dart';
import 'package:paperdrop/features/extraction/extraction_router.dart';
import 'package:paperdrop/intake/intake_result.dart';
import 'package:paperdrop_core/paperdrop_core.dart';
import 'package:path/path.dart' as p;

import 'extraction_fixtures.dart';

void main() {
  /// The engine names the adapters resolve, which is what a label is built from.
  const String pdfEngine = PdfrxTextSource.toolName;
  const String ocrEngine = MlKitOcrTextSource.toolName;

  /// The router over the two fakes, and the fakes it was built over.
  ({ExtractionRouter router, FakePdfTextSource text, FakeOcrTextSource ocr})
  routerOver({
    List<TextPage> textPages = const <TextPage>[],
    PdfTextReadFailure? textFailure,
    List<OcrPass> passes = const <OcrPass>[],
    OcrFailure? ocrFailure,
  }) {
    final FakePdfTextSource text = FakePdfTextSource(
      pages: textPages,
      failure: textFailure,
    );
    final FakeOcrTextSource ocr = FakeOcrTextSource(
      passes: passes,
      failure: ocrFailure,
    );
    return (
      router: ExtractionRouter(pdfText: text, ocr: ocr),
      text: text,
      ocr: ocr,
    );
  }

  test(
    '[extraction-pipeline/invoice-route-priority] a PDF whose pages all '
    'carry a text layer takes the text route, and no OCR pass runs on it',
    () async {
      final IntakeResult document = anIntakeResult();
      final List<TextPage> pages = <TextPage>[invoicePage(0), invoicePage(1)];
      final ({
        ExtractionRouter router,
        FakePdfTextSource text,
        FakeOcrTextSource ocr,
      })
      fakes = routerOver(textPages: pages);

      final RoutedExtraction routed = await fakes.router.route(document);

      expect(routed.route, ExtractionRoute.pdfText);
      expect(routed.recognitionEngine, 'pdf-text/$pdfEngine');
      expect(
        routed.passes,
        hasLength(1),
        reason: 'one pass `text` (design §2)',
      );
      expect(routed.passes.single.passId, textLayerPassId);
      expect(routed.passes.single.routeLabel, routed.recognitionEngine);
      expect(routed.passes.single.pages, pages);
      expect(fakes.text.readPaths, <String>[
        document.storedPath,
      ], reason: 'the stored copy is read where it is (ADR-015)');
      expect(
        fakes.ocr.recognisePaths,
        isEmpty,
        reason: 'the route stops at the first method that succeeds',
      );
    },
  );

  test('[extraction-pipeline/invoice-route-priority] a PDF no page of which '
      'has a text layer falls through to recognition', () async {
    final IntakeResult document = anIntakeResult();
    final List<OcrPass> passes = fourPasses(<TextPage>[
      recognisedPage(0),
      recognisedPage(1),
    ]);
    final ({
      ExtractionRouter router,
      FakePdfTextSource text,
      FakeOcrTextSource ocr,
    })
    fakes = routerOver(
      textPages: <TextPage>[blankPage(0), blankPage(1)],
      passes: passes,
    );

    final RoutedExtraction routed = await fakes.router.route(document);

    expect(routed.route, ExtractionRoute.pdfOcr);
    expect(routed.recognitionEngine, 'pdf-ocr/$ocrEngine');
    expect(
      routed.passes.map((ExtractionPass pass) => pass.passId),
      ocrRenderPasses.map((OcrRenderPass pass) => pass.passId),
      reason: 'the port\'s own passes, ids and order unchanged',
    );
    expect(routed.passes.first.pages, passes.first.pages);
    expect(
      routed.passes.every(
        (ExtractionPass pass) => pass.routeLabel == routed.recognitionEngine,
      ),
      isTrue,
      reason: 'Core refuses a list of passes that do not share one label',
    );
    expect(fakes.text.readPaths, <String>[
      document.storedPath,
    ], reason: 'a page has to be read to know it has no text layer');
    expect(fakes.ocr.recognisePaths, <String>[document.storedPath]);
  });

  test('a PDF with pages of both kinds takes the mixed route, and every pass '
      'counts the document\'s own pages', () async {
    final IntakeResult document = anIntakeResult();
    final TextPage withText = invoicePage(0);
    final TextPage withoutText = blankPage(1);
    final List<OcrPass> passes = fourPasses(<TextPage>[
      recognisedPage(0),
      recognisedPage(1),
    ]);
    final ({
      ExtractionRouter router,
      FakePdfTextSource text,
      FakeOcrTextSource ocr,
    })
    fakes = routerOver(
      textPages: <TextPage>[withText, withoutText],
      passes: passes,
    );

    final RoutedExtraction routed = await fakes.router.route(document);

    expect(routed.route, ExtractionRoute.pdfMixed);
    expect(
      routed.recognitionEngine,
      'pdf-mixed/$pdfEngine + $ocrEngine',
      reason: 'design §2 writes one engine; a mixed document is read by both',
    );
    expect(routed.passes, hasLength(4));
    for (var i = 0; i < routed.passes.length; i++) {
      final ExtractionPass pass = routed.passes[i];
      expect(pass.passId, ocrRenderPasses[i].passId);
      expect(pass.routeLabel, routed.recognitionEngine);
      expect(pass.pages.map((TextPage page) => page.index), <int>[
        0,
        1,
      ], reason: 'the pages agree across passes, so consensus compares pages');
      expect(
        pass.pages.first,
        withText,
        reason:
            'the page the text layer answered is never replaced by a '
            'recognition reading of it',
      );
      expect(
        pass.pages.last,
        passes[i].pages.last,
        reason: 'the page with no text layer takes this pass\'s own reading',
      );
    }
    expect(fakes.ocr.recognisePaths, <String>[document.storedPath]);
  });

  test(
    'a recognition pass that does not carry a page leaves it without words',
    () async {
      final IntakeResult document = anIntakeResult();
      final TextPage withoutText = blankPage(1, width: 595280, height: 841890);
      final ({
        ExtractionRouter router,
        FakePdfTextSource text,
        FakeOcrTextSource ocr,
      })
      fakes = routerOver(
        textPages: <TextPage>[invoicePage(0), withoutText],
        // One pass came back short: it read page 0 and nothing of page 1.
        passes: <OcrPass>[
          OcrPass(ocrRenderPasses.first.passId, <TextPage>[recognisedPage(0)]),
        ],
      );

      final RoutedExtraction routed = await fakes.router.route(document);

      final ExtractionPass pass = routed.passes.single;
      expect(pass.pages, hasLength(2));
      final TextPage missing = pass.pages.last;
      expect(missing.index, 1);
      expect(missing.hasTextLayer, isFalse, reason: 'no word was read on it');
      expect(
        <int>[missing.width, missing.height],
        <int>[withoutText.width, withoutText.height],
        reason: 'the page keeps the document\'s own geometry',
      );
    },
  );

  test(
    'an image is recognised as it is, and its text layer is never opened',
    () async {
      for (final String mediaType in <String>['image/jpeg', 'image/png']) {
        final IntakeResult document = anIntakeResult(mediaType: mediaType);
        final List<OcrPass> passes = <OcrPass>[
          OcrPass(MlKitOcrTextSource.imagePassId, <TextPage>[
            recognisedPage(0),
          ]),
        ];
        final ({
          ExtractionRouter router,
          FakePdfTextSource text,
          FakeOcrTextSource ocr,
        })
        fakes = routerOver(passes: passes);

        final RoutedExtraction routed = await fakes.router.route(document);

        expect(routed.route, ExtractionRoute.photoOcr, reason: mediaType);
        expect(
          routed.recognitionEngine,
          'photo-ocr/$ocrEngine',
          reason: mediaType,
        );
        expect(routed.passes.single.passId, MlKitOcrTextSource.imagePassId);
        expect(routed.passes.single.pages, passes.single.pages);
        expect(fakes.ocr.recognisePaths, <String>[document.storedPath]);
        expect(
          fakes.text.readPaths,
          isEmpty,
          reason: 'an image has no text layer to read ($mediaType)',
        );
      }
    },
  );

  test('a text layer that cannot be read is one failure, and the route stops there', () async {
    final IntakeResult document = anIntakeResult();
    final ({
      ExtractionRouter router,
      FakePdfTextSource text,
      FakeOcrTextSource ocr,
    })
    fakes = routerOver(
      textFailure: PdfTextReadFailure(
        'the document could not be opened',
        StateError('nothing of the document'),
      ),
      passes: fourPasses(<TextPage>[recognisedPage(0)]),
    );

    await expectLater(
      fakes.router.route(document),
      throwsA(
        isA<ExtractionFailure>()
            .having(
              (ExtractionFailure failure) => failure.code,
              'code',
              ExtractionFailureCode.textLayerUnreadable,
            )
            .having(
              (ExtractionFailure failure) => failure.cause,
              'cause',
              isA<PdfTextReadFailure>(),
            ),
      ),
    );
    expect(
      fakes.ocr.recognisePaths,
      isEmpty,
      reason: 'a document that could not be read is not read another way',
    );
  });

  test(
    'recognition that fails is the same one failure, on both its routes',
    () async {
      for (final String mediaType in <String>[
        'application/pdf',
        'image/jpeg',
      ]) {
        final IntakeResult document = anIntakeResult(mediaType: mediaType);
        final ({
          ExtractionRouter router,
          FakePdfTextSource text,
          FakeOcrTextSource ocr,
        })
        fakes = routerOver(
          textPages: mediaType == 'application/pdf'
              ? <TextPage>[blankPage(0)]
              : const <TextPage>[],
          ocrFailure: const OcrFailure('no pass could read the document'),
        );

        await expectLater(
          fakes.router.route(document),
          throwsA(
            isA<ExtractionFailure>().having(
              (ExtractionFailure failure) => failure.code,
              'code',
              ExtractionFailureCode.recognitionUnreadable,
            ),
          ),
          reason: mediaType,
        );
      }
    },
  );

  test(
    'recognition that answers with no pass at all is that same failure',
    () async {
      final ({
        ExtractionRouter router,
        FakePdfTextSource text,
        FakeOcrTextSource ocr,
      })
      fakes = routerOver(textPages: <TextPage>[blankPage(0)]);

      await expectLater(
        fakes.router.route(anIntakeResult()),
        throwsA(
          isA<ExtractionFailure>()
              .having(
                (ExtractionFailure failure) => failure.code,
                'code',
                ExtractionFailureCode.recognitionUnreadable,
              )
              .having(
                (ExtractionFailure failure) => failure.cause,
                'cause',
                isNull,
              ),
        ),
        reason: 'no pass and no exception: nothing to keep as a cause',
      );
    },
  );

  test('the failure carries no document content and no path', () {
    final ExtractionFailure failure = ExtractionFailure(
      ExtractionFailureCode.textLayerUnreadable,
      cause: PdfTextReadFailure(
        'the document could not be opened',
        FileSystemException(
          'cannot open',
          p.join('originals', 'a-document', 'original.pdf'),
        ),
      ),
    );

    expect(failure.toString(), 'ExtractionFailure(text_layer_unreadable)');
    expect(failure.code.code, 'text_layer_unreadable');
  });

  test(
    'a media type the intake never stores is a defect, not a document failure',
    () async {
      final ({
        ExtractionRouter router,
        FakePdfTextSource text,
        FakeOcrTextSource ocr,
      })
      fakes = routerOver();

      await expectLater(
        fakes.router.route(anIntakeResult(mediaType: 'image/tiff')),
        throwsA(isA<ArgumentError>()),
      );
      expect(fakes.text.readPaths, isEmpty);
      expect(fakes.ocr.recognisePaths, isEmpty);
    },
  );
}
