import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:paperdrop/settings/country_setting.dart';
import 'package:paperdrop_core/paperdrop_core.dart' show CountryTable;
import 'package:path/path.dart' as p;

import '../tool/fakes.dart';

/// A phone whose region a test decides.
final class FakePhoneRegion implements PhoneRegion {
  /// Answers [name] as the platform's locale.
  FakePhoneRegion(this.name);

  /// The locale name the platform reports, as it reports it (`es_ES`, `en`).
  String? name;

  @override
  String? localeName() => name;
}

/// The default country of the settings (DEC-022, `countries-languages` · `country-is-an-input`).
///
/// The rules proved here are the ones about the setting itself: where the first value comes from,
/// that the device is not asked again, that a country without a row is stored as it is (GAP-036),
/// and that the file holds one code and nothing else.
void main() {
  late Directory root;
  late FakePhoneRegion region;

  setUp(() {
    root = Directory.systemTemp.createTempSync('paperdrop-country');
    region = FakePhoneRegion('es_ES');
  });

  tearDown(() {
    if (root.existsSync()) {
      root.deleteSync(recursive: true);
    }
  });

  FileCountrySettingStore aStore() =>
      FileCountrySettingStore(storage: TemporaryStorage(root), region: region);

  File countryFile() =>
      File(p.join(root.path, FileCountrySettingStore.fileName));

  group('[countries-languages/country-is-an-input]', () {
    test('the first run takes the phone\'s region, and stores it', () async {
      final CountrySetting setting = await aStore().read();

      expect(setting, const CountrySetting('ES'));
      expect(setting.rowIn(CountryTable.launch), CountryTable.es);
      expect(countryFile().existsSync(), isTrue);
      expect(jsonDecode(countryFile().readAsStringSync()), <String, Object?>{
        'countryCode': 'ES',
      }, reason: 'the file holds one code and nothing else');
    });

    test(
      'the region is asked once: the stored value answers afterwards',
      () async {
        final FileCountrySettingStore store = aStore();
        await store.read();

        // The phone is now set to another region, which changes nothing: the setting is the user's
        // data from the first run on, not a reading of the device.
        region.name = 'de_DE';

        expect(await store.read(), const CountrySetting('ES'));
        expect(await store.read(), const CountrySetting('ES'));
      },
    );

    test('a region the table has no row for is stored all the same', () async {
      region.name = 'pt_PT';
      final CountrySetting setting = await aStore().read();

      expect(setting, const CountrySetting('PT'));
      expect(
        setting.rowIn(CountryTable.launch),
        isNull,
        reason: 'no row is applied in the place of a country that has none (GAP-036)',
      );
      expect(jsonDecode(countryFile().readAsStringSync()), <String, Object?>{
        'countryCode': 'PT',
      }, reason: 'the value the user is working in is kept, row or no row');
    });

    test(
      'a region that names no country leaves the setting without one',
      () async {
        region.name = 'en';
        final CountrySetting setting = await aStore().read();

        expect(setting, const CountrySetting(null));
        expect(
          countryFile().existsSync(),
          isFalse,
          reason: 'nothing is assumed, so nothing is written',
        );
      },
    );

    test('the phone naming nothing at all is no country either', () async {
      region.name = null;
      expect(await aStore().read(), const CountrySetting(null));
    });

    test('a stored country is read back and replaced by a write', () async {
      final FileCountrySettingStore store = aStore();
      await store.write(const CountrySetting('DE'));

      expect(await store.read(), const CountrySetting('DE'));
      expect(region.localeName(), 'es_ES');
    });

    test('a file that is not this store\'s is refused, not guessed', () async {
      countryFile().writeAsStringSync('{"countryCode":"es"}');

      expect(aStore().read(), throwsA(isA<FormatException>()));

      countryFile().writeAsStringSync('[]');
      expect(aStore().read(), throwsA(isA<FormatException>()));
    });
  });

  group('countryCodeFromLocale', () {
    test('a locale name carries its region', () {
      expect(countryCodeFromLocale('es_ES'), 'ES');
      expect(countryCodeFromLocale('es-ES'), 'ES');
      expect(countryCodeFromLocale('de_DE'), 'DE');
      expect(countryCodeFromLocale('pt_PT'), 'PT');
      expect(countryCodeFromLocale('en_GB'), 'GB');
    });

    test(
      'a locale name without a region is no country, and neither is nothing',
      () {
        expect(countryCodeFromLocale('en'), isNull);
        expect(countryCodeFromLocale(''), isNull);
        expect(countryCodeFromLocale(null), isNull);
        expect(countryCodeFromLocale('es_'), isNull);
      },
    );

    test('a region that is not two letters is not a country code', () {
      expect(countryCodeFromLocale('en_US.UTF-8'), isNull);
      expect(countryCodeFromLocale('es_ESP'), isNull);
    });
  });
}
