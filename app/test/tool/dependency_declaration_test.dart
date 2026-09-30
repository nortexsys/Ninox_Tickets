import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// The dependency declaration of `app/README.md` against the build that exists
/// (NFR-LIC-001, `setup-mvp-foundations` §9).
///
/// **What this proves.** Every direct dependency of `app/pubspec.yaml` is named
/// in the declaration, the version the declaration states is the version the
/// workspace resolved (`pubspec.lock`), and no declared licence is AGPL or GPL —
/// which is the done-when of task 1.6.
///
/// **Where it stops.** It reads the declaration as text: a row whose licence
/// cell says something the licence is not would still pass. Licences are checked
/// by reading the package's own `LICENSE` when the dependency is added, and the
/// orchestrator reviews them; this test keeps the table from falling behind the
/// code, which is the failure mode the design names.
void main() {
  late File pubspec;
  late File readme;

  setUpAll(() {
    final String app = Directory.current.path;
    pubspec = File(p.join(app, 'pubspec.yaml'));
    readme = File(p.join(app, 'README.md'));
    expect(pubspec.existsSync(), isTrue, reason: 'run from the package root');
    expect(readme.existsSync(), isTrue);
  });

  test('every direct dependency is declared, and no licence is AGPL or GPL', () {
    final Map<String, String> direct = _directDependencies(
      pubspec.readAsStringSync(),
    );
    expect(
      direct.keys,
      isNotEmpty,
      reason: 'the pubspec parse found nothing, so it proves nothing',
    );

    final List<_Declaration> declared = _declarations(
      readme.readAsStringSync(),
    );
    final Map<String, String> resolved = _resolvedVersions(
      File(p.join(Directory.current.path, '..', 'pubspec.lock'))
          .readAsStringSync(),
    );

    final Set<String> names = declared
        .map((_Declaration row) => row.name)
        .toSet();

    for (final MapEntry<String, String> dependency in direct.entries) {
      // Our own packages live in this repository under the same licence as it,
      // and are not third-party dependencies of the application.
      if (dependency.value.startsWith('path:')) {
        continue;
      }
      expect(
        names,
        contains(dependency.key),
        reason: '${dependency.key} is in pubspec.yaml and not in the table',
      );
    }

    for (final _Declaration row in declared) {
      expect(
        row.licence.toUpperCase().contains('GPL'),
        isFalse,
        reason: '${row.name} declares the licence ${row.licence}',
      );
      if (row.version != null) {
        expect(
          row.version,
          resolved[row.name],
          reason:
              'the table says ${row.name} ${row.version}; the workspace '
              'resolved ${resolved[row.name]}',
        );
      }
    }

    // The three the lane added, named here so that deleting a row fails loudly.
    expect(
      names,
      containsAll(<String>[
        'go_router',
        'crypto',
        'file_picker',
        'share_handler',
        'google_mlkit_document_scanner',
      ]),
    );
  });

  test('the parser reads a row and its licence', () {
    const String table = '''
| Dependency | Used for | Licence | Proprietary |
| --- | --- | --- | --- |
| `example` 1.2.3, with `example_platform` 0.1.0 | something | BSD-3-Clause | No |
| `other` | something else | AGPL-3.0 | No |
''';
    final List<_Declaration> rows = _declarations(table);
    expect(rows, hasLength(2));
    expect(rows.first.name, 'example');
    expect(rows.first.version, '1.2.3');
    expect(rows.first.licence, 'BSD-3-Clause');
    expect(rows.last.name, 'other');
    expect(rows.last.version, isNull);
    expect(rows.last.licence, 'AGPL-3.0');
  });
}

/// The direct dependencies of a pubspec: those under `dependencies:`, before
/// `dev_dependencies:`. Enough for a file Flutter generates and this project
/// edits by hand. The value is what follows the colon — `sdk: flutter`,
/// `path: ../packages/…` or a version constraint.
Map<String, String> _directDependencies(String pubspec) {
  final Map<String, String> dependencies = <String, String>{};
  bool inDependencies = false;
  String? pending;
  for (final String line in pubspec.split('\n')) {
    if (line.startsWith('dependencies:')) {
      inDependencies = true;
      continue;
    }
    if (line.startsWith('dev_dependencies:')) {
      inDependencies = false;
      continue;
    }
    if (!inDependencies || line.trim().isEmpty || line.startsWith('  #')) {
      continue;
    }
    final RegExpMatch? name = RegExp(r'^  ([a-z0-9_]+):').firstMatch(line);
    if (name != null) {
      pending = name.group(1)!;
      final String rest = line.substring(name.end).trim();
      dependencies[pending] = rest.isEmpty ? '(nested)' : rest;
      continue;
    }
    // A nested source: `    path: ../packages/paperdrop_core`, `    sdk: flutter`.
    final RegExpMatch? nested = RegExp(r'^    (path|sdk): (.+)$')
        .firstMatch(line);
    if (nested != null && pending != null) {
      dependencies[pending] = '${nested.group(1)}: ${nested.group(2)!.trim()}';
    }
  }
  return dependencies;
}

/// The rows of the declaration table: the package the row names first, its
/// version when it states one, and the licence cell.
List<_Declaration> _declarations(String readme) {
  final List<_Declaration> rows = <_Declaration>[];
  for (final String line in readme.split('\n')) {
    if (!line.startsWith('|')) {
      continue;
    }
    final List<String> raw = line.split('|').skip(1).toList();
    if (raw.isNotEmpty && raw.last.trim().isEmpty) {
      // The table's closing pipe.
      raw.removeLast();
    }
    final List<String> cells = raw.map((String cell) => cell.trim()).toList();
    if (cells.length < 4) {
      continue;
    }
    final String first = cells.first;
    final String licence = cells[2];
    if (first == 'Dependency' || first.startsWith('---')) {
      continue;
    }
    final RegExpMatch? name = RegExp(r'`([a-z0-9_]+)`').firstMatch(first);
    if (name == null) {
      continue;
    }
    final RegExpMatch? version = RegExp(
      '`${name.group(1)}`\\s+(\\d+\\.\\d+\\.\\d+[^ ,]*)',
    ).firstMatch(first);
    rows.add(
      _Declaration(
        name: name.group(1)!,
        version: version?.group(1),
        licence: licence,
      ),
    );
  }
  return rows;
}

/// The versions the workspace resolved, from `pubspec.lock`.
///
/// A pub workspace has one lock file, at its root: this is `app/`'s parent.
Map<String, String> _resolvedVersions(String lock) {
  final Map<String, String> versions = <String, String>{};
  String? current;
  for (final String line in lock.split('\n')) {
    final RegExpMatch? package = RegExp(r'^  ([a-z0-9_]+):$').firstMatch(line);
    if (package != null) {
      current = package.group(1);
      continue;
    }
    final RegExpMatch? version = RegExp(r'^    version: "([^"]+)"')
        .firstMatch(line);
    if (version != null && current != null) {
      versions[current] = version.group(1)!;
      current = null;
    }
  }
  return versions;
}

/// One row of the declaration table.
class _Declaration {
  const _Declaration({
    required this.name,
    required this.version,
    required this.licence,
  });

  final String name;
  final String? version;
  final String licence;
}
