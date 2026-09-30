import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'source_scan.dart';

/// `all-user-facing-strings-are-externalised` · *no string is hardcoded*:
/// no user-facing text outside the string resources.
///
/// **What this scan does.** It reads every Dart file of `app/lib/` except the
/// generated string resources, masks the comments, and reports any string
/// literal that is passed directly to one of [userFacingTokens] — `Text(`,
/// `Text.rich(`, `semanticsLabel:`, `tooltip:`, `label:`, `SnackBar(`,
/// `title:`, `onGenerateTitle:`, `hintText:`, `helperText:`, `labelText:`,
/// `message:`.
///
/// **What it cannot see** (design §2: keep it simple and say where it stops):
/// it is lexical, so it finds the literal in the argument position it knows and
/// not one reached through a variable, a spread or an interpolation inside a
/// list; and it reads names, so a user-facing constructor added later has to be
/// added to [userFacingTokens] in the same commit. It proves the absence of
/// literals, not the presence of translations.
void main() {
  test('[local-config-privacy/all-user-facing-strings-are-externalised] '
      'no string is hardcoded', () {
    final Directory lib = appLibDirectory();
    expect(lib.existsSync(), isTrue, reason: 'run from the package root');

    final List<HardcodedLiteral> findings = <HardcodedLiteral>[];
    for (final File file in dartSources(lib)) {
      // The generated localisations are the string resources themselves.
      if (p.split(file.path).contains('generated')) {
        continue;
      }
      findings.addAll(
        findHardcodedLiterals(
          file.readAsStringSync(),
          path: p.relative(file.path, from: lib.path),
        ),
      );
    }

    expect(
      findings,
      isEmpty,
      reason:
          'user-facing text outside app/lib/l10n/app_en.arb:\n'
          '${findings.join('\n')}',
    );
    // A scan over nothing would pass too, so say what it read.
    expect(dartSources(lib).length, greaterThan(3));
  });

  test('the scan fails on a planted literal', () {
    const String planted = '''
import 'package:flutter/material.dart';

class Planted extends StatelessWidget {
  const Planted({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        // A comment naming Text('not code') is not a finding.
        child: Text('Scan a document'),
      ),
    );
  }
}
''';
    final List<HardcodedLiteral> findings = findHardcodedLiterals(planted);
    expect(findings, hasLength(1));
    expect(findings.single.line, 11);
    expect(findings.single.token, 'Text(');
    expect(findings.single.excerpt, contains('Scan a document'));
  });

  test('a label read from the resources is not a finding', () {
    const String source = '''
import 'package:flutter/material.dart';
import 'package:paperdrop/l10n/generated/app_localizations.dart';

class Fine extends StatelessWidget {
  const Fine({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.appTitle)),
      body: Column(
        children: <Widget>[
          Text(
            l10n.captureHeadline,
          ),
          FilledButton(
            onPressed: () {},
            child: Text(l10n.captureScanAction),
          ),
        ],
      ),
    );
  }
}
''';
    expect(findHardcodedLiterals(source), isEmpty);
  });

  test('the masker keeps offsets and drops comments', () {
    const String source = "a // Text('x')\nb /* Text('y') */ c\n";
    final String masked = maskComments(source);
    expect(masked.length, source.length);
    expect(masked.split('\n').length, source.split('\n').length);
    expect(masked.contains('Text('), isFalse);
    expect(findHardcodedLiterals(source), isEmpty);
  });
}
