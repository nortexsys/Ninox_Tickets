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
