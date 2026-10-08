import 'dart:convert';
import 'dart:typed_data';

import 'package:ninox_client/ninox_client.dart';
import 'package:test/test.dart';

import 'live/t19_support.dart';

/// The T1.9 support helpers, proved **without a token**: this file is untagged, so it runs in every
/// lane and in every CI run, while `live/write_limits_test.dart` needs the product owner's machine.
///
/// What is proved here is what a single live run cannot afford to get wrong: that the caps refuse a
/// call before it is made, and that the synthetic documents really are PDFs of the size asked for,
/// with an xref table whose entries point at their own objects.
void main() {
  group('WriteBudget refuses before the call', () {
    test('the defaults are the approved caps', () {
      final budget = WriteBudget();

      expect(budget.maxRecords, 30);
      expect(budget.maxAttachmentBytes, 25 * mebibyte);
      expect(budget.maxTotalBytes, 150 * mebibyte);
      expect(budget.recordsCreated, 0);
      expect(budget.bytesUploaded, 0);
    });

    test('it counts creates and refuses the one that would pass the cap', () {
      final budget = WriteBudget(maxRecords: 3);

      for (var index = 0; index < 3; index++) {
        budget.beforeCreate();
        budget.afterCreate();
      }

      expect(budget.recordsCreated, 3);
      expect(budget.beforeCreate, throwsA(isA<WriteBudgetExceeded>()));
      expect(
        budget.recordsCreated,
        3,
        reason: 'a refused create is not counted',
      );
    });

    test('it refuses one attachment above the per-attachment cap', () {
      final budget = WriteBudget(maxRecords: 30, maxAttachmentBytes: 1000);

      expect(() => budget.beforeUpload(1000), returnsNormally);
      expect(
        () => budget.beforeUpload(1001),
        throwsA(isA<WriteBudgetExceeded>()),
      );
      expect(
        budget.bytesUploaded,
        0,
        reason: 'a refused upload is not counted',
      );
    });

    test('it refuses the upload that would pass the total cap', () {
      final budget = WriteBudget(maxAttachmentBytes: 1000, maxTotalBytes: 1500);

      budget.beforeUpload(1000);
      budget.afterUpload(1000);
      expect(() => budget.beforeUpload(500), returnsNormally);
      expect(
        () => budget.beforeUpload(501),
        throwsA(isA<WriteBudgetExceeded>()),
      );
      expect(budget.bytesUploaded, 1000);
      expect(budget.toJson(), {
        'maxRecords': 30,
        'maxAttachmentBytes': 1000,
        'maxTotalBytes': 1500,
        'recordsCreated': 0,
        'bytesUploaded': 1000,
      });
    });
  });

  group('syntheticPdf writes a PDF of the size asked for', () {
    test('a one-page document of a few kilobytes', () {
      final bytes = syntheticPdf(pages: 1, targetBytes: 4 * 1024);

      _expectSoundPdf(bytes, pages: 1, targetBytes: 4 * 1024);
    });

    test('a multipage document, wrapped across two xref digit widths', () {
      final small = syntheticPdf(pages: 3, targetBytes: 20 * 1024);
      final large = syntheticPdf(pages: 8, targetBytes: 2 * mebibyte);

      _expectSoundPdf(small, pages: 3, targetBytes: 20 * 1024);
      _expectSoundPdf(large, pages: 8, targetBytes: 2 * mebibyte);
      expect(large.length, greaterThan(small.length));
    });

    test('the largest size the ladder may ask for stays inside the per-attachment cap', () {
      final bytes = syntheticPdf(pages: 1, targetBytes: 25 * mebibyte);

      _expectSoundPdf(bytes, pages: 1, targetBytes: 25 * mebibyte);
      WriteBudget().beforeUpload(bytes.length);
    });

    test('a page count below one is refused rather than guessed at', () {
      expect(
        () => syntheticPdf(pages: 0, targetBytes: 1024),
        throwsArgumentError,
      );
      expect(() => syntheticPdf(pages: 1, targetBytes: 0), throwsArgumentError);
    });
  });

  group('classify reads a failure the way the ladder must', () {
    test('an answer about a size stops the ladder as a measurement', () {
      expect(classify(const UnexpectedResponse('HTTP 413')), Verdict.limit);
      expect(
        classify(const TransportFailure('a request that ran out of time')),
        Verdict.limit,
      );
    });

    test('a 5xx and a 429 are unexpected, whatever they look like', () {
      // ADR-004: this API answers an invalid, formula or read-only field name with HTTP 500, so a
      // 500 on an attachment is a finding, not evidence about a size limit.
      expect(
        classify(const ServerError(500, 'Unknown field')),
        Verdict.unexpected,
      );
      expect(classify(const RateLimited()), Verdict.unexpected);
    });

    test('a lost create is fatal even though it is a transport failure', () {
      expect(const CreateOutcomeUncertain(), isA<TransportFailure>());
      expect(classify(const CreateOutcomeUncertain()), Verdict.fatal);
    });

    test('an authentication or destination failure stops the run', () {
      expect(classify(const Unauthorized()), Verdict.fatal);
      expect(classify(const NotFound()), Verdict.fatal);
    });
  });

  group('sameValue compares a read-back with what was sent', () {
    test('numbers compare numerically, so an integer read back as a decimal is the same value', () {
      expect(sameValue(1999, 1999), isTrue);
      expect(sameValue(1999, 1999.0), isTrue);
      expect(sameValue(1999, 2049), isFalse);
    });

    test('a date accepts the stored day or an ISO-8601 stamp of it', () {
      expect(sameValue('2026-10-08', '2026-10-08', asDate: true), isTrue);
      expect(
        sameValue('2026-10-08', '2026-10-08T00:00:00Z', asDate: true),
        isTrue,
      );
      expect(sameValue('2026-10-08', '2026-10-09', asDate: true), isFalse);
      expect(
        sameValue('2026-10-08', '2026-10-08T00:00:00Z'),
        isFalse,
        reason: 'the tolerance belongs to the date field, not to every string',
      );
    });

    test('text is compared exactly, including the non-ASCII the run writes on purpose', () {
      const sent = 'T1.9 synthetic — disposable';

      expect(sameValue(sent, sent), isTrue);
      expect(sameValue(sent, 'T1.9 synthetic'), isFalse);
      expect(sameValue(null, null), isTrue);
      expect(sameValue(null, ''), isFalse);
    });

    test('a list or a nested object compares by value', () {
      expect(sameValue(const [1, 2], const [1, 2]), isTrue);
      expect(sameValue(const [1, 2], const [2, 1]), isFalse);
    });
  });

  group('rateMibPerSecond', () {
    test('reports MiB per second to two decimals', () {
      expect(rateMibPerSecond(mebibyte, 1000), '1.00');
      expect(rateMibPerSecond(mebibyte, 500), '2.00');
      expect(rateMibPerSecond(25 * mebibyte, 2000), '12.50');
    });
  });

  group('deleteOutcome reads a delete the way the run must', () {
    test('200 and 204 are a delete', () {
      expect(deleteOutcome(200), DeleteOutcome.deleted);
      expect(deleteOutcome(204), DeleteOutcome.deleted);
    });

    test('404 for an id this run created is already gone, never a failure', () {
      // The 2026-10-08 run: every delete answered 200, a second overlapping pass answered 404 for
      // seven records that were already deleted, and the run reported a table it had cleaned up as
      // dirty. A 404 here means the delete had already happened, which is what it was for.
      expect(deleteOutcome(404), DeleteOutcome.alreadyGone);
      expect(deleteOutcome(404), isNot(DeleteOutcome.failed));
    });

    test('anything else is a failure to report', () {
      expect(deleteOutcome(400), DeleteOutcome.failed);
      expect(deleteOutcome(401), DeleteOutcome.failed);
      expect(deleteOutcome(500), DeleteOutcome.failed);
    });
  });

  group('listUntilSettled waits out a listing that lags a delete', () {
    test('one listing is enough when the answer is already settled', () async {
      final listings = <int>[];
      final snapshot = await listUntilSettled(
        list: () async {
          listings.add(0);
          return {'1', '2'};
        },
        preexisting: {'1', '2'},
        created: {'7'},
        sleep: (_) async {
          fail('a settled listing must not be waited on');
        },
      );

      expect(listings, hasLength(1));
      expect(snapshot.attempts, 1);
      expect(snapshot.settled, isTrue);
      expect(snapshot.left, isEmpty);
      expect(snapshot.missing, isEmpty);
    });

    test('it re-lists while an id this run deleted is still shown, then believes the listing', () async {
      var listing = 0;
      final slept = <Duration>[];
      final snapshot = await listUntilSettled(
        list: () async {
          listing++;
          // The first two readings still show the record; the third does not.
          return listing < 3 ? {'1', '2', '7'} : {'1', '2'};
        },
        preexisting: {'1', '2'},
        created: {'7'},
        sleep: (duration) async => slept.add(duration),
      );

      expect(snapshot.attempts, 3);
      expect(snapshot.settled, isTrue);
      expect(snapshot.left, isEmpty, reason: 'the third listing is the answer');
      expect(
        snapshot.firstListingLeft,
        ['7'],
        reason:
            'the first listing showed it: that is the lag, kept as evidence',
      );
      expect(slept, [verifyWait, verifyWait]);
    });

    test('it gives up at the bound and reports what it still sees', () async {
      var listing = 0;
      final snapshot = await listUntilSettled(
        list: () async {
          listing++;
          return {'1', '7', '8'};
        },
        preexisting: {'1', '2'},
        created: {'7', '8'},
        attempts: 3,
        sleep: (_) async {},
      );

      expect(listing, 3, reason: 'bounded: three listings and no more');
      expect(snapshot.attempts, 3);
      expect(snapshot.settled, isFalse);
      expect(sortedIds(snapshot.left), ['7', '8']);
      expect(
        sortedIds(snapshot.missing),
        ['2'],
        reason: 'a pre-existing id the listing no longer shows is reported too',
      );
    });

    test('an id that is neither pre-existing nor the run\'s is reported, and not waited for', () async {
      var listing = 0;
      final snapshot = await listUntilSettled(
        list: () async {
          listing++;
          return {'1', '99'};
        },
        preexisting: {'1'},
        created: {'7'},
        sleep: (_) async {},
      );

      expect(
        listing,
        1,
        reason:
            'nothing of the run is left and nothing pre-existing is missing',
      );
      expect(snapshot.settled, isTrue);
      expect(sortedIds(snapshot.untracked), ['99']);
    });

    test('the snapshot records the policy it ran with', () async {
      final snapshot = await listUntilSettled(
        list: () async => {'1'},
        preexisting: {'1'},
        created: {'7'},
        attempts: 4,
        wait: const Duration(milliseconds: 10),
        sleep: (_) async {},
      );

      expect(snapshot.toJson(), {
        'listings': 1,
        'listingsSpacedByMs': 10,
        'settled': true,
        'preexistingAllPresent': true,
        'missingPreexistingIds': <String>[],
        'recordsLeftByThisRun': <String>[],
        'createdIdsSeenOnTheFirstListing': <String>[],
        'untrackedIdsSeen': <String>[],
      });
    });

    test('a bound below one is refused rather than guessed at', () {
      expect(
        () => listUntilSettled(
          list: () async => <String>{},
          preexisting: const {},
          created: const {},
          attempts: 0,
        ),
        throwsArgumentError,
      );
    });
  });

  group('sortedIds orders ids the way a human reads them', () {
    test('numerically when every id is a number', () {
      expect(sortedIds({'10', '7', '16', '8'}), ['7', '8', '10', '16']);
    });

    test('lexicographically when any id is not a number', () {
      expect(sortedIds({'team-2', 'team-10'}), ['team-10', 'team-2']);
    });

    test('an empty set is an empty list', () {
      expect(sortedIds(const <String>{}), isEmpty);
    });
  });
}

