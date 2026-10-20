/// The default country of the settings, and how it is born and kept (DEC-022).
///
/// Requirement served: `countries-languages` · `country-is-an-input` — the country of a
/// photographed document **is an input**, not a detection result: the settings keep a default
/// country, initialised on first run from the phone's region and not re-read from the device
/// afterwards, and every ticket takes that default until its own country is changed on the review
/// screen (`review-screen` · `country-shown-and-editable-per-ticket`). `local-config-privacy` ·
/// `configuration-export-and-import` carries the same one value through the configuration file;
/// that file does not exist in the app yet, and this module does not invent one (GAP-039, items
/// (2) and (3), are not decided either: no wizard step, no change to the clearing action).
///
/// **A code, not a row.** What is stored is the ISO 3166-1 alpha-2 code — `ES`, `DE`, `PT` — and
/// the row it resolves to is the country table's answer, read through
/// [CountrySetting.rowIn] at the moment the ticket is read. That is what lets a country without a
/// row exist as a value (GAP-036): the app stores it and warns, and no row is applied in its
/// place.
///
/// **First run only.** The device's region is asked when the file does not exist, and the answer
/// is written before it is used, so a later change of the phone's language or region does not move
/// the default country. A region the platform reports without a country (`en`) leaves the setting
/// without a code: nothing is stored and nothing is assumed, and the ticket's fields are filled by
/// hand like those of a country without a row.
///
/// **No secret, no document.** The file holds one code and nothing else, so it can sit beside
/// `destinations.json` (`local-config-privacy`).
library;

import 'dart:convert';
import 'dart:io';

import 'package:paperdrop/adapters/storage/app_storage.dart';
import 'package:paperdrop_core/paperdrop_core.dart'
    show CountryRow, CountryTable;
import 'package:path/path.dart' as p;

final RegExp _countryCodeShape = RegExp(r'^[A-Z]{2}$');

/// The default country of the settings: one ISO 3166-1 alpha-2 code, or none.
final class CountrySetting {
  /// Binds the setting to [countryCode].
  ///
  /// [countryCode] is an upper-case ISO 3166-1 alpha-2 code, or `null` when the device named no
  /// country and the app therefore has no default (see the library's note). It is not validated
  /// here: a code the country table has no row for is a value the setting may hold (GAP-036), and
  /// the table is what answers for it.
  const CountrySetting(this.countryCode);

  /// The code in force, or `null` when the settings have no country.
  final String? countryCode;

  /// The row [countryCode] resolves to in [table], or `null` when it has none.
  ///
  /// A `null` answer is either *no country* or *a country without a row*, and the review screen
  /// says which (`review-screen` · `country-shown-and-editable-per-ticket`).
  CountryRow? rowIn(CountryTable table) {
    final String? code = countryCode;
    return code == null ? null : table.rowFor(code);
  }

  /// Value equality on the code.
  @override
  bool operator ==(Object other) =>
      other is CountrySetting && other.countryCode == countryCode;

  @override
  int get hashCode => countryCode.hashCode;

  /// The code, and nothing else.
  @override
  String toString() => 'CountrySetting(${countryCode ?? 'none'})';
}

/// The country the device's region names, as far as the app can read it.
///
/// `dart:io`'s `Platform.localeName` is a platform service, so it sits behind an interface and
/// every test supplies its own: no test needs a device (design §1). It answers the platform's
/// locale name as the platform spells it (`es_ES`, `es-ES`, `en`), never a code: the code is
/// [countryCodeFromLocale]'s.
abstract interface class PhoneRegion {
  /// The platform's locale name, or `null` when it reports none.
  String? localeName();
}

/// The device's answer: what `dart:io` reports about the platform's locale.
final class PlatformPhoneRegion implements PhoneRegion {
  /// Builds the port over the platform.
  const PlatformPhoneRegion();

  @override
  String? localeName() => Platform.localeName;
}

/// The ISO 3166-1 alpha-2 code a locale name carries, or `null` when it carries none.
///
/// `es_ES` and `es-ES` both answer `ES`; `en` and an empty name answer `null`, because a region
/// the platform did not name is not a country to assume. Nothing is inferred from the language: a
/// phone set to `en_GB` is Great Britain and a phone set to `en` is nowhere.
String? countryCodeFromLocale(String? localeName) {
  if (localeName == null) {
    return null;
  }
  final List<String> parts = localeName.split(RegExp('[_-]'));
  if (parts.length < 2) {
    return null;
  }
  final String candidate = parts[1].toUpperCase();
  return _countryCodeShape.hasMatch(candidate) ? candidate : null;
}

/// Where the default country is kept between sessions.
abstract interface class CountrySettingStore {
  /// The default country: what was stored, or — on the first run — the phone's region, which is
  /// stored before it is answered.
  ///
  /// Throws a [FormatException] when the stored file is not one this store wrote: the caller says
  /// *no country in force* rather than assuming one, exactly as an unreadable acknowledgement
  /// means *not acknowledged*.
  Future<CountrySetting> read();

  /// Stores [setting] as the default country, replacing what was there.
  ///
  /// Throws an [IOException] when the file cannot be written. Nothing in this change writes here
  /// on a ticket's behalf: a country changed for one ticket is that ticket's and never the
  /// default (`countries-languages` · `country-is-an-input`).
  Future<void> write(CountrySetting setting);
}

/// The file-backed store: one JSON object in the application's documents directory.
///
/// The directory comes from [AppStorage] — the same one `FileDestinationStore` writes
/// `destinations.json` in — so a test writes into a directory it owns and no test needs a device
/// (design §1).
final class FileCountrySettingStore implements CountrySettingStore {
  /// Builds the store over the application's storage and the phone's region.
  const FileCountrySettingStore({required this.storage, required this.region});

  /// Where the application keeps its own documents.
  final AppStorage storage;

  /// The device's region, asked once and only when nothing is stored yet.
  final PhoneRegion region;

  /// The file's name, under the documents directory, beside `destinations.json`.
  static const String fileName = 'country.json';

  /// The one key the file holds: the ISO 3166-1 alpha-2 code.
  static const String countryCodeKey = 'countryCode';

  @override
  Future<CountrySetting> read() async {
    final File file = await _file();
    if (!file.existsSync()) {
      return _firstRun();
    }
    final Object? decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map<String, Object?>) {
      throw const FormatException(
        '${FileCountrySettingStore.fileName}: expected a JSON object',
      );
    }
    final Object? code = decoded[countryCodeKey];
    if (code == null) {
      return const CountrySetting(null);
    }
    if (code is! String || !_countryCodeShape.hasMatch(code)) {
      throw FormatException(
        '${FileCountrySettingStore.fileName}: `$countryCodeKey` is not an '
        'ISO 3166-1 alpha-2 code',
      );
    }
    return CountrySetting(code);
  }

  @override
  Future<void> write(CountrySetting setting) async {
    final File file = await _file();
    await file.parent.create(recursive: true);
    await file.writeAsString(
      jsonEncode(<String, Object?>{countryCodeKey: setting.countryCode}),
      flush: true,
    );
  }

  /// The phone's region, stored before it is answered — and only when it names a country.
  Future<CountrySetting> _firstRun() async {
    final CountrySetting setting = CountrySetting(
      countryCodeFromLocale(region.localeName()),
    );
    if (setting.countryCode != null) {
      await write(setting);
    }
    return setting;
  }

  /// The file, under the documents directory the platform reports.
  Future<File> _file() async =>
      File(p.join((await storage.documentsDirectory()).path, fileName));
}
