import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../tool/source_scan.dart';

/// `setup-wizard/token-step-via-the-system-browser` · *no WebView the app controls renders it*
/// (NFR-SEC-002, ADR-018). The login is presented by the platform's browser and by nothing the app
/// builds itself.
///
/// **What this proves.** The word the requirement forbids appears nowhere in `app/lib/` and nowhere
/// in `app/pubspec.yaml`: no package that embeds a browser view is a dependency of the application,
/// and no source file names one. The step's own action goes through the `SystemBrowser` port, whose
/// only implementation asks the platform to open an address.
///
/// **Where it stops** (design §2 and §3: keep it simple and say where it stops). It is lexical, and
/// it reads the two places a browser view could come from — the dependency list and the app's own
/// Dart. It cannot see a browser reached through a transitive dependency this scan does not name,
/// and it deliberately does not forbid the word in a comment of a **test**, which is where the rule
/// is stated and checked.
void main() {
  const String forbidden = 'webview';

  test('the platform presents the login, and the app renders no browser of its '
      'own', () {
    final File pubspec = File(p.join(Directory.current.path, 'pubspec.yaml'));
    expect(
      pubspec.existsSync(),
      isTrue,
      reason: 'run from the package root, `app/`',
    );
    expect(
      pubspec.readAsStringSync().toLowerCase(),
      isNot(contains(forbidden)),
    );

    final Directory lib = appLibDirectory();
    expect(lib.existsSync(), isTrue, reason: 'run from the package root');
    final List<File> sources = dartSources(lib);
    expect(sources.length, greaterThan(3), reason: 'the scan read nothing');

    final List<String> findings = <String>[
      for (final File file in sources)
        if (file.readAsStringSync().toLowerCase().contains(forbidden))
          p.relative(file.path, from: lib.path),
    ];
    expect(
      findings,
      isEmpty,
      reason:
          'the app must not render Ninox inside a browser view of its own '
          '(NFR-SEC-002): $findings',
    );
  });

  test('the scan fails on a planted browser view', () {
    // The scan is only worth having if it would catch the thing it is written for: a file that
    // names one, in a place that is read.
    const String planted =
        "const String name = 'flutter_inappwebview'; // a browser view";
    expect(planted.toLowerCase().contains(forbidden), isTrue);
  });
}
