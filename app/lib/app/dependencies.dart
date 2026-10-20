import 'package:paperdrop/adapters/intake/file_picker_source.dart';
import 'package:paperdrop/adapters/intake/share_in_source.dart';
import 'package:paperdrop/adapters/scanner/mlkit_document_scanner.dart';
import 'package:paperdrop/adapters/storage/app_storage.dart';
import 'package:paperdrop/features/capture/capture_controller.dart';
import 'package:paperdrop/features/wizard/data/destination_store.dart';
import 'package:paperdrop/features/wizard/destination.dart';
import 'package:paperdrop/intake/document_intake.dart';
import 'package:paperdrop/settings/country_setting.dart';

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

/// Whether the device already holds a destination, as the application answers
/// it — the question the shell's first-run redirect is built on (design §10 of
/// `implement-setup-wizard`, task 3.5).
///
/// **Read-only.** It asks the wizard's own [DestinationStore] for the
/// destinations it holds, through that store's public API and nothing else: no
/// write, no parse of the file, no second reader of the wizard's format. `false`
/// — the answer that sends the user to the wizard — is given only when the store
/// could be read and holds nothing yet (FR-DST-002,
/// `destinations-mapping/no-default-destination-until-a-first-send`).
///
/// **A store that cannot be read answers `true`**, which is the decision of
/// design §10: a device whose destinations cannot be read is exactly the device
/// on which the wizard would also fail to save, and sending the user to a wizard
/// that cannot finish would trap them there. So an unreadable store is treated as
/// *a destination may exist* and the app opens on capture. Only an [Exception]
/// counts as unreadable; an `Error` is a defect of this code and travels.
///
/// [store] is the test's, and the device's file store when it is `null` — the
/// same store and the same directory the wizard writes to. `main.dart` passes
/// this function to `PaperdropApp`.
Future<bool> deviceHasDestination({DestinationStore? store}) async {
  final DestinationStore resolved =
      store ?? const FileDestinationStore(storage: PathProviderAppStorage());
  final List<Destination> destinations;
  try {
    destinations = await resolved.readAll();
  } on Exception {
    return true;
  }
  return destinations.isNotEmpty;
}

/// The settings' default country as the device keeps it
/// (`countries-languages` · `country-is-an-input`, DEC-022).
///
/// **One value, in one file, beside the destinations.** It is the application's composition of the
/// two platform-bound halves — the documents directory from `path_provider` and the phone's region
/// from `dart:io` — and nothing else: the first run asks the region once and stores the answer, and
/// from then on the file is the answer (`FileCountrySettingStore`).
///
/// **Who reads it.** The review screen's controller, which shows the country in force for a ticket
/// and never writes this value back; the composition of that screen's own collaborators is the step
/// that wires extraction and review together, and it is not this file's.
CountrySettingStore deviceCountrySettingStore() =>
    const FileCountrySettingStore(
      storage: PathProviderAppStorage(),
      region: PlatformPhoneRegion(),
    );
