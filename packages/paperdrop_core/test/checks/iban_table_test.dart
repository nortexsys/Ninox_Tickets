import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('IBAN length table is complete to SWIFT registry release 101', () async {
    var file = File('packages/paperdrop_core/lib/src/checks/iban.dart');
    if (!await file.exists()) {
      file = File('lib/src/checks/iban.dart');
    }

    final source = await file.readAsString();
    final tableStart = source.indexOf('_lengthByCountry = <String, int>{');
    expect(tableStart, isNot(-1), reason: 'length table not found');

    final tableEnd = source.indexOf('};', tableStart);
    expect(tableEnd, isNot(-1), reason: 'length table end not found');

    final table = source.substring(tableStart, tableEnd);
    final entries = <String, int>{};
    final pattern = RegExp(r"'([A-Z]{2})': ([0-9]+)");
    for (final match in pattern.allMatches(table)) {
      entries[match.group(1)!] = int.parse(match.group(2)!);
    }

    expect(entries.length, 89, reason: 'table size must be 89');

    expect(entries['FK'], 18);
    expect(entries['HN'], 28);
    expect(entries['MN'], 20);
    expect(entries['NI'], 28);
    expect(entries['OM'], 23);
    expect(entries['SO'], 23);
    expect(entries['YE'], 30);
  });
}
