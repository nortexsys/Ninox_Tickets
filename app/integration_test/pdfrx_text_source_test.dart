import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:paperdrop/adapters/pdf_text/pdf_text_source.dart';
import 'package:paperdrop/adapters/pdf_text/pdfrx_text_source.dart';
import 'package:paperdrop_core/paperdrop_core.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../test/tool/synthetic_documents.dart';

/// The pdfrx adapter reading real documents (`close-adr-011-pdf-text-route`,
/// task 2.2).
///
/// **What this proves, and where.** Everything the pure unit test in
/// `test/adapters/pdf_text/pdfrx_text_source_test.dart` cannot: that PDFium
/// opens a document, that the conversion holds on the coordinates a real page
/// reports, that a page with no text layer answers with no word, that a
/// document that cannot be read fails as [PdfTextReadFailure], and — the
/// promise the whole route rests on — that reading a file **leaves it
/// byte-for-byte what it was** (ADR-015,
/// `received-files-are-attached-byte-for-byte`), proved with a SHA-256 taken
/// before and after the read and never by inspection.
///
/// **Why it is here and not in `flutter test`.** It needs the native engine,
/// which `pdfrx`'s build hook downloads and links for the device; the pages it
/// reads are written by the test itself, in the application's temporary
/// directory, so this test needs no pushed file and no corpus.
///
/// **It writes nothing but its own documents.** The PDFs are synthetic
/// (`syntheticPdf`, the writer the intake tests already use); the private
/// corpus is not read, copied or named, and nothing of a real document appears
/// here.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Directory work;
  late File invoice;

  setUpAll(() async {
    work = await getTemporaryDirectory();
    invoice = File(p.join(work.path, 'paperdrop-pdfrx-source.pdf'));
    // 12-point Helvetica at 72 points from the left and 770 from the bottom of
    // a 595x842 page: the geometry is known, so what the adapter reports can be
    // checked against it instead of against itself.
    invoice.writeAsBytesSync(syntheticPdf(text: 'Gesamtbetrag 1.234,50'));
  });

  tearDownAll(() {
    if (invoice.existsSync()) {
      invoice.deleteSync();
    }
  });

  test('a real page becomes Core\'s positioned words, top-left origin', () async {
    final Uint8List before = invoice.readAsBytesSync();
    final List<Duration> pageTimes = <Duration>[];
    final PdfrxTextSource source = PdfrxTextSource(onPageRead: pageTimes.add);

    final List<TextPage> pages = await source.read(invoice.path);

    // Read-only (ADR-015): the bytes after the read are the bytes before it.
    expect(
      sha256.convert(invoice.readAsBytesSync()).toString(),
      sha256.convert(before).toString(),
      reason: 'reading a document must not write to it',
    );

    expect(pages, hasLength(1));
    final TextPage page = pages.single;
    expect(page.index, 0);
    expect(page.hasTextLayer, isTrue);
    // One timing per page, in page order: what the evaluation harness reports
    // as `ms_per_page` (design §2).
    expect(pageTimes, hasLength(1));

    final PositionedWord label = _only(page, 'Gesamtbetrag');
    final PositionedWord value = _only(page, '1.234,50');
    // The page's own size in thousandths of a point.
    expect(page.width, closeTo(595000, 1000));
    expect(page.height, closeTo(842000, 1000));
    // The text is drawn at x = 72 and its glyph box starts there; PDFium reports
    // the box of the first glyph, a fraction of a point further right.
    expect(label.x0, closeTo(72000, 2000));
    // The baseline of a 12-point line sits 72 points below the top edge of the
    // page, and a glyph box straddles it: its ascender above the baseline and
    // its descender below, so the top of the box is the smaller number — the
    // opposite of the plugin's own coordinate system, which is the conversion
    // this test exists for.
    expect(label.top, lessThan(72000));
    expect(label.bottom, greaterThan(72000));
    expect(72000 - label.top, lessThan(15000));
    expect(label.bottom - 72000, lessThan(15000));
    // One line, the value to the right of the label.
    expect(value.top, label.top);
    expect(value.bottom, label.bottom);
    expect(label.x1, lessThan(value.x0));
  });

  test('a page with no text layer answers with no word', () async {
    final File scanned = File(p.join(work.path, 'paperdrop-pdfrx-no-text.pdf'));
    scanned.writeAsBytesSync(syntheticPdf(text: ''));
    addTearDown(() {
      if (scanned.existsSync()) {
        scanned.deleteSync();
      }
    });

    final List<TextPage> pages = await const PdfrxTextSource().read(
      scanned.path,
    );

    expect(pages, hasLength(1));
    expect(pages.single.words, isEmpty);
    // The fall-through signal for the OCR route (T2.1), which this type does
    // not decide: it only reports that the page yielded nothing.
    expect(pages.single.hasTextLayer, isFalse);
  });

  test(
    'a document that cannot be read fails as a PdfTextReadFailure',
    () async {
      final File notAPdf = File(p.join(work.path, 'paperdrop-pdfrx-not-a.pdf'));
      notAPdf.writeAsStringSync('not a PDF at all');
      addTearDown(() {
        if (notAPdf.existsSync()) {
          notAPdf.deleteSync();
        }
      });

      await expectLater(
        const PdfrxTextSource().read(notAPdf.path),
        throwsA(isA<PdfTextReadFailure>()),
      );
    },
  );
}

PositionedWord _only(TextPage page, String text) {
  final List<PositionedWord> matches = page.words
      .where((PositionedWord word) => word.text == text)
      .toList();
  expect(matches, hasLength(1), reason: '"$text" once on the page');
  return matches.single;
}
