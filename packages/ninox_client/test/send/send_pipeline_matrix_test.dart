/// The retry matrix of `ninox-send/the-retry-matrix` (FR-SND-004), one test per row of the change's
/// design §3.
///
/// The matrix is a table rather than a principle on purpose: the intuitive answer is wrong for
/// several of its rows — a 500 is a mapping error and not an outage, a lost create must not be
/// retried, a 401 makes sleeping pointless — so each row is proved here as the behaviour of a
/// scripted call and not as an intention.
library;

import 'package:ninox_client/ninox_client.dart';
import 'package:test/test.dart';

import 'send_harness.dart';

void main() {
  test('[ninox-send/the-retry-matrix] no connectivity before the request left leaves the send queued', () async {
    final SendHarness h = SendHarness();
    final SendRequest r = testRequest();
    h.port.creates = <Object>[const TransportFailure('no route to host')];

    final SendOutcome outcome = await h.pipeline.send(r);

    expect(outcome, isA<Queued>());
    // Nothing was retried, nothing else was called: the request never left.
    expect(h.port.calls, <String>['createRecord:T1']);
    expect(h.slept, isEmpty);
    expect(h.journal.stepsOf(r.docId), <SendStep>[
      SendStep.sending,
      SendStep.queued,
    ]);
  });

  test(
    '[ninox-send/the-retry-matrix] a timed-out create is not retried',
    () async {
      final SendHarness h = SendHarness();
      final SendRequest r = testRequest();
      h.port.creates = <Object>[
        const CreateOutcomeUncertain('the response was lost'),
      ];
      h.port.nextId = const RecordId('1419');
      h.port.nextFiles = <NinoxFile>[storedFile(size: r.bytes.length)];

      final SendOutcome outcome = await h.pipeline.send(r);

      // The call after the lost create is the reconciliation's read, never a second POST.
      expect(h.port.calls.first, 'createRecord:T1');
      expect(h.port.calls[1], 'listRecords:T1');
      expect(h.port.listedPerPage, 50);
      // Nothing was found, so exactly one create followed — and the send completed.
      expect(
        h.port.calls.where((String c) => c == 'createRecord:T1').length,
        2,
      );
      expect(outcome, isA<Sent>());
      expect(h.journal.stepsOf(r.docId), contains(SendStep.uncertain));
      expect(h.journal.stepsOf(r.docId).last, SendStep.sent);
    },
  );

  test(
    '[ninox-send/the-retry-matrix] an attachment timeout is safe to retry',
    () async {
      final SendHarness h = SendHarness();
      final SendRequest r = testRequest();
      h.port.uploads = <Object>[
        const TransportFailure('the response was lost'),
        const TransportFailure('the response was lost'),
      ];
      h.port.nextFiles = <NinoxFile>[storedFile(size: r.bytes.length)];

      final SendOutcome outcome = await h.pipeline.send(r);

      expect(h.slept, <Duration>[
        const Duration(seconds: 1),
        const Duration(seconds: 2),
      ]);
      expect(outcome, isA<Sent>());
      // Neither timeout could duplicate a record: exactly one was created.
      expect(
        h.port.calls.where((String c) => c == 'createRecord:T1').length,
        1,
      );
    },
  );

  test('[ninox-send/the-retry-matrix] a timeout on the upload is bounded and reported incomplete', () async {
    final SendHarness h = SendHarness();
    final SendRequest r = testRequest();
    h.port.nextId = const RecordId('1420');
    h.port.uploads = <Object>[
      const TransportFailure('timed out'),
      const TransportFailure('timed out'),
      const TransportFailure('timed out'),
      const TransportFailure('timed out'),
    ];

    final SendOutcome outcome = await h.pipeline.send(r);

    expect(h.slept, <Duration>[
      const Duration(seconds: 1),
      const Duration(seconds: 2),
      const Duration(seconds: 4),
    ]);
    expect(
      h.port.calls.where((String c) => c.startsWith('uploadFile')).length,
      4,
    );
    expect(outcome, isA<Incomplete>());
    expect((outcome as Incomplete).recordId.value, '1420');
    // The record exists and is not reported as done: it is the resume() case.
    expect(h.journal.stepsOf(r.docId).last, SendStep.incomplete);
  });

  test('[ninox-send/the-retry-matrix] a timeout on the read-back is bounded and reported incomplete', () async {
    final SendHarness h = SendHarness();
    final SendRequest r = testRequest();
    h.port.nextId = const RecordId('1421');
    h.port.nextFiles = <NinoxFile>[storedFile(size: r.bytes.length)];
    h.port.reads = <Object>[
      const TransportFailure('timed out'),
      const TransportFailure('timed out'),
      const TransportFailure('timed out'),
      const TransportFailure('timed out'),
    ];

    final SendOutcome outcome = await h.pipeline.send(r);

    expect(h.slept, <Duration>[
      const Duration(seconds: 1),
      const Duration(seconds: 2),
      const Duration(seconds: 4),
    ]);
    expect(outcome, isA<Incomplete>());
    expect((outcome as Incomplete).recordId.value, '1421');
    // The attachment is already in the record; only the read-back failed.
    expect(h.port.calls, contains('uploadFile:T1#1421'));
  });

  test('[ninox-send/the-retry-matrix] a timeout on the files read is bounded and reported incomplete', () async {
    final SendHarness h = SendHarness();
    final SendRequest r = testRequest();
    h.port.nextId = const RecordId('1422');
    h.port.files = <Object>[
      const TransportFailure('timed out'),
      const TransportFailure('timed out'),
      const TransportFailure('timed out'),
      const TransportFailure('timed out'),
    ];

    final SendOutcome outcome = await h.pipeline.send(r);

    expect(h.slept, <Duration>[
      const Duration(seconds: 1),
      const Duration(seconds: 2),
      const Duration(seconds: 4),
    ]);
    expect(outcome, isA<Incomplete>());
    expect((outcome as Incomplete).recordId.value, '1422');
  });

  test('[ninox-send/the-retry-matrix] the attempts bound is a total, not a number of retries', () async {
    final SendHarness h = SendHarness(attachmentAttempts: 2);
    final SendRequest r = testRequest();
    h.port.nextId = const RecordId('1423');
    h.port.uploads = <Object>[
      const TransportFailure('timed out'),
      const TransportFailure('timed out'),
    ];

    final SendOutcome outcome = await h.pipeline.send(r);

    expect(
      h.port.calls.where((String c) => c.startsWith('uploadFile')).length,
      2,
    );
    expect(h.slept, <Duration>[const Duration(seconds: 1)]);
    expect(outcome, isA<Incomplete>());
  });

  test('[ninox-send/the-retry-matrix] an authentication failure asks for the token', () async {
    final SendHarness h = SendHarness();
    final SendRequest r = testRequest();
    h.port.creates = <Object>[const Unauthorized('the token expired')];

    final SendOutcome outcome = await h.pipeline.send(r);

    expect(outcome, isA<Failed>());
    final Failed failed = outcome as Failed;
    expect(failed.kind, SendFailureKind.auth);
    expect(failed.failure, isA<Unauthorized>());
    // No retry and no sleep: a 401 is not fixed by waiting.
    expect(h.port.calls, <String>['createRecord:T1']);
    expect(h.slept, isEmpty);
    expect(h.journal.stepsOf(r.docId).last, SendStep.failed);
  });

  test(
    '[ninox-send/the-retry-matrix] a vanished destination is not retried',
    () async {
      final SendHarness h = SendHarness();
      final SendRequest r = testRequest();
      h.port.creates = <Object>[const NotFound('Team Not Found')];

      final SendOutcome outcome = await h.pipeline.send(r);

      expect(outcome, isA<Failed>());
      expect((outcome as Failed).kind, SendFailureKind.destinationGone);
      expect(h.port.calls, <String>['createRecord:T1']);
      expect(h.slept, isEmpty);
    },
  );

  test(
    '[ninox-send/the-retry-matrix] a 500 is reported as a mapping error',
    () async {
      final SendHarness h = SendHarness();
      final SendRequest r = testRequest();
      h.port.creates = <Object>[
        const ServerError(500, 'Unknown field'),
        const ServerError(500, 'Unknown field'),
      ];

      final SendOutcome outcome = await h.pipeline.send(r);

      expect(outcome, isA<Failed>());
      expect((outcome as Failed).kind, SendFailureKind.mapping);
      // The schema was refreshed before the single retry, and the retry happened exactly once.
      expect(h.refreshes, 1);
      expect(h.port.calls, <String>['createRecord:T1', 'createRecord:T1']);
      expect(h.slept, isEmpty);
    },
  );

  test(
    '[ninox-send/the-retry-matrix] a 500 is never retried forever',
    () async {
      final SendHarness h = SendHarness();
      final SendRequest r = testRequest();
      h.port.creates = <Object>[
        const ServerError(500, 'Unknown field'),
        const ServerError(500, 'Unknown field'),
        const ServerError(500, 'Unknown field'),
      ];

      final SendOutcome outcome = await h.pipeline.send(r);

      expect(outcome, isA<Failed>());
      // The third scripted 500 was never asked for: one retry means one.
      expect(h.port.calls, <String>['createRecord:T1', 'createRecord:T1']);
      expect(h.refreshes, 1);
    },
  );

  test('[ninox-send/the-retry-matrix] a 500 during the read-back is a server failure, not a mapping one', () async {
    final SendHarness h = SendHarness();
    final SendRequest r = testRequest();
    h.port.nextFiles = <NinoxFile>[storedFile(size: r.bytes.length)];
    h.port.reads = <Object>[
      const ServerError(500, 'boom'),
      const ServerError(500, 'boom'),
    ];

    final SendOutcome outcome = await h.pipeline.send(r);

    expect(outcome, isA<Failed>());
    expect((outcome as Failed).kind, SendFailureKind.server);
    expect(h.refreshes, 1);
    expect(
      h.port.calls.where((String c) => c.startsWith('readRecord')).length,
      2,
    );
    expect(h.slept, isEmpty);
  });

  test('[ninox-send/the-retry-matrix] a rate-limited create is a server failure and is not retried', () async {
    final SendHarness h = SendHarness();
    final SendRequest r = testRequest();
    h.port.creates = <Object>[const RateLimited('too many requests')];

    final SendOutcome outcome = await h.pipeline.send(r);

    expect(outcome, isA<Failed>());
    expect((outcome as Failed).kind, SendFailureKind.server);
    // A rate-limited create may have landed: no retry and no wait.
    expect(h.port.calls, <String>['createRecord:T1']);
    expect(h.slept, isEmpty);
  });

  test(
    '[ninox-send/the-retry-matrix] a rate-limited attachment backs off',
    () async {
      final SendHarness h = SendHarness();
      final SendRequest r = testRequest();
      h.port.uploads = <Object>[const RateLimited('too many requests')];
      h.port.nextFiles = <NinoxFile>[storedFile(size: r.bytes.length)];

      final SendOutcome outcome = await h.pipeline.send(r);

      expect(h.slept, <Duration>[const Duration(seconds: 1)]);
      expect(outcome, isA<Sent>());
    },
  );

  test('[ninox-send/the-retry-matrix] an unreadable response to a create is reconciled, never re-posted', () async {
    final SendHarness h = SendHarness();
    final SendRequest r = testRequest();
    // A 2xx whose body carried no identifier is this failure — the record may exist.
    h.port.creates = <Object>[
      const UnexpectedResponse('a 200 without an identifier'),
    ];
    h.port.nextFiles = <NinoxFile>[storedFile(size: r.bytes.length)];

    final SendOutcome outcome = await h.pipeline.send(r);

    expect(h.port.calls[1], 'listRecords:T1');
    expect(outcome, isA<Sent>());
    expect(h.journal.stepsOf(r.docId), contains(SendStep.uncertain));
  });

  test('[ninox-send/the-retry-matrix] an unreadable response to a read-back is a server failure', () async {
    final SendHarness h = SendHarness();
    final SendRequest r = testRequest();
    h.port.files = <Object>[
      const UnexpectedResponse('not json'),
      const UnexpectedResponse('not json'),
    ];

    final SendOutcome outcome = await h.pipeline.send(r);

    expect(outcome, isA<Failed>());
    expect((outcome as Failed).kind, SendFailureKind.server);
    expect(h.refreshes, 1);
  });

  test('[ninox-send/the-retry-matrix] a rate-limited reconciliation read asks rather than deciding', () async {
    final SendHarness h = SendHarness(attachmentAttempts: 2);
    final SendRequest r = testRequest();
    h.port.creates = <Object>[
      const CreateOutcomeUncertain('the response was lost'),
    ];
    h.port.listings = <Object>[
      const RateLimited('too many requests'),
      const RateLimited('too many requests'),
    ];

    final SendOutcome outcome = await h.pipeline.send(r);

    // The create's outcome is still unknown and the evidence could not be read: the user is asked,
    // with no candidates, rather than one more record being written on a guess.
    expect(outcome, isA<Uncertain>());
    expect((outcome as Uncertain).candidates, isEmpty);
    expect(h.port.calls.where((String c) => c == 'createRecord:T1').length, 1);
    expect(h.slept, <Duration>[const Duration(seconds: 1)]);
  });
}
