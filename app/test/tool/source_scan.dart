import 'dart:io';

import 'package:path/path.dart' as p;

/// A source reader for the two scans of design §2 and §3: the scan for
/// hardcoded user-facing strings, and the scan for image processing.
///
/// It is deliberately small and lexical, not an analyzer: it edits no source and
/// it needs no build. **Its limits are real and are stated at each use** — it
/// reads names, not types, so a literal passed to a constructor this list does
/// not name is not found.

/// Every constructor or named argument in `app/lib/` whose first argument is
/// user-facing text, and which therefore may not hold a string literal.
///
/// The five of design §2 first; the rest are the ones the shell of T1.12 and the
/// capture screens of T1.13 actually use, so that the scan covers every
/// user-facing constructor this application has (design §2: the scenario is
/// tagged only if it does).
const List<String> userFacingTokens = <String>[
  'Text(',
  'Text.rich(',
  'semanticsLabel:',
  'tooltip:',
  'label:',
  'SnackBar(',
  'title:',
  'onGenerateTitle:',
  'hintText:',
  'helperText:',
  'labelText:',
  'message:',
];

/// One string literal found where a user-facing string belongs.
class HardcodedLiteral {
  const HardcodedLiteral({
    required this.path,
    required this.line,
    required this.token,
    required this.excerpt,
  });

  final String path;
  final int line;
  final String token;
  final String excerpt;

  @override
  String toString() => '$path:$line: $token $excerpt';
}

/// Returns [source] with every comment replaced by spaces, so that offsets and
/// line numbers survive and a constructor named inside a comment is not read as
/// code.
///
/// String literals are copied verbatim, including their `//` and `/*`, because
/// the text inside them is exactly what the scan is looking for.
String maskComments(String source) {
  final StringBuffer out = StringBuffer();
  int i = 0;
  while (i < source.length) {
    final String c = source[i];
    if (c == '/' && i + 1 < source.length && source[i + 1] == '/') {
      while (i < source.length && source[i] != '\n') {
        out.write(' ');
        i++;
      }
      continue;
    }
    if (c == '/' && i + 1 < source.length && source[i + 1] == '*') {
      out.write('  ');
      i += 2;
      while (i < source.length &&
          !(source[i] == '*' &&
              i + 1 < source.length &&
              source[i + 1] == '/')) {
        out.write(source[i] == '\n' ? '\n' : ' ');
        i++;
      }
      if (i < source.length) {
        out.write('  ');
        i += 2;
      }
      continue;
    }
    final bool raw =
        c == 'r' &&
        i + 1 < source.length &&
        (source[i + 1] == "'" || source[i + 1] == '"');
    if (c == "'" || c == '"' || raw) {
      if (raw) {
        out.write('r');
        i++;
      }
      final String quote = source[i];
      final String delimiter = source.startsWith(quote * 3, i)
          ? quote * 3
          : quote;
      out.write(delimiter);
      i += delimiter.length;
      while (i < source.length) {
        if (!raw && source[i] == r'\' && i + 1 < source.length) {
          out.write(source.substring(i, i + 2));
          i += 2;
          continue;
        }
        if (source.startsWith(delimiter, i)) {
          out.write(delimiter);
          i += delimiter.length;
          break;
        }
        out.write(source[i]);
        i++;
      }
      continue;
    }
    out.write(c);
    i++;
  }
  return out.toString();
}

/// Finds every string literal passed where a user-facing string belongs.
List<HardcodedLiteral> findHardcodedLiterals(
  String source, {
  String path = '<source>',
}) {
  final String masked = maskComments(source);
  final List<HardcodedLiteral> findings = <HardcodedLiteral>[];
  for (final String token in userFacingTokens) {
    final RegExp pattern = RegExp(
      '(?<![A-Za-z0-9_\$.])${RegExp.escape(token)}',
    );
    for (final RegExpMatch match in pattern.allMatches(masked)) {
      int j = match.end;
      while (j < masked.length && _isSpace(masked[j])) {
        j++;
      }
      if (masked.startsWith('const ', j)) {
        j += 'const '.length;
        while (j < masked.length && _isSpace(masked[j])) {
          j++;
        }
      }
      if (j >= masked.length) {
        continue;
      }
      final String c = masked[j];
      final bool literal =
          c == "'" ||
          c == '"' ||
          (c == 'r' &&
              j + 1 < masked.length &&
              (masked[j + 1] == "'" || masked[j + 1] == '"'));
      if (!literal) {
        continue;
      }
      findings.add(
        HardcodedLiteral(
          path: path,
          line: '\n'.allMatches(masked.substring(0, match.start)).length + 1,
          token: token,
          excerpt: masked
              .substring(
                match.start,
                j + 40 > masked.length ? masked.length : j + 40,
              )
              .split('\n')
              .first,
        ),
      );
    }
  }
  findings.sort((HardcodedLiteral a, HardcodedLiteral b) {
    final int byLine = a.line.compareTo(b.line);
    return byLine != 0 ? byLine : a.token.compareTo(b.token);
  });
  return findings;
}

/// One occurrence of a token this project forbids.
class TokenOccurrence {
  const TokenOccurrence({
    required this.path,
    required this.line,
    required this.token,
    required this.excerpt,
  });

  final String path;
  final int line;
  final String token;
  final String excerpt;

  @override
  String toString() => '$path:$line: $token — $excerpt';
}

/// Finds every occurrence of any of [tokens] in [source], comments excluded.
///
/// A token that ends in `/` (a package prefix such as `package:image/`) is
/// matched literally; anything else is matched as a whole word, so that
/// `decodeImageFromList` is not found inside a longer identifier and `camera`
/// is not found inside another word.
List<TokenOccurrence> findOccurrences(
  String source,
  List<String> tokens, {
  String path = '<source>',
}) {
  final String masked = maskComments(source);
  final List<TokenOccurrence> findings = <TokenOccurrence>[];
  for (final String token in tokens) {
    final String pattern = token.endsWith('/')
        ? RegExp.escape(token)
        : '(?<![A-Za-z0-9_])${RegExp.escape(token)}(?![A-Za-z0-9_])';
    for (final RegExpMatch match in RegExp(pattern).allMatches(masked)) {
      findings.add(
        TokenOccurrence(
          path: path,
          line: '\n'.allMatches(masked.substring(0, match.start)).length + 1,
          token: token,
          excerpt: masked
              .substring(match.start, _min(match.start + 60, masked.length))
              .split('\n')
              .first,
        ),
      );
    }
  }
  findings.sort((TokenOccurrence a, TokenOccurrence b) {
    final int byLine = a.line.compareTo(b.line);
    return byLine != 0 ? byLine : a.token.compareTo(b.token);
  });
  return findings;
}

int _min(int a, int b) => a < b ? a : b;

bool _isSpace(String c) => c == ' ' || c == '\t' || c == '\r' || c == '\n';

/// The Dart sources of [root], in path order.
List<File> dartSources(Directory root) {
  final List<File> files = root
      .listSync(recursive: true)
      .whereType<File>()
      .where((File file) => file.path.endsWith('.dart'))
      .toList();
  files.sort((File a, File b) => a.path.compareTo(b.path));
  return files;
}

/// The `lib/` folder of the application under test.
///
/// `flutter test` runs with the package root as the working directory, which is
/// what makes this relative path correct; the caller asserts that it exists.
Directory appLibDirectory() => Directory(p.join(Directory.current.path, 'lib'));
