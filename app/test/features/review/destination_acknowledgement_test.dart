import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:paperdrop/adapters/storage/app_storage.dart';
import 'package:paperdrop/features/review/destination_acknowledgement.dart';
import 'package:paperdrop_core/paperdrop_core.dart';
import 'package:path/path.dart' as p;

import 'review_fixtures.dart';

/// The day the destination was last acknowledged: FR-REV-002's one persisted fact (design §4).
///
/// **The file, not the screen.** One JSON object beside `destinations.json`, read strictly and
/// answered safely: an unreadable file is *not acknowledged*, never *acknowledged*, because the
/// mistake the requirement exists to prevent is a document going to a table nobody looked at today.
void main() {
  late Directory root;
  late FileDestinationAcknowledgement store;

  setUp(() {
    root = aTempRoot();
    store = FileDestinationAcknowledgement(storage: _TempStorage(root));
  });

  test('a device that has never acknowledged answers nothing', () async {
    expect(await store.lastAcknowledged(), isNull);
  });

  test('a written day is read back, in the documents directory', () async {
    await store.acknowledge(fixedDay());

    expect(await store.lastAcknowledged(), fixedDay());
    expect(
      File(p.join(root.path, FileDestinationAcknowledgement.fileName))
          .existsSync(),
      isTrue,
      reason: 'the file sits beside destinations.json, in the same directory',
    );
  });

  test('acknowledging again replaces the day', () async {
    await store.acknowledge(CalendarDate(2026, 10, 16));
    await store.acknowledge(fixedDay());

    expect(await store.lastAcknowledged(), fixedDay());
  });

  test('a file that is not this store\'s answers "not acknowledged"', () async {
    for (final String content in <String>[
      'not json at all',
      '[]',
      '{"date": "not a date"}',
      '{"date": "2026-02-31"}',
      '{}',
    ]) {
      File(p.join(root.path, FileDestinationAcknowledgement.fileName))
          .writeAsStringSync(content);

      expect(
        await store.lastAcknowledged(),
        isNull,
        reason: '"$content" must never be read as an acknowledgement',
      );
    }
  });

  test('the file holds the day and nothing else', () async {
    await store.acknowledge(fixedDay());

    final Object? decoded = jsonDecode(
      File(p.join(root.path, FileDestinationAcknowledgement.fileName))
          .readAsStringSync(),
    );

    expect(decoded, <String, Object?>{
      FileDestinationAcknowledgement.dateKey: '2026-10-17',
    });
  });
}

/// The application's documents directory, as a test supplies it.
final class _TempStorage implements AppStorage {
  const _TempStorage(this.directory);

  final Directory directory;

  @override
  Future<Directory> documentsDirectory() async => directory;
}
