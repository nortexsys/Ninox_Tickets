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

  @override
  String get wizardTitle => 'Set up Ninox';

  @override
  String get wizardTokenInstructions =>
      'Create an API token in Ninox\'s own settings: open Integrations, then New API Key, and copy the token. Paperdrop asks for a token and for nothing else: never for your user name or your password.';

  @override
  String get wizardTokenFieldLabel => 'API token';

  @override
  String get wizardTokenFieldHint => 'Paste the token from Ninox';

  @override
  String get wizardTokenPasteAction => 'Paste';

  @override
  String get wizardTokenOpenSettingsAction => 'Open Ninox settings';

  @override
  String get wizardTokenAdvancedTitle => 'Advanced setup';

  @override
  String get wizardTokenHostLabel => 'Ninox host';

  @override
  String get wizardTokenHostHint => 'api.ninox.com';

  @override
  String get wizardTokenHostHelp =>
      'Change this only for a Ninox private cloud.';

  @override
  String get wizardTokenConnectAction => 'Connect';

  @override
  String get wizardTeamStepTitle => 'Which team should Paperdrop use?';

  @override
  String get wizardDatabaseStepTitle => 'Which database?';

  @override
  String get wizardTableStepTitle => 'Which table should the documents go to?';

  @override
  String get wizardBackAction => 'Back';

  @override
  String get wizardTryAgainAction => 'Try again';

  @override
  String get wizardErrorHostNotValid => 'That is not a valid host.';

  @override
  String get wizardErrorTokenNotAccepted => 'Ninox did not accept that token.';

  @override
  String get wizardErrorHostUnreachable =>
      'The host could not be reached. Check the address and your connection.';

  @override
  String get wizardErrorNotANinoxApi =>
      'That address answered, but it is not a Ninox API.';

  @override
  String get wizardErrorNinoxError =>
      'Ninox answered with an error. Try again.';

  @override
  String get wizardNoticeNoTeams => 'This account can see no team.';

  @override
  String get wizardNoticeNoDatabases => 'This team holds no database.';

  @override
  String get wizardNoticeNoTables => 'This database holds no table.';

  @override
  String get wizardMappingHeadline => 'Which column should each value go to?';

  @override
  String get wizardMappingExplanation =>
      'Paperdrop suggests a column where it recognises one. Correct it, choose another column, or leave the value unmapped: nothing here is required.';

  @override
  String get wizardMappingUnmapped => 'Not mapped';

  @override
  String get wizardMappingAbsentLabel => 'If the document prints no value';

  @override
  String get wizardMappingAbsentEmpty => 'Leave it empty';

  @override
  String get wizardMappingAbsentZero => 'Write zero';

  @override
  String get wizardMappingContinueAction => 'Continue';

  @override
  String wizardMappingAlsoUsed(String column, String field) {
    return '$column (also mapped to $field)';
  }

  @override
  String get wizardFieldDocDate => 'Document date';

  @override
  String get wizardFieldSupplierName => 'Supplier';

  @override
  String get wizardFieldSupplierTaxId => 'Supplier tax ID';

  @override
  String get wizardFieldDocNumber => 'Document number';

  @override
  String get wizardFieldGrossTotal => 'Gross total';

  @override
  String get wizardFieldNetTotal => 'Net total';

  @override
  String get wizardFieldTaxTotal => 'Tax total';

  @override
  String get wizardFieldCurrency => 'Currency';

  @override
  String get wizardSummaryHeadline => 'This is what Paperdrop will write';

  @override
  String wizardSummarySaved(String fields) {
    return 'It will save the $fields on the record.';
  }

  @override
  String wizardSummaryNotSaved(String fields) {
    return 'It will not save the $fields: those columns stay as they are.';
  }

  @override
  String get wizardSummaryNothingMapped =>
      'Only the document will be attached, with no data: no column of the record will be filled.';

  @override
  String get wizardSummaryCaptureAction => 'Capture a document';

  @override
  String get wizardSummarySaveFailed =>
      'Paperdrop could not save this setup on the device, so nothing has been saved yet. Try again.';

  @override
  String get reviewTitle => 'Review the document';

  @override
  String get reviewFieldDocDate => 'Document date';

  @override
  String get reviewFieldSupplierName => 'Supplier';

  @override
  String get reviewFieldSupplierTaxId => 'Supplier tax ID';

  @override
  String get reviewFieldDocNumber => 'Document number';

  @override
  String get reviewFieldGrossTotal => 'Gross total';

  @override
  String get reviewFieldCurrency => 'Currency';

  @override
  String reviewFieldValue(String label, String value) {
    return '$label: $value';
  }

  @override
  String get reviewValueNotRead => 'not read';

  @override
  String get reviewConfidenceGreen => 'Confirmed';

  @override
  String get reviewConfidenceAmber => 'Read, not confirmed';

  @override
  String get reviewConfidenceRed => 'Not read';

  @override
  String get reviewEdited => 'Edited';

  @override
  String get reviewLockAction => 'Unlock to edit';

  @override
  String get reviewNeedsReviewNotice =>
      'Paperdrop flagged this document for review: check the values before saving.';

  @override
  String get reviewAmountsHeadline => 'Amounts';

  @override
  String reviewAmountsConfirmed(String total) {
    return 'Total $total, confirmed by the base and the tax.';
  }

  @override
  String reviewAmountsBase(String amount) {
    return 'Base $amount';
  }

  @override
  String reviewAmountsTax(String amount) {
    return 'Tax $amount';
  }

  @override
  String reviewAmountsSlot(String rate, String amount) {
    return '$rate% — $amount';
  }

  @override
  String reviewAmountsTotal(String amount) {
    return 'Total $amount';
  }

  @override
  String reviewDestinationBar(String team, String database, String table) {
    return '$team / $database / $table';
  }

  @override
  String get reviewDestinationAction => 'Change the destination';

  @override
  String get reviewDestinationTitle => 'Where should the document go?';

  @override
  String get reviewDestinationNone =>
      'No other destination is configured on this device.';

  @override
  String get reviewAcknowledgePrompt =>
      'Check that this is where the document should go.';

  @override
  String get reviewAcknowledgeAction => 'The destination is correct';

  @override
  String get reviewAcknowledgeFailed =>
      'The confirmation could not be recorded on this device. Try again.';

  @override
  String get reviewDuplicateNotice => 'This document may already be in Ninox.';

  @override
  String get reviewDuplicateLink => 'Open the existing record';

  @override
  String get reviewDuplicateProceed => 'Save anyway';

  @override
  String reviewSaveAction(String table) {
    return 'Save to $table';
  }

  @override
  String get reviewDiscardAction => 'Discard';

  @override
  String get reviewDiscardFailed =>
      'The document could not be discarded, so nothing was deleted.';

  @override
  String get reviewThumbnailAction => 'Show the document';

  @override
  String get reviewNoThumbnail => 'No preview';

  @override
  String get reviewCloseAction => 'Close';

  @override
  String get reviewSaveCompleted => 'The save finished.';

  @override
  String get reviewSaveStoreFailed =>
      'The document could not be saved. Try again.';

  @override
  String get reviewLoadFailed => 'This document could not be opened.';

  @override
  String get reviewErrorNotADate => 'Use a date as YYYY-MM-DD.';

  @override
  String get reviewErrorNotAnAmount =>
      'That is not an amount in the document\'s currency.';

  @override
  String get reviewErrorUnknownCurrency =>
      'That is not a currency code Paperdrop knows.';

  @override
  String get reviewErrorAmountNeedsCurrency =>
      'Set the currency first, so that the amount can be read.';
}
