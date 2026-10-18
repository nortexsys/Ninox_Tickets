/// What the six groups of the negative release checklist share (Funcional §10.6).
///
/// §10.6 requires that *every non-goal of §1.2 has a negative test in the release checklist*:
/// no backend call, no schema mutation, no credential beyond the token, no unmapped write, no
/// telemetry artefact, no mail-body byte. This library holds the three things those six test
/// files need and none of them should reimplement:
///
/// * **where the shipped code is** — [repoRoot] and [shippedSources], so a scan reads `app/lib`
///   and every `packages/*/lib` no matter whether the runner started in `app/` or in the
///   repository root;
/// * **the scans** — [occurrencesIn] and [literalsIn] over sources whose comments are already
///   masked by `app/test/tool/source_scan.dart`, the lexical reader this repository already
///   uses for its guards, plus the two-directional allowlist helpers [unauthorised] and
///   [unmatchedEntries], so that an allowlist entry which no longer matches anything fails
///   instead of quietly widening;
/// * **[RecordingHttpOverrides]** — an `HttpOverrides` that records every attempt to open a
///   connection and refuses it, which is how a test proves a code path makes *no* outbound call
///   and how one proves the guard itself is not vacuous.
///
/// **Where the scans stop.** They are lexical, not an analyzer: they read names and literals,
/// never types. A network client reached through a name this file does not list would not be
/// found, and every test says so in its own doc comment. What they do catch is the failure mode
/// the checklist exists for — the next lane adding a dependency, a host or a log line.
library;

import 'dart:io';

import 'package:paperdrop/adapters/storage/app_storage.dart';
import 'package:path/path.dart' as p;

import '../../app/test/tool/source_scan.dart';

export '../../app/test/history/history_fixtures.dart'
    show aDocId, aDocumentHash, anEntry;
export '../../app/test/tool/source_scan.dart'
    show TokenOccurrence, dartSources, findOccurrences, maskComments;
export '../../packages/ninox_client/test/send/fake_ninox_port.dart'
    show FakeNinoxPort;
export '../../packages/ninox_client/test/send/send_harness.dart'
    show SendHarness, storedFile, testRef, testRequest;

/// The repository root: the folder holding `openspec/` and `packages/`.
///
/// Found by walking up from the working directory, because the checklist runs as
/// `flutter test ../validation/release_checklist` from `app/` — a working directory two levels
/// below the root — and must not depend on which of the two it was started from.
Directory repoRoot() {
  Directory directory = Directory.current.absolute;
  while (true) {
    final bool hasSpecs = Directory(p.join(directory.path, 'openspec'))
        .existsSync();
    final bool hasPackages = Directory(p.join(directory.path, 'packages'))
        .existsSync();
    if (hasSpecs && hasPackages) {
      return directory;
    }
    final Directory parent = directory.parent;
    if (parent.path == directory.path) {
      throw StateError(
        'the repository root was not found from ${Directory.current.path}',
      );
    }
    directory = parent;
  }
}

