/// The licence notices of the PDFium binary this application ships.
///
/// **Why they are here.** `pdfrx` renders PDFs with PDFium, and the binary is
/// not built by this project: `pdfium_dart`'s build hook downloads a prebuilt
/// `lib/libpdfium.so` at build time and the APK carries it. Flutter's own
/// `NOTICES` covers Dart packages only, so without this file the binary would be
/// redistributed without the notices its licences require (NFR-LIC-001,
/// `local-config-privacy` · `no-agpl-component-ships` and
/// `product-invariants` · `proprietary-dependencies-declared`).
///
/// **Where the texts come from.** They are the files of the distribution the
/// build actually resolved — release `chromium/7811` of
/// `bblanchon/pdfium-binaries`, whose Android arm64 archive carries
/// `lib/libpdfium.so` — copied byte for byte into `assets/licenses/pdfium/`
/// (`VERSION`, the packaging's `LICENSE`, and the archive's whole `licenses/`
/// directory). Nothing here is written from memory, and nothing is rewritten:
/// one of the notices (`licenses/freetype.txt`) is not valid UTF-8 in the
/// distribution itself, and it is read with its malformed bytes replaced rather
/// than edited.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The asset that names the PDFium build these notices belong to.
const String pdfiumVersionAsset = 'assets/licenses/pdfium/VERSION';

/// The licence files that ship and are shown in the licence page, in the order
/// the distribution lists them.
///
/// The list is written out rather than discovered, because an asset that is not
/// declared in `pubspec.yaml` does not ship and nothing would notice: a test
/// checks that every path here is declared there and exists on disk.
const List<String> pdfiumNoticeAssets = <String>[
  'assets/licenses/pdfium/LICENSE',
  'assets/licenses/pdfium/licenses/abseil.txt',
  'assets/licenses/pdfium/licenses/agg23.txt',
  'assets/licenses/pdfium/licenses/catapult.txt',
  'assets/licenses/pdfium/licenses/cpu_features.txt',
  'assets/licenses/pdfium/licenses/fast_float.txt',
  'assets/licenses/pdfium/licenses/freetype.txt',
  'assets/licenses/pdfium/licenses/icu.txt',
  'assets/licenses/pdfium/licenses/lcms.txt',
  'assets/licenses/pdfium/licenses/libjpeg_turbo.ijg',
  'assets/licenses/pdfium/licenses/libjpeg_turbo.md',
  'assets/licenses/pdfium/licenses/libopenjpeg.txt',
  'assets/licenses/pdfium/licenses/libpng.txt',
  'assets/licenses/pdfium/licenses/libtiff.txt',
  'assets/licenses/pdfium/licenses/libunwind.txt',
  'assets/licenses/pdfium/licenses/llvm-libc.txt',
  'assets/licenses/pdfium/licenses/pdfium.txt',
  'assets/licenses/pdfium/licenses/simdutf.txt',
  'assets/licenses/pdfium/licenses/zlib.txt',
];

/// The name the notices appear under in Flutter's licence page.
const String pdfiumPackageName = 'PDFium';

/// Registers the shipped PDFium notices with Flutter's licence registry.
///
/// It is called once, from `main`, before the application is built: the licence
/// page reads the registry lazily, so registering at start-up is what makes the
/// notices visible to a user who opens it.
///
/// Each notice becomes one entry, prefixed by the path it has inside the
/// distribution, so that a reader of the licence page can tell the packaging's
/// MIT licence from PDFium's own BSD-3-Clause one and from the eighteen bundled
/// third-party notices.
void registerPdfiumLicences() {
  LicenseRegistry.addLicense(() async* {
    final String version = (await _readAsset(pdfiumVersionAsset)).trim();
    for (final String asset in pdfiumNoticeAssets) {
      yield LicenseEntryWithLineBreaks(
        <String>[pdfiumPackageName],
        <String>[
          'PDFium ${_oneLine(version)} — its VERSION file ships beside these '
              'notices.',
          '${_archiveName(asset)}, as distributed with the binary this '
              'application links:',
          '',
          await _readAsset(asset),
        ].join('\n'),
      );
    }
  });
}

/// The path a shipped notice has **inside the PDFium distribution**, which is
/// what a reader comparing the notice with the archive needs.
String _archiveName(String asset) =>
    asset.startsWith(_assetRoot) ? asset.substring(_assetRoot.length) : asset;

/// The asset directory the notices were copied into.
const String _assetRoot = 'assets/licenses/pdfium/';

/// [text] with every whitespace run collapsed to one space, so that a
/// multi-line version file reads as one line in a licence page.
String _oneLine(String text) => text.replaceAll(RegExp(r'\s+'), ' ').trim();

/// Reads one licence asset, tolerating the bytes the distribution ships.
///
/// `rootBundle.loadString` decodes strictly, and one of PDFium's notices is not
/// valid UTF-8 as distributed. A licence notice is not a file this project may
/// rewrite, so the malformed bytes are replaced on the way in instead.
Future<String> _readAsset(String asset) async {
  final ByteData data = await rootBundle.load(asset);
  return utf8.decode(
    data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    allowMalformed: true,
  );
}
