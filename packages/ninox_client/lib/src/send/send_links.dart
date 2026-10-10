/// The deep link back into the web application: the record a send just created, and the database
/// form it degrades to.
///
/// `ninox-send/deep-link-back-to-the-record` (FR-SND-006, ADR-008): after a successful send the
/// confirmation offers a link that opens the record, built entirely from data the application
/// already holds — the destination's team, database and table, and the record identifier the create
/// returned — with **no additional API call and no credentials**. Both builders are pure functions
/// of that data: they take no [NinoxPort] and cannot make a call.
///
/// **The web host is not the API host.** The API lives at `api.ninox.com` (ADR-017,
/// `NinoxEndpoint`), and the web application the link opens lives at `next.ninox.com`; nothing about
/// one follows from the other, which is why `webHost` is an argument with a default rather than a
/// constant buried in the builder — a private-cloud customer passes the host of their own
/// deployment.
///
/// **Provenance and GAP-008.** The record shape was measured: the product owner copied the URL of a
/// record of the **test base** out of the vendor's web application (a read; nothing was written),
/// and [recordLink] reproduces it exactly minus the two optional segments. The shape is **not a
/// published vendor contract** and can change without notice, which is why the confirmation
/// degrades to [databaseLink] instead of showing an error — and why [databaseLink]'s own shape is
/// **not** yet verified against the browser.
library;

import '../model.dart';
import '../port.dart';

/// The web application's host on the vendor's public cloud, and the default for `webHost`.
///
/// It is the host a record link opens, and it is not the API host of `NinoxEndpoint.cloud`: the API
/// answers `api.ninox.com` and the web application `next.ninox.com`. Like every host in this
/// package it is configuration with a default, never a compiled-in assumption (ADR-017,
/// `destinations-mapping/configurable-ninox-host`).
const String ninoxWebHost = 'next.ninox.com';

/// The web application's page for one record of a table — what the confirmation opens.
///
/// The URL is `https://{webHost}/#/teams/{team}/database/{database}/module/{table}/node/{table}{id}`
/// (ADR-008; the shape was read from the vendor's web application for a record of the test base and
/// is not a published contract):
///
/// * the segment after `#` is a **fragment**, not a path: the web application reads it, the server
///   never sees it, and it is emitted literally;
/// * `module/{tableId}` is the table identifier exactly as [TableRef.tableId] carries it;
/// * `node/{...}` is the table identifier **concatenated with** the record's numeric identifier —
///   record `869` of table `S` is `node/S869` — because [RecordId] is the numeric part alone;
/// * the `view/{viewId}` and `tab/{n}` segments the web application also puts in that URL are
///   **optional** and are deliberately not emitted: this builder holds no view identifier, and
///   ADR-008 verified that the view segment may be absent;
/// * every segment is percent-encoded, so an identifier with a character a URL does not carry
///   literal still produces a usable link.
///
/// No call is made and no credential is used: everything in the URL is the destination the app
/// already stores and the identifier the create returned. If the shape stops resolving, the caller
/// falls back to [databaseLink] rather than showing an error (GAP-008).
///
/// [webHost] is the host of the **web application** — a host label, with a port when the deployment
/// has one, and not a URL: a private-cloud destination passes its own, the same way it passes its
/// API host to `NinoxEndpoint`.
Uri recordLink(TableRef ref, RecordId id, {String webHost = ninoxWebHost}) =>
    _webUri(
      webHost,
      '/teams/${Uri.encodeComponent(ref.teamId)}'
      '/database/${Uri.encodeComponent(ref.databaseId)}'
      '/module/${Uri.encodeComponent(ref.tableId)}'
      '/node/${Uri.encodeComponent('${ref.tableId}${id.value}')}',
    );

/// The web application's page for the destination's **database** — the degraded form of
/// [recordLink].
///
/// This is what the confirmation opens when the record link no longer resolves: ADR-008 and FR-SND-006
/// require the action to degrade rather than fail, and the database is the widest address the
/// destination can still vouch for.
///
/// **Provenance: not verified against the browser.** The record shape above was copied out of the
/// vendor's web application; this shorter form is the same shape with the table and record segments
/// removed, which is an inference from it and not a measurement. It is kept beside [recordLink],
/// under the same GAP-008 caveat, and the confirmation is expected to fall back from it to nothing
/// rather than to an error if the shape changes again.
///
/// [webHost] is [recordLink]'s, with the same default.
Uri databaseLink(TableRef ref, {String webHost = ninoxWebHost}) => _webUri(
  webHost,
  '/teams/${Uri.encodeComponent(ref.teamId)}'
  '/database/${Uri.encodeComponent(ref.databaseId)}',
);

/// Builds the link: `https://{webHost}/` with [fragment] after it, which is what the web
/// application's own URLs are.
///
/// A trailing `/` before the `#` is what the measured URL carries, and the fragment is normalised
/// by [Uri] rather than assembled by string concatenation, so a segment this package encoded by
/// hand is never encoded a second time.
Uri _webUri(String webHost, String fragment) =>
    Uri.parse('https://$webHost/').replace(fragment: fragment);
