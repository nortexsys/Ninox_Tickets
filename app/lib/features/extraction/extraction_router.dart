/// The route selector of the extraction pipeline (design §2, T2.1).
///
/// Requirement served: `extraction-pipeline` · `invoice-route-priority` (FR-EXT-002) —
/// the methods are tried in a fixed order and the first that succeeds is recorded — and
/// `positional-pdf-text-extraction`'s fall-through, whose signal is
/// [TextPage.hasTextLayer] and whose decision is this file's and not the adapter's.
///
/// **What it does.** An intake document — the PDF or the image `DocumentIntake` stored
/// (FR-CAP-005) — becomes the passes of the route that reads it, each carrying the label
/// Core records in `recognitionEngine`:
///
/// | Input | Route | Passes |
/// | --- | --- | --- |
/// | PDF, every page has a text layer | `pdf-text` | one pass `text`, from `PdfTextSource` |
/// | PDF, no page has a text layer | `pdf-ocr` | the passes `OcrTextSource` returns |
/// | PDF, some pages with and some without | `pdf-mixed` | per page: the text layer where it exists, this pass's own reading otherwise (§3, open point 2) |
/// | Image or photo | `photo-ocr` | the passes `OcrTextSource` returns |
///
/// **What it does not do.** It decides no value: it segments no word, binds no label,
/// parses no amount and merges no pass into another. Which reading of a field wins is
/// Core's consensus, and `pipeline-order-is-fixed` is what keeps it there (plan §7.2).
///
/// **The label.** Every pass of one extraction carries the same label, and the label is
/// `<route>/<engine+version>` — `pdf-text/pdfrx 2.6.5`, `photo-ocr/
/// google_mlkit_text_recognition 0.17.1` (design §2). Core records that string verbatim,
/// so the route and the engine that produced the values both survive into
/// `CanonicalDocument.recognitionEngine`. The engine names are the adapters' own
/// `toolName` constants, kept in step with `pubspec.yaml`, and not strings written here.
///
/// **Read-only (ADR-015).** Nothing here opens the document for writing: the stored path
/// goes to the ports as it is, and a caller may hash the file before and after a call and
/// find the same bytes (`received-files-are-attached-byte-for-byte`).
///
/// **A failure is one failure.** Both ports' failures become an [ExtractionFailure]
/// (design §2), and a document the intake could not have stored — a media type outside
/// `IntakeResult.supportedMediaTypes` — is an [ArgumentError]: that is this code being
/// called with the wrong document, not a document that could not be read.
library;

import 'package:paperdrop/adapters/ocr/mlkit_ocr_text_source.dart';
import 'package:paperdrop/adapters/ocr/ocr_text_source.dart';
import 'package:paperdrop/adapters/pdf_text/pdf_text_source.dart';
import 'package:paperdrop/adapters/pdf_text/pdfrx_text_source.dart';
import 'package:paperdrop/features/extraction/extraction_failure.dart';
import 'package:paperdrop/intake/intake_result.dart';
import 'package:paperdrop_core/paperdrop_core.dart';

/// The four routes of design §2, in the order FR-EXT-002 tries them.
///
/// The XML step of that requirement is R1 and is absent by cut, not by omission: a
/// ZUGFeRD or Factur-X PDF has a text layer and takes `pdf-text` (plan §4, design §2).
enum ExtractionRoute {
  /// The PDF's own text layer, read with word positions.
  pdfText('pdf-text'),

  /// The PDF's pages rendered and recognised, because no page has a text layer.
  pdfOcr('pdf-ocr'),

  /// The PDF read page by page: the text layer where a page has one, recognition
  /// otherwise (design §3, open point 2).
  pdfMixed('pdf-mixed'),

  /// An image, or the PDF the platform's scanner produced, read by recognition.
  photoOcr('photo-ocr');

  /// Creates a route with its [route] name.
  const ExtractionRoute(this.route);

  /// The route as it is recorded: `pdf-text`, `pdf-ocr`, `pdf-mixed`, `photo-ocr`.
  final String route;

