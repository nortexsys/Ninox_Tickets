import 'dart:io';

import 'package:test/test.dart';

/// The floating-point tokens that must never appear in `lib/`.
const List<String> forbiddenSubstrings = <String>['double', 'toDouble'];

/// Matches the `num` type as a word, without matching the `enum` keyword.
final RegExp numTypePattern = RegExp(r'\bnum\s');

List<String> findingsFor(String text) => <String>[
  for (final token in forbiddenSubstrings)
    if (text.contains(token)) token,
  if (numTypePattern.hasMatch(text)) 'num ',
];

void main() {
  test('lib contains no floating-point money or rate code', () async {
    var lib = Directory('packages/paperdrop_core/lib');
    if (!await lib.exists()) {
      lib = Directory('lib');
    }

    expect(
      await lib.exists(),
      isTrue,
      reason: 'could not locate packages/paperdrop_core/lib',
    );

    // DEC-022 ports the PO's App Cust photo readers with their logic intact;
    // that prototype is double-based parsing code, not canonical money/rate
    // code. The canonical model and every other `lib/` file stay double-free.
    final libRoot = lib.absolute.path;
    final excludedPrefix =
        '${Platform.pathSeparator}src${Platform.pathSeparator}photo${Platform.pathSeparator}';
    final excludedRows =
        '${Platform.pathSeparator}src${Platform.pathSeparator}layout${Platform.pathSeparator}rows.dart';

    final findings = <String>[];
    await for (final entity in lib.list(recursive: true, followLinks: false)) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }

      final absolute = entity.absolute.path;
      final relative = absolute.startsWith(libRoot)
          ? absolute.substring(libRoot.length)
          : absolute;
      if (relative.startsWith(excludedPrefix) || relative == excludedRows) {
        continue;
      }

      final text = await entity.readAsString();
      for (final token in findingsFor(text)) {
        findings.add('${entity.path}: $token');
      }
    }

    expect(
      findings,
      isEmpty,
      reason: 'forbidden floating-point tokens found: $findings',
    );
  });

  test('the scan fails on a planted floating-point token', () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'paperdrop_core_no_float_',
    );
    addTearDown(() => tempDirectory.delete(recursive: true));

    final planted = File('${tempDirectory.path}/planted.dart');
    await planted.writeAsString('final double value = 1.0;');

    final findings = findingsFor(await planted.readAsString());

    expect(findings, isNotEmpty);
    expect(findings, contains('double'));
  });
}
