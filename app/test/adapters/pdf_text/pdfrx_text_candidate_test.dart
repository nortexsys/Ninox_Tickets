import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:paperdrop/adapters/pdf_text/pdf_text_candidate.dart';
import 'package:paperdrop/adapters/pdf_text/pdfrx_text_candidate.dart';
import 'package:path/path.dart' as p;
import 'package:pdfrx/pdfrx.dart';

import '../../tool/pdfrx_host.dart';
import '../../tool/synthetic_documents.dart';

/// Candidate B of ADR-011 (`close-adr-011-pdf-text-route`, task 1.2).
///
/// **What this proves.** Two things, one of them the whole reason this candidate
/// is a Flutter package rather than a platform channel: the plugin's own
/// fragments become [CandidateWord]s with the y flipped into the frame design §2
/// fixes, and `pdfrx` **actually reads a document on this machine**, because
/// PDFium is a native library `pdfrx` downloads and loads here as well as on the
/// S22. That second test is the one the note under task 1.4 records: candidate A
/// cannot run anywhere but a device, candidate B can run on the host.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// A page of structured text of the shape `pdfrx` produces: three fragments —
  /// a word, its run of whitespace, and another word — with boxes in PDF page
  /// coordinates, where y grows upwards from the bottom of the page.
  PdfPageText onePage() {
    const String full = 'Gesamtbetrag 1.234,50';
    const PdfPageText owner = PdfPageText(
      pageNumber: 1,
      fullText: full,
      charRects: <PdfRect>[],
      fragments: <PdfPageTextFragment>[],
    );
    const List<PdfRect> labelRects = <PdfRect>[
      PdfRect(42.5, 130.5, 108.75, 120.0),
    ];
    const List<PdfRect> spaceRects = <PdfRect>[
      PdfRect(108.75, 130.5, 112.0, 120.0),
    ];
    const List<PdfRect> valueRects = <PdfRect>[
      PdfRect(112.0, 130.5, 158.25, 120.0),
    ];
    return const PdfPageText(
      pageNumber: 1,
      fullText: full,
      charRects: <PdfRect>[...labelRects, ...spaceRects, ...valueRects],
      fragments: <PdfPageTextFragment>[
        PdfPageTextFragment(
          pageText: owner,
          index: 0,
          length: 12,
          bounds: PdfRect(42.5, 130.5, 108.75, 120.0),
          charRects: labelRects,
          direction: PdfTextDirection.ltr,
        ),
        PdfPageTextFragment(
          pageText: owner,
          index: 12,
          length: 1,
          bounds: PdfRect(108.75, 130.5, 112.0, 120.0),
          charRects: spaceRects,
          direction: PdfTextDirection.ltr,
        ),
        PdfPageTextFragment(
          pageText: owner,
          index: 13,
          length: 8,
          bounds: PdfRect(112.0, 130.5, 158.25, 120.0),
          charRects: valueRects,
          direction: PdfTextDirection.ltr,
        ),
      ],
    );
  }

  test('the plugin\'s fragments become words, y measured from the top', () {
    final CandidatePage page = candidatePageFromPdfrx(
      index: 0,
      width: 595.28,
      height: 841.89,
      text: onePage(),
    );

    // The run of whitespace is a separator, not a word; the two words either
    // side of it are exactly as the plugin cut them.
    expect(
      page.words.map((CandidateWord word) => word.text),
      <String>['Gesamtbetrag', '1.234,50'],
    );
    expect(page.width, 595.28);

    final CandidateWord label = page.words.first;
    expect(label.x0, 42.5);
    expect(label.x1, 108.75);
    // PDFium said top 130.5 and bottom 120.0 above the page's bottom edge; from
    // the page's top edge that is 711.39 and 721.89.
    expect(label.top, 841.89 - 130.5);
    expect(label.bottom, 841.89 - 120.0);
    expect(label.top, lessThan(label.bottom));

    // The two words sit on one line: the same box, one to the right of the
    // other. That is the geometry the label-value rule of Core reads.
    expect(label.top, page.words.last.top);
    expect(label.x1, lessThan(page.words.last.x0));
  });

  test('a page with no text layer yields no word', () {
    final PdfPageText empty = const PdfPageText(
      pageNumber: 1,
      fullText: '',
      charRects: <PdfRect>[],
      fragments: <PdfPageTextFragment>[],
    );
    final CandidatePage page = candidatePageFromPdfrx(
      index: 3,
      width: 595.28,
      height: 841.89,
      text: empty,
    );

    expect(page.index, 3);
    expect(page.words, isEmpty);
  });

  test('PDFium reads a document on this machine, and reads it read-only', () async {
    final Directory directory = Directory.systemTemp.createTempSync('paperdrop-pdfrx-test');
    addTearDown(() => directory.deleteSync(recursive: true));
    // On a device the plugin asks the platform for a cache directory; on the
    // test host there is no platform, so the test answers for it.
    mockPathProviderCacheDirectory(directory);

    final File file = File(p.join(directory.path, 'synthetic.pdf'));
    final List<int> bytes = syntheticPdf(text: 'Gesamtbetrag 1.234,50');
    file.writeAsBytesSync(bytes);

    final CandidateDocument document = await const PdfrxTextCandidate().read(
      file.path,
    );
    final List<CandidatePage> pages = document.pages;

    expect(pages, hasLength(1));
    // One page, one number: the time that page's extraction took, measured
    // around the plugin's own call (design §1.3).
    expect(document.msPerPage, hasLength(1));
    expect(document.msPerPage.single, greaterThanOrEqualTo(0));
    expect(
      pages.single.words.map((CandidateWord word) => word.text),
      containsAll(<String>['Gesamtbetrag', '1.234,50']),
    );

    // The fixture draws 12-point Helvetica at 72 points from the left and 770
    // from the bottom of a 595x842 page, so from the page's top edge the word
    // starts at 72 and its box straddles 842 - 770: the band above the baseline
    // is the font's ascender, the band below it its descender. That is the
    // direction design §2 fixes, checked against a page whose geometry is known
    // rather than against another library's answer.
    final CandidateWord first = pages.single.words.first;
    expect(first.x0, closeTo(72.0, 1.0));
    expect(first.top, closeTo(63.2, 2.0));
    expect(first.bottom, closeTo(74.6, 2.0));
    expect(first.top, lessThan(first.bottom));
    // Reading a document does not write to it (ADR-015). The harness proves
    // this against the intake hash on the device; here it is the same bytes.
    expect(file.readAsBytesSync(), bytes);
    expect(const PdfrxTextCandidate().tool, 'pdfrx 2.6.5');
  });

  test('a document that is not a PDF fails rather than answering nothing', () async {
    final Directory directory = Directory.systemTemp.createTempSync('paperdrop-pdfrx-broken');
    addTearDown(() => directory.deleteSync(recursive: true));
    final File file = File(p.join(directory.path, 'not-a.pdf'));
    file.writeAsStringSync('not a PDF at all');

    await expectLater(
      const PdfrxTextCandidate().read(file.path),
      throwsA(anything),
    );
  });
}
