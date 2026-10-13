/// The fakes, the synthetic pages and the stored documents the extraction tests share.
///
/// **Why fakes and not the adapters.** `ExtractionRouter` and `ExtractionService` are the
/// orchestration, and the orchestration is what these tests are about: which port is
/// asked, with which path, in which order, and what becomes of the answer. The adapters
/// behind the ports need PDFium and ML Kit and are exercised in `app/integration_test/`
/// on a device; here the ports are values a test controls (design §1: no test needs a
/// device).
///
/// **Every identifier and every hash is computed at run time**, as `history_fixtures.dart`
/// does it: a 32-character document identifier or a 64-character SHA-256 written as a
/// literal is a token-like string to `.github/scripts/privacy_check.py`.
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:paperdrop/adapters/ocr/ocr_text_source.dart';
import 'package:paperdrop/adapters/ocr/render_passes.dart';
import 'package:paperdrop/adapters/pdf_text/pdf_text_source.dart';
import 'package:paperdrop/history/history_entry.dart';
import 'package:paperdrop/history/history_store.dart';
import 'package:paperdrop/intake/document_intake.dart';
import 'package:paperdrop/intake/intake_result.dart';
import 'package:paperdrop_core/paperdrop_core.dart';
import 'package:path/path.dart' as p;

import '../../history/history_fixtures.dart';

/// The SHA-256 of [bytes], computed exactly as `DocumentIntake` computes one.
String sha256Of(List<int> bytes) => sha256.convert(bytes).toString();

/// A text-layer port that answers with what it was told to and records what it was asked.
final class FakePdfTextSource implements PdfTextSource {
  /// Creates a port answering with [pages], or failing with [failure].
  ///
  /// [onRead] runs after the call was recorded, so a test can look at the store or at the
  /// other port while this one is being read.
  FakePdfTextSource({
    this.pages = const <TextPage>[],
    this.failure,
    this.onRead,
  });

  /// The pages a successful read answers with.
  final List<TextPage> pages;

  /// What a read throws instead, when a test needs the port to fail.
  final PdfTextReadFailure? failure;

  /// Called during a read, after [readPaths] has the path.
  final Future<void> Function(String path)? onRead;

  /// Every path this port was asked to read, in order.
  final List<String> readPaths = <String>[];

  @override
  Future<List<TextPage>> read(String path) async {
    readPaths.add(path);
    await onRead?.call(path);
    final PdfTextReadFailure? failure = this.failure;
    if (failure != null) {
      throw failure;
    }
    return pages;
  }
}

/// A recognition port that answers with what it was told to and records what it was asked.
final class FakeOcrTextSource implements OcrTextSource {
  /// Creates a port answering with [passes], or failing with [failure].
  FakeOcrTextSource({
    this.passes = const <OcrPass>[],
    this.failure,
    this.onRead,
  });

  /// The passes a successful recognition answers with.
  final List<OcrPass> passes;

  /// What a recognition throws instead, when a test needs the port to fail.
  final OcrFailure? failure;

  /// Called during a recognition, after [recognisePaths] has the path.
  final Future<void> Function(String path)? onRead;

  /// Every path this port was asked to recognise, in order.
  final List<String> recognisePaths = <String>[];

  @override
  Future<List<OcrPass>> recognise(String path) async {
    recognisePaths.add(path);
    await onRead?.call(path);
    final OcrFailure? failure = this.failure;
    if (failure != null) {
      throw failure;
    }
    return passes;
  }
}

/// A word of a synthetic page, in Core's units.
PositionedWord word(String text, int x0, int x1, int top, int bottom) =>
    PositionedWord(text, x0, x1, top, bottom);

/// A synthetic invoice page whose labels bind: `TOTAL 121,00`, `BASE 100,00`,
/// `IVA 21,00`, `21 %` and `EUR`.
///
/// The shape is Core's own test page (`packages/paperdrop_core/test/extraction/`), so a
/// document built from it produces a base, a tax and a total with a currency in the ES
/// row: what these tests assert about values is what Core already asserts about them.
TextPage invoicePage(int index) =>
    TextPage(index, 300000, 300000, <PositionedWord>[
      word('TOTAL', 100000, 120000, 100000, 120000),
      word('121,00', 130000, 200000, 100000, 120000),
      word('BASE', 100000, 120000, 140000, 160000),
      word('100,00', 130000, 200000, 140000, 160000),
      word('IVA', 100000, 120000, 180000, 200000),
      word('21,00', 130000, 200000, 180000, 200000),
      word('21', 100000, 110000, 220000, 240000),
      word('%', 115000, 125000, 220000, 240000),
      word('EUR', 200000, 220000, 260000, 280000),
    ]);

