import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'source_scan.dart';

/// `platform-document-scanner` · *the app carries no pre-processing of its own*:
/// no perspective correction, no binarisation, and no stage that re-enhances an
/// image the platform scanner already produced.
///
/// **What this scan proves.** Nothing in `app/lib/` imports an image-processing
/// package or calls a low-level codec or pixel routine, and nothing opens a
/// camera. Combined with the one path that produces an image — the platform's
/// document scanner, whose PDF is used as it is (FR-CAP-002, FR-CAP-004) — there
/// is no stage left that could re-enhance, crop or binarise anything.
///
/// **The one decode, and why it is not pre-processing.** The photo route's
/// passes read a photograph more than once — decoded grey-stretched, decoded
/// smaller, decoded larger (`implement-photo-passes`, design §2) — and a decoder
/// is the only way to get those pixels, with no new dependency (design §3:
/// "Dart's image codec"). That decode is allowed **in one file and nowhere
/// else**: `app/lib/adapters/ocr/image_decoder.dart`, which reads an image into
/// memory for recognition. It is not a pre-processing stage of the scenario this
/// scan guards: it writes nothing back to the document, it is applied to the
/// bytes in memory for the length of one recognition, it is never the image the
/// application attaches or shows, and it corrects no perspective, binarises
/// nothing and re-encodes nothing. `binarize`, `perspectiveTransform`,
/// `copyResize`, `encodePng` and `encodeJpg` stay forbidden everywhere,
/// including there, and every other file of `app/lib/` stays forbidden for the
/// decode routines too.
///
/// **Flagged for review.** This narrows a check that used to hold for the whole
/// of `app/lib/`. It was the lane's smallest way to satisfy design §2 and §3
/// without adding a package; the orchestrator and the product owner decide
/// whether the allowance is acceptable, and the alternative — the paths of
/// `adapters/ocr/` excluded in some other way, or a new dependency — is theirs
/// and not this test's.
///
/// **Where it stops** (design §2 and §3: keep it simple and say where it stops).
/// It is lexical: it reads imports and names. It cannot see an image processed
/// through a package it does not know, and it deliberately does not forbid
/// *showing* an image, because the review screen's thumbnail (FR-REV-003, T2.2)
/// is allowed to display one — this scan forbids decoding, re-encoding and
/// pixel work, not display.
void main() {
  /// Packages that would process an image, or present a camera of the app's own
  /// — which FR-CAP-002 forbids outright ("never a raw camera view").
  const List<String> forbiddenPackages = <String>[
    'package:image/',
    'package:image_editor/',
    'package:opencv_dart/',
    'package:flutter_image_compress/',
    'package:edge_detection/',
    'package:camera/',
  ];

  /// Routines that decode, re-encode or touch pixels. `Image.file` and
  /// `Image.memory` are not here: showing a document is not processing it.
  ///
  /// `instantiateImageCodec` and `toByteData` are the two of them that the one
  /// decoder named in [decodeAllowedIn] calls: the first decodes, the second
  /// hands the pixels back. Every other routine below re-encodes, resizes or
  /// rewrites an image, and no part of this application may call one.
  const List<String> forbiddenRoutines = <String>[
    'instantiateImageCodec',
    'decodeImageFromList',
    'encodePng',
    'encodeJpg',
    'copyResize',
    'drawImage',
    'toByteData',
    'binarize',
    'perspectiveTransform',
  ];

  /// The routines [decodeAllowedIn] may call, and only there.
  const List<String> decodingRoutines = <String>[
    'instantiateImageCodec',
    'toByteData',
  ];

  /// The one file of `app/lib/` that may decode a photograph, relative to
  /// `app/lib` with forward slashes.
  const String decodeAllowedIn = 'adapters/ocr/image_decoder.dart';

  const List<String> forbidden = <String>[
    ...forbiddenPackages,
    ...forbiddenRoutines,
  ];

  test('[capture-intake/platform-document-scanner] the app carries no '
      'pre-processing of its own', () {
    final Directory lib = appLibDirectory();
    expect(lib.existsSync(), isTrue, reason: 'run from the package root');

    final List<TokenOccurrence> findings = <TokenOccurrence>[];
    final List<File> sources = dartSources(lib);
    for (final File file in sources) {
      final String relative = p
          .relative(file.path, from: lib.path)
          .replaceAll(r'\', '/');
      final bool decodesHere = relative == decodeAllowedIn;
      findings.addAll(
        findOccurrences(
          file.readAsStringSync(),
          decodesHere
              ? <String>[
                  ...forbiddenPackages,
                  ...forbiddenRoutines.where(
                    (String routine) => !decodingRoutines.contains(routine),
                  ),
                ]
              : forbidden,
          path: relative,
        ),
      );
    }

    expect(
      findings,
      isEmpty,
      reason:
          'image processing in app/lib (FR-CAP-002 forbids it):\n'
          '${findings.join('\n')}',
    );
    expect(sources.length, greaterThan(3), reason: 'the scan read nothing');
  });

  test('the one decode is in the file this scan allows, and nowhere else', () {
    // The allowance is narrow, and this says so: the decoder itself calls the
    // two routines, and a copy of that call in any other file of `app/lib/` is
    // a finding.
    const String decoder = '''
Future<void> decode(Uint8List bytes) async {
  final ui.Codec codec = await ui.instantiateImageCodec(bytes);
  await codec.getNextFrame();
}
''';
    expect(findOccurrences(decoder, decodingRoutines), hasLength(1));

    final Directory lib = appLibDirectory();
    final List<File> sources = dartSources(lib);
    final List<String> callers = <String>[];
    for (final File file in sources) {
      if (findOccurrences(
        file.readAsStringSync(),
        decodingRoutines,
      ).isNotEmpty) {
        callers.add(
          p.relative(file.path, from: lib.path).replaceAll(r'\', '/'),
        );
      }
    }
    expect(callers, <String>[decodeAllowedIn]);
  });

  test('the scan fails on a planted import', () {
    const String planted = '''
import 'package:camera/camera.dart';
import 'package:image/image.dart' as image;

Future<void> process(List<int> bytes) async {
  final image.Image decoded = image.decodeImage(bytes)!;
  final image.Image fixed = image.copyResize(decoded, width: 800);
  final List<int> png = image.encodePng(fixed);
  print(png);
}
''';
    final List<TokenOccurrence> findings = findOccurrences(planted, forbidden);
    expect(findings.map((TokenOccurrence finding) => finding.token), <String>[
      'package:camera/',
      'package:image/',
      'copyResize',
      'encodePng',
    ]);
  });

  test('displaying a document is not processing it', () {
    const String source = '''
import 'package:flutter/material.dart';

class Thumbnail extends StatelessWidget {
  const Thumbnail({super.key, required this.path});

  final String path;

  @override
  Widget build(BuildContext context) => Image.file(File(path));
}
''';
    expect(findOccurrences(source, forbidden), isEmpty);
  });
}
