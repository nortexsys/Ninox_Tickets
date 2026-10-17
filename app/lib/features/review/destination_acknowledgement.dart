/// The day the destination was last acknowledged — FR-REV-002's one persisted fact.
///
/// Requirement served: FR-REV-002 (`review-screen/daily-destination-confirmation`) — the bar is
/// pre-loaded with the destination used last, and on the first capture of each calendar day it is
/// highlighted with the save button disabled until the user acknowledges it once, and once only.
/// Design §4 of `implement-review-screen` puts the fact in *a small file beside
/// `destinations.json`*.
///
/// **A date, and nothing else.** No team, no database, no table, no document and no user: the file
/// says which day the user last looked at the destination and confirmed it, which is why it can sit
/// beside the destination file (FR-DST-003, `local-config-privacy`). It is what makes the daily
/// confirmation *once a day rather than once per document*
/// (`daily-destination-confirmation` · *the exception is bounded to once a day*).
///
/// **What an unreadable file means.** Not acknowledged. A file that cannot be read could be a file
/// from a newer version, half a write or a hand edit; answering *acknowledged* from it would skip a
/// confirmation the user never gave, and the whole point of the requirement is that a document is
/// not sent to a table the user has not looked at today. Answering *not acknowledged* costs one tap.
/// The exchange, at the other end, is strict: a write that the file system refuses throws, because a
/// confirmation that was not recorded would come back as a second confirmation.
library;

import 'dart:convert';
import 'dart:io';

import 'package:paperdrop/adapters/storage/app_storage.dart';
import 'package:paperdrop_core/paperdrop_core.dart' show CalendarDate;
import 'package:path/path.dart' as p;

/// Where the day of the last destination acknowledgement is kept.
abstract interface class DestinationAcknowledgement {
  /// The local calendar day the destination was last acknowledged on, or `null` when it never was.
  ///
  /// A file that cannot be read answers `null`: not acknowledged, never *acknowledged* (see the
  /// library's note).
  Future<CalendarDate?> lastAcknowledged();

  /// Records that the destination is acknowledged for [day], replacing whatever was stored.
  ///
  /// Throws an [IOException] when the file cannot be written: the screen then keeps the save
  /// button disabled, which is the failure that lets the user try again rather than the one that
  /// sends a document to a destination nobody confirmed.
  Future<void> acknowledge(CalendarDate day);
}

/// The file-backed store: one JSON object in the application's documents directory.
///
/// The directory comes from [AppStorage] — the same one `FileDestinationStore` writes
/// `destinations.json` in — so a test writes into a directory it owns and no test needs a device
/// (design §1).
final class FileDestinationAcknowledgement
    implements DestinationAcknowledgement {
  /// Builds the store over the application's storage.
  const FileDestinationAcknowledgement({required this.storage});

  /// Where the application keeps its own documents.
  final AppStorage storage;

  /// The file's name, under the documents directory, beside `destinations.json`.
  static const String fileName = 'destination-acknowledgement.json';

  /// The one key the file holds: the local date, as the core's `YYYY-MM-DD` text.
  static const String dateKey = 'date';

  @override
  Future<CalendarDate?> lastAcknowledged() async {
    final File file = await _file();
    if (!file.existsSync()) {
      return null;
    }
    try {
      final Object? decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, Object?>) {
        return null;
      }
      return CalendarDate.fromJson(decoded[dateKey]);
    } on FormatException {
      // Not the file this store wrote: not acknowledged, and never *acknowledged*.
      return null;
    } on ArgumentError {
      // A date that is not a date — `2026-02-31` — is corruption too, and it is data rather than a
      // defect of this code, so it is answered the same way.
      return null;
    } on IOException {
      return null;
    }
  }

  @override
  Future<void> acknowledge(CalendarDate day) async {
    final File file = await _file();
    await file.parent.create(recursive: true);
    await file.writeAsString(
      jsonEncode(<String, Object?>{dateKey: day.toJson()}),
      flush: true,
    );
  }

  /// The file, under the documents directory the platform reports.
  Future<File> _file() async =>
      File(p.join((await storage.documentsDirectory()).path, fileName));
}
