import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// Product name: the application label and the title of the capture screen.
  ///
  /// In en, this message translates to:
  /// **'Paperdrop for Ninox'**
  String get appTitle;

  /// Heading of the capture screen, the one entry point of FR-CAP-001.
  ///
  /// In en, this message translates to:
  /// **'Capture a document'**
  String get captureHeadline;

  /// Explains the paths the MVP keeps: the platform scanner, the file picker and share-in.
  ///
  /// In en, this message translates to:
  /// **'Scan a paper document with the camera, or choose a PDF or an image from this device. A document shared to Paperdrop from another app arrives here as well.'**
  String get captureExplanation;

  /// Primary action of the capture screen: the platform document scanner (FR-CAP-002).
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get captureScanAction;

  /// Second action of the capture screen: the file picker (FR-CAP-001).
  ///
  /// In en, this message translates to:
  /// **'Choose file'**
  String get captureChooseFileAction;

  /// Placeholder screen after a document is stored, until extraction and review exist (M2).
  ///
  /// In en, this message translates to:
  /// **'Document received'**
  String get intakeTitle;

  /// Label of the content-free identifier the intake store assigns.
  ///
  /// In en, this message translates to:
  /// **'Document'**
  String get intakeDocIdLabel;

  /// Label of the media type of the stored original.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get intakeMediaTypeLabel;

  /// Label of the size of the stored original.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get intakeByteLengthLabel;

  /// Label of the digest that proves the stored copy is the input (FR-CAP-005).
  ///
  /// In en, this message translates to:
  /// **'SHA-256'**
  String get intakeSha256Label;

  /// Size of the stored original, in bytes.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 byte} other{{count} bytes}}'**
  String intakeSizeInBytes(int count);

  /// Refusal of a media type outside the MVP cut (design §3).
  ///
  /// In en, this message translates to:
  /// **'Paperdrop stores PDF, JPEG and PNG documents only.'**
  String get errorUnsupportedMediaType;

  /// Refusal of several files shared at once (product owner, 2026-09-30).
  ///
  /// In en, this message translates to:
  /// **'Paperdrop takes one document at a time. Share a single PDF or image.'**
  String get errorSeveralFilesShared;

  /// A share arrived carrying no file at all.
  ///
  /// In en, this message translates to:
  /// **'No document arrived with that share. Share a PDF or an image.'**
  String get errorNoDocumentShared;

  /// The platform scanner answered without a PDF; the app never assembles one itself (design §3).
  ///
  /// In en, this message translates to:
  /// **'The scanner returned no PDF. Scan the document again.'**
  String get errorScannerReturnedNoPdf;

  /// Copy, hash or storage failure inside DocumentIntake.
  ///
  /// In en, this message translates to:
  /// **'The document could not be stored, and nothing was kept.'**
  String get errorIntakeFailed;

  /// Title of every screen of the setup wizard (FR-WIZ-001).
  ///
  /// In en, this message translates to:
  /// **'Set up Ninox'**
  String get wizardTitle;

  /// How the user obtains the token (FR-WIZ-003, product-invariants/token-is-the-only-credential), naming the vendor's own steps: Integrations, then New API Key.
  ///
  /// In en, this message translates to:
  /// **'Create an API token in Ninox\'s own settings: open Integrations, then New API Key, and copy the token. Paperdrop asks for a token and for nothing else: never for your user name or your password.'**
  String get wizardTokenInstructions;

  /// Label of the obscured field the token is pasted into (FR-WIZ-003).
  ///
  /// In en, this message translates to:
  /// **'API token'**
  String get wizardTokenFieldLabel;

  /// Hint of the token field.
  ///
  /// In en, this message translates to:
  /// **'Paste the token from Ninox'**
  String get wizardTokenFieldHint;

  /// Fills the token field from the clipboard, trimmed (FR-WIZ-003).
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get wizardTokenPasteAction;

  /// Opens Ninox's own settings page in the platform's browser (FR-WIZ-003): https://admin.ninox.com on the public cloud, https://<host>/admin on a private one.
  ///
  /// In en, this message translates to:
  /// **'Open Ninox settings'**
  String get wizardTokenOpenSettingsAction;

  /// The collapsed section holding the Ninox host (FR-DST-008).
  ///
  /// In en, this message translates to:
  /// **'Advanced setup'**
  String get wizardTokenAdvancedTitle;

  /// Label of the host field of the destination (FR-DST-008).
  ///
  /// In en, this message translates to:
  /// **'Ninox host'**
  String get wizardTokenHostLabel;

  /// The vendor's public cloud host, the default of the field (ADR-017).
  ///
  /// In en, this message translates to:
  /// **'api.ninox.com'**
  String get wizardTokenHostHint;

  /// Why the host field exists: a private-cloud customer has another host (FR-DST-008).
  ///
  /// In en, this message translates to:
  /// **'Change this only for a Ninox private cloud.'**
  String get wizardTokenHostHelp;

  /// The one action that validates the token and the host by their effect (FR-WIZ-003).
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get wizardTokenConnectAction;

  /// Question of the team step (FR-WIZ-002).
  ///
  /// In en, this message translates to:
  /// **'Which team should Paperdrop use?'**
  String get wizardTeamStepTitle;

  /// Question of the database step (FR-WIZ-002).
  ///
  /// In en, this message translates to:
  /// **'Which database?'**
  String get wizardDatabaseStepTitle;

  /// Question of the table step (FR-WIZ-002, FR-WIZ-004).
  ///
  /// In en, this message translates to:
  /// **'Which table should the documents go to?'**
  String get wizardTableStepTitle;

  /// Returns to the previous step the lists still show (FR-WIZ-002).
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get wizardBackAction;

  /// Runs the call a step failed on again, without leaving the step (orchestrator, 2026-10-07).
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get wizardTryAgainAction;

  /// The host field holds something NinoxEndpoint.parse does not accept (design §4); reported at the field.
  ///
  /// In en, this message translates to:
  /// **'That is not a valid host.'**
  String get wizardErrorHostNotValid;

  /// The call answered Unauthorized (design §4).
  ///
  /// In en, this message translates to:
  /// **'Ninox did not accept that token.'**
  String get wizardErrorTokenNotAccepted;

  /// The call answered TransportFailure (design §4).
  ///
  /// In en, this message translates to:
  /// **'The host could not be reached. Check the address and your connection.'**
  String get wizardErrorHostUnreachable;

  /// The call answered UnexpectedResponse (design §4).
  ///
  /// In en, this message translates to:
  /// **'That address answered, but it is not a Ninox API.'**
  String get wizardErrorNotANinoxApi;

  /// ServerError, RateLimited, NotFound and any other failure of a wizard call (design §4).
  ///
  /// In en, this message translates to:
  /// **'Ninox answered with an error. Try again.'**
  String get wizardErrorNinoxError;

  /// The team list came back empty (design §3: the step stays with this explanation).
  ///
  /// In en, this message translates to:
  /// **'This account can see no team.'**
  String get wizardNoticeNoTeams;

  /// The database list came back empty (design §3).
  ///
  /// In en, this message translates to:
  /// **'This team holds no database.'**
  String get wizardNoticeNoDatabases;

  /// The table list came back empty (design §3).
  ///
  /// In en, this message translates to:
  /// **'This database holds no table.'**
  String get wizardNoticeNoTables;

  /// Question of the mapping step (FR-WIZ-005, FR-WIZ-006).
  ///
  /// In en, this message translates to:
  /// **'Which column should each value go to?'**
  String get wizardMappingHeadline;

  /// Says what the step does, that the proposals are corrections, and that no mapping is mandatory (FR-WIZ-007).
  ///
  /// In en, this message translates to:
  /// **'Paperdrop suggests a column where it recognises one. Correct it, choose another column, or leave the value unmapped: nothing here is required.'**
  String get wizardMappingExplanation;

  /// The visibly unmapped state of a core field — never an empty selector (FR-WIZ-005).
  ///
  /// In en, this message translates to:
  /// **'Not mapped'**
  String get wizardMappingUnmapped;

  /// Introduces the per-field absent setting of a mapped field (FR-DST-006).
  ///
  /// In en, this message translates to:
  /// **'If the document prints no value'**
  String get wizardMappingAbsentLabel;

  /// The default of the absent setting (FR-DST-006: empty, not zero).
  ///
  /// In en, this message translates to:
  /// **'Leave it empty'**
  String get wizardMappingAbsentEmpty;

  /// The other value of the absent setting (FR-DST-006).
  ///
  /// In en, this message translates to:
  /// **'Write zero'**
  String get wizardMappingAbsentZero;

  /// Finishes the mapping step, mapped, partly mapped or not at all (FR-WIZ-007).
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get wizardMappingContinueAction;

  /// Marks a column another core field already uses, in the picker (design 10.2, approved 2026-10-07). The column stays selectable: two fields may share one column, and the send pipeline reports it if Ninox rejects it.
  ///
  /// In en, this message translates to:
  /// **'{column} (also mapped to {field})'**
  String wizardMappingAlsoUsed(String column, String field);

  /// Plain-language name of the canonical field doc_date (FR-WIZ-005, FR-WIZ-008).
  ///
  /// In en, this message translates to:
  /// **'Document date'**
  String get wizardFieldDocDate;

  /// Plain-language name of the canonical field supplier_name.
  ///
  /// In en, this message translates to:
  /// **'Supplier'**
  String get wizardFieldSupplierName;

  /// Plain-language name of the canonical field supplier_tax_id.
  ///
  /// In en, this message translates to:
  /// **'Supplier tax ID'**
  String get wizardFieldSupplierTaxId;

  /// Plain-language name of the canonical field doc_number.
  ///
  /// In en, this message translates to:
  /// **'Document number'**
  String get wizardFieldDocNumber;

  /// Plain-language name of the canonical field gross_total.
  ///
  /// In en, this message translates to:
  /// **'Gross total'**
  String get wizardFieldGrossTotal;

  /// Plain-language name of the canonical field net_total.
  ///
  /// In en, this message translates to:
  /// **'Net total'**
  String get wizardFieldNetTotal;

  /// Plain-language name of the canonical field tax_total.
  ///
  /// In en, this message translates to:
  /// **'Tax total'**
  String get wizardFieldTaxTotal;

  /// Plain-language name of the canonical field currency.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get wizardFieldCurrency;

  /// Heading of the closing summary (FR-WIZ-008).
  ///
  /// In en, this message translates to:
  /// **'This is what Paperdrop will write'**
  String get wizardSummaryHeadline;

  /// Names the core fields that will be saved, in plain language rather than as keys (FR-WIZ-008).
  ///
  /// In en, this message translates to:
  /// **'It will save the {fields} on the record.'**
  String wizardSummarySaved(String fields);

  /// Names the core fields that will not be saved, so the consequence is stated rather than left to be discovered (FR-WIZ-008).
  ///
  /// In en, this message translates to:
  /// **'It will not save the {fields}: those columns stay as they are.'**
  String wizardSummaryNotSaved(String fields);

  /// The empty-record case, in the requirement's own words: only the document will be attached, with no data (FR-WIZ-008, FR-WIZ-007).
  ///
  /// In en, this message translates to:
  /// **'Only the document will be attached, with no data: no column of the record will be filled.'**
  String get wizardSummaryNothingMapped;

  /// The closing screen's offer: capture a document of any kind rather than returning the user to an empty application (FR-WIZ-008).
  ///
  /// In en, this message translates to:
  /// **'Capture a document'**
  String get wizardSummaryCaptureAction;

  /// A failure to write the destination (design §10.1). It claims nothing as saved, and the same screen offers the retry.
  ///
  /// In en, this message translates to:
  /// **'Paperdrop could not save this setup on the device, so nothing has been saved yet. Try again.'**
  String get wizardSummarySaveFailed;

  /// Title of the review screen, the screen the user sees on every document (FR-REV-004, T2.2).
  ///
  /// In en, this message translates to:
  /// **'Review the document'**
  String get reviewTitle;

  /// Plain-language name of the canonical field doc_date on the review screen (FR-REV-004).
  ///
  /// In en, this message translates to:
  /// **'Document date'**
  String get reviewFieldDocDate;

  /// Plain-language name of the canonical field supplier_name on the review screen.
  ///
  /// In en, this message translates to:
  /// **'Supplier'**
  String get reviewFieldSupplierName;

  /// Plain-language name of the canonical field supplier_tax_id on the review screen.
  ///
  /// In en, this message translates to:
  /// **'Supplier tax ID'**
  String get reviewFieldSupplierTaxId;

  /// Plain-language name of the canonical field doc_number on the review screen.
  ///
  /// In en, this message translates to:
  /// **'Document number'**
  String get reviewFieldDocNumber;

  /// Plain-language name of the canonical field gross_total on the review screen.
  ///
  /// In en, this message translates to:
  /// **'Gross total'**
  String get reviewFieldGrossTotal;

  /// Plain-language name of the canonical field currency on the review screen.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get reviewFieldCurrency;

  /// One core field as the review screen shows it: the plain-language name of the field and the value read, edited or missing (FR-REV-004).
  ///
  /// In en, this message translates to:
  /// **'{label}: {value}'**
  String reviewFieldValue(String label, String value);

  /// What a field shows when nothing was read for it — the red state of FR-REV-004.
  ///
  /// In en, this message translates to:
  /// **'not read'**
  String get reviewValueNotRead;

  /// Semantic label of a green value: confirmed by redundancy (validation-confidence/three-confidence-strengths).
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get reviewConfidenceGreen;

  /// Semantic label of an amber value: read and not confirmed, including a value read with no country row (PO decision 2026-10-17, point 6).
  ///
  /// In en, this message translates to:
  /// **'Read, not confirmed'**
  String get reviewConfidenceAmber;

  /// Semantic label of a red value: not read at all.
  ///
  /// In en, this message translates to:
  /// **'Not read'**
  String get reviewConfidenceRed;

  /// The mark a value the user typed carries instead of a confidence colour (DEC-007, FR-REV-010).
  ///
  /// In en, this message translates to:
  /// **'Edited'**
  String get reviewEdited;

  /// The lock of a green value: tapping it is the only way into the editor (validation-confidence/green-is-editable-only-after-unlocking).
  ///
  /// In en, this message translates to:
  /// **'Unlock to edit'**
  String get reviewLockAction;

  /// The one line that tells a document whose values stay amber apart, because the document's own needsReview is the only thing that says so (design §2, PO decision 2026-10-17 point 6).
  ///
  /// In en, this message translates to:
  /// **'Paperdrop flagged this document for review: check the values before saving.'**
  String get reviewNeedsReviewNotice;

  /// Heading of the amounts block of FR-REV-005.
  ///
  /// In en, this message translates to:
  /// **'Amounts'**
  String get reviewAmountsHeadline;

  /// The single confirming line of a collapsed amounts block: the redundancy check of base plus tax equals total passed (FR-REV-005).
  ///
  /// In en, this message translates to:
  /// **'Total {total}, confirmed by the base and the tax.'**
  String reviewAmountsConfirmed(String total);

  /// The net total in the expanded amounts block.
  ///
  /// In en, this message translates to:
  /// **'Base {amount}'**
  String reviewAmountsBase(String amount);

  /// The tax total in the expanded amounts block.
  ///
  /// In en, this message translates to:
  /// **'Tax {amount}'**
  String reviewAmountsTax(String amount);

  /// One occupied tax slot in the expanded amounts block: the printed rate and its amount (FR-REV-005).
  ///
  /// In en, this message translates to:
  /// **'{rate}% — {amount}'**
  String reviewAmountsSlot(String rate, String amount);

  /// The gross total in the expanded amounts block.
  ///
  /// In en, this message translates to:
  /// **'Total {amount}'**
  String reviewAmountsTotal(String amount);

  /// The full-width destination bar of FR-REV-001: team, database and table, always visible.
  ///
  /// In en, this message translates to:
  /// **'{team} / {database} / {table}'**
  String reviewDestinationBar(String team, String database, String table);

  /// The accessible name of the destination bar, which opens destination selection without leaving the document (FR-REV-001).
  ///
  /// In en, this message translates to:
  /// **'Change the destination'**
  String get reviewDestinationAction;

  /// Title of the destination selection the bar opens (FR-REV-001).
  ///
  /// In en, this message translates to:
  /// **'Where should the document go?'**
  String get reviewDestinationTitle;

  /// The selection when the destination store holds nothing else to choose (FR-DST-002).
  ///
  /// In en, this message translates to:
  /// **'No other destination is configured on this device.'**
  String get reviewDestinationNone;

  /// What the highlighted destination bar says on the first capture of a calendar day (FR-REV-002).
  ///
  /// In en, this message translates to:
  /// **'Check that this is where the document should go.'**
  String get reviewAcknowledgePrompt;

  /// The acknowledgement of FR-REV-002; until it is given the save action is disabled.
  ///
  /// In en, this message translates to:
  /// **'The destination is correct'**
  String get reviewAcknowledgeAction;

  /// A write of the acknowledgement file that the file system refused (design §4); the save action stays disabled.
  ///
  /// In en, this message translates to:
  /// **'The confirmation could not be recorded on this device. Try again.'**
  String get reviewAcknowledgeFailed;

  /// The duplicate notice of FR-REV-007, shown when document-history's read-side check matched an earlier send.
  ///
  /// In en, this message translates to:
  /// **'This document may already be in Ninox.'**
  String get reviewDuplicateNotice;

  /// The notice's link to the record that already exists (FR-REV-007).
  ///
  /// In en, this message translates to:
  /// **'Open the existing record'**
  String get reviewDuplicateLink;

  /// Proceeding anyway: a second record is created deliberately and the entry is flagged as a duplicate (FR-REV-007, FR-DUP-002).
  ///
  /// In en, this message translates to:
  /// **'Save anyway'**
  String get reviewDuplicateProceed;

  /// The save action, fixed at the bottom of the screen and naming the table rather than a generic verb (FR-REV-008).
  ///
  /// In en, this message translates to:
  /// **'Save to {table}'**
  String reviewSaveAction(String table);

  /// Discarding the document: no record, no history entry and no local file (FR-REV-011).
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get reviewDiscardAction;

  /// A discard the file system refused; the capture is still there and the screen says so rather than claiming it is gone (FR-REV-011).
  ///
  /// In en, this message translates to:
  /// **'The document could not be discarded, so nothing was deleted.'**
  String get reviewDiscardFailed;

  /// The thumbnail of FR-REV-003, tapped to see the document full screen.
  ///
  /// In en, this message translates to:
  /// **'Show the document'**
  String get reviewThumbnailAction;

  /// Shown where the thumbnail would be when the document has none.
  ///
  /// In en, this message translates to:
  /// **'No preview'**
  String get reviewNoThumbnail;

  /// Closes the full-screen view of the document (FR-REV-003).
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get reviewCloseAction;

  /// Said when the pipeline has answered a save; the confirmation screen that follows the send is ninox-send's (design §5).
  ///
  /// In en, this message translates to:
  /// **'The save finished.'**
  String get reviewSaveCompleted;

  /// The store refused the write a save needs (a duplicate flag, an overtaken revision): nothing was sent and the action stays available.
  ///
  /// In en, this message translates to:
  /// **'The document could not be saved. Try again.'**
  String get reviewSaveStoreFailed;

  /// The history store refused the entry the screen was asked to show.
  ///
  /// In en, this message translates to:
  /// **'This document could not be opened.'**
  String get reviewLoadFailed;

  /// An edit of doc_date that is not a calendar date (design §2).
  ///
  /// In en, this message translates to:
  /// **'Use a date as YYYY-MM-DD.'**
  String get reviewErrorNotADate;

  /// An edit of gross_total that is not an amount of the document's currency, including one with more fractional digits than the currency has.
  ///
  /// In en, this message translates to:
  /// **'That is not an amount in the document\'s currency.'**
  String get reviewErrorNotAnAmount;

  /// An edit of currency that ISO 4217 does not list; no default exponent is ever assumed.
  ///
  /// In en, this message translates to:
  /// **'That is not a currency code Paperdrop knows.'**
  String get reviewErrorUnknownCurrency;

  /// An edit of gross_total while the document has no currency: an amount is an integer in a currency's minor unit.
  ///
  /// In en, this message translates to:
  /// **'Set the currency first, so that the amount can be read.'**
  String get reviewErrorAmountNeedsCurrency;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
