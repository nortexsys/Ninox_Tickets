/// Where a destination is kept between sessions (design §6).
///
/// Requirement served: FR-DST-001 (`destinations-mapping/what-a-destination-is`) for the stored
/// tuple and FR-DST-003 (`destinations-store-identifiers-not-names`) for what the stored form is:
/// the field **identifiers** are what a destination holds, and the names beside them are for
/// display and are resolved again at send time.
///
/// **No secret in it.** Not the token — that is the platform keystore's (FR-CFG-004) — and no
/// document: the host, three identifiers and a field mapping per core field. `Destination.toJson`
/// cannot write a credential because `Destination` has no field for one.
///
/// **Several destinations are the data model's (FR-DST-001); the MVP configures one.** The file
/// holds a **list of one**, written by the wizard when it finishes, and reading it back is the send
/// pipeline's business later. The shape is a JSON array of destination objects, each with its host,
/// its team, database and table, and its mappings: a list, so the second destination R1 adds does
/// not have to change the file's shape.
library;

import 'dart:convert';
import 'dart:io';

import 'package:paperdrop/adapters/storage/app_storage.dart';
import 'package:path/path.dart' as p;

import '../destination.dart';

/// Where a destination is read from and written to.
abstract interface class DestinationStore {
  /// Every destination the device holds, in the order they were stored.
  ///
  /// An empty list when nothing has been configured — which is not an error and not a default: a
  /// fresh installation has no destination (FR-DST-002). A file that cannot be read is
  /// **reported** as a [FormatException] rather than answered with an empty list, because an empty
  /// list would silently look like a user who has configured nothing.
  Future<List<Destination>> readAll();

  /// Stores [destination], replacing what was stored.
  ///
  /// The MVP configures one destination, so this is the list of one (design §6); FR-DST-001's
  /// several destinations arrive with R1's bar, and this signature grows then.
  Future<void> save(Destination destination);
}

/// The file-backed store: one JSON file in the application's documents directory.
///
/// The directory comes from [AppStorage] — `path_provider` behind an interface — so a test writes
/// into a directory it owns and no test needs a device (design §1).
final class FileDestinationStore implements DestinationStore {
  /// Builds the store over the application's storage.
  const FileDestinationStore({required this.storage});

  /// Where the application keeps its own documents.
  final AppStorage storage;

  /// The file's name, under the documents directory. It carries no user data: the destination
  /// itself is inside it.
  static const String fileName = 'destinations.json';

  @override
  Future<List<Destination>> readAll() async {
    final File file = await _file();
    if (!file.existsSync()) {
      return const <Destination>[];
    }
    final Object? decoded = jsonDecode(await file.readAsString());
    if (decoded is! List) {
      throw const FormatException(
        '${FileDestinationStore.fileName}: expected a JSON array of destinations',
      );
    }
    return <Destination>[
      for (final Object? entry in decoded) Destination.fromJson(entry),
    ];
  }

  @override
  Future<void> save(Destination destination) async {
    final File file = await _file();
    await file.parent.create(recursive: true);
    // One destination in the MVP: the file is a list of one, and saving replaces what was there.
    await file.writeAsString(
      jsonEncode(<Object?>[destination.toJson()]),
      flush: true,
    );
  }

  /// The file, under the documents directory the platform reports.
  Future<File> _file() async =>
      File(p.join((await storage.documentsDirectory()).path, fileName));
}
