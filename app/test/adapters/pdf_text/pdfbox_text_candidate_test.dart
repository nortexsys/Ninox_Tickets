import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperdrop/adapters/pdf_text/pdf_text_candidate.dart';
import 'package:paperdrop/adapters/pdf_text/pdfbox_text_candidate.dart';

/// Candidate A of ADR-011 on the Dart side (`close-adr-011-pdf-text-route`,
/// task 1.1: "a unit test of the Dart side parses a channel reply").
///
/// **What this proves.** The channel boundary: that the call carries the path
/// and the method the Kotlin side answers on, that a reply of design §2's shape
/// becomes [CandidatePage]s and [CandidateWord]s with the numbers the platform
/// sent, and that a reply of any other shape fails loudly instead of becoming a
/// document that yielded no words.
///
/// **Where it stops.** It parses a reply; it does not produce one. PdfBox-Android
/// is a JVM library inside the application process, so the reading itself runs
/// on a device and nowhere else — the note under task 1.4 says so, and the
/// channel reply mocked here is the one that device run would answer with.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel(PdfBoxTextCandidate.channelName);
  final List<MethodCall> calls = <MethodCall>[];

  void answer(Object? reply) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
          calls.add(call);
          return reply;
        });
  }

  setUp(calls.clear);

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  /// A reply with one page and two words, in the shape the Kotlin channel
  /// answers with (design §2).
  Map<String, Object?> onePage() => <String, Object?>{
    'tool': PdfBoxTextCandidate.toolName,
    'pages': <Object?>[
      <String, Object?>{
        'index': 0,
        'width': 595.28,
        'height': 841.89,
        'words': <Object?>[
          <String, Object?>{
            'text': 'Gesamtbetrag',
            'x0': 42.5,
            'x1': 108.75,
            'top': 120.0,
            'bottom': 130.5,
          },
          <String, Object?>{
            'text': '1.234,50',
            'x0': 320.0,
            'x1': 366.25,
            'top': 120.0,
            'bottom': 130.5,
          },
        ],
      },
    ],
  };

  test('the call names the method and carries the path', () async {
    answer(onePage());
    await const PdfBoxTextCandidate().read(
      '/data/user/0/app/files/invoice.pdf',
    );

    expect(calls, hasLength(1));
    expect(calls.single.method, PdfBoxTextCandidate.readWordsMethod);
    expect(calls.single.arguments, <String, Object?>{
      'path': '/data/user/0/app/files/invoice.pdf',
    });
  });

  test('a page of words arrives with the numbers the platform sent', () async {
    answer(onePage());
    final List<CandidatePage> pages = await const PdfBoxTextCandidate().read(
      '/tmp/invoice.pdf',
    );

    expect(pages, hasLength(1));
    final CandidatePage page = pages.single;
    expect(page.index, 0);
    expect(page.width, 595.28);
    expect(page.height, 841.89);
    expect(page.words.map((CandidateWord word) => word.text), <String>[
      'Gesamtbetrag',
      '1.234,50',
    ]);

    final CandidateWord label = page.words.first;
    expect(label.x0, 42.5);
    expect(label.x1, 108.75);
    expect(label.top, 120.0);
    expect(label.bottom, 130.5);
    // Top-left origin, as design §2 fixes it: the top of a box is above its
    // bottom, which is the opposite of a PDF's own bottom-left coordinates.
    expect(label.top, lessThan(label.bottom));

    expect(const PdfBoxTextCandidate().tool, 'pdfbox-android 2.0.27.0');
  });

  test('a page with no word is a page with no word, not a failure', () async {
    answer(<String, Object?>{
      'tool': PdfBoxTextCandidate.toolName,
      'pages': <Object?>[
        <String, Object?>{
          'index': 0,
          'width': 595.28,
          'height': 841.89,
          'words': <Object?>[],
        },
      ],
    });

    final List<CandidatePage> pages = await const PdfBoxTextCandidate().read(
      '/tmp/scanned.pdf',
    );
    expect(pages.single.words, isEmpty);
  });

  test('a reply of another shape fails loudly', () async {
    for (final Object? broken in <Object?>[
      'not a map',
      <String, Object?>{'tool': PdfBoxTextCandidate.toolName},
      <String, Object?>{
        'tool': PdfBoxTextCandidate.toolName,
        'pages': <Object?>['not a page'],
      },
      <String, Object?>{
        'tool': PdfBoxTextCandidate.toolName,
        'pages': <Object?>[
          <String, Object?>{'index': 0, 'width': 1.0, 'height': 1.0},
        ],
      },
      <String, Object?>{
        'tool': PdfBoxTextCandidate.toolName,
        'pages': <Object?>[
          <String, Object?>{
            'index': 0,
            'width': 1.0,
            'height': 1.0,
            'words': <Object?>[
              <String, Object?>{
                'text': 'x',
                'x0': 'left',
                'x1': 1.0,
                'top': 0.0,
                'bottom': 1.0,
              },
            ],
          },
        ],
      },
    ]) {
      answer(broken);
      await expectLater(
        const PdfBoxTextCandidate().read('/tmp/invoice.pdf'),
        throwsA(isA<PdfTextReplyFormatException>()),
      );
    }
  });

  test('a reply that names another library is refused', () async {
    // A stale APK would otherwise be measured under this build's name.
    answer(<String, Object?>{
      'tool': 'pdfbox-android 2.0.24.0',
      'pages': <Object?>[],
    });

    await expectLater(
      const PdfBoxTextCandidate().read('/tmp/invoice.pdf'),
      throwsA(
        isA<PdfTextReplyFormatException>().having(
          (PdfTextReplyFormatException failure) => failure.reason,
          'reason',
          contains('pdfbox-android 2.0.24.0'),
        ),
      ),
    );
  });
}