/// Checks the document against what a PDF is: header, xref, trailer, and one `n 0 obj` at every
/// offset the xref names.
void _expectSoundPdf(
  Uint8List bytes, {
  required int pages,
  required int targetBytes,
}) {
  // Latin-1 maps one character to one byte, so offsets taken from the text are byte offsets.
  final text = latin1.decode(bytes);

  expect(text.startsWith('%PDF-1.7\n'), isTrue);
  expect(text.endsWith('%%EOF\n'), isTrue);
  expect(text, contains('/Count $pages'));
  expect(
    RegExp(r'\bstream\b').allMatches(text).length,
    pages,
    reason: 'one content stream per page (`\\bstream\\b` does not match inside `endstream`)',
  );
  expect(
    bytes.length,
    lessThanOrEqualTo(targetBytes),
    reason: 'a target equal to a cap must not produce a document that passes the cap',
  );
  expect(
    bytes.length,
    greaterThan(targetBytes - 64),
    reason: 'and it is within 64 bytes below the size the ladder asked for',
  );

  final startxref = RegExp(r'startxref\n(\d+)\n%%EOF\n').firstMatch(text);
  expect(startxref, isNotNull, reason: 'a PDF ends by pointing at its xref');
  final xrefOffset = int.parse(startxref!.group(1)!);
  expect(text.substring(xrefOffset, xrefOffset + 4), 'xref');

  final lines = text.substring(xrefOffset).split('\n');
  final size = int.parse(RegExp(r'^0 (\d+)$').firstMatch(lines[1])!.group(1)!);
  expect(
    size,
    2 * pages + 4,
    reason: 'catalog, pages, one page and one content stream per page, font — plus the free head',
  );
  for (var object = 1; object < size; object++) {
    final entry = lines[2 + object];
    expect(
      entry.endsWith(' n '),
      isTrue,
      reason: 'object $object is listed as in use',
    );
    final offset = int.parse(entry.substring(0, 10));
    final expected = '$object 0 obj';
    expect(
      text.substring(offset, offset + expected.length),
      expected,
      reason: 'the xref entry for object $object points at its own object',
    );
  }
  expect(lines[2].endsWith(' f '), isTrue, reason: 'object 0 is the free head');
}
