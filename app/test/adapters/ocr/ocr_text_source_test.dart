import 'package:flutter_test/flutter_test.dart';
import 'package:paperdrop/adapters/ocr/ocr_text_source.dart';
import 'package:paperdrop_core/paperdrop_core.dart';

/// The port's own types (`implement-photo-route`, task 1.1).
///
/// **What this proves.** That a pass is a value: its id and its pages, compared
/// by what they hold, with the page list a caller cannot edit behind the
/// adapter's back. That is what makes a pass safe to hand to Core's consensus
/// (T1.5/T2.1), which compares readings from different passes.
///
/// **Where it stops.** It is the port, not an engine: nothing here recognises
/// anything. A port has no behaviour beyond its shapes, and the shapes are what
/// this file fixes.
void main() {
  List<TextPage> onePage() => <TextPage>[
    TextPage(0, 595280, 841890, <PositionedWord>[
      PositionedWord('Gesamtbetrag', 42500, 108750, 118500, 130250),
    ]),
  ];

  test('a pass is its id and its pages', () {
    final OcrPass pass = OcrPass('p1-native', onePage());

    expect(pass.passId, 'p1-native');
    expect(pass.pages, hasLength(1));
    expect(pass.pages.single.hasTextLayer, isTrue);
    expect(pass, OcrPass('p1-native', onePage()));
    expect(pass.hashCode, OcrPass('p1-native', onePage()).hashCode);
    expect(pass, isNot(OcrPass('p2-hi', onePage())));
    expect(pass, isNot(OcrPass('p1-native', <TextPage>[])));
    expect(pass.toString(), 'OcrPass(p1-native, 1 pages)');
  });

  test('a pass holds its pages against a caller', () {
    final List<TextPage> pages = onePage();
    final OcrPass pass = OcrPass('p1-native', pages);

    pages.clear();

    expect(pass.pages, hasLength(1), reason: 'the list is not the caller\'s');
    expect(() => pass.pages.clear(), throwsUnsupportedError);
  });

  test('a failure carries what happened, and what raised it', () {
    const OcrFailure bare = OcrFailure('the document could not be opened');
    expect(bare.reason, 'the document could not be opened');
    expect(bare.cause, isNull);
    expect(bare.toString(), 'OcrFailure: the document could not be opened');

    final OcrFailure withCause = OcrFailure(
      'the page could not be rendered',
      StateError('no engine'),
    );
    expect(withCause.cause, isA<StateError>());
    expect(withCause.toString(), contains('no engine'));
    expect(withCause, isA<Exception>());
  });
}
