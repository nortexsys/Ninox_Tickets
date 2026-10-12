import 'package:flutter_test/flutter_test.dart';
import 'package:paperdrop/adapters/ocr/render_passes.dart';

/// Design §3's pass table against the one constant the adapter reads
/// (`implement-photo-route`, task 1.4).
///
/// **What this proves.** That the four passes are the four the design names, in
/// the order it names them, under the ids it names them by, with the
/// resolutions it gives — and that two of those ids are the same strings every
/// run, because a pass that changes its name between runs is a pass consensus
/// cannot compare. The list is the contract the harness reports timings under.
///
/// **Where it stops.** It reads the list itself: that the adapter reads them in
/// this order is
/// `test/adapters/ocr/mlkit_ocr_text_source_test.dart`'s, and what each
/// rendering does to recognition quality is a device screening's (T2.5), not a
/// unit test's.
void main() {
  test('the list is design §3\'s table, in its order', () {
    expect(ocrRenderPasses.map((OcrRenderPass pass) => pass.passId), <String>[
      'p1-native',
      'p2-hi',
      'p3-lo',
      'p4-contrast',
    ]);
    expect(ocrRenderPasses.map((OcrRenderPass pass) => pass.dpi), <int>[
      150,
      200,
      100,
      150,
    ]);
    expect(
      ocrRenderPasses.map((OcrRenderPass pass) => pass.greyContrast),
      <bool>[false, false, false, true],
    );
  });

  test('the ids are stable, and belong to no other pass', () {
    final List<String> ids = ocrRenderPasses
        .map((OcrRenderPass pass) => pass.passId)
        .toList();

    expect(ids.toSet(), hasLength(ids.length), reason: 'one id per pass');
    // A pass is reported by this name and no other, on every run.
    expect(ocrRenderPasses.first.passId, 'p1-native');
    expect(ocrRenderPasses.last.passId, 'p4-contrast');
  });

  test('a pass says what it is', () {
    expect(
      const OcrRenderPass('p1-native', dpi: 150).toString(),
      'OcrRenderPass(p1-native, 150dpi)',
    );
    expect(
      const OcrRenderPass(
        'p4-contrast',
        dpi: 150,
        greyContrast: true,
      ).toString(),
      'OcrRenderPass(p4-contrast, 150dpi, contrast)',
    );
  });
}
