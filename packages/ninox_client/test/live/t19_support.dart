/// The pure helpers behind the T1.9 live write run (`write_limits_test.dart`).
///
/// They live here, apart from the live test, because they are testable **without a token**: the
/// synthetic documents have to be real PDFs of the size the ladder asks for, and the caps have to
/// refuse a call *before* it is made rather than report afterwards that it was passed. Both are
/// proved in CI by `test/t19_support_test.dart`, which runs in every lane and in every CI run.
///
/// Nothing here touches the network, the environment or a file.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:ninox_client/ninox_client.dart';

/// One mebibyte, the unit the size ladder is stated in.
const int mebibyte = 1024 * 1024;

/// How a failure is read while the T1.9 run is going on.
enum Verdict {
  /// The API's answer about a size — a 413, or a request that ran out of time at this size. The
  /// ladder stops here, and that stop **is** the measurement.
  limit,

  /// Something the run did not ask for: a 5xx (which in this API is usually a field-name problem
  /// rather than an outage), a 429, or a create whose outcome is unknown. The ladder stops and the
  /// run is reported with a finding.
  unexpected,

  /// The run cannot continue at all: the token is not accepted, or the table is not there.
  fatal,
}

/// Reads a failure the way the T1.9 run must: as an answer about a size, as something unexpected, or
/// as a reason to stop everything.
///
/// The classification is counter-intuitive enough to be worth stating rather than improvising —
/// ADR-004: an HTTP 500 from this API is usually the caller's own field name, and a 500 on an
/// attachment is therefore not evidence about a size limit but a finding to report.
Verdict classify(NinoxFailure failure) => switch (failure) {
  Unauthorized() || NotFound() => Verdict.fatal,
  // Cannot come from an upload, and must never be ignored if it somehow does.
  CreateOutcomeUncertain() => Verdict.fatal,
  ServerError() || RateLimited() => Verdict.unexpected,
  // A 413, or any other status the adapter cannot place: the API answering about the size.
  UnexpectedResponse() => Verdict.limit,
  // A request that ran out of time at this size: the limit, or the network, showing itself here.
  TransportFailure() => Verdict.limit,
};

/// Whether what came back is what was sent.
///
/// Numbers are compared numerically, because the same integer can arrive as a JSON number of either
/// kind. With [asDate], the stored value may be the `YYYY-MM-DD` that was sent or an ISO-8601 stamp
/// of the same day, and either is accepted — the run records which one it saw rather than assuming
/// a shape the skill does not settle. Everything else is compared as JSON, so a list or a nested
/// object compares by value.
bool sameValue(Object? submitted, Object? stored, {bool asDate = false}) {
  if (submitted is num && stored is num) {
    return submitted.toDouble() == stored.toDouble();
  }
  if (asDate && submitted is String && stored is String) {
    return stored == submitted || stored.startsWith(submitted);
  }
  return jsonEncode(submitted) == jsonEncode(stored);
}

/// The upload rate of one step, in mebibytes per second, to two decimals.
String rateMibPerSecond(int bytes, int elapsedMs) =>
    (bytes / mebibyte / (elapsedMs / 1000)).toStringAsFixed(2);

/// What a DELETE answered, as the T1.9 run must read it.
///
/// The 404 case is not a formality: on the 2026-10-08 run every delete answered 200 and the same
/// ten ids were also deleted by a second, overlapping pass, which saw the records already gone and
/// answered 404 "Not Found" — seven ids that were recorded as delete **failures** although the
/// records were gone, which is what made the run report a table it had cleaned up as dirty.
enum DeleteOutcome {
  /// HTTP 200 or 204: the record was deleted by this call.
  deleted,

  /// HTTP 404: the record is not there, which is what deleting it was for. It counts as **gone**,
  /// because either a second pass or the API itself applied the delete twice — and a delete this
  /// run asked for is not a failure when its only cause is that it had already happened.
  alreadyGone,

  /// Any other status, or a delete that never completed: reported, with its id, for a human.
  failed,
}

/// Reads one delete's status the way the run must.
DeleteOutcome deleteOutcome(int statusCode) => switch (statusCode) {
  200 || 204 => DeleteOutcome.deleted,
  404 => DeleteOutcome.alreadyGone,
  _ => DeleteOutcome.failed,
};