  @override
  String toString() => route;
}

/// The pass id of the text-layer route's single pass.
///
/// Design §2 names it: *one pass `text`*. It is the reader identity Core's consensus
/// compares against, and one pass is legal — its values are `Single`, which confidence
/// caps below green (`consensus.dart`).
const String textLayerPassId = 'text';

/// What the route selector produced: the route, the label and the passes.
///
/// The passes are Core's own [ExtractionPass], all carrying [recognitionEngine] as their
/// route label, so the caller hands them to `extractDocument` unchanged and the label
/// reaches `CanonicalDocument.recognitionEngine` without being re-derived.
final class RoutedExtraction {
  /// Builds a routing result from its [route], its [recognitionEngine] label and its
  /// [passes], the list copied so a caller cannot edit it behind the model's back.
  RoutedExtraction({
    required this.route,
    required this.recognitionEngine,
    required List<ExtractionPass> passes,
  }) : passes = List<ExtractionPass>.unmodifiable(passes);

  /// Which route was taken.
  final ExtractionRoute route;

  /// The label every pass of this extraction carries, `<route>/<engine+version>`.
  final String recognitionEngine;

  /// The passes, in the order the route produced them.
  final List<ExtractionPass> passes;

  /// A value-only string form naming the label and the pass count.
  @override
  String toString() =>
      'RoutedExtraction($recognitionEngine, ${passes.length} passes)';