/// A page carrying only a date, for a document whose pages each hold part of it.
TextPage datePage(int index, String date) =>
    TextPage(index, 300000, 300000, <PositionedWord>[
      word('FECHA', 100000, 120000, 100000, 120000),
      word(date, 130000, 220000, 100000, 120000),
    ]);

/// A page with no word: a page without a text layer, which is the fall-through signal the
/// route selector reads.
TextPage blankPage(int index, {int width = 300000, int height = 300000}) =>
    TextPage(index, width, height, const <PositionedWord>[]);

/// One page read by recognition, with a word no text layer carries.
TextPage recognisedPage(int index) => TextPage(
  index,
  300000,
  300000,
  <PositionedWord>[word('TOTAL', 100000, 120000, 100000, 120000)],
);

/// The passes a recognition port reads a document in: design §3's four renderings, each
/// over [pages].
List<OcrPass> fourPasses(List<TextPage> pages) => <OcrPass>[
  for (final OcrRenderPass pass in ocrRenderPasses) OcrPass(pass.passId, pages),
];

/// A document as `DocumentIntake` leaves it: the file under the store root and the result
/// that proves what was stored (FR-CAP-005).
///
/// The bytes are written as they are, and the hash is computed over them, so the intake
/// result and the file on disk agree the way they do on the device.
Future<IntakeResult> storeDocument(
  Directory root,
  List<int> bytes, {
  String? docId,
  String mediaType = 'application/pdf',
}) async {
  final String id = docId ?? aDocId(3);
  final Directory folder = Directory(p.join(root.path, id));
  await folder.create(recursive: true);
  final File file = File(
    p.join(
      folder.path,
      'original.${DocumentIntake.extensionsByMediaType[mediaType]}',
    ),
  );
  await file.writeAsBytes(bytes);
  return IntakeResult(
    docId: id,
    source: IntakeSource.picker,
    mediaType: mediaType,
    byteLength: bytes.length,
    sha256: sha256Of(bytes),
    storedPath: file.path,
  );
}

/// An intake result for a document that need not exist on disk.
///
/// The route tests hand it to the router and nothing opens it: the ports are fakes, so
/// the path is a value the test reads back and not a file.
IntakeResult anIntakeResult({
  String mediaType = 'application/pdf',
  int seed = 9,
  String? storedPath,
}) {
  final String docId = aDocId(seed);
  return IntakeResult(
    docId: docId,
    source: IntakeSource.picker,
    mediaType: mediaType,
    byteLength: textBytes('a stored document').length,
    sha256: sha256Of(textBytes('a stored document')),
    storedPath: storedPath ?? p.join('originals', docId, 'original.pdf'),
  );
}

/// The entry `DocumentIntake` and the capture step leave behind: `pending`, with the
/// stored copy's own hash.
HistoryEntry pendingEntry(IntakeResult document) => anEntry(
  docId: document.docId,
  state: DocumentState.pending,
  documentHash: document.sha256,
);

/// The bytes of the committed synthetic scan, which is a real PDF of one page.
///
/// It is read as bytes only: no test here opens it, and the private corpus is not read,
/// copied or named.
List<int> syntheticScanBytes() => File(
  p.join(
    Directory.current.path,
    'test',
    'fixtures',
    'ocr',
    'synthetic_invoice.pdf',
  ),
).readAsBytesSync();

/// The UTF-8 bytes of [text], for a test that needs a file of known content and no PDF.
List<int> textBytes(String text) => utf8.encode(text);

/// A store that is another store, with the states it was asked to write.
///
/// It is how a test reads the *order* of the writes without reimplementing the store: the
/// entries it writes are the real ones, in the real format, and the states are kept here.
final class RecordingHistoryStore implements HistoryStore {
  /// Wraps [inner].
  RecordingHistoryStore(this.inner);

  /// The store the writes go to.
  final HistoryStore inner;

  /// The state of every entry this store was asked to write, in order.
  final List<DocumentState> writtenStates = <DocumentState>[];

  @override
  Future<void> create(HistoryEntry entry) => inner.create(entry);

  @override
  Future<HistoryEntry> get(String docId) => inner.get(docId);

  @override
  Future<void> update(String docId, HistoryEntry entry) {
    writtenStates.add(entry.state);
    return inner.update(docId, entry);
  }

  @override
  Future<HistoryListing> list() => inner.list();

  @override
  Future<void> deleteOriginal(String docId) => inner.deleteOriginal(docId);
}
