/// The deep link back to the record: `ninox-send/deep-link-back-to-the-record` (FR-SND-006,
/// ADR-008), its shape, its zero calls and its degradation.
///
/// The record shape is the one the product owner copied out of the vendor's web application for a
/// record of the **test base** (a read; nothing was written). It is not a published contract, which
/// is why the degraded database form exists at all. No test here reaches the network: the link
/// builders cannot, they hold no port.
library;

import 'package:ninox_client/ninox_client.dart';
import 'package:test/test.dart';

import 'send_harness.dart';

/// The destination of the measured URL: the test team, the test database and one of its tables.
const TableRef measuredRef = TableRef(
  teamId: 'qCq3JS7q7ptoap8Yg',
  databaseId: 'jd1m8n8l4j7i',
  tableId: 'S',
);

/// The URL the product owner copied from the browser for record `869` of table `S`.
///
/// The `view/{viewId}` and `tab/0` segments it carried are optional (ADR-008) and are not emitted,
/// so the link this package builds is this URL without them — which is what the first test asserts,
/// character for character.
const String measuredUrlWithOptionalSegments =
    'https://next.ninox.com/#/teams/qCq3JS7q7ptoap8Yg/database/jd1m8n8l4j7i'
    '/module/S/view/G2rvGjOgGckdXxCm/node/S869/tab/0';

void main() {
  test('[ninox-send/deep-link-back-to-the-record] the record opens', () {
    final Uri link = recordLink(measuredRef, const RecordId('869'));

    const String upToTheTable =
        'https://next.ninox.com/#/teams/qCq3JS7q7ptoap8Yg'
        '/database/jd1m8n8l4j7i/module/S';
    // The measured URL carried `view/{viewId}` before the node segment and `tab/0` after it; both
    // are optional (ADR-008), this builder holds no view identifier, and neither is invented.
    expect(link.toString(), '$upToTheTable/node/S869');
    expect(
      measuredUrlWithOptionalSegments,
      '$upToTheTable/view/G2rvGjOgGckdXxCm/node/S869/tab/0',
    );
    // The shape the web application uses: a fragment, not a path, and no query at all.
    expect(link.host, 'next.ninox.com');
    expect(link.path, '/');
    expect(link.fragment, startsWith('/teams/'));
    expect(link.query, isEmpty);
    expect(link.hasPort, isFalse);
  });

  test('[ninox-send/deep-link-back-to-the-record] building it makes no call at all', () async {
    final SendHarness h = SendHarness();
    // A pipeline that has just sent something: the link is built from what the send already
    // returned and from the destination the app already holds (FR-SND-006).
    final SendRequest r = testRequest();
    h.port.nextFiles = <NinoxFile>[storedFile(size: r.bytes.length)];
    final SendOutcome outcome = await h.pipeline.send(r);
    final Sent sent = outcome as Sent;
    h.forget();

    final Uri link = recordLink(r.ref, sent.recordId);

    expect(h.port.calls, isEmpty);
    expect(link.fragment, contains(r.ref.tableId));
    expect(link.fragment, contains(sent.recordId.value));
    // No credential travels in the link, and the API host is not the web host.
    expect(link.userInfo, isEmpty);
    expect(link.toString(), isNot(contains('api.ninox.com')));
    expect(link.toString(), isNot(contains('Bearer')));
  });

  test('[ninox-send/deep-link-back-to-the-record] a private cloud keeps its own host', () {
    final Uri link = recordLink(
      measuredRef,
      const RecordId('869'),
      webHost: 'ninox.example.de',
    );
    final Uri withPort = recordLink(
      measuredRef,
      const RecordId('869'),
      webHost: 'ninox.example.de:8443',
    );

    expect(link.host, 'ninox.example.de');
    expect(link.path, '/');
    expect(
      link.toString(),
      startsWith('https://ninox.example.de/#/teams/qCq3JS7q7ptoap8Yg/'),
    );
    expect(withPort.host, 'ninox.example.de');
    expect(withPort.port, 8443);
    expect(withPort.path, '/');
  });

  test('[ninox-send/deep-link-back-to-the-record] a changed URL shape degrades instead of failing', () {
    final Uri database = databaseLink(measuredRef);
    final Uri record = recordLink(measuredRef, const RecordId('869'));

    // The degraded form is exactly the record link with the table and record segments removed,
    // so a caller that falls back from one to the other still lands on the same destination.
    expect(
      database.toString(),
      'https://next.ninox.com/#/teams/qCq3JS7q7ptoap8Yg/database/jd1m8n8l4j7i',
    );
    expect(record.toString(), startsWith(database.toString()));
    expect(database.fragment, isNot(contains('/module/')));
    expect(database.query, isEmpty);
  });

  test('[ninox-send/deep-link-back-to-the-record] the degraded form is not built by a call either', () {
    final SendHarness h = SendHarness();

    final Uri link = databaseLink(measuredRef);

    expect(h.port.calls, isEmpty);
    expect(link.host, ninoxWebHost);
  });

  test('every segment is percent-encoded, so an identifier a URL cannot carry still links', () {
    const TableRef oddRef = TableRef(
      teamId: 'team 1',
      databaseId: 'db/1',
      tableId: 'A B',
    );

    final Uri link = recordLink(oddRef, const RecordId('8 6'));

    expect(link.toString(), contains('/teams/team%201/'));
    expect(link.toString(), contains('/database/db%2F1/'));
    // The node segment is the table identifier concatenated with the record identifier, encoded as
    // one segment: the spaces in it are escaped once, not twice.
    expect(link.toString(), contains('/node/A%20B8%206'));
    expect(link.toString(), isNot(contains('%25')));
    expect(link.toString().split('#').length, 2);
  });

  test('the default web host is configuration, named once', () {
    expect(ninoxWebHost, 'next.ninox.com');
    expect(recordLink(measuredRef, const RecordId('869')).host, ninoxWebHost);
    expect(databaseLink(measuredRef).host, ninoxWebHost);
  });
}