  /// Value equality on the route, the label and the passes.
  @override
  bool operator ==(Object other) {
    if (other is! RoutedExtraction ||
        other.route != route ||
        other.recognitionEngine != recognitionEngine ||
        other.passes.length != passes.length) {
      return false;
    }
    for (var i = 0; i < passes.length; i++) {
      if (other.passes[i] != passes[i]) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode =>
      Object.hash(route, recognitionEngine, Object.hashAll(passes));
}

/// Picks the route an intake document is read by, and returns the passes it produced.
///
/// Both ports are injected and faked in tests: no test of this class opens a PDF or a
/// camera image, and no test needs a device (design §1).
class ExtractionRouter {
  /// Creates the selector over the two ports.
  ///
  /// [pdfEngine] and [ocrEngine] are the `<engine+version>` halves of the label, and they
  /// default to the adapters' own `toolName` constants — the versions `pubspec.yaml`
  /// resolves — so the recorded engine cannot drift from the engine in the build. A test
  /// passes its own to keep the assertion readable.
  ExtractionRouter({
    required this.pdfText,
    required this.ocr,
    String? pdfEngine,
    String? ocrEngine,
  }) : _pdfEngine = pdfEngine ?? PdfrxTextSource.toolName,
       _ocrEngine = ocrEngine ?? MlKitOcrTextSource.toolName;

  /// The invoice route's text-layer port.
  final PdfTextSource pdfText;

  /// The photo route's recognition port, which reads a scanned PDF as well.
  final OcrTextSource ocr;

  final String _pdfEngine;
  final String _ocrEngine;

  /// The route [document] is read by, and the passes it produced.
  ///
  /// Throws an [ExtractionFailure] when the text layer of a PDF cannot be read, when the
  /// pages cannot be recognised, or when a route that needs recognition produced no pass
  /// at all. Throws an [ArgumentError] — not a failure of a document — when [document]
  /// carries a media type the intake never stores: the three of
  /// `IntakeResult.supportedMediaTypes` are the only ones it can produce.
  Future<RoutedExtraction> route(IntakeResult document) async {
    switch (document.mediaType) {
      case 'application/pdf':
        return _pdfRoute(document);
      case 'image/jpeg':
      case 'image/png':
        return _photoRoute(document);
      default:
        throw ArgumentError.value(
          document.mediaType,
          'document.mediaType',
          'the intake stores application/pdf, image/jpeg and image/png, and no '
              'other (design §3); this is a document it cannot have produced',
        );
    }
  }

  /// A PDF: the text layer first, and recognition only where the text layer is not there.
  ///
  /// The text layer is read once and, when every page has one, that reading *is* the
  /// route: no OCR pass runs on a PDF whose text was read, which is FR-EXT-002's fixed
  /// order and not an optimisation. Asking whether a page has a text layer is only
  /// possible by reading it — a page that holds no word is a page with no word, not a
  /// failure — so a scanned PDF is read here, finds nothing, and falls through.
  Future<RoutedExtraction> _pdfRoute(IntakeResult document) async {
    final List<TextPage> pages = await _readTextLayer(document.storedPath);

    if (pages.isNotEmpty && pages.every((TextPage page) => page.hasTextLayer)) {
      return _textRoute(pages);
    }
    if (!pages.any((TextPage page) => page.hasTextLayer)) {
      return _ocrRoute(document, ExtractionRoute.pdfOcr);
    }
    return _mixedRoute(document, pages);
  }

  /// A PDF whose pages all carry a text layer: the text route, one pass.
  RoutedExtraction _textRoute(List<TextPage> pages) {
    final String label = _label(ExtractionRoute.pdfText);
    return RoutedExtraction(
      route: ExtractionRoute.pdfText,
      recognitionEngine: label,
      passes: <ExtractionPass>[
        ExtractionPass(
          passId: textLayerPassId,
          routeLabel: label,
          pages: pages,
        ),
      ],
    );
  }

  /// A PDF no page of which carries a text layer: the recognition route.
  Future<RoutedExtraction> _ocrRoute(
    IntakeResult document,
    ExtractionRoute route,
  ) async {
    final List<ExtractionPass> passes = await _recognisedPasses(
      document,
      route,
    );
    return RoutedExtraction(
      route: route,
      recognitionEngine: _label(route),
      passes: passes,
    );
  }

  /// An image, or the PDF the scanner produced: the recognition route, read as it is.
  ///
  /// Nothing distinguishes a photo from a scanned PDF here beyond the media type the
  /// intake resolved: the port decides how a file is read, and it reads an image as it is
  /// (one pass, `p1-native`) because this application decodes no image of its own.
  Future<RoutedExtraction> _photoRoute(IntakeResult document) =>
      _ocrRoute(document, ExtractionRoute.photoOcr);

  /// A PDF with pages of both kinds: design §2's `pdf-mixed`, applied literally.
  ///
  /// **A proposal, and treated as one.** Design §3's open point 2 records that no mixed
  /// document exists in the corpus yet, so this rule is the design's proposal pending the
  /// product owner's confirmation: the pages a page has a text layer for are read from
  /// the text layer, the pages it has none for are this pass's own recognition of them,
  /// and the text pages repeat in every pass so that the passes of one extraction count
  /// the same pages and consensus compares like with like.
  ///
  /// Recognition runs over the whole document, because `OcrTextSource` is asked about a
  /// file and not about a page: the readings of the pages the text layer already answered
  /// are dropped here, and dropped readings are never merged into the text ones.
  Future<RoutedExtraction> _mixedRoute(
    IntakeResult document,
    List<TextPage> textPages,
  ) async {
    final String label = _label(ExtractionRoute.pdfMixed);
    final List<OcrPass> recognised = await _requiredPasses(document.storedPath);
    return RoutedExtraction(
      route: ExtractionRoute.pdfMixed,
      recognitionEngine: label,
      passes: <ExtractionPass>[
        for (final OcrPass pass in recognised)
          ExtractionPass(
            passId: pass.passId,
            routeLabel: label,
            pages: _mixedPages(textPages, pass),
          ),
      ],
    );
  }

  /// The passes of a recognition route, one [ExtractionPass] per pass the port read.
  ///
  /// The pass ids and the pages are the port's own, unchanged: a pass that was dropped is
  /// a pass that is not in the list (the port reports that itself), and one pass alone is
  /// legal.
  Future<List<ExtractionPass>> _recognisedPasses(
    IntakeResult document,
    ExtractionRoute route,
  ) async {
    final String label = _label(route);
    final List<OcrPass> recognised = await _requiredPasses(document.storedPath);
    return <ExtractionPass>[
      for (final OcrPass pass in recognised)
        ExtractionPass(
          passId: pass.passId,
          routeLabel: label,
          pages: pass.pages,
        ),
    ];
  }

  /// The passes of a file, or the failure of a route that needs recognition and got none.
  ///
  /// A pass may be dropped and the list may therefore be short — that is the port's own
  /// report and design §3 allows it. No pass at all is not a route: `MlKitOcrTextSource`
  /// raises an `OcrFailure` for it, and a port that answered with an empty list instead
  /// must not become a document that records no engine, so it is the same failure here.
  Future<List<OcrPass>> _requiredPasses(String path) async {
    final List<OcrPass> recognised = await _recognise(path);
    if (recognised.isEmpty) {
      throw const ExtractionFailure(
        ExtractionFailureCode.recognitionUnreadable,
      );
    }
    return recognised;
  }

  /// One mixed pass's pages: the text layer where there is one, this pass's reading where
  /// there is not — one page per page of the document, in the document's own order.
  ///
  /// A pass that does not carry a page it was asked for read nothing on that page, which
  /// is an answer and not a failure (`ocr_text_source.dart`): the page keeps the
  /// document's own geometry from the text-layer read, holds no word, and is never filled
  /// from another pass — that would be a guess, and the value rule of this pipeline is
  /// Core's.
  List<TextPage> _mixedPages(List<TextPage> textPages, OcrPass pass) {
    final Map<int, TextPage> recognised = <int, TextPage>{
      for (final TextPage page in pass.pages) page.index: page,
    };
    return <TextPage>[
      for (final TextPage page in textPages)
        if (page.hasTextLayer)
          page
        else
          recognised[page.index] ??
              TextPage(
                page.index,
                page.width,
                page.height,
                const <PositionedWord>[],
              ),
    ];
  }

  /// The PDF's text layer, or the one failure of the text route (ADR-011's port).
  ///
  /// A `PdfTextReadFailure` is the document the layer could not be read from — opened and
  /// read, but not a PDF this engine could open, or damaged. Anything else the port
  /// throws is a defect of this code or of that adapter and travels as it is.
  Future<List<TextPage>> _readTextLayer(String path) async {
    try {
      return await pdfText.read(path);
    } on PdfTextReadFailure catch (failure) {
      throw ExtractionFailure(
        ExtractionFailureCode.textLayerUnreadable,
        cause: failure,
      );
    }
  }

  /// The recognition passes of the file, or the one failure of a recognition route
  /// (ADR-010's port, behind its own proposed decision).
  Future<List<OcrPass>> _recognise(String path) async {
    try {
      return await ocr.recognise(path);
    } on OcrFailure catch (failure) {
      throw ExtractionFailure(
        ExtractionFailureCode.recognitionUnreadable,
        cause: failure,
      );
    }
  }

  /// The label every pass of [route] carries: `<route>/<engine+version>`.
  String _label(ExtractionRoute route) => '${route.route}/${_engineFor(route)}';

  /// The engine that read a route's pages.
  ///
  /// Two of the four routes belong to one engine each, and the recorded name is the
  /// adapter's own `toolName`. `pdf-mixed` is the exception and it is reported as one: it
  /// is the route both engines read, and design §2 writes `<engine+version>` in the
  /// singular, so a mixed document names both engines, joined by ` + `. Which name the
  /// metadata of a mixed document should carry is not decided in `openspec/`; it travels
  /// with design §3's open point 2 to the product owner.
  String _engineFor(ExtractionRoute route) => switch (route) {
    ExtractionRoute.pdfText => _pdfEngine,
    ExtractionRoute.pdfOcr => _ocrEngine,
    ExtractionRoute.photoOcr => _ocrEngine,
    ExtractionRoute.pdfMixed => '$_pdfEngine + $_ocrEngine',
  };
}
