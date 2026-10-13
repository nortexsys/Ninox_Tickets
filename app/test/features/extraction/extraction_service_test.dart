/// The extraction step against the real store: the state machine, the country the
/// document's own evidence picks, the stored values, the reason a failure leaves and the
/// document that is never touched (T2.1 tasks 2.2–2.3; `implement-country-detection` task
/// 2.2).
///
/// Requirement served: `document-history` · `document-states` (FR-HIS-002) — an entry
/// holds exactly one of the eight states and every change goes through
/// `document_machine.dart`; `countries-languages` ·
/// `deterministic-country-detection` (FR-CTR-001) — the row that governs a document is the
/// document's own evidence and never a caller's argument; `countries-languages` ·
/// `universal-core` (FR-CTR-002) — a document no row governs is read anyway, `needsReview`,
/// with the reason in its engine metadata and never as a failure (design §4);
/// `extraction-pipeline` · `invoice-route-priority` (FR-EXT-002) — the route taken is
/// recorded in the recognition engine the values carry; `extraction-pipeline` ·
/// `multi-page-consolidation` (FR-EXT-012) — the pages of one document become one model;
/// `extraction-pipeline` · `consensus-by-majority` (FR-EXT-006) as design §3 applies it to
/// the country — the passes of one extraction must agree about it; and `capture-intake` ·
/// `received-files-are-attached-byte-for-byte` (FR-CAP-005, ADR-015) — the stored copy is
/// the same bytes before and after it was read.
///
/// **A real store, a real file.** `FileHistoryStore` writes into a directory this test
/// owns, so the entries asserted here are the ones a device would read back, and the
/// source file is hashed before and after the extraction to show that reading a document
/// changes nothing about it. The two ports are fakes: what PDFium and ML Kit read is
/// measured on a device (design §4, dispatch C).
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
import 'package:paperdrop/features/extraction/extraction_service.dart';
import 'package:paperdrop/history/history_entry.dart';
import 'package:paperdrop/history/history_store.dart';
import 'package:paperdrop/intake/intake_result.dart';
import 'package:paperdrop_core/paperdrop_core.dart';

import '../../history/history_fixtures.dart';
import 'extraction_fixtures.dart';

/// One route's case: the document, what the two ports answer and the label the stored
/// values must carry.
final class _RouteCase {
  const _RouteCase({
    required this.mediaType,
    required this.bytes,
    required this.textPages,
    required this.passes,
    required this.engine,
  });

  /// The media type the intake resolved.
  final String mediaType;

  /// The bytes of the stored copy.
  final List<int> bytes;

  /// What the text-layer port answers.
  final List<TextPage> textPages;

  /// What the recognition port answers.
  final List<OcrPass> passes;

  /// The label every pass carries and the values must record.
  final String engine;
}

/// One way a document cannot be read, and the code it must leave behind.
final class _FailureCase {
  const _FailureCase({
    required this.name,
    required this.mediaType,
    required this.textPages,
    this.textFailure,
    this.ocrFailure,
    required this.code,
  });

  /// What this case is about, for the message of a failing expectation.
  final String name;

  /// The media type the intake resolved.
  final String mediaType;

  /// What the text-layer port answers before it fails.
  final List<TextPage> textPages;

  /// What the text-layer port throws, when it is this port that fails.
  final PdfTextReadFailure? textFailure;

  /// What the recognition port throws, when it is this port that fails.
  final OcrFailure? ocrFailure;

  /// The code the failure must carry and the entry must store.
  final ExtractionFailureCode code;
}

