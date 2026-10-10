/// How a send continues after it stopped: `resume` for an incomplete record, `adopt` for the record
/// the user chose, and `createAnyway` for the user's *none of these*.
///
/// Requirements: `ninox-send/the-retry-matrix` row *record created, attachment failed* and
/// `ninox-send/updates-are-merges` (FR-SND-008) — a retry touches nothing but the attachment — and
/// `ninox-send/reconciliation-of-an-uncertain-create`, where the choice belongs to the user.
library;

import 'package:ninox_client/ninox_client.dart';
import 'package:test/test.dart';

import 'send_harness.dart';

/// Sends a document whose attachment never gets through, so that the outcome is `Incomplete`.
Future<Incomplete> _sendWithAFailedAttachment(
  SendHarness h,
  SendRequest r,
) async {
  h.port.nextId = const RecordId('1416');
  h.port.uploads = <Object>[
    const TransportFailure('timed out'),
    const TransportFailure('timed out'),
    const TransportFailure('timed out'),
    const TransportFailure('timed out'),
  ];
  final SendOutcome outcome = await h.pipeline.send(r);
  return outcome as Incomplete;
}

void main() {
  test(
    '[ninox-send/the-retry-matrix] a failed attachment retries alone',
    () async {
      final SendHarness h = SendHarness();
      final SendRequest r = testRequest();
      final Incomplete incomplete = await _sendWithAFailedAttachment(h, r);
      h.forget();
      h.port.nextFiles = <NinoxFile>[storedFile(size: r.bytes.length)];

      final SendOutcome outcome = await h.pipeline.resume(
        r,
        incomplete.recordId,
      );

      // Nothing but the record's own file endpoints and the read-back: no create, no listing, no
      // update of a mapped value.
      expect(h.port.calls, <String>[
        'uploadFile:T1#1416',
        'readRecord:T1#1416',
        'listFiles:T1#1416',
      ]);
      expect(outcome, isA<Sent>());
      expect((outcome as Sent).recordId.value, '1416');
      expect(h.journal.stepsOf(r.docId).first, SendStep.created);
      expect(h.journal.stepsOf(r.docId).last, SendStep.sent);
    },
  );

  test('[ninox-send/updates-are-merges] retrying an attachment changes nothing but the attachment', () async {
    final SendHarness h = SendHarness();
    final SendRequest r = testRequest();
    final Incomplete incomplete = await _sendWithAFailedAttachment(h, r);
    final Map<String, Object?> sentOnce = Map<String, Object?>.of(
      h.port.createdFields!,
    );
    h.forget();
    h.port.nextFiles = <NinoxFile>[storedFile(size: r.bytes.length)];

    await h.pipeline.resume(r, incomplete.recordId);

    // The record was written once, with the same payload, and the retry wrote no field at all.
    expect(h.port.createdFields, sentOnce);
    expect(h.port.calls, isNot(contains('createRecord:T1')));
    expect(h.port.calls, isNot(contains('updateRecord:T1#1416')));
    expect(h.port.uploadedFilename, r.filename);
  });

  test('[ninox-send/the-retry-matrix] a resume that is not authorised asks for the token', () async {
    final SendHarness h = SendHarness();
    final SendRequest r = testRequest();
    h.port.uploads = <Object>[const Unauthorized('the token expired')];

    final SendOutcome outcome = await h.pipeline.resume(
      r,
      const RecordId('1416'),
    );

    expect(outcome, isA<Failed>());
    expect((outcome as Failed).kind, SendFailureKind.auth);
    expect(h.port.calls, <String>['uploadFile:T1#1416']);
    expect(h.slept, isEmpty);
  });

  test('[ninox-send/the-retry-matrix] a resume on a vanished record is not retried', () async {
    final SendHarness h = SendHarness();
    final SendRequest r = testRequest();
    h.port.uploads = <Object>[const NotFound('Record not found')];

    final SendOutcome outcome = await h.pipeline.resume(
      r,
      const RecordId('1416'),
    );

    expect(outcome, isA<Failed>());
    expect((outcome as Failed).kind, SendFailureKind.destinationGone);
    expect(h.port.calls, <String>['uploadFile:T1#1416']);
  });

  test('[ninox-send/reconciliation-of-an-uncertain-create] the user choice continues with the attachment', () async {
    final SendHarness h = SendHarness();
    final SendRequest r = testRequest();
    h.port.nextFiles = <NinoxFile>[storedFile(size: r.bytes.length)];

    final SendOutcome outcome = await h.pipeline.adopt(
      r,
      const RecordId('9001'),
    );

    expect(h.port.calls, <String>[
      'uploadFile:T1#9001',
      'readRecord:T1#9001',
      'listFiles:T1#9001',
    ]);
    expect(outcome, isA<Sent>());
    expect((outcome as Sent).recordId.value, '9001');
    expect(h.journal.stepsOf(r.docId), <SendStep>[
      SendStep.created,
      SendStep.attaching,
      SendStep.attached,
      SendStep.sent,
    ]);
  });

  test('[ninox-send/reconciliation-of-an-uncertain-create] none of the candidates is it, so the user creates anyway', () async {
    final SendHarness h = SendHarness();
    final SendRequest r = testRequest();
    h.port.nextId = const RecordId('9006');
    h.port.nextFiles = <NinoxFile>[storedFile(size: r.bytes.length)];

    final SendOutcome outcome = await h.pipeline.createAnyway(r);

    // The user's answer, so no reconciliation is run first.
    expect(h.port.calls, <String>[
      'createRecord:T1',
      'uploadFile:T1#9006',
      'readRecord:T1#9006',
      'listFiles:T1#9006',
    ]);
    expect(outcome, isA<Sent>());
    expect((outcome as Sent).recordId.value, '9006');
    expect(h.journal.stepsOf(r.docId).first, SendStep.sending);
  });

  test('[ninox-send/reconciliation-of-an-uncertain-create] creating anyway does not reconcile a second time', () async {
    final SendHarness h = SendHarness();
    final SendRequest r = testRequest();
    h.port.creates = <Object>[
      const CreateOutcomeUncertain('the response was lost'),
    ];

    final SendOutcome outcome = await h.pipeline.createAnyway(r);

    // The app has already asked; asking again in a loop is not asking.
    expect(h.port.calls, <String>['createRecord:T1']);
    expect(outcome, isA<Uncertain>());
    expect((outcome as Uncertain).candidates, isEmpty);
    expect(h.journal.stepsOf(r.docId).last, SendStep.uncertain);
  });

  test('[ninox-send/attachment-upload] a record created without its document is incomplete, with its identifier', () async {
    final SendHarness h = SendHarness();
    final SendRequest r = testRequest();

    final Incomplete incomplete = await _sendWithAFailedAttachment(h, r);

    // The identifier is what makes the resume possible at all: without it the record could not be
    // finished, and the send would be lost rather than incomplete.
    expect(incomplete.recordId.value, '1416');
    expect(incomplete.reason, isNotEmpty);
  });
}
