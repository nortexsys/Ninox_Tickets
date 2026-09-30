import 'package:paperdrop/adapters/intake/file_picker_source.dart';
import 'package:paperdrop/adapters/intake/share_in_source.dart';
import 'package:paperdrop/adapters/scanner/mlkit_document_scanner.dart';
import 'package:paperdrop/adapters/storage/app_storage.dart';
import 'package:paperdrop/features/capture/capture_controller.dart';
import 'package:paperdrop/intake/document_intake.dart';

/// The capture pipeline as the device provides it: the app's own documents
/// directory, ML Kit's document scanner, the platform's file picker, and Android
/// share-in.
///
/// Everything here is a platform service, which is why it is assembled in one
/// place and nowhere else: a widget test hands the shell a controller built on
/// fakes instead (design §1, no test needs a device).
CaptureController deviceCaptureController() => CaptureController(
  intake: DocumentIntake(storage: const PathProviderAppStorage()),
  scanner: const MlKitDocumentScanner(),
  picker: const PlatformFilePickerSource(),
  shareIn: SharedIntentShareInSource(),
);
