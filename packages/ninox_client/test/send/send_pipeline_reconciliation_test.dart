/// The reconciliation of an uncertain create: `ninox-send/reconciliation-of-an-uncertain-create`
/// (FR-SND-005, ADR-013), its four scenarios and the filters it is made of.
///
/// A create whose POST may have landed is never sent again on a guess. The app reads the
/// destination's recent records and weighs them — `createdAt` inside the window, `createdBy` equal
/// to the token's user, every mapped field equal to what was sent — and where the evidence does not
/// decide, it **asks**.
library;

import 'package:ninox_client/ninox_client.dart';
import 'package:test/test.dart';

import 'send_harness.dart';

/// A candidate as the destination would return it: the values that were sent, created a minute
/// before the attempt, by the token's own user.
NinoxRecord _candidate({String id = '9001', String? createdBy = 'user-1'}) =>
    NinoxRecord(
      id: RecordId(id),
      fields: const <String, Object?>{'Importe': 1999, 'Fecha': '2026-10-10'},
      createdAt: '2026-10-10T11:59:00Z',
      createdBy: createdBy,
    );

void main() {
  test('[ninox-send/reconciliation-of-an-uncertain-create] the POST landed but the response was lost', () async {
    final SendHarness h = SendHarness();
    final SendRequest r = testRequest();
    await h.learnTokenUser('user-1');
    h.forget();
    h.port.creates = <Object>[
      const CreateOutcomeUncertain('the response was lost'),
    ];
    h.port.nextListing = <NinoxRecord>[_candidate()];
    h.port.nextFiles = <NinoxFile>[storedFile(size: r.bytes.length)];

    final SendOutcome outcome = await h.pipeline.send(r);

    // The record was adopted and the flow continued to the attachment: one record exists, and no
    // second one was written.
    expect(h.port.calls.where((String c) => c == 'createRecord:T1').length, 1);
    expect(h.port.calls, contains('uploadFile:T1#9001'));
    expect(outcome, isA<Sent>());
    expect((outcome as Sent).recordId.value, '9001');
    expect(
      h.journal.entries.map((SendJournalEntry e) => e.recordId?.value),
      contains('9001'),
    );
  });

  test(
    '[ninox-send/reconciliation-of-an-uncertain-create] the POST did not land',
    () async {
      final SendHarness h = SendHarness();
      final SendRequest r = testRequest();
      await h.learnTokenUser('user-1');
      h.forget();
      h.port.creates = <Object>[
        const CreateOutcomeUncertain('the response was lost'),
      ];
      h.port.nextListing = const <NinoxRecord>[];
      h.port.nextId = const RecordId('9002');
      h.port.nextFiles = <NinoxFile>[storedFile(size: r.bytes.length)];

      final SendOutcome outcome = await h.pipeline.send(r);

      // No matching record was found, so the record was created — once — after the read.
      expect(h.port.calls, <String>[
        'createRecord:T1',
        'listRecords:T1',
        'createRecord:T1',
        'uploadFile:T1#9002',
        'readRecord:T1#9002',
        'listFiles:T1#9002',
      ]);
      expect(outcome, isA<Sent>());
      expect((outcome as Sent).recordId.value, '9002');
    },
  );

  test('[ninox-send/reconciliation-of-an-uncertain-create] ambiguity is surfaced rather than guessed', () async {
    final SendHarness h = SendHarness();
    final SendRequest r = testRequest();
    await h.learnTokenUser('user-1');
    h.forget();
    h.port.creates = <Object>[
      const CreateOutcomeUncertain('the response was lost'),
    ];
    final NinoxRecord one = _candidate();
    final NinoxRecord two = _candidate(id: '9003');
    h.port.nextListing = <NinoxRecord>[one, two];

    final SendOutcome outcome = await h.pipeline.send(r);

    expect(outcome, isA<Uncertain>());
    expect((outcome as Uncertain).candidates, <NinoxRecord>[one, two]);
    // The app did not decide: no second record and no attachment.
    expect(h.port.calls.where((String c) => c == 'createRecord:T1').length, 1);
    expect(h.port.calls, isNot(contains('uploadFile:T1#9001')));
    expect(h.journal.stepsOf(r.docId).last, SendStep.uncertain);
  });

  test('[ninox-send/reconciliation-of-an-uncertain-create] the reconciliation does not depend on mapping', () async {
    final SendHarness h = SendHarness();
    // Nothing is mapped at all: there is no field to compare and no marker field was ever
    // written. `createdAt` and `createdBy` are what narrow the candidates.
    final SendRequest r = testRequest(fieldsByName: const <String, Object?>{});
    await h.learnTokenUser('user-1');
    h.forget();
    h.port.creates = <Object>[
      const CreateOutcomeUncertain('the response was lost'),
    ];
    h.port.nextListing = <NinoxRecord>[_candidate()];

    final SendOutcome outcome = await h.pipeline.send(r);

    expect(h.port.createdFields, isEmpty);
    expect(outcome, isA<Uncertain>());
    // The candidates were narrowed to the one record of ours inside the window.
    expect((outcome as Uncertain).candidates.single.id.value, '9001');
    expect(h.port.calls.where((String c) => c == 'createRecord:T1').length, 1);
  });

  test('[ninox-send/reconciliation-of-an-uncertain-create] a record created by someone else is not a candidate', () async {
    final SendHarness h = SendHarness();
    final SendRequest r = testRequest();
    await h.learnTokenUser('user-1');
    h.forget();
    h.port.creates = <Object>[
      const CreateOutcomeUncertain('the response was lost'),
    ];
    h.port.nextListing = <NinoxRecord>[_candidate(createdBy: 'somebody-else')];
    h.port.nextFiles = <NinoxFile>[storedFile(size: r.bytes.length)];

    final SendOutcome outcome = await h.pipeline.send(r);

    // Not ours, so nothing was adopted: the record was created instead.
    expect(h.port.calls.where((String c) => c == 'createRecord:T1').length, 2);
    expect(outcome, isA<Sent>());
  });

  test('[ninox-send/reconciliation-of-an-uncertain-create] a record outside the window is not a candidate', () async {
    final SendHarness h = SendHarness();
    final SendRequest r = testRequest();
    await h.learnTokenUser('user-1');
    h.forget();
    h.port.creates = <Object>[
      const CreateOutcomeUncertain('the response was lost'),
    ];
    // Three minutes old, with a two-minute window: it is not this attempt's record.
    h.port.nextListing = <NinoxRecord>[
      NinoxRecord(
        id: const RecordId('9004'),
        fields: const <String, Object?>{'Importe': 1999, 'Fecha': '2026-10-10'},
        createdAt: '2026-10-10T11:57:00Z',
        createdBy: 'user-1',
      ),
    ];
    h.port.nextFiles = <NinoxFile>[storedFile(size: r.bytes.length)];

    final SendOutcome outcome = await h.pipeline.send(r);

    expect(h.port.calls.where((String c) => c == 'createRecord:T1').length, 2);
    expect(outcome, isA<Sent>());
    expect((outcome as Sent).recordId.value, isNot('9004'));
  });

  test('[ninox-send/reconciliation-of-an-uncertain-create] an unknown token user is not skipped', () async {
    // No send has completed yet, so the pipeline has never read back a record of its own and does
    // not know which `createdBy` is its own. It must ask, not assume.
    final SendHarness h = SendHarness();
    final SendRequest r = testRequest();
    h.port.creates = <Object>[
      const CreateOutcomeUncertain('the response was lost'),
    ];
    final NinoxRecord found = _candidate();
    h.port.nextListing = <NinoxRecord>[found];

    final SendOutcome outcome = await h.pipeline.send(r);

    expect(outcome, isA<Uncertain>());
    expect((outcome as Uncertain).candidates, <NinoxRecord>[found]);
    expect(h.port.calls.where((String c) => c == 'createRecord:T1').length, 1);
  });

  test('[ninox-send/reconciliation-of-an-uncertain-create] a record with no readable createdAt is not skipped', () async {
    final SendHarness h = SendHarness();
    final SendRequest r = testRequest();
    await h.learnTokenUser('user-1');
    h.forget();
    h.port.creates = <Object>[
      const CreateOutcomeUncertain('the response was lost'),
    ];
    // No audit stamp to compare the window against, so the window cannot be applied: ask.
    h.port.nextListing = <NinoxRecord>[
      const NinoxRecord(
        id: RecordId('9005'),
        fields: <String, Object?>{'Importe': 1999, 'Fecha': '2026-10-10'},
        createdBy: 'user-1',
      ),
    ];

    final SendOutcome outcome = await h.pipeline.send(r);

    expect(outcome, isA<Uncertain>());
    expect((outcome as Uncertain).candidates.single.id.value, '9005');
    expect(h.port.calls.where((String c) => c == 'createRecord:T1').length, 1);
  });

  test('[ninox-send/reconciliation-of-an-uncertain-create] a second uncertain create ends in Uncertain', () async {
    final SendHarness h = SendHarness();
    final SendRequest r = testRequest();
    await h.learnTokenUser('user-1');
    h.forget();
    h.port.creates = <Object>[
      const CreateOutcomeUncertain('the response was lost'),
      const CreateOutcomeUncertain('the response was lost'),
    ];
    h.port.nextListing = const <NinoxRecord>[];

    final SendOutcome outcome = await h.pipeline.send(r);

    // One reconciliation, one create, no loop: the second uncertainty is handed to the user.
    expect(h.port.calls, <String>[
      'createRecord:T1',
      'listRecords:T1',
      'createRecord:T1',
    ]);
    expect(outcome, isA<Uncertain>());
    expect((outcome as Uncertain).candidates, isEmpty);
  });

  test('[ninox-send/reconciliation-of-an-uncertain-create] a nested value is compared by structure', () async {
    final SendHarness h = SendHarness();
    // A JSON payload may carry a list or an object, and `==` on those is identity: a candidate
    // that stored the same thing would never match, and the flow would write a duplicate.
    final SendRequest r = testRequest(
      fieldsByName: <String, Object?>{
        'Lineas': <Object?>[
          <String, Object?>{'Importe': 1999, 'Concepto': 'Combustible'},
        ],
        'Fecha': '2026-10-10',
      },
    );
    await h.learnTokenUser('user-1');
    h.forget();
    h.port.creates = <Object>[
      const CreateOutcomeUncertain('the response was lost'),
    ];
    h.port.nextListing = <NinoxRecord>[
      NinoxRecord(
        id: const RecordId('9007'),
        fields: <String, Object?>{
          'Lineas': <Object?>[
            <String, Object?>{'Importe': 1999, 'Concepto': 'Combustible'},
          ],
          'Fecha': '2026-10-10',
        },
        createdAt: '2026-10-10T11:59:00Z',
        createdBy: 'user-1',
      ),
    ];
    h.port.nextFiles = <NinoxFile>[storedFile(size: r.bytes.length)];

    final SendOutcome outcome = await h.pipeline.send(r);

    expect(outcome, isA<Sent>());
    expect((outcome as Sent).recordId.value, '9007');
    expect(h.port.calls.where((String c) => c == 'createRecord:T1').length, 1);
  });

  test('[ninox-send/reconciliation-of-an-uncertain-create] the user choice teaches the pipeline nothing', () async {
    // The user may choose a record that is not the token's own, so `adopt` must not turn that
    // record's `createdBy` into the pipeline's idea of who it is: a reconciliation would then be
    // comparing against somebody else's audit key.
    final SendHarness h = SendHarness();
    final SendRequest r = testRequest();
    h.port.nextFiles = <NinoxFile>[storedFile(size: r.bytes.length)];
    h.port.nextRecord = const NinoxRecord(
      id: RecordId('9008'),
      fields: <String, Object?>{},
      createdBy: 'somebody-else',
    );

    await h.pipeline.adopt(r, const RecordId('9008'));
    h.forget();
    h.port.creates = <Object>[
      const CreateOutcomeUncertain('the response was lost'),
    ];
    h.port.nextListing = <NinoxRecord>[_candidate(id: '9009')];

    final SendOutcome outcome = await h.pipeline.send(r);

    // Still unknown, so the reconciliation asks instead of adopting on the wrong audit key.
    expect(outcome, isA<Uncertain>());
    expect((outcome as Uncertain).candidates.single.id.value, '9009');
  });
}
