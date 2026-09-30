import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('no file in lib reads a locale', () async {
    var lib = Directory('packages/paperdrop_core/lib');
    if (!await lib.exists()) {
      lib = Directory('lib');
    }

    final findings = <String>[];
    await for (final entity in lib.list(recursive: true, followLinks: false)) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }

      final text = await entity.readAsString();
      if (text.contains('localeName') ||
          text.contains('package:intl') ||
          text.contains('dart:io') ||
          text.contains('Platform.locale')) {
        findings.add(entity.path);
      }
    }

    expect(findings, isEmpty, reason: 'locale reads found: $findings');
  });
}
