/// The happy path of the send: create → attach → read back, and what each step proves.
///
/// Requirements: `ninox-send/create-attach-read-back` (FR-SND-001), `ninox-send/payload-shape`
/// (FR-SND-002) and `ninox-send/attachment-upload` (FR-SND-003). No test here reaches the network:
/// the port is [FakeNinoxPort], and no token exists in this package.
library;

import 'package:ninox_client/ninox_client.dart';
import 'package:test/test.dart';

import 'send_harness.dart';

void main() {
  test(
    '[ninox-send/create-attach-read-back] the three steps happen in this order',
    () async {
      final SendHarness h = SendHarness();
      final SendRequest r = testRequest();
      h.port.nextId = const RecordId('1416');
      h.port.nextRecord = NinoxRecord(
        id: const RecordId('ignored'),
        fields: const <String, Object?>{'Importe': 2049, 'Fecha': '2026-10-10'},
        createdBy: 'user-1',
      );
      h.port.nextFiles = <NinoxFile>[storedFile(size: r.bytes.length)];

      final SendOutcome outcome = await h.pipeline.send(r);

      expect(h.port.calls, <String>[
        'createRecord:T1',
        'uploadFile:T1#1416',
        'readRecord:T1#1416',
        'listFiles:T1#1416',
      ]);
      expect(outcome, isA<Sent>());
      final Sent sent = outcome as Sent;
      expect(sent.recordId.value, '1416');
      expect(sent.readBack.fields, <String, Object?>{
        'Importe': 2049,
        'Fecha': '2026-10-10',
      });
      expect(sent.files, <NinoxFile>[storedFile(size: r.bytes.length)]);
    },
  );

  test('[ninox-send/create-attach-read-back] the confirmation shows stored values, not what was sent', () async {
    final SendHarness h = SendHarness();
    // The port stores what Ninox stored: the amount was overridden by a table default, and the
    // create response — which carries only the identifier — never revealed it. So what the user
    // is shown has to come from the read-back.
    final SendRequest r = testRequest();
    h.port.nextRecord = NinoxRecord(
      id: const RecordId('ignored'),
      fields: const <String, Object?>{'Importe': 2049, 'Fecha': '2026-10-10'},
    );
    h.port.nextFiles = <NinoxFile>[storedFile(size: r.bytes.length)];

    final SendOutcome outcome = await h.pipeline.send(r);

    expect(r.fieldsByName['Importe'], 1999);
    expect((outcome as Sent).readBack.fields['Importe'], 2049);
    expect(h.port.createdFields, r.fieldsByName);
  });

  test('[ninox-send/payload-shape] the payload is keyed by name and handed over unchanged', () async {
    final SendHarness h = SendHarness();
    final SendRequest r = testRequest();
    h.port.nextFiles = <NinoxFile>[storedFile(size: r.bytes.length)];

    await h.pipeline.send(r);

    // The same map, not a copy and not a rebuilt one: the pipeline decides no value, adds no key
    // and removes none (never-write-an-unmapped-field).
    expect(h.port.createdFields, same(r.fieldsByName));
    expect(h.port.createdFields!.keys.toList(), <String>['Importe', 'Fecha']);
    expect(
      h.port.createdFields!.values.every((Object? v) => v is! double),
      isTrue,
    );
  });

  test(
    '[ninox-send/attachment-upload] the upload succeeds and is readable',
    () async {
      final SendHarness h = SendHarness();
      final SendRequest r = testRequest();
      h.port.nextFiles = <NinoxFile>[storedFile(size: r.bytes.length)];

      final SendOutcome outcome = await h.pipeline.send(r);

      // What travelled is exactly what was handed over, byte for byte (ADR-007, BR-17).
      expect(h.port.uploadedBytes, r.bytes);
      expect(h.port.uploadedFilename, 'receipt.pdf');
      expect(h.port.uploadedContentType, 'application/pdf');
      // And the read-back carries the file on all three of its properties.
      final NinoxFile stored = (outcome as Sent).files.single;
      expect(stored.name, r.filename);
      expect(stored.size, r.bytes.length);
      expect(stored.contentType, r.contentType);
    },
  );

  test('[ninox-send/attachment-upload] a read-back without the document is incomplete, not done', () async {
    final SendHarness h = SendHarness();
    final SendRequest r = testRequest();
    h.port.nextId = const RecordId('1417');
    // The upload answered, and the record does not carry the document — a size that does not
    // match is enough to say the record is not done.
    h.port.nextFiles = <NinoxFile>[storedFile(size: r.bytes.length + 1)];

    final SendOutcome outcome = await h.pipeline.send(r);

    expect(outcome, isA<Incomplete>());
    final Incomplete incomplete = outcome as Incomplete;
    expect(incomplete.recordId.value, '1417');
    expect(incomplete.reason, isNotEmpty);
    expect(h.journal.stepsOf(r.docId).last, SendStep.incomplete);
  });

  test('[ninox-send/create-attach-read-back] the journal sees the transitions of a send', () async {
    final SendHarness h = SendHarness();
    final SendRequest r = testRequest();
    h.port.nextId = const RecordId('1418');
    h.port.nextFiles = <NinoxFile>[storedFile(size: r.bytes.length)];

    await h.pipeline.send(r);

    expect(h.journal.stepsOf(r.docId), <SendStep>[
      SendStep.sending,
      SendStep.created,
      SendStep.attaching,
      SendStep.attached,
      SendStep.sent,
    ]);
    expect(h.journal.entries.first.recordId, isNull);
    expect(h.journal.entries[1].recordId?.value, '1418');
    expect(h.journal.entries.last.recordId?.value, '1418');
  });
}
