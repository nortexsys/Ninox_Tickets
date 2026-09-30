import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Where the application keeps what it must keep (design §3).
///
/// `path_provider` is a platform service, so it sits behind an interface and
/// every test that needs storage uses the file system directly (design §1: no
/// test needs a device).
abstract interface class AppStorage {
  /// The application's own documents directory, on the device.
  Future<Directory> documentsDirectory();
}

/// The device's answer: the app documents directory of the platform.
class PathProviderAppStorage implements AppStorage {
  const PathProviderAppStorage();

  @override
  Future<Directory> documentsDirectory() => getApplicationDocumentsDirectory();
}
