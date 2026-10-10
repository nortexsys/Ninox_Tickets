/// The reconciliation's read reaches the **end** of the destination table: the defect this file
/// exists for.
///
/// `?order=` and `?desc=` are accepted by the API and their effect is unverified (GAP-023), and the
/// default order is not known to put the newest records first. On a table longer than one page the
/// record a lost POST created can therefore be on the last page — so a read that stops after one
/// page would find *no candidates* and create the duplicate the requirement exists to prevent. The
/// fake port paginates honestly here: it serves the table in the order it is configured, oldest
/// first, so the scenario is the real one.
library;

import 'package:ninox_client/ninox_client.dart';
import 'package:test/test.dart';

import 'fake_ninox_port.dart';
import 'send_harness.dart';

/// A table of [count] records, oldest first as the API's unknown default order may well serve it.
///
/// Every record but [last] is old enough to be outside the reconciliation window, and so is never a
/// candidate; [last], when given, sits at the very end of the table with the values that were sent
/// and inside the window. It is therefore the record a read that only looks at the first page
/// misses.
List<NinoxRecord> _longTable(int count, {NinoxRecord? last}) => <NinoxRecord>[
  for (var index = 0; index < count; index++)
    if (last != null && index == count - 1)
      last
    else
      NinoxRecord(
        id: RecordId('${1000 + index}'),
        fields: const <String, Object?>{'Importe': 1, 'Fecha': '2026-01-01'},
        createdAt: '2026-10-10T11:00:00Z',
        createdBy: 'user-1',
      ),
];

/// The record a lost POST left behind, at the end of the table.
const NinoxRecord _theLostPost = NinoxRecord(
  id: RecordId('869'),
  fields: <String, Object?>{'Importe': 1999, 'Fecha': '2026-10-10'},
  createdAt: '2026-10-10T11:59:30Z',
  createdBy: 'user-1',
);

void main() {
  test('[ninox-send/reconciliation-of-an-uncertain-create] the record at the end of a long table is found', () async {
    final SendHarness h = SendHarness();
    final SendRequest r = testRequest();
    await h.learnTokenUser('user-1');
    h.forget();
    h.port.creates = <Object>[
      const CreateOutcomeUncertain('the response was lost'),
    ];
    h.port.nextListing = _longTable(230, last: _theLostPost);
    h.port.nextFiles = <NinoxFile>[storedFile(size: r.bytes.length)];

    final SendOutcome outcome = await h.pipeline.send(r);

    // The record was adopted, so no second one was written: 230 records at 100 a page is three
    // reads, and only the third carries it.
    expect(outcome, isA<Sent>());
    expect((outcome as Sent).recordId.value, '869');
    expect(h.port.calls.where((String c) => c == 'createRecord:T1').length, 1);
    expect(h.port.calls, contains('uploadFile:T1#869'));
    expect(h.port.pageReads.map((ListingCall call) => call.page), <int?>[
      0,
      1,
      2,
    ]);
  });

  test('[ninox-send/reconciliation-of-an-uncertain-create] the whole table is read before a create is decided', () async {
    final SendHarness h = SendHarness();
    final SendRequest r = testRequest();
    await h.learnTokenUser('user-1');
    h.forget();
    h.port.creates = <Object>[
      const CreateOutcomeUncertain('the response was lost'),
    ];
    // The POST did not land: the same 230 records are there, none of them this attempt's, and the
    // first page is as empty of candidates as the last.
    h.port.nextListing = _longTable(230);
    h.port.nextId = const RecordId('9002');
    h.port.nextFiles = <NinoxFile>[storedFile(size: r.bytes.length)];

    final SendOutcome outcome = await h.pipeline.send(r);

    expect(h.port.pageReads.map((ListingCall call) => call.page), <int?>[
      0,
      1,
      2,
    ]);
    expect(h.port.calls.where((String c) => c == 'createRecord:T1').length, 2);
    expect(outcome, isA<Sent>());
    expect((outcome as Sent).recordId.value, '9002');
  });

  test('[ninox-send/reconciliation-of-an-uncertain-create] pages are read in order and no ordering is asked for', () async {
    final SendHarness h = SendHarness();
    final SendRequest r = testRequest();
    await h.learnTokenUser('user-1');
    h.forget();
    h.port.creates = <Object>[
      const CreateOutcomeUncertain('the response was lost'),
    ];
    h.port.nextListing = _longTable(230);
    h.port.nextFiles = <NinoxFile>[storedFile(size: r.bytes.length)];

    await h.pipeline.send(r);

    expect(
      h.port.pageReads.map((ListingCall call) => call.perPage).toSet(),
      <int?>{100},
    );
    // No `order`, no `desc`: the reconciliation sorts and filters locally, because the
    // server-side effect of those parameters is not verified (GAP-023).
    expect(
      h.port.pageReads.every(
        (ListingCall call) => call.order == null && call.desc == null,
      ),
      isTrue,
    );
    // The reads stop at the first short page — 230 records is 100, 100, 30 — and not at a fixed
    // number of pages.
    expect(h.port.pageReads.length, 3);
  });

  test('[ninox-send/reconciliation-of-an-uncertain-create] a table longer than the page bound asks the user', () async {
    // Two pages may be read; the table is longer, so its tail — where this attempt's record would
    // be — was not seen, and nothing about it can be concluded.
    final SendHarness h = SendHarness(maxPages: 2);
    final SendRequest r = testRequest();
    await h.learnTokenUser('user-1');
    h.forget();
    h.port.creates = <Object>[
      const CreateOutcomeUncertain('the response was lost'),
    ];
    h.port.nextListing = _longTable(230, last: _theLostPost);

    final SendOutcome outcome = await h.pipeline.send(r);

    expect(h.port.pageReads.map((ListingCall call) => call.page), <int?>[0, 1]);
    expect(outcome, isA<Uncertain>());
    // No candidates rather than "none found": the tail was not seen, so this is the read that
    // could not establish the evidence, never the *zero candidates, create one* path.
    expect((outcome as Uncertain).candidates, isEmpty);
    expect(h.port.calls.where((String c) => c == 'createRecord:T1').length, 1);
    expect(h.journal.stepsOf(r.docId).last, SendStep.uncertain);
  });

  test('a bound below one page is refused rather than guessed at', () {
    final SendHarness h = SendHarness();

    expect(
      () => SendPipeline(h.port, maxPages: 0),
      throwsA(isA<ArgumentError>()),
    );
  });
}