/// [relative] as a repository-relative path with forward slashes, which is what an allowlist
/// and a failure message quote.
String repositoryPath(String relative) =>
    p.relative(relative, from: repoRoot().path).replaceAll(r'\', '/');

/// The repository-relative path of [file].
String pathOf(File file) =>
    p.relative(file.path, from: repoRoot().path).replaceAll(r'\', '/');

/// A file of the repository, by its repository-relative path.
File fileAt(String relativePath) =>
    File(p.join(repoRoot().path, p.joinAll(relativePath.split('/'))));

/// Every Dart source the product ships, in path order: `app/lib` and each `packages/*/lib`.
///
/// Tests and tooling are deliberately outside it. The checklist is about what is in the build a
/// user installs, and a test's own helper is not.
List<File> shippedSources() {
  final Directory root = repoRoot();
  final List<File> files = <File>[
    ...dartSources(Directory(p.join(root.path, 'app', 'lib'))),
  ];
  final Directory packages = Directory(p.join(root.path, 'packages'));
  for (final Directory package in packages.listSync().whereType<Directory>()) {
    final Directory lib = Directory(p.join(package.path, 'lib'));
    if (lib.existsSync()) {
      files.addAll(dartSources(lib));
    }
  }
  files.sort((File a, File b) => pathOf(a).compareTo(pathOf(b)));
  return files;
}

/// Every `pubspec.yaml` of the workspace: the root, the application and each package.
///
/// A dependency is declared in one of these files, so a scan for a package a release must not
/// carry starts here.
List<File> pubspecFiles() {
  final List<File> files = <File>[
    fileAt('pubspec.yaml'),
    fileAt('app/pubspec.yaml'),
  ];
  for (final Directory package in Directory(
    '${repoRoot().path}/packages',
  ).listSync().whereType<Directory>()) {
    final File pubspec = File('${package.path}/pubspec.yaml');
    if (pubspec.existsSync()) {
      files.add(pubspec);
    }
  }
  files.sort((File a, File b) => pathOf(a).compareTo(pathOf(b)));
  return files;
}

/// Every occurrence of [tokens] in [sources], with comments excluded.
List<TokenOccurrence> occurrencesIn(
  Iterable<File> sources,
  List<String> tokens,
) {
  final List<TokenOccurrence> found = <TokenOccurrence>[];
  for (final File file in sources) {
    found.addAll(
      findOccurrences(file.readAsStringSync(), tokens, path: pathOf(file)),
    );
  }
  return found;
}

/// A string literal of a source, as a [TokenOccurrence]: [TokenOccurrence.token] is the
/// literal's content and [TokenOccurrence.excerpt] the source line it sits on.
///
/// Raw strings (`r'…'`) and both quote characters are read; a triple-quoted literal is read as
/// one literal. Comments are masked first, so a host name written in a doc comment is not a
/// finding — the scans are about code, and the design of each group says what that leaves out.
List<TokenOccurrence> literalsIn(File file) {
  final String masked = maskComments(file.readAsStringSync());
  final String path = pathOf(file);
  final List<TokenOccurrence> found = <TokenOccurrence>[];
  int i = 0;
  while (i < masked.length) {
    final String c = masked[i];
    final bool raw =
        c == 'r' &&
        i + 1 < masked.length &&
        (masked[i + 1] == "'" || masked[i + 1] == '"');
    if (c != "'" && c != '"' && !raw) {
      i++;
      continue;
    }
    final int start = i;
    if (raw) {
      i++;
    }
    final String quote = masked[i];
    final String delimiter = masked.startsWith(quote * 3, i)
        ? quote * 3
        : quote;
    i += delimiter.length;
    final int contentStart = i;
    while (i < masked.length) {
      if (!raw && masked[i] == r'\' && i + 1 < masked.length) {
        i += 2;
        continue;
      }
      if (masked.startsWith(delimiter, i)) {
        break;
      }
      i++;
    }
    final String content = masked.substring(
      contentStart,
      i > masked.length ? masked.length : i,
    );
    found.add(
      TokenOccurrence(
        path: path,
        line: '\n'.allMatches(masked.substring(0, start)).length + 1,
        token: content,
        excerpt: masked
            .substring(start, i + 1 > masked.length ? masked.length : i + 1)
            .split('\n')
            .first,
      ),
    );
    i += delimiter.length;
  }
  return found;
}

/// The key an allowlist uses: the file and the text that identifies the occurrence.
String allowlistKey(String path, String token) => '$path|$token';

/// The findings [allowlist] does not authorise, as readable lines.
///
/// [allowlist] maps `path|token` to the reason the occurrence is allowed, so an entry is a claim
/// a reviewer can argue with rather than a pattern that silences a file.
List<String> unauthorised(
  List<TokenOccurrence> found,
  Map<String, String> allowlist,
) => <String>[
  for (final TokenOccurrence finding in found)
    if (!allowlist.containsKey(allowlistKey(finding.path, finding.token)))
      '$finding',
];

/// The entries of [allowlist] that no finding matched: a stale entry proves nothing and is
/// itself a failure of the checklist, exactly as `privacy_check.py` treats one.
List<String> unmatchedEntries(
  List<TokenOccurrence> found,
  Map<String, String> allowlist,
) {
  final Set<String> seen = <String>{
    for (final TokenOccurrence finding in found)
      allowlistKey(finding.path, finding.token),
  };
  return <String>[
    for (final String key in allowlist.keys)
      if (!seen.contains(key)) key,
  ];
}

/// One attempt to open an outbound connection, as [RecordingHttpOverrides] saw it.
final class HttpAttempt {
  /// Records the verb and the address of one attempt.
  const HttpAttempt({required this.method, required this.uri});

  /// The HTTP verb the client was about to use.
  final String method;

  /// The address it was about to reach.
  final Uri uri;

  @override
  String toString() => '$method $uri';
}

/// An `HttpOverrides` that records every attempt to open a connection and refuses to make one.
///
/// Two things depend on it. A path that must not touch the network is run inside
/// `HttpOverrides.runZoned(…, createHttpClient: guard)` and proved by [attempts] and
/// [clientsCreated] staying empty — nothing beneath `package:http` reaches the real
/// `HttpClient`, because the factory is this one. And the guard is proved **not vacuous** by a
/// path that legitimately does reach out (the classic adapter on its configured host): it is
/// seen, with the verb and the address, and refused.
final class RecordingHttpOverrides extends HttpOverrides {
  /// Every connection an `HttpClient` of this zone tried to open, in order.
  final List<HttpAttempt> attempts = <HttpAttempt>[];

  /// How many clients were built at all. A path that builds none could not have called out,
  /// which is a second, independent way of reading the same answer.
  int clientsCreated = 0;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    clientsCreated++;
    return _RecordingHttpClient(this);
  }
}

/// The client [RecordingHttpOverrides] hands out: it records the attempt and refuses it.
///
/// `package:http` asks an `HttpClient` for `openUrl` (and, for an abortable request, `open`),
/// which is the one call that leaves the process. The rest of the interface is answered by
/// [noSuchMethod], which throws: a test that reached this object any other way is failing
/// loudly rather than silently passing.
final class _RecordingHttpClient implements HttpClient {
  _RecordingHttpClient(this._guard);

  final RecordingHttpOverrides _guard;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #openUrl || invocation.memberName == #open) {
      final List<Object?> arguments = invocation.positionalArguments;
      _guard.attempts.add(
        HttpAttempt(method: arguments[0]! as String, uri: arguments[1]! as Uri),
      );
    }
    throw const SocketException(
      'the release checklist refuses every outbound connection',
    );
  }
}

/// Storage over a directory a test owns, so that no device and no plugin is needed to exercise a
/// path that writes a file — the configuration export and the intake store.
final class TemporaryStorage implements AppStorage {
  /// Wraps one directory: the caller creates it and deletes it.
  const TemporaryStorage(this.root);

  /// The documents directory this storage answers with.
  final Directory root;

  @override
  Future<Directory> documentsDirectory() async => root;
}
