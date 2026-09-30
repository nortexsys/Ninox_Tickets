import 'dart:io';

/// Reads a recorded response body from `test/fixtures/classic/`.
///
/// The path is found by looking for this package's `pubspec.yaml` — in the working directory, in
/// `packages/ninox_client/` below it, or above either — because `dart test packages/ninox_client`
/// from the repository root and `dart test` from inside the package leave the working directory in
/// two different places.
String classicFixture(String name) {
  final file = File(
    '${packageRoot().path}${Platform.pathSeparator}test'
    '${Platform.pathSeparator}fixtures${Platform.pathSeparator}classic'
    '${Platform.pathSeparator}$name',
  );
  if (!file.existsSync()) {
    throw StateError('no such fixture: ${file.path}');
  }
  return file.readAsStringSync();
}

/// The `packages/ninox_client` directory, whatever the working directory happens to be.
Directory packageRoot() {
  for (final candidate in _candidates()) {
    if (_isPackageRoot(candidate)) return candidate;
  }
  throw StateError(
    'the ninox_client package root was not found '
    'from ${Directory.current.path}',
  );
}

Iterable<Directory> _candidates() sync* {
  var directory = Directory.current;
  while (true) {
    yield directory;
    yield Directory(
      '${directory.path}${Platform.pathSeparator}packages'
      '${Platform.pathSeparator}ninox_client',
    );
    final parent = directory.parent;
    if (parent.path == directory.path) return;
    directory = parent;
  }
}

bool _isPackageRoot(Directory directory) {
  final pubspec = File(
    '${directory.path}${Platform.pathSeparator}pubspec.yaml',
  );
  return pubspec.existsSync() &&
      pubspec.readAsStringSync().contains('name: ninox_client');
}
