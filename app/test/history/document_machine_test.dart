/// The document state machine of design §5.3: the table, every pair, and the invariants that
/// travel with a state (FR-HIS-002).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:ninox_client/ninox_client.dart';
import 'package:paperdrop/history/document_machine.dart';
import 'package:paperdrop/history/history_entry.dart';
import 'package:paperdrop_core/paperdrop_core.dart';

import 'history_fixtures.dart';

void main() {
  test('[document-history/document-states] an offline save is queued, not '
      'failed', () {
    // GIVEN a save performed with no connectivity WHEN its entry is inspected
    // THEN it reads queued AND it does not read failed.
    final HistoryEntry reviewing = anEntry(state: DocumentState.reviewing);

    final HistoryEntry queued = transition(reviewing, DocumentState.queued);

    expect(queued.state, DocumentState.queued);
    expect(queued.state, isNot(DocumentState.failed));
    expect(queued.state.name, isNot('failed'));
    // Waiting is not a failure: nothing moves an entry from a failure *into* the
    // queue, which is how a failure would look like a wait.
    expect(
      isAllowedTransition(DocumentState.failed, DocumentState.queued),
      isFalse,
    );
    expect(
      isAllowedTransition(DocumentState.queued, DocumentState.failed),
      isFalse,
    );
  });

  test(
    '[document-history/document-states] a lost create response is uncertain, '
    'not failed',
    () {
      // GIVEN a create whose response was lost WHEN its entry is inspected THEN it
      // reads uncertain AND it is not collapsed into failed or into sent.
      final HistoryEntry sending = anEntry(state: DocumentState.sending);

      final HistoryEntry uncertain = transition(
        sending,
        DocumentState.uncertain,
      );

      expect(uncertain.state, DocumentState.uncertain);
      expect(uncertain.state, isNot(DocumentState.failed));
      expect(uncertain.state, isNot(DocumentState.sent));
    },
  );

  test('[document-history/document-states] a completed send carries its record '
      'identifier', () {
    // GIVEN a send that completed WHEN its entry is inspected THEN it reads sent
    // AND its Ninox record identifier is populated — and it stays populated
    // through the correction that returns the entry to `reviewing`.
    final HistoryEntry sending = anEntry(state: DocumentState.sending);

    final HistoryEntry sent = transition(
      sending,
      DocumentState.sent,
      ninoxRecordId: const RecordId('record-9'),
    );

    expect(sent.state, DocumentState.sent);
    expect(sent.ninoxRecordId, const RecordId('record-9'));

    final HistoryEntry corrected = transition(sent, DocumentState.reviewing);
    expect(corrected.state, DocumentState.reviewing);
    expect(corrected.ninoxRecordId, const RecordId('record-9'));
  });

  test('a transition to sent without a record identifier is refused', () {
    // The refusal half of the same scenario: an entry in `sent` whose record
    // nobody knows could not be corrected, so the machine refuses to enter it.
    expect(
      () =>
          transition(anEntry(state: DocumentState.sending), DocumentState.sent),
      throwsArgumentError,
    );
  });

  test('every allowed transition passes and every other pair is refused', () {
    // The table of design §5.3, pair by pair: 64 combinations, each one either
    // the transition the design allows or a StateError that names both states.
    for (final DocumentState from in DocumentState.values) {
      for (final DocumentState to in DocumentState.values) {
        final HistoryEntry entry = anEntry(state: from);
        final bool allowed = isAllowedTransition(from, to);
        expect(
          allowedTransitions[from]!.contains(to),
          allowed,
          reason: 'the table and the predicate agree on $from -> $to',
        );

        if (allowed) {
          final HistoryEntry moved = transition(
            entry,
            to,
            ninoxRecordId: to == DocumentState.sent
                ? const RecordId('record-9')
                : null,
          );
          expect(moved.state, to, reason: '$from -> $to is allowed');
          expect(moved.revision, entry.revision + 1);
          // Nothing about the entry it came from changed: an entry is immutable,
          // and a transition produces a new one.
          expect(entry.state, from);
          expect(entry.revision, 1);
        } else {
          expect(
            () => transition(
              entry,
              to,
              ninoxRecordId: to == DocumentState.sent
                  ? const RecordId('record-9')
                  : null,
            ),
            throwsA(
              isA<StateError>().having(
                (StateError error) => error.message,
                'message',
                allOf(contains(from.name), contains(to.name)),
              ),
            ),
            reason: '$from -> $to is not a transition the machine allows',
          );
        }
      }
    }
  });

  test('the transitions the design names are exactly these', () {
    // Read out of design §5.3 as a table, so that a change to the machine has to
    // change this test too.
    const Map<DocumentState, Set<DocumentState>> design =
        <DocumentState, Set<DocumentState>>{
          DocumentState.pending: <DocumentState>{
            DocumentState.extracting,
            DocumentState.failed,
          },
          DocumentState.extracting: <DocumentState>{
            DocumentState.reviewing,
            DocumentState.failed,
          },
          DocumentState.reviewing: <DocumentState>{
            DocumentState.queued,
            DocumentState.sending,
          },
          DocumentState.queued: <DocumentState>{DocumentState.sending},
          DocumentState.sending: <DocumentState>{
            DocumentState.sent,
            DocumentState.uncertain,
            DocumentState.failed,
            DocumentState.queued,
          },
          DocumentState.uncertain: <DocumentState>{
            DocumentState.sending,
            DocumentState.sent,
            DocumentState.failed,
          },
          DocumentState.failed: <DocumentState>{DocumentState.reviewing},
          DocumentState.sent: <DocumentState>{DocumentState.reviewing},
        };

    expect(
      allowedTransitions.keys.toSet(),
      unorderedEquals(DocumentState.values),
    );
    for (final MapEntry<DocumentState, Set<DocumentState>> row
        in design.entries) {
      expect(
        allowedTransitions[row.key],
        unorderedEquals(row.value),
        reason: 'the transitions out of ${row.key.name}',
      );
    }
    // `queued` is never reached by a failure, and neither `sent` nor `failed`
    // leads anywhere but back to `reviewing`.
    expect(
      DocumentState.values
          .where(
            (DocumentState from) =>
                allowedTransitions[from]!.contains(DocumentState.queued),
          )
          .toSet(),
      <DocumentState>{DocumentState.reviewing, DocumentState.sending},
    );
  });

  test(
    'a duplicate flag can be set in any state and never blocks a transition',
    () {
      // Design §5.3 and DEC-016: the flag is a property of the document, not a
      // ninth state, so it travels through every state and no transition is
      // refused because of it.
      for (final DocumentState from in DocumentState.values) {
        final HistoryEntry flagged = anEntry(
          state: from,
          duplicateFlagged: true,
        );
        expect(flagged.duplicateFlagged, isTrue);

        for (final DocumentState to in allowedTransitions[from]!) {
          final HistoryEntry moved = transition(
            flagged,
            to,
            ninoxRecordId: to == DocumentState.sent
                ? const RecordId('record-9')
                : null,
          );
          expect(moved.duplicateFlagged, isTrue, reason: '$from -> $to');
          expect(moved.state, to);
        }
      }
    },
  );

  test(
    'a stage attaches its values once and they travel with the document',
    () {
      // Extraction attaches the values, the confidence and the thumbnail on the
      // way into `reviewing`; the transitions after it carry them, so the send
      // pipeline and the history detail read the same extraction.
      final HistoryEntry extracting = anEntry(state: DocumentState.extracting);

      final HistoryEntry reviewing = transition(
        extracting,
        DocumentState.reviewing,
        values: aCanonicalDocument(),
        confidence: ConfidenceState.amber,
        thumbnailPath: 'thumbs/one.jpg',
      );

      expect(reviewing.values, aCanonicalDocument());
      expect(reviewing.confidence, ConfidenceState.amber);
      expect(reviewing.thumbnailPath, 'thumbs/one.jpg');

      final HistoryEntry sending = transition(reviewing, DocumentState.sending);
      expect(sending.values, aCanonicalDocument());
      expect(sending.confidence, ConfidenceState.amber);
      expect(sending.thumbnailPath, 'thumbs/one.jpg');
      expect(sending.revision, 3);
    },
  );

  test('a failure reason belongs to the attempt that produced it', () {
    // A reason is not a property of the document: a transition that is not given
    // one produces an entry without one, so a stale reason cannot outlive the
    // attempt it described — and one that is given, such as the send pipeline's
    // `attachment_incomplete` (design §5.4), is carried.
    final HistoryEntry failed = transition(
      anEntry(state: DocumentState.sending),
      DocumentState.failed,
      failureReason: 'attachment_incomplete',
    );
    expect(failed.failureReason, 'attachment_incomplete');

    final HistoryEntry corrected = transition(failed, DocumentState.reviewing);
    expect(corrected.failureReason, isNull);
    expect(corrected.state, DocumentState.reviewing);

    final HistoryEntry again = transition(
      corrected,
      DocumentState.sending,
      failureReason: 'attachment_incomplete',
    );
    expect(again.failureReason, 'attachment_incomplete');
  });
}