/// How many listings a verification may take before it believes what it sees.
const int verifyAttempts = 6;

/// How long it waits between those listings.
///
/// A listing lags a delete: the 2026-10-08 run's own end-of-run check showed eight ids it had just
/// deleted, while the same table was clean by the time it was read again. Five seconds a time, six
/// times, is twenty-five seconds of patience — bounded, so a record that really did survive is
/// still reported.
const Duration verifyWait = Duration(seconds: 5);

/// What a (possibly repeated) listing of the table says about a T1.9 run's records.
final class ListingSnapshot {
  /// Builds a snapshot.
  const ListingSnapshot({
    required this.attempts,
    required this.left,
    required this.missing,
    required this.untracked,
    required this.firstListingLeft,
    required this.waited,
  });

  /// How many listings were made before the answer settled (or before the bound was reached).
  final int attempts;

  /// Ids this run created that the last listing still showed.
  final Set<String> left;

  /// Ids that were in the table before the run and that the last listing no longer shows.
  final Set<String> missing;

  /// Ids the last listing showed that were neither there before the run nor created by it.
  final Set<String> untracked;

  /// Ids this run created that the **first** listing still showed.
  ///
  /// This is the lag itself, recorded as evidence: when [left] is empty and this is not, the run
  /// saw records that had already been deleted and saw them disappear, rather than finding records
  /// that survived.
  final List<String> firstListingLeft;

  /// How long the listings were spaced by.
  final Duration waited;

  /// Whether the last listing says what the run wanted: nothing of its own left, and nothing that
  /// was there before it missing.
  bool get settled => left.isEmpty && missing.isEmpty;

  /// The snapshot, for the results file.
  Map<String, Object?> toJson() => {
    'listings': attempts,
    'listingsSpacedByMs': waited.inMilliseconds,
    'settled': settled,
    'preexistingAllPresent': missing.isEmpty,
    'missingPreexistingIds': sortedIds(missing),
    'recordsLeftByThisRun': sortedIds(left),
    'createdIdsSeenOnTheFirstListing': firstListingLeft,
    'untrackedIdsSeen': sortedIds(untracked),
  };
}

/// Lists a table, re-listing while the answer is not settled, with a bounded number of attempts.
///
/// A listing lags a delete, so "a record this run created is still there" is not concluded from one
/// reading. The loop stops as soon as nothing of the run's is left and nothing that was there
/// before is missing, and otherwise runs to the bound — after which whatever it still sees is
/// reported as a record to remove by hand.
///
/// [sleep] is injected so that this can be proved offline without waiting: the tests pass a
/// no-op, the live run passes the real one.
Future<ListingSnapshot> listUntilSettled({
  required Future<Set<String>> Function() list,
  required Set<String> preexisting,
  required Set<String> created,
  int attempts = verifyAttempts,
  Duration wait = verifyWait,
  Future<void> Function(Duration) sleep = realSleep,
}) async {
  if (attempts < 1) {
    throw ArgumentError.value(
      attempts,
      'attempts',
      'a verification lists at least once',
    );
  }
  var seen = <String>{};
  var left = <String>{};
  var missing = <String>{};
  var untracked = <String>{};
  final firstListingLeft = <String>[];
  for (var attempt = 1; attempt <= attempts; attempt++) {
    if (attempt > 1) await sleep(wait);
    seen = await list();
    left = seen.intersection(created);
    missing = preexisting.difference(seen);
    untracked = seen.difference(preexisting).difference(created);
    if (attempt == 1) firstListingLeft.addAll(sortedIds(left));
    if (left.isEmpty && missing.isEmpty) {
      return ListingSnapshot(
        attempts: attempt,
        left: left,
        missing: missing,
        untracked: untracked,
        firstListingLeft: firstListingLeft,
        waited: wait,
      );
    }
  }
  return ListingSnapshot(
    attempts: attempts,
    left: left,
    missing: missing,
    untracked: untracked,
    firstListingLeft: firstListingLeft,
    waited: wait,
  );
}

