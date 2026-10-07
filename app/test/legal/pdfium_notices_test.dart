import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperdrop/legal/pdfium_notices.dart';
import 'package:path/path.dart' as p;

/// The PDFium notices that ship (`close-adr-011-pdf-text-route`, task 2.4;
/// NFR-LIC-001, `local-config-privacy` · `no-agpl-component-ships`).
///
/// **What this proves.** That the notices of the PDFium binary are **in the
/// build** and not only in the repository: every file the registration names
/// exists on disk *and* is declared as an asset in `pubspec.yaml`, the registry
/// yields one entry per notice under the package name `PDFium`, the packaging's
/// MIT licence and PDFium's own BSD-3-Clause licence are both among them, and
/// Flutter's licence page lists them for a user who opens it.
///
/// **Where it stops.** It cannot prove that the texts are the distribution's
/// own: that is what reading them out of the resolved archive was for, and the
/// copy is byte-for-byte (`VERSION` says which build they belong to). A test
/// over file contents would only repeat what was copied.
void main() {
  test('every notice is an asset that ships, declared in pubspec.yaml', () {
    final String pubspec = File(p.join(Directory.current.path, 'pubspec.yaml'))
        .readAsStringSync();

    for (final String asset in <String>[
      pdfiumVersionAsset,
      ...pdfiumNoticeAssets,
    ]) {
      expect(
        File(p.join(Directory.current.path, asset)).existsSync(),
        isTrue,
        reason: '$asset is named by the registration and is not on disk',
      );
      expect(
        pubspec.contains(asset) || pubspec.contains(_directoryOf(asset)),
        isTrue,
        reason:
            '$asset is named by the registration and no asset declaration in '
            'pubspec.yaml covers it, so it would not ship',
      );
    }
    // The version file is not a licence and is not registered, but it ships: it
    // is what tells a reader of the notices which PDFium build they belong to.
    expect(pdfiumNoticeAssets, isNot(contains(pdfiumVersionAsset)));
    expect(pdfiumNoticeAssets, hasLength(19));
  });

  test('the registry yields the notices, under the PDFium name', () async {
    registerPdfiumLicences();

    final List<LicenseEntry> pdfium = <LicenseEntry>[];
    await for (final LicenseEntry entry in LicenseRegistry.licenses) {
      if (entry.packages.contains(pdfiumPackageName)) {
        pdfium.add(entry);
      }
    }

    expect(
      pdfium,
      hasLength(pdfiumNoticeAssets.length),
      reason: 'one entry per notice that ships',
    );

    final String all = pdfium
        .expand((LicenseEntry entry) => entry.paragraphs)
        .map((LicenseParagraph paragraph) => paragraph.text)
        .join('\n');
    // The packaging's own MIT licence, PDFium's BSD-3-Clause licence, and the
    // version the whole set belongs to. The registry re-wraps the text, so the
    // version is compared with its whitespace collapsed rather than line by
    // line.
    expect(all, contains('Benoit Blanchon'));
    expect(all, contains('The PDFium Authors'));
    final String version = File(
      p.join(Directory.current.path, pdfiumVersionAsset),
    ).readAsStringSync().trim();
    expect(_collapsed(all), contains(_collapsed(version)));
    expect(all, contains('VERSION'));
    // Every notice names the path it has inside the distribution, so a reader
    // can tell them apart.
    expect(all, contains('licenses/pdfium.txt'));
    expect(all, contains('LICENSE'));
  });

  testWidgets('the licence page lists them', (WidgetTester tester) async {
    registerPdfiumLicences();

    await tester.pumpWidget(const MaterialApp(home: LicensePage()));
    await tester.pumpAndSettle();

    // What a user sees: the package the notices are registered under, in
    // Flutter's own licence page. Opening it is Flutter's behaviour, not this
    // test's.
    expect(find.text(pdfiumPackageName), findsOneWidget);
  });
}

/// [text] with every whitespace run collapsed to one space.
String _collapsed(String text) => text.replaceAll(RegExp(r'\s+'), ' ').trim();

String _directoryOf(String asset) =>
    '${asset.substring(0, asset.lastIndexOf('/'))}/';
