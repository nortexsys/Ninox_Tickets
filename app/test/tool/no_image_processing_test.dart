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
      findings.addAll(
        findOccurrences(
          file.readAsStringSync(),
          forbidden,
          path: p.relative(file.path, from: lib.path),
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
