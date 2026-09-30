import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:paperdrop/adapters/intake/incoming_document.dart';
import 'package:paperdrop/intake/intake_failure.dart';
import 'package:paperdrop/intake/intake_result.dart';

/// The file picker of the device (FR-CAP-001, design §3).
///
/// One document at a time, and only the three media types the MVP accepts: the
/// filter is the platform's, so the documents the user may choose are the ones
/// the app can store. A type that gets through anyway — a share, or a picker
/// that ignores its filter — is refused downstream, with a message.
class PlatformFilePickerSource implements FilePickerSource {
  const PlatformFilePickerSource();

  /// The extensions of [IntakeResult.supportedMediaTypes], which is what the
  /// platform's picker filters on.
  static const List<String> allowedExtensions = <String>[
    'pdf',
    'jpg',
    'jpeg',
    'png',
  ];

  @override
  Future<IncomingDocument?> pick() async {
    final FilePickerResult? picked;
    try {
      picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: allowedExtensions,
        allowMultiple: false,
        withData: false,
      );
    } on Error {
      rethrow;
    } on IntakeFailure {
      rethrow;
    } catch (_) {
      throw const IntakeFailure(IntakeFailureCode.intakeFailed);
    }

    if (picked == null || picked.files.isEmpty) {
      return null;
    }
    final PlatformFile file = picked.files.single;
    final String? path = file.path;
    if (path == null) {
      // Without a path there is nothing to copy, and guessing would mean
      // holding the document in memory.
      throw const IntakeFailure(IntakeFailureCode.intakeFailed);
    }
    return IncomingDocument(
      source: IntakeSource.picker,
      bytes: File(path).openRead(),
      // The declared type is left to the store, which resolves it from the name
      // and accepts only the three.
      filename: file.name,
    );
  }
}
