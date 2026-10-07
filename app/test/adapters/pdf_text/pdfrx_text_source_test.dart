import 'package:flutter_test/flutter_test.dart';
import 'package:paperdrop/adapters/pdf_text/pdfrx_text_source.dart';
import 'package:paperdrop_core/paperdrop_core.dart';
import 'package:pdfrx/pdfrx.dart';

/// The pdfrx adapter's conversion (`close-adr-011-pdf-text-route`, task 2.2).
///
/// **What this proves.** Everything about the adapter that can be proved
/// without the native engine: that the plugin's own fragments become Core's
/// positioned words, that a run of whitespace and a line break are separators
/// and not words, and — the part worth a test of its own — that the plugin's
/// points and bottom-left origin become Core's integer thousandths of a point
/// and top-left origin. `PdfPageText`, `PdfPageTextFragment` and `PdfRect` are
/// plain constructible types, so the fabricated page below is the very shape the
/// plugin hands the conversion.
///
/// **Where it stops.** It never opens a document: that needs PDFium, and the
/// tests that read one live in `app/integration_test/`, where the orchestrator
/// runs them on a device.
void main() {
  /// A page of structured text of the shape `pdfrx` produces: a word, its run of
  /// whitespace, another word, a line break, and a word on the next line. The
  /// boxes are in PDF page coordinates — origin at the bottom-left, y upwards,
  /// `top` the larger number — on a 595.28 x 841.89 point page.
  PdfPageText onePage() {
    const String full = 'Gesamtbetrag 1.234,50\nTomo 8.741';
    const PdfPageText owner = PdfPageText(
      pageNumber: 1,
      fullText: full,
      charRects: <PdfRect>[],
      fragments: <PdfPageTextFragment>[],
    );
    const List<PdfRect> labelRects = <PdfRect>[
      PdfRect(42.5, 723.39, 108.75, 711.64),
    ];
    const List<PdfRect> spaceRects = <PdfRect>[
      PdfRect(108.75, 723.39, 112.0, 711.64),
    ];
    const List<PdfRect> valueRects = <PdfRect>[
      PdfRect(112.0, 723.39, 158.25, 711.64),
    ];
    const List<PdfRect> volumeRects = <PdfRect>[
      PdfRect(42.5, 705.39, 70.0, 693.64),
    ];
    return const PdfPageText(
      pageNumber: 1,
      fullText: full,
      charRects: <PdfRect>[
        ...labelRects,
        ...spaceRects,
        ...valueRects,
        ...volumeRects,
      ],
      fragments: <PdfPageTextFragment>[
        PdfPageTextFragment(
          pageText: owner,
          index: 0,
          length: 12,
          bounds: PdfRect(42.5, 723.39, 108.75, 711.64),
          charRects: labelRects,
          direction: PdfTextDirection.ltr,
        ),
        PdfPageTextFragment(
          pageText: owner,
          index: 12,
          length: 1,
          bounds: PdfRect(108.75, 723.39, 112.0, 711.64),
          charRects: spaceRects,
          direction: PdfTextDirection.ltr,
        ),
        PdfPageTextFragment(
          pageText: owner,
          index: 13,
          length: 8,
          bounds: PdfRect(112.0, 723.39, 158.25, 711.64),
          charRects: valueRects,
          direction: PdfTextDirection.ltr,
        ),
        // The line break: a fragment of its own, and not a word.
        PdfPageTextFragment(
          pageText: owner,
          index: 21,
          length: 1,
          bounds: PdfRect(158.25, 723.39, 158.25, 711.64),
          charRects: <PdfRect>[PdfRect(158.25, 723.39, 158.25, 711.64)],
          direction: PdfTextDirection.ltr,
        ),
        // "Tomo", the first word of the line below: the plugin cuts a line on
        // whitespace, so a fragment never carries any — which is what Core's
        // `PositionedWord` requires of a word.
        PdfPageTextFragment(
          pageText: owner,
          index: 22,
          length: 4,
          bounds: PdfRect(42.5, 705.39, 70.0, 693.64),
          charRects: volumeRects,
          direction: PdfTextDirection.ltr,
        ),
      ],
    );
  }

  test('the plugin\'s fragments become Core\'s words in milli-points', () {
    final TextPage page = textPageFromPdfrx(
      index: 0,
      width: 595.28,
      height: 841.89,
      text: onePage(),
    );

    // The whitespace run and the line break are separators, not words; the three
    // words are exactly as the plugin cut them, in its order.
    expect(page.words.map((PositionedWord word) => word.text), <String>[
      'Gesamtbetrag',
      '1.234,50',
      'Tomo',
    ]);
    expect(page.index, 0);
    expect(page.width, 595280);
    expect(page.height, 841890);
    expect(page.hasTextLayer, isTrue);

    final PositionedWord label = page.words.first;
    expect(label.x0, 42500);
    expect(label.x1, 108750);
    // PDFium said the box ran from y 711.64 to 723.39 above the page's bottom
    // edge; from the top edge of a 841.89-point page that is 118.50 to 130.25,
    // in points — 118500 and 130250 in thousandths.
    expect(label.top, 118500);
    expect(label.bottom, 130250);
    // Top-left origin, which is Core's contract: the top of a box is above its
    // bottom, the opposite of the plugin's own coordinate system.
    expect(label.top, lessThan(label.bottom));

    // The label and its value sit on one line, one to the right of the other;
    // the volume is on the next line down.
    final PositionedWord value = page.words[1];
    final PositionedWord volume = page.words.last;
    expect(value.top, label.top);
    expect(label.x1, lessThan(value.x0));
    expect(volume.top, greaterThan(label.bottom));
  });

  test('a page with no word has no text layer', () {
    final TextPage page = textPageFromPdfrx(
      index: 3,
      width: 595.28,
      height: 841.89,
      text: const PdfPageText(
        pageNumber: 4,
        fullText: '',
        charRects: <PdfRect>[],
        fragments: <PdfPageTextFragment>[],
      ),
    );

    expect(page.index, 3);
    expect(page.words, isEmpty);
    expect(page.hasTextLayer, isFalse);
  });

  test('a fraction of a thousandth rounds to the nearest one', () {
    const String full = 'x';
    const PdfPageText owner = PdfPageText(
      pageNumber: 1,
      fullText: full,
      charRects: <PdfRect>[],
      fragments: <PdfPageTextFragment>[],
    );
    // A quarter of a thousandth of a point is the same as no difference at all:
    // a library reports hundredths of a point at best.
    const PdfRect bounds = PdfRect(10.0004, 800.0004, 20.0004, 790.0004);
    final TextPage page = textPageFromPdfrx(
      index: 0,
      width: 595.0004,
      height: 841.0004,
      text: const PdfPageText(
        pageNumber: 1,
        fullText: full,
        charRects: <PdfRect>[bounds],
        fragments: <PdfPageTextFragment>[
          PdfPageTextFragment(
            pageText: owner,
            index: 0,
            length: 1,
            bounds: bounds,
            charRects: <PdfRect>[bounds],
            direction: PdfTextDirection.ltr,
          ),
        ],
      ),
    );

    expect(page.width, 595000);
    expect(page.height, 841000);
    expect(page.words.single.x0, 10000);
    expect(page.words.single.x1, 20000);
    expect(page.words.single.top, 41000);
    expect(page.words.single.bottom, 51000);
  });
}