void main() {
  const String pdfEngine = PdfrxTextSource.toolName;
  const String ocrEngine = MlKitOcrTextSource.toolName;
  final CurrencyCode eur = CurrencyCode.parse('EUR')!;

  late Directory root;
  late FileHistoryStore files;
  late RecordingHistoryStore store;
  late List<int> sourceBytes;

  setUp(() {
    root = Directory.systemTemp.createTempSync('paperdrop-extraction-test');
    files = FileHistoryStore(root);
    store = RecordingHistoryStore(files);
    sourceBytes = syntheticScanBytes();
  });

  tearDown(() {
    if (root.existsSync()) {
      root.deleteSync(recursive: true);
    }
  });

  /// The step over the two fakes, and the fakes it was built over.
  ({ExtractionService service, FakePdfTextSource text, FakeOcrTextSource ocr})
  serviceOver({
    List<TextPage> textPages = const <TextPage>[],
    PdfTextReadFailure? textFailure,
    List<OcrPass> passes = const <OcrPass>[],
    OcrFailure? ocrFailure,
    Future<void> Function(String path)? onRead,
  }) {
    final FakePdfTextSource text = FakePdfTextSource(
      pages: textPages,
      failure: textFailure,
      onRead: onRead,
    );
    final FakeOcrTextSource ocr = FakeOcrTextSource(
      passes: passes,
      failure: ocrFailure,
    );
    return (
      service: ExtractionService(
        store: store,
        router: ExtractionRouter(pdfText: text, ocr: ocr),
        // No country row is handed over: the document's own evidence picks it
        // (`deterministic-country-detection`, design §1), and the launch table is
        // the one it is read in.
      ),
      text: text,
      ocr: ocr,
    );
  }

  /// A stored document as the capture step leaves it: the file, the intake result and a
  /// `pending` entry carrying the stored copy's own hash.
  Future<IntakeResult> storedDocument({
    String mediaType = 'application/pdf',
    int seed = 5,
    List<int>? bytes,
  }) async {
    final IntakeResult document = await storeDocument(
      root,
      bytes ?? sourceBytes,
      docId: aDocId(seed),
      mediaType: mediaType,
    );
    await files.create(pendingEntry(document));
    return document;
  }

  test(
    '[document-history/document-states] a document that is read moves '
    'pending -> extracting -> reviewing, and its values are stored',
    () async {
      final IntakeResult document = await storedDocument();
      final List<DocumentState> statesWhileReading = <DocumentState>[];
      final ({
        ExtractionService service,
        FakePdfTextSource text,
        FakeOcrTextSource ocr,
      })
      fakes = serviceOver(
        // The document's own evidence: a Spanish issuer's CIF, which is what picks the
        // ES row now that the service is not told one (design §1).
        textPages: <TextPage>[spanishInvoicePage(0)],
        onRead: (String path) async {
          statesWhileReading.add((await files.get(document.docId)).state);
        },
      );

      final ExtractionOutcome outcome = await fakes.service.extract(document);

      expect(outcome, isA<ExtractionCompleted>());
      final ExtractionCompleted completed = outcome as ExtractionCompleted;
      expect(
        statesWhileReading,
        <DocumentState>[DocumentState.extracting],
        reason:
            'the stored state says what the document is doing while its pages '
            'are read',
      );
      expect(
        store.writtenStates,
        <DocumentState>[DocumentState.extracting, DocumentState.reviewing],
        reason:
            'the state is written before the port runs, and every change goes '
            'through the machine',
      );
      expect(completed.entry.state, DocumentState.reviewing);
      expect(
        completed.entry.revision,
        3,
        reason: 'created 1, extracting 2, reviewing 3',
      );
      expect(
        completed.entry.confidence,
        isNull,
        reason:
            'confidence is what validation produces, and validation is not '
            'this change\'s step',
      );
      expect(completed.entry.failureReason, isNull);
      expect(
        await files.get(document.docId),
        completed.entry,
        reason: 'the outcome carries the entry as it was written',
      );

      // Core's own reading of this page, and Core's own cap: one pass is a `Single`,
      // which confidence holds below green.
      final CanonicalDocument values = completed.document;
      expect(
        values.grossTotal,
        Present<Money>(
          Money(12100, eur),
          Provenance.read,
          ConfidenceState.amber,
        ),
      );
      expect(
        values.netTotal,
        Present<Money>(
          Money(10000, eur),
          Provenance.read,
          ConfidenceState.amber,
        ),
      );
      expect(values.needsReview, isTrue);
      expect(values.recognitionEngine, 'pdf-text/$pdfEngine');
      expect(
        completed.detection,
        Detected(
          row: CountryTable.es,
          evidence: const <CountryEvidenceKind>[CountryEvidenceKind.taxId],
        ),
        reason: 'the country is the document\'s own evidence, not a setting',
      );
      expect(
        values.taxSlots,
        hasLength(CountryTable.es.slotCount),
        reason:
            'the detected row governs the reading: its rate set is the slot count '
            '(`country-table-contract`), and a document no row governs has no slot '
            'at all',
      );
      expect(values, completed.entry.values);
    },
  );

  test(
    '[capture-intake/received-files-are-attached-byte-for-byte] the stored '
    'document is read and not touched: the same bytes, and the same hash',
    () async {
      final IntakeResult document = await storedDocument();
      final File stored = File(document.storedPath);
      final String before = sha256Of(stored.readAsBytesSync());
      final ({
        ExtractionService service,
        FakePdfTextSource text,
        FakeOcrTextSource ocr,
      })
      fakes = serviceOver(textPages: <TextPage>[invoicePage(0)]);

      final ExtractionOutcome outcome = await fakes.service.extract(document);

      expect(
        sha256Of(stored.readAsBytesSync()),
        before,
        reason: 'reading a document is read-only (ADR-015)',
      );
      expect(
        before,
        document.sha256,
        reason: 'the copy is the intake\'s bytes',
      );
      expect(fakes.text.readPaths, <String>[
        document.storedPath,
      ], reason: 'the port is handed the stored path unchanged');
      expect(
        fakes.ocr.recognisePaths,
        isEmpty,
        reason: 'the route stopped at the text layer',
      );
      expect(
        (outcome as ExtractionCompleted).document.sourceHash,
        document.sha256,
        reason:
            'the hash of the copy the values came from travels in the model',
      );
    },
  );

  test(
    '[extraction-pipeline/invoice-route-priority] every route records itself '
    'in the values it stores',
    () async {
      final List<_RouteCase> cases = <_RouteCase>[
        _RouteCase(
          mediaType: 'application/pdf',
          bytes: sourceBytes,
          textPages: <TextPage>[spanishInvoicePage(0)],
          passes: const <OcrPass>[],
          engine: 'pdf-text/$pdfEngine',
        ),
        _RouteCase(
          mediaType: 'application/pdf',
          bytes: sourceBytes,
          textPages: <TextPage>[blankPage(0)],
          passes: fourPasses(<TextPage>[spanishInvoicePage(0)]),
          engine: 'pdf-ocr/$ocrEngine',
        ),
        _RouteCase(
          mediaType: 'application/pdf',
          bytes: sourceBytes,
          textPages: <TextPage>[spanishInvoicePage(0), blankPage(1)],
          passes: fourPasses(<TextPage>[spanishInvoicePage(0), invoicePage(1)]),
          engine: 'pdf-mixed/$pdfEngine + $ocrEngine',
        ),
        _RouteCase(
          mediaType: 'image/jpeg',
          bytes: textBytes('a synthetic photo'),
          textPages: const <TextPage>[],
          passes: <OcrPass>[
            OcrPass(MlKitOcrTextSource.imagePassId, <TextPage>[
              spanishInvoicePage(0),
            ]),
          ],
          engine: 'photo-ocr/$ocrEngine',
        ),
      ];

      for (var i = 0; i < cases.length; i++) {
        final _RouteCase routeCase = cases[i];
        final IntakeResult document = await storedDocument(
          mediaType: routeCase.mediaType,
          bytes: routeCase.bytes,
          seed: 20 + i,
        );
        final ({
          ExtractionService service,
          FakePdfTextSource text,
          FakeOcrTextSource ocr,
        })
        fakes = serviceOver(
          textPages: routeCase.textPages,
          passes: routeCase.passes,
        );

        final ExtractionOutcome outcome = await fakes.service.extract(document);

        expect(outcome, isA<ExtractionCompleted>(), reason: routeCase.engine);
        final ExtractionCompleted completed = outcome as ExtractionCompleted;
        expect(completed.document.recognitionEngine, routeCase.engine);
        expect(
          (await files.get(document.docId)).values?.recognitionEngine,
          routeCase.engine,
          reason: 'the route survives the store round trip',
        );
      }
    },
  );

  test('[extraction-pipeline/multi-page-consolidation] a two-page document '
      'becomes one model, with the value of each page in it', () async {
    final IntakeResult document = await storedDocument();
    final ({
      ExtractionService service,
      FakePdfTextSource text,
      FakeOcrTextSource ocr,
    })
    // The total is on page 1 and the date on page 2, and the pass carries both pages:
    // what `PdfTextSource` returns for a two-page PDF, handed on as one pass. Page 1
    // prints the issuer's CIF, so the ES row — and with it the day-first date order —
    // is the document's own evidence.
    fakes = serviceOver(
      textPages: <TextPage>[spanishInvoicePage(0), datePage(1, '01/01/2024')],
    );

    final ExtractionOutcome outcome = await fakes.service.extract(document);

    final CanonicalDocument values = (outcome as ExtractionCompleted).document;
    expect(
      values.grossTotal,
      Present<Money>(Money(12100, eur), Provenance.read, ConfidenceState.amber),
      reason: 'the value of the first page',
    );
    expect(
      values.docDate,
      Present<CalendarDate>(
        CalendarDate(2024, 1, 1),
        Provenance.read,
        ConfidenceState.amber,
      ),
      reason: 'the value of the second page, in the same model',
    );
    expect(values, (await files.get(document.docId)).values);
  });

  test('[countries-languages/deterministic-country-detection] the row is the '
      'document\'s own evidence: a Spanish ticket reads under ES and a German '
      'invoice under DE', () async {
    // Two documents, one service, no country handed over: which row reads them is
    // what their own words say (design §1).
    final List<({String name, TextPage page, CountryRow row})> cases =
        <({String name, TextPage page, CountryRow row})>[
          (
            name: 'a Spanish issuer\'s CIF',
            page: spanishInvoicePage(0),
            row: CountryTable.es,
          ),
          (
            name: 'a German issuer\'s VAT identifier',
            page: germanInvoicePage(0),
            row: CountryTable.de,
          ),
        ];

    for (var i = 0; i < cases.length; i++) {
      final ({String name, TextPage page, CountryRow row}) detectionCase =
          cases[i];
      final IntakeResult document = await storedDocument(seed: 75 + i);
      final ({
        ExtractionService service,
        FakePdfTextSource text,
        FakeOcrTextSource ocr,
      })
      fakes = serviceOver(textPages: <TextPage>[detectionCase.page]);

      final ExtractionOutcome outcome = await fakes.service.extract(document);

      expect(outcome, isA<ExtractionCompleted>(), reason: detectionCase.name);
      final ExtractionCompleted completed = outcome as ExtractionCompleted;
      expect(
        completed.detection,
        Detected(
          row: detectionCase.row,
          evidence: const <CountryEvidenceKind>[CountryEvidenceKind.taxId],
        ),
        reason: detectionCase.name,
      );
      expect(
        completed.document.taxSlots,
        hasLength(detectionCase.row.slotCount),
        reason:
            'the detected row governed the reading: the slot count is the '
            'row\'s own rate set (`country-table-contract`) and a document '
            'with no row has no slot (${detectionCase.name})',
      );
      expect(
        completed.document.recognitionEngine,
        'pdf-text/$pdfEngine',
        reason:
            'a detected country needs no reason in the engine metadata '
            '(${detectionCase.name})',
      );
      expect(completed.entry.state, DocumentState.reviewing);
      expect(completed.entry.failureReason, isNull);
    }
  });

  test('[countries-languages/universal-core] an Undetected document is not a '
      'failure: it is read by the universal core and goes to review', () async {
    final IntakeResult document = await storedDocument(seed: 90);
    final ({
      ExtractionService service,
      FakePdfTextSource text,
      FakeOcrTextSource ocr,
    })
    // No tax identifier, no country name and no currency no row declares: the
    // Spanish label words are weak evidence and never decide on their own.
    fakes = serviceOver(
      textPages: <TextPage>[invoicePage(0)],
    );

    final ExtractionOutcome outcome = await fakes.service.extract(document);

    expect(
      outcome,
      isA<ExtractionCompleted>(),
      reason:
          'a country nobody could name is not a document nobody could read '
          '(design §4)',
    );
    final ExtractionCompleted completed = outcome as ExtractionCompleted;
    expect(
      completed.detection,
      const Undetected(reason: UndetectedReason.noEvidence),
    );
    expect(completed.entry.state, DocumentState.reviewing);
    expect(store.writtenStates, <DocumentState>[
      DocumentState.extracting,
      DocumentState.reviewing,
    ], reason: '`failed` is not on an undetected document\'s path');
    expect(
      completed.entry.failureReason,
      isNull,
      reason:
          'a reason in that field would say the route could not read the '
          'document; this one was read',
    );
    expect(
      completed.document.recognitionEngine,
      'pdf-text/$pdfEngine [country=noEvidence]',
      reason: 'the reason is engine metadata, beside the route it came with',
    );

    // What the universal core reads: the amounts and the convention they are
    // printed in, no legal-rate gate and no slot.
    expect(
      completed.document.grossTotal,
      Present<Money>(Money(12100, eur), Provenance.read, ConfidenceState.amber),
    );
    expect(
      completed.document.netTotal,
      Present<Money>(Money(10000, eur), Provenance.read, ConfidenceState.amber),
    );
    expect(
      completed.document.taxSlots,
      isEmpty,
      reason: 'no row, so no rate set and no slot',
    );
    expect(completed.document.needsReview, isTrue);

    // The reason is *added to the engine metadata and to nothing else*: Core's
    // own answer for the same passes with no country is the stored document, in
    // every field but that one string.
    final CanonicalDocument universalCore = extractDocument(
      passes: <ExtractionPass>[
        ExtractionPass(
          passId: textLayerPassId,
          routeLabel: 'pdf-text/$pdfEngine',
          pages: <TextPage>[invoicePage(0)],
        ),
      ],
      country: null,
      table: CountryTable.launch,
      sourceHash: document.sha256,
    );
    final Map<String, Object?> stored = completed.document.toJson();
    final Map<String, Object?> fromCore = universalCore.toJson();
    expect(stored.keys, fromCore.keys);
    for (final String field in fromCore.keys) {
      if (field == 'recognitionEngine') {
        continue;
      }
      expect(
        stored[field],
        fromCore[field],
        reason: 'the service added a reason and changed no value ($field)',
      );
    }
    expect(
      (await files.get(document.docId)).values?.recognitionEngine,
      'pdf-text/$pdfEngine [country=noEvidence]',
      reason: 'the reason survives the store round trip',
    );
    expect(
      sha256Of(File(document.storedPath).readAsBytesSync()),
      document.sha256,
      reason: 'an unresolved item keeps its file',
    );
  });

  test(
    '[countries-languages/universal-core] the reason of every Undetected '
    'document is stored in its engine metadata, and the document is reviewed',
    () async {
      final List<({String name, List<TextPage> pages, UndetectedReason reason})>
      cases = <({String name, List<TextPage> pages, UndetectedReason reason})>[
        (
          name: 'no evidence at all',
          pages: <TextPage>[invoicePage(0)],
          reason: UndetectedReason.noEvidence,
        ),
        (
          name: 'two tax identifiers of two countries and no tiebreak',
          pages: <TextPage>[
            evidencePage(0, <String>['B12345678', 'DE987654321']),
          ],
          reason: UndetectedReason.conflictingEvidence,
        ),
        (
          name: 'evidence of a country with no row',
          pages: <TextPage>[
            evidencePage(0, <String>['CHE123456789', 'CHF']),
          ],
          reason: UndetectedReason.countryWithoutRow,
        ),
      ];

      for (var i = 0; i < cases.length; i++) {
        final ({String name, List<TextPage> pages, UndetectedReason reason})
        detectionCase = cases[i];
        final IntakeResult document = await storedDocument(seed: 80 + i);
        final ({
          ExtractionService service,
          FakePdfTextSource text,
          FakeOcrTextSource ocr,
        })
        fakes = serviceOver(textPages: detectionCase.pages);

        final ExtractionOutcome outcome = await fakes.service.extract(document);

        expect(outcome, isA<ExtractionCompleted>(), reason: detectionCase.name);
        final ExtractionCompleted completed = outcome as ExtractionCompleted;
        expect(
          completed.detection,
          Undetected(reason: detectionCase.reason),
          reason: detectionCase.name,
        );
        expect(
          completed.entry.state,
          DocumentState.reviewing,
          reason: detectionCase.name,
        );
        expect(store.writtenStates, <DocumentState>[
          DocumentState.extracting,
          DocumentState.reviewing,
        ], reason: detectionCase.name);
        expect(
          completed.entry.failureReason,
          isNull,
          reason:
              'the reason is never a failure, whichever reason it is '
              '(${detectionCase.name})',
        );
        expect(
          completed.document.needsReview,
          isTrue,
          reason: detectionCase.name,
        );
        final String metadata =
            'pdf-text/$pdfEngine [country=${detectionCase.reason.name}]';
        expect(
          completed.document.recognitionEngine,
          metadata,
          reason: detectionCase.name,
        );
        expect(
          (await files.get(document.docId)).values?.recognitionEngine,
          metadata,
          reason:
              'the reason is stored, and survives the store round trip '
              '(${detectionCase.name})',
        );
        store.writtenStates.clear();
      }
    },
  );

  test('[extraction-pipeline/consensus-by-majority] passes that name different '
      'countries detect neither, and the reason is the conflict', () async {
    final IntakeResult document = await storedDocument(seed: 95);
    final ({
      ExtractionService service,
      FakePdfTextSource text,
      FakeOcrTextSource ocr,
    })
    // One document read four times: the renderings do not agree about the
    // issuer's country, so no row governs it (design §3).
    fakes = serviceOver(
      textPages: <TextPage>[blankPage(0)],
      passes: <OcrPass>[
        OcrPass(ocrRenderPasses[0].passId, <TextPage>[spanishInvoicePage(0)]),
        OcrPass(ocrRenderPasses[1].passId, <TextPage>[germanInvoicePage(0)]),
        OcrPass(ocrRenderPasses[2].passId, <TextPage>[blankPage(0)]),
        OcrPass(ocrRenderPasses[3].passId, <TextPage>[spanishInvoicePage(0)]),
      ],
    );

    final ExtractionOutcome outcome = await fakes.service.extract(document);

    expect(outcome, isA<ExtractionCompleted>());
    final ExtractionCompleted completed = outcome as ExtractionCompleted;
    expect(
      completed.detection,
      const Undetected(reason: UndetectedReason.conflictingEvidence),
      reason: 'two passes name ES and one names DE: this is a conflict',
    );
    expect(
      completed.document.recognitionEngine,
      'pdf-ocr/$ocrEngine [country=conflictingEvidence]',
    );
    expect(
      completed.document.taxSlots,
      isEmpty,
      reason: 'no row governs the document, so nothing is read under one',
    );
    expect(completed.entry.state, DocumentState.reviewing);
    expect(completed.entry.failureReason, isNull);
  });

  test('[extraction-pipeline/consensus-by-majority] a pass that names a country and '
      'a pass that names none are a conflict, not a vote', () async {
    final IntakeResult document = await storedDocument(seed: 96);
    final ({
      ExtractionService service,
      FakePdfTextSource text,
      FakeOcrTextSource ocr,
    })
    fakes = serviceOver(
      textPages: <TextPage>[blankPage(0)],
      passes: <OcrPass>[
        OcrPass(ocrRenderPasses[0].passId, <TextPage>[spanishInvoicePage(0)]),
        OcrPass(ocrRenderPasses[1].passId, <TextPage>[invoicePage(0)]),
      ],
    );

    final ExtractionOutcome outcome = await fakes.service.extract(document);

    final ExtractionCompleted completed = outcome as ExtractionCompleted;
    expect(
      completed.detection,
      const Undetected(reason: UndetectedReason.conflictingEvidence),
      reason: 'one reading found ES and the other found no evidence at all',
    );
    expect(completed.entry.state, DocumentState.reviewing);
  });

  test(
    '[extraction-pipeline/consensus-by-majority] passes that agree about the '
    'country are one answer, even when they found it in different evidence',
    () async {
      final IntakeResult document = await storedDocument(seed: 97);
      final ({
        ExtractionService service,
        FakePdfTextSource text,
        FakeOcrTextSource ocr,
      })
      fakes = serviceOver(
        textPages: <TextPage>[blankPage(0)],
        passes: <OcrPass>[
          // ES from the issuer's CIF …
          OcrPass(ocrRenderPasses[0].passId, <TextPage>[spanishInvoicePage(0)]),
          // … and ES from a country name beside a postal code. A different
          // evidence kind is not a different country.
          OcrPass(ocrRenderPasses[1].passId, <TextPage>[
            invoicePageWithEvidence(0, <String>['España', '28001']),
          ]),
          // A pass that read no word carries no evidence and is not asked
          // (design §3: the first pass with words).
          OcrPass(ocrRenderPasses[2].passId, <TextPage>[blankPage(0)]),
        ],
      );

      final ExtractionOutcome outcome = await fakes.service.extract(document);

      final ExtractionCompleted completed = outcome as ExtractionCompleted;
      expect(
        completed.detection,
        Detected(
          row: CountryTable.es,
          evidence: const <CountryEvidenceKind>[CountryEvidenceKind.taxId],
        ),
        reason: 'the evidence kinds of the pass that answered, and one country',
      );
      expect(
        completed.document.taxSlots,
        hasLength(CountryTable.es.slotCount),
        reason: 'the agreed row governs the reading',
      );
      expect(
        completed.document.recognitionEngine,
        'pdf-ocr/$ocrEngine',
        reason: 'a detected country needs no reason in the engine metadata',
      );
    },
  );

  test('a document that could not be read ends in failed with the code as its '
      'reason, and keeps its file', () async {
    final List<_FailureCase> cases = <_FailureCase>[
      _FailureCase(
        name: 'the text layer of a PDF',
        mediaType: 'application/pdf',
        textPages: const <TextPage>[],
        textFailure: const PdfTextReadFailure(
          'the document could not be opened',
        ),
        code: ExtractionFailureCode.textLayerUnreadable,
      ),
      _FailureCase(
        name: 'the pages of a scanned PDF',
        mediaType: 'application/pdf',
        textPages: <TextPage>[blankPage(0)],
        ocrFailure: const OcrFailure('no pass could read the document'),
        code: ExtractionFailureCode.recognitionUnreadable,
      ),
      _FailureCase(
        name: 'a photo',
        mediaType: 'image/png',
        textPages: const <TextPage>[],
        ocrFailure: const OcrFailure('the file could not be read'),
        code: ExtractionFailureCode.recognitionUnreadable,
      ),
    ];

    for (var i = 0; i < cases.length; i++) {
      final _FailureCase failureCase = cases[i];
      final IntakeResult document = await storedDocument(
        mediaType: failureCase.mediaType,
        bytes: failureCase.mediaType == 'application/pdf'
            ? sourceBytes
            : textBytes('a synthetic photo'),
        seed: 40 + i,
      );
      final ({
        ExtractionService service,
        FakePdfTextSource text,
        FakeOcrTextSource ocr,
      })
      fakes = serviceOver(
        textPages: failureCase.textPages,
        textFailure: failureCase.textFailure,
        ocrFailure: failureCase.ocrFailure,
      );

      final ExtractionOutcome outcome = await fakes.service.extract(document);

      expect(outcome, isA<ExtractionRefused>(), reason: failureCase.name);
      final ExtractionRefused refused = outcome as ExtractionRefused;
      expect(refused.failure.code, failureCase.code, reason: failureCase.name);
      expect(store.writtenStates, <DocumentState>[
        DocumentState.extracting,
        DocumentState.failed,
      ], reason: failureCase.name);
      expect(refused.entry.state, DocumentState.failed);
      expect(refused.entry.failureReason, failureCase.code.code);
      expect(
        refused.entry.values,
        isNull,
        reason:
            'nothing was read, so nothing is stored as values '
            '(${failureCase.name})',
      );
      expect(await files.get(document.docId), refused.entry);
      expect(
        sha256Of(File(document.storedPath).readAsBytesSync()),
        document.sha256,
        reason: 'an unresolved item keeps its file (${failureCase.name})',
      );
      store.writtenStates.clear();
    }
  });

  test('an entry that is not pending is refused by the machine, and nothing is '
      'written', () async {
    final IntakeResult document = await storeDocument(
      root,
      sourceBytes,
      docId: aDocId(51),
    );
    final HistoryEntry reviewing = anEntry(
      docId: document.docId,
      state: DocumentState.reviewing,
      documentHash: document.sha256,
    );
    await files.create(reviewing);
    final ({
      ExtractionService service,
      FakePdfTextSource text,
      FakeOcrTextSource ocr,
    })
    fakes = serviceOver(textPages: <TextPage>[invoicePage(0)]);

    await expectLater(
      fakes.service.extract(document),
      throwsA(
        isA<StateError>().having(
          (StateError error) => error.message,
          'message',
          contains('reviewing -> extracting'),
        ),
      ),
    );

    expect(store.writtenStates, isEmpty);
    expect((await files.get(document.docId)).revision, reviewing.revision);
    expect(fakes.text.readPaths, isEmpty);
    expect(fakes.ocr.recognisePaths, isEmpty);
  });

  test(
    'a document with no entry is the store\'s refusal, not a document failure',
    () async {
      final IntakeResult document = await storedDocument(seed: 61);
      final IntakeResult withoutEntry = await storeDocument(
        root,
        sourceBytes,
        docId: aDocId(62),
      );
      final ({
        ExtractionService service,
        FakePdfTextSource text,
        FakeOcrTextSource ocr,
      })
      fakes = serviceOver(textPages: <TextPage>[invoicePage(0)]);

      await expectLater(
        fakes.service.extract(withoutEntry),
        throwsA(
          isA<HistoryStoreFailure>().having(
            (HistoryStoreFailure failure) => failure.code,
            'code',
            HistoryStoreFailureCode.notFound,
          ),
        ),
      );
      expect(
        (await files.get(document.docId)).state,
        DocumentState.pending,
        reason: 'another document\'s failure is not this document\'s state',
      );
      expect(store.writtenStates, isEmpty);
    },
  );

  test(
    'an intake paired with another document\'s entry is a defect, and nothing '
    'is written',
    () async {
      final IntakeResult document = await storeDocument(
        root,
        sourceBytes,
        docId: aDocId(71),
      );
      await files.create(
        anEntry(
          docId: document.docId,
          documentHash: aDocumentHash('another doc'),
        ),
      );
      final ({
        ExtractionService service,
        FakePdfTextSource text,
        FakeOcrTextSource ocr,
      })
      fakes = serviceOver(textPages: <TextPage>[invoicePage(0)]);

      await expectLater(
        fakes.service.extract(document),
        throwsA(isA<ArgumentError>()),
      );

      expect(store.writtenStates, isEmpty);
      expect((await files.get(document.docId)).state, DocumentState.pending);
      expect(fakes.text.readPaths, isEmpty);
    },
  );
}
