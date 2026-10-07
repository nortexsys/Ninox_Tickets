import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// What `pdfrx` needs on the **test host** and not on a device.
///
/// `pdfrxFlutterInitialize` asks the platform for a cache directory through
/// `path_provider`. On the S22 the platform answers; under `flutter test` there
/// is no platform, so the test answers for it. That is the only difference
/// between the two runs: the native engine, the parsing and the coordinates are
/// the same code.
///
/// Candidate A needs no such helper, because it has no host run at all: PdfBox
/// is a JVM library inside the application process.
void mockPathProviderCacheDirectory(Directory directory) {
  const MethodChannel channel = MethodChannel(
    'plugins.flutter.io/path_provider',
  );
  final TestDefaultBinaryMessenger messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(
    channel,
    (MethodCall call) async => directory.path,
  );
  addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
}