/// Waits for real. The default of [listUntilSettled], and the only place it touches the clock.
Future<void> realSleep(Duration duration) => Future<void>.delayed(duration);

/// Record ids in the order a human reads them: numerically when they are all numbers, and
/// lexicographically otherwise. A set has no order of its own, and "10 before 7" in a report is a
/// reader's problem that costs nothing to avoid.
List<String> sortedIds(Iterable<String> ids) {
  final sorted = ids.toList();
  final allNumeric = sorted.every((id) => int.tryParse(id) != null);
  sorted.sort(
    allNumeric
        ? (one, other) => int.parse(one).compareTo(int.parse(other))
        : (one, other) => one.compareTo(other),
  );
  return sorted;
}

/// The hard caps of the approved T1.9 run (product owner, 2026-10-08).
///
/// The caps are counted, not asserted afterwards: every counter method is a *refusal* that throws
/// before the call it guards, so a run can never pass a cap and then discover it. The state it
/// keeps is recorded in the results file, so the evidence of what the run cost is the same object
/// that enforced the limit.
final class WriteBudget {
  /// Builds a budget. The defaults are the approved caps.
  WriteBudget({
    this.maxRecords = 30,
    this.maxAttachmentBytes = 25 * mebibyte,
    this.maxTotalBytes = 150 * mebibyte,
  });

  /// The most records this run may create.
  final int maxRecords;

  /// The most bytes one attachment may carry.
  final int maxAttachmentBytes;

  /// The most bytes this run may upload in total.
  final int maxTotalBytes;

  int _records = 0;
  int _bytes = 0;

  /// How many records this run has created so far.
  int get recordsCreated => _records;

  /// How many bytes this run has uploaded so far.
  int get bytesUploaded => _bytes;

  /// Refuses the next create when it would pass [maxRecords]. Call before `createRecord`.
  void beforeCreate() {
    if (_records + 1 > maxRecords) {
      throw WriteBudgetExceeded(
        'this run has created $_records records and the cap is $maxRecords',
      );
    }
  }

  /// Counts a create that happened. Call after a create returned an identifier.
  void afterCreate() {
    _records++;
  }

  /// Refuses an attachment of [bytes] when it would pass [maxAttachmentBytes] or [maxTotalBytes].
  /// Call before `uploadFile`.
  void beforeUpload(int bytes) {
    if (bytes > maxAttachmentBytes) {
      throw WriteBudgetExceeded(
        'a single attachment of $bytes bytes passes the per-attachment cap of '
        '$maxAttachmentBytes bytes',
      );
    }
    if (_bytes + bytes > maxTotalBytes) {
      throw WriteBudgetExceeded(
        'this run has uploaded $_bytes bytes; $bytes more would pass the total cap of '
        '$maxTotalBytes bytes',
      );
    }
  }

  /// Counts an attachment that was accepted. Call after `uploadFile` returned.
  void afterUpload(int bytes) {
    _bytes += bytes;
  }

  /// The caps and what they cost, for the results file.
  Map<String, Object?> toJson() => {
    'maxRecords': maxRecords,
    'maxAttachmentBytes': maxAttachmentBytes,
    'maxTotalBytes': maxTotalBytes,
    'recordsCreated': _records,
    'bytesUploaded': _bytes,
  };

  @override
  String toString() =>
      'WriteBudget($_records/$maxRecords records, $_bytes/$maxTotalBytes bytes)';
}

/// A cap was reached. Thrown by [WriteBudget] **before** the call it guards.
final class WriteBudgetExceeded implements Exception {
  /// Builds the refusal with the arithmetic that produced it.
  const WriteBudgetExceeded(this.message);

  /// What the budget would have allowed and what was asked for.
  final String message;

  @override
  String toString() => 'WriteBudgetExceeded: $message';
}

