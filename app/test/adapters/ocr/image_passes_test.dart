import 'package:flutter_test/flutter_test.dart';
import 'package:paperdrop/adapters/ocr/image_header.dart';
import 'package:paperdrop/adapters/ocr/image_passes.dart';

/// Design §2's image pass table against the one constant the adapter reads
/// (`implement-photo-passes`, task 1.3).
///
/// **What this proves.** That the four passes are the four the design names, in
/// the order it names them, under the ids it names them by, with the variations
/// it gives: the file as it is, contrast, about 0.7 and about 1.4 of the long
/// side. It also proves what a pass asks a decoder for — which is the one piece
/// of arithmetic the list adds to the design's factors, and the reason the
/// tolerance of design §4 is one pixel.
///
/// **Where it stops.** It reads the list itself. That the adapter reads them in
/// this order, decodes what each asks for and reports what each read is
/// `test/adapters/ocr/mlkit_ocr_text_source_test.dart`'s, and what each reading
/// does to recognition quality is a device screening's (T2.5) — no pass is
/// dropped, weighted or preferred here.
void main() {
  test('the list is design §2\'s table, in its order', () {
    expect(ocrImagePasses.map((OcrImagePass pass) => pass.passId), <String>[
      'p1-native',
      'p2-contrast',
      'p3-lo',
      'p4-hi',
    ]);
    expect(
      ocrImagePasses.map((OcrImagePass pass) => pass.longSideScale),
      <double>[1, 1, 0.7, 1.4],
    );
    expect(ocrImagePasses.map((OcrImagePass pass) => pass.greyContrast), <bool>[
      false,
      true,
      false,
      false,
    ]);
    // One pass and one only reads the file as it is: the first, which is the
    // reading the adapter had before this change, so today's results stay
    // comparable.
    expect(
      ocrImagePasses
          .where((OcrImagePass pass) => pass.readsTheFileAsItIs)
          .map((OcrImagePass pass) => pass.passId),
      <String>['p1-native'],
    );
  });

  test('the ids are stable, and belong to no other pass', () {
    final List<String> ids = ocrImagePasses
        .map((OcrImagePass pass) => pass.passId)
        .toList();

    expect(ids.toSet(), hasLength(ids.length), reason: 'one id per pass');
    expect(ocrImagePasses.first.passId, 'p1-native');
    expect(ocrImagePasses.last.passId, 'p4-hi');
  });

  test('a pass asks the decoder for both sides, scaled and never empty', () {
    const ImagePixelSize photo = ImagePixelSize(4032, 3024);

    // The pass that reads the file as it is decodes nothing.
    expect(ocrImagePasses.first.decodeTargetFor(photo), isNull);
    // The design's "about 0.7" and "about 1.4" of the long side: both sides by
    // the same factor, so the long side stays the long side.
    expect(
      const OcrImagePass('p3-lo', longSideScale: 0.7).decodeTargetFor(photo),
      const ImagePixelSize(2822, 2117),
    );
    expect(
      const OcrImagePass('p4-hi', longSideScale: 1.4).decodeTargetFor(photo),
      const ImagePixelSize(5645, 4234),
    );
    // The contrast pass decodes as it is and stretches the bytes.
    expect(
      const OcrImagePass(
        'p2-contrast',
        greyContrast: true,
      ).decodeTargetFor(photo),
      photo,
    );
  });

  test('a target of no pixel is never asked for', () {
    // A one-pixel image scaled down to a tenth rounds to no pixel, which is not
    // an image: the decoder is asked for one pixel instead of none.
    expect(
      const OcrImagePass(
        'p3-lo',
        longSideScale: 0.7,
      ).decodeTargetFor(const ImagePixelSize(1, 1)),
      const ImagePixelSize(1, 1),
    );
    expect(
      const OcrImagePass(
        'p3-lo',
        longSideScale: 0.1,
      ).decodeTargetFor(const ImagePixelSize(9, 4)),
      const ImagePixelSize(1, 1),
    );
  });

  test('a pass says what it is', () {
    expect(
      const OcrImagePass.asTheFileIs('p1-native').toString(),
      'OcrImagePass(p1-native, 1.0x, as the file is)',
    );
    expect(
      const OcrImagePass('p3-lo', longSideScale: 0.7).toString(),
      'OcrImagePass(p3-lo, 0.7x)',
    );
    expect(
      const OcrImagePass('p2-contrast', greyContrast: true).toString(),
      'OcrImagePass(p2-contrast, 1.0x, contrast)',
    );
  });
}
