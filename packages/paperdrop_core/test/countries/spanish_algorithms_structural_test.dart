import 'dart:io';

import 'package:test/test.dart';

void main() {
  test(
    'the three Spanish algorithms live in three files that share no code',
    () async {
      var countries = Directory('packages/paperdrop_core/lib/src/countries');
      if (!await countries.exists()) {
        countries = Directory('lib/src/countries');
      }

      final paths = <String, File>{
        'es_nif.dart': File('${countries.path}/es_nif.dart'),
        'es_nie.dart': File('${countries.path}/es_nie.dart'),
        'es_cif.dart': File('${countries.path}/es_cif.dart'),
      };

      for (final entry in paths.entries) {
        expect(
          await entry.value.exists(),
          isTrue,
          reason: 'missing ${entry.key}',
        );
      }

      final sources = <String, String>{
        for (final entry in paths.entries)
          entry.key: await entry.value.readAsString(),
      };

      for (final source in sources.entries) {
        for (final line in source.value.split('\n')) {
          final trimmed = line.trim();
          if (!trimmed.startsWith('import ') &&
              !trimmed.startsWith('export ')) {
            continue;
          }
          for (final other in paths.keys) {
            expect(
              trimmed.contains(other),
              isFalse,
              reason: '${source.key} must not import $other',
            );
          }
          expect(
            trimmed.contains('spanish'),
            isFalse,
            reason: '${source.key} must not share a Spanish helper file',
          );
        }
      }

      expect(
        sources['es_nif.dart'],
        contains('TRWAGMYFPDXBNJZSQVHLCKE'),
        reason: 'es_nif.dart must hold its own mod-23 letter table',
      );
      expect(
        sources['es_nie.dart'],
        contains('TRWAGMYFPDXBNJZSQVHLCKE'),
        reason: 'es_nie.dart must hold its own mod-23 letter table',
      );
      expect(
        sources['es_cif.dart'],
        isNot(contains('TRWAGMYFPDXBNJZSQVHLCKE')),
        reason: 'the CIF algorithm has no mod-23 letter table',
      );
    },
  );
}