/// A minimal but structurally valid PDF of [pages] pages, padded to around [targetBytes].
///
/// The bytes are generated, never a real document: `Paperdrop_corpus` is not read, no file is
/// opened, and the content is one synthetic line per page. The padding is a **comment line inside
/// the first page's content stream**, which PDF allows, so the file stays a PDF that a reader can
/// open rather than a valid file with junk appended after `%%EOF`.
///
/// The file's xref table is written from the offsets measured while assembling it, so
/// `test/t19_support_test.dart` can check every entry points at its own object. The result lands
/// **within 64 bytes of [targetBytes] and never above it**, so that a target equal to a cap cannot
/// produce a document that passes the cap. (A [targetBytes] below the size of a minimal PDF —
/// roughly 600 bytes — is the one case where the document is larger than asked, because no smaller
/// valid PDF exists.)
Uint8List syntheticPdf({required int pages, required int targetBytes}) {
  if (pages < 1) {
    throw ArgumentError.value(pages, 'pages', 'a PDF has at least one page');
  }
  if (targetBytes < 1) {
    throw ArgumentError.value(
      targetBytes,
      'targetBytes',
      'a PDF has at least one byte',
    );
  }
  // Aim below the target: padding a stream also changes the digits of its `/Length` and of the
  // xref offsets, which adds a handful of bytes in response. The document therefore lands within
  // [_slack] bytes of `targetBytes` and never above it, so that a target equal to a cap cannot
  // produce a document that passes the cap.
  final aim = targetBytes > _slack ? targetBytes - _slack : 1;
  var padding = 0;
  var bytes = _pdfBytes(pages: pages, padding: padding);
  for (var attempt = 0; attempt < 6 && bytes.length < aim; attempt++) {
    padding += aim - bytes.length;
    bytes = _pdfBytes(pages: pages, padding: padding);
  }
  return bytes;
}

/// How far below its target [syntheticPdf] may land.
const int _slack = 64;

Uint8List _pdfBytes({required int pages, required int padding}) {
  final fontNumber = 3 + 2 * pages;
  final objects = <Uint8List>[];

  objects.add(_ascii('<< /Type /Catalog /Pages 2 0 R >>'));
  objects.add(
    _ascii(
      '<< /Type /Pages /Kids '
      '[${[for (var page = 0; page < pages; page++) '${3 + 2 * page} 0 R'].join(' ')}] '
      '/Count $pages >>',
    ),
  );
  for (var page = 0; page < pages; page++) {
    final pageNumber = 3 + 2 * page;
    final contentNumber = pageNumber + 1;
    objects.add(
      _ascii(
        '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] '
        '/Resources << /Font << /F1 $fontNumber 0 R >> >> /Contents $contentNumber 0 R >>',
      ),
    );
    final content = StringBuffer()
      ..write('BT /F1 12 Tf 72 760 Td (Paperdrop T1.9 synthetic page ')
      ..write(page + 1)
      ..write(' of ')
      ..write(pages)
      ..write(') Tj ET\n');
    if (page == 0 && padding > 0) {
      content
        ..write('%')
        ..write('p' * padding)
        ..write('\n');
    }
    final text = content.toString();
    // ASCII only, so the string's length is the stream's byte length.
    objects.add(
      _ascii('<< /Length ${text.length} >>\nstream\n$text\nendstream'),
    );
  }
  objects.add(_ascii('<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>'));

  final out = BytesBuilder();
  out.add(_ascii('%PDF-1.7\n'));
  // The four-byte binary marker a PDF carries so that tools treat it as binary, not as text.
  out.add(Uint8List.fromList(const [0x25, 0xE2, 0xE3, 0xCF, 0xD3, 0x0A]));
  final offsets = <int>[];
  for (var index = 0; index < objects.length; index++) {
    offsets.add(out.length);
    out.add(_ascii('${index + 1} 0 obj\n'));
    out.add(objects[index]);
    out.add(_ascii('\nendobj\n'));
  }
  final xrefOffset = out.length;
  final size = objects.length + 1;
  out.add(_ascii('xref\n0 $size\n0000000000 65535 f \n'));
  for (final offset in offsets) {
    out.add(_ascii('${offset.toString().padLeft(10, '0')} 00000 n \n'));
  }
  out.add(
    _ascii(
      'trailer\n<< /Size $size /Root 1 0 R >>\nstartxref\n$xrefOffset\n%%EOF\n',
    ),
  );
  return out.toBytes();
}

Uint8List _ascii(String text) => ascii.encode(text);
