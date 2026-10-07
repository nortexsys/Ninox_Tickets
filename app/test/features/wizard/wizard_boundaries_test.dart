import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// The boundaries the wizard may not cross, read off its own source (design §1, §2 and §3).
///
/// **What this proves.**
///
/// * `wizard_routes.dart` imports nothing from `paperdrop/app/router.dart`: the wizard never reaches
///   into the shell, which is what keeps the capture offer an `onFinished` callback instead of a
///   cycle (design §2).
/// * `package:http` appears in exactly one file of the feature — the composition of design §3 — so
///   no widget, controller or screen can send a request of its own.
/// * `package:url_launcher` appears in exactly one file: the `SystemBrowser` implementation.
/// * `package:flutter_secure_storage` appears in exactly one file: the Keystore store, which is the
///   only place the token is written (FR-CFG-004).
///
/// **Where it stops.** It is lexical, and it reads imports: a symbol reached through a re-export, or
/// a file added under another folder, is outside what it can see. It is the same kind of check as
/// `test/tool/no_image_processing_test.dart`, and it exists because every one of these rules was
/// written down and a rule with no check behind it is only a wish.
void main() {
  /// The wizard's own folder, which is the lane's to write.
  Directory wizardFolder() =>
      Directory(p.join(Directory.current.path, 'lib', 'features', 'wizard'));

  /// Every Dart file under [folder], with its path **inside the folder in POSIX form**, so that the
  /// names the assertions use are the same on every platform.
  Map<String, String> sources(Directory folder) {
    final Map<String, String> files = <String, String>{};
    for (final FileSystemEntity entity in folder.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }
      final String name = p.posix.joinAll(
        p.split(p.relative(entity.path, from: folder.path)),
      );
      files[name] = entity.readAsStringSync();
    }
    return files;
  }

  /// The import lines of one file, as `package:` or relative URIs.
  List<String> imports(String source) => <String>[
    for (final String line in source.split('\n'))
      if (line.startsWith('import ')) line,
  ];

  test('the wizard imports no route of the shell', () {
    final Directory folder = wizardFolder();
    expect(folder.existsSync(), isTrue, reason: 'run from the package root');

    for (final MapEntry<String, String> file in sources(folder).entries) {
      for (final String line in imports(file.value)) {
        expect(
          line.contains('app/router.dart'),
          isFalse,
          reason:
              '${file.key} imports the shell\'s router: the wizard tells the '
              'router it is finished through a callback instead (design §2)',
        );
      }
    }
  });

  test('http, url_launcher and the keystore are each in exactly one file', () {
    // The three dependencies the orchestrator declared for this change, and the one file each of
    // them may appear in (design §1, §3, §4).
    const Map<String, String> onlyIn = <String, String>{
      'package:http/': 'data/port_factory.dart',
      'package:url_launcher/': 'token/system_browser.dart',
      'package:flutter_secure_storage/': 'data/keystore_token_store.dart',
    };
    final Map<String, String> files = sources(wizardFolder());
    expect(
      files.length,
      greaterThan(8),
      reason: 'the scan read almost nothing, so it proves almost nothing',
    );

    for (final MapEntry<String, String> notAllowed in onlyIn.entries) {
      final List<String> found = <String>[
        for (final MapEntry<String, String> file in files.entries)
          if (file.value.contains(notAllowed.key)) file.key,
      ];
      expect(
        found,
        <String>[notAllowed.value],
        reason:
            '${notAllowed.key} may appear in ${notAllowed.value} and nowhere '
            'else in the wizard',
      );
    }
  });

  test('every file of the wizard is a file this test read', () {
    // A file added later is read by the two scans above the moment it exists; this test states the
    // inventory so that a scan over an empty folder cannot pass unnoticed.
    final List<String> names = sources(wizardFolder()).keys.toList()..sort();
    expect(names, contains('wizard_routes.dart'));
    expect(names, contains('wizard_controller.dart'));
    expect(names, contains('data/keystore_token_store.dart'));
    expect(names, contains('token/token_screen.dart'));
    expect(names, contains('choose/choose_screen.dart'));
  });
}
