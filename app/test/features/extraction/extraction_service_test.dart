/// The extraction step against the real store: the state machine, the stored values, the
/// reason a failure leaves and the document that is never touched (T2.1, tasks 2.2–2.3).
///
/// Requirement served: `document-history` · `document-states` (FR-HIS-002) — an entry
/// holds exactly one of the eight states and every change goes through
/// `document_machine.dart`; `extraction-pipeline` · `invoice-route-priority` (FR-EXT-002)
/// — the route taken is recorded in the recognition engine the values carry;
/// `extraction-pipeline` · `multi-page-consolidation` (FR-EXT-012) — the pages of one
/// document become one model; and `capture-intake` ·
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
        // Which country row a document is read against is its caller's decision, so
        // nothing here invents production wiring for it.
        country: CountryTable.es,
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
        textPages: <TextPage>[invoicePage(0)],
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
          textPages: <TextPage>[invoicePage(0)],
          passes: const <OcrPass>[],
          engine: 'pdf-text/$pdfEngine',
        ),
        _RouteCase(
          mediaType: 'application/pdf',
          bytes: sourceBytes,
          textPages: <TextPage>[blankPage(0)],
          passes: fourPasses(<TextPage>[recognisedPage(0)]),
          engine: 'pdf-ocr/$ocrEngine',
        ),
        _RouteCase(
          mediaType: 'application/pdf',
          bytes: sourceBytes,
          textPages: <TextPage>[invoicePage(0), blankPage(1)],
          passes: fourPasses(<TextPage>[recognisedPage(0), recognisedPage(1)]),
          engine: 'pdf-mixed/$pdfEngine + $ocrEngine',
        ),
        _RouteCase(
          mediaType: 'image/jpeg',
          bytes: textBytes('a synthetic photo'),
          textPages: const <TextPage>[],
          passes: <OcrPass>[
            OcrPass(MlKitOcrTextSource.imagePassId, <TextPage>[
              recognisedPage(0),
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
    // what `PdfTextSource` returns for a two-page PDF, handed on as one pass.
    fakes = serviceOver(
      textPages: <TextPage>[invoicePage(0), datePage(1, '01/01/2024')],
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
