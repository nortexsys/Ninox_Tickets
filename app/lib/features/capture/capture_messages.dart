import 'package:paperdrop/intake/intake_failure.dart';
import 'package:paperdrop/l10n/generated/app_localizations.dart';

/// The user-facing text of a refused document (NFR-I18N-001).
///
/// Every refusal has a message, every message comes from the ARB file, and this
/// mapping is exhaustive: a new [IntakeFailureCode] cannot be added without the
/// compiler asking for its string.
String captureFailureMessage(AppLocalizations l10n, IntakeFailureCode code) =>
    switch (code) {
      IntakeFailureCode.unsupportedMediaType => l10n.errorUnsupportedMediaType,
      IntakeFailureCode.severalFilesShared => l10n.errorSeveralFilesShared,
      IntakeFailureCode.noDocumentShared => l10n.errorNoDocumentShared,
      IntakeFailureCode.scannerProducedNoPdf => l10n.errorScannerReturnedNoPdf,
      IntakeFailureCode.intakeFailed => l10n.errorIntakeFailed,
    };
