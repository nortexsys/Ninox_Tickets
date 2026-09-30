// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Paperdrop for Ninox';

  @override
  String get captureHeadline => 'Capture a document';

  @override
  String get captureExplanation =>
      'Scan a paper document with the camera, or choose a PDF or an image from this device. A document shared to Paperdrop from another app arrives here as well.';

  @override
  String get captureScanAction => 'Scan';

  @override
  String get captureChooseFileAction => 'Choose file';

  @override
  String get intakeTitle => 'Document received';

  @override
  String get intakeDocIdLabel => 'Document';

  @override
  String get intakeMediaTypeLabel => 'Type';

  @override
  String get intakeByteLengthLabel => 'Size';

  @override
  String get intakeSha256Label => 'SHA-256';

  @override
  String intakeSizeInBytes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bytes',
      one: '1 byte',
    );
    return '$_temp0';
  }

  @override
  String get errorUnsupportedMediaType =>
      'Paperdrop stores PDF, JPEG and PNG documents only.';

  @override
  String get errorSeveralFilesShared =>
      'Paperdrop takes one document at a time. Share a single PDF or image.';

  @override
  String get errorNoDocumentShared =>
      'No document arrived with that share. Share a PDF or an image.';

  @override
  String get errorScannerReturnedNoPdf =>
      'The scanner returned no PDF. Scan the document again.';

  @override
  String get errorIntakeFailed =>
      'The document could not be stored, and nothing was kept.';
}
