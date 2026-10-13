/// The journal the pipeline reports to: the interface's one method, the no-op and the in-memory
/// implementation this change ships for tests (T1.14's local store implements the same interface).
library;

import 'package:ninox_client/ninox_client.dart';
import 'package:test/test.dart';

void main() {
  test('the in-memory journal keeps the transitions in the order they were reported', () async {
    final InMemorySendJournal journal = InMemorySendJournal();

    await journal.record('document-1', SendStep.sending);
    await journal.record(
      'document-1',
      SendStep.created,
      recordId: const RecordId('1416'),
    );
    await journal.record('document-2', SendStep.sending);

    expect(journal.entries, <SendJournalEntry>[
      const SendJournalEntry(docId: 'document-1', step: SendStep.sending),
      const SendJournalEntry(
        docId: 'document-1',
        step: SendStep.created,
        recordId: RecordId('1416'),
      ),
      const SendJournalEntry(docId: 'document-2', step: SendStep.sending),
    ]);
    expect(journal.stepsOf('document-1'), <SendStep>[
      SendStep.sending,
      SendStep.created,
    ]);
    expect(journal.stepsOf('document-3'), isEmpty);
  });

  test('the no-op journal records nothing and throws nothing', () async {
    const SendJournal journal = NoopSendJournal();

    await journal.record('document-1', SendStep.failed);

    expect(journal, isA<SendJournal>());
  });

  test('a journal entry carries a record identifier only on the steps about one record', () async {
    final InMemorySendJournal journal = InMemorySendJournal();
    const RecordId id = RecordId('1416');

    await journal.record('d', SendStep.attaching, recordId: id);
    await journal.record('d', SendStep.attached, recordId: id);
    await journal.record('d', SendStep.incomplete, recordId: id);
    await journal.record('d', SendStep.queued);

    expect(
      journal.entries.where((SendJournalEntry e) => e.recordId != null).length,
      3,
    );
    expect(journal.entries.last.recordId, isNull);
  });
}
