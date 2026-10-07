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
