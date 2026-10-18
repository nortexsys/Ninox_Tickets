/// Group 3 of the negative release checklist: **no credential beyond the token**
/// (Funcional §10.6, §1.2).
///
/// The non-goal: *the app never requests, stores or transmits a Ninox username or password. The
/// API token is the only credential.* The requirements it protects are BR-19 (*the token is the
/// only credential*, obtained through the platform's system browser and living in the platform
/// keystore), NFR-SEC-001 (the token never appears in an export, a backup snapshot or a log
/// line), NFR-SEC-003 (*no credentials beyond the token*) and ADR-018 with them — plus the
/// project rule of `AGENTS.md` §1.4, which forbids one particular environment variable outright
/// (GAP-012).
///
/// **What this file proves.** No shipped source — Dart, the localisation catalogue, the Android
/// manifests, the pubspecs — asks for or holds a password, a client secret or a second key; the
/// platform keystore is the only place a secret is stored, and it removes the token's own entry
/// and nothing else; the configuration file the app writes carries no credential, read back from
/// the real store; and the forbidden environment variable is named nowhere in the product.
///
/// **Where it stops.** The scan reads names and literals. A secret held under a name this file
/// does not list would not be found, and a *value* is never inspected (a credential is checked by
/// its effect, never by printing it — `AGENTS.md` §4.4). The user-facing half of BR-19 — that the
/// login page is only ever the platform browser's — is `token_no_webview_test.dart` in `app`; the
/// narrower import-count check is `wizard_boundaries_test.dart` there. This file reads **every**
/// shipped source, which is the checklist's scope.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ninox_client/ninox_client.dart';
import 'package:paperdrop/features/wizard/data/destination_store.dart';
import 'package:paperdrop/features/wizard/data/keystore_token_store.dart';
import 'package:paperdrop/features/wizard/destination.dart';

import 'checklist_support.dart';

/// The names a second credential would answer to, as a lexical scan sees them.
///
/// `password`/`passwort`/`benutzername` cover the two interface languages (NFR-I18N-001), so a
/// screen that offered such a field would fail here in either language.
const List<String> credentialTokens = <String>[
  'password',
  'Password',
  'passwort',
  'Passwort',
  'clientSecret',
  'client_secret',
  'apiSecret',
  'api_secret',
  'privateKey',
  'username',
  'userName',
  'benutzername',
  'Benutzername',
];

/// The two lines of the product that name a password, and why each is allowed.
///
/// They are not a surface: the token instruction tells the user the opposite, and BR-19 is the
/// requirement being served. The generated line is the same sentence the catalogue holds.
const Map<String, String> credentialAllowlist = <String, String>{
  'app/lib/l10n/app_en.arb|password':
      'the token instruction of FR-WIZ-003 tells the user the app asks for no user name and no '
      'password: it states the rule rather than offering a field',
  'app/lib/l10n/generated/app_localizations_en.dart|password':
      'the same instruction, generated from `app_en.arb`',
};

/// The name of the environment variable `AGENTS.md` §1.4 forbids, spelled once so that the scan
/// has something to look for: the shipped product must never mention it (GAP-012).
const String forbiddenEnvironmentVariable = 'NINOX_DB_ID';

/// The text of the app's localisation catalogue, which is not a Dart source but is shipped.
File _localisationCatalogue() => fileAt('app/lib/l10n/app_en.arb');

void main() {
  const String nonGoal = 'no credential beyond the token';
  const String requirements = 'BR-19, NFR-SEC-001, NFR-SEC-003, ADR-018';

  test('[$nonGoal] no shipped source asks for a password or a second secret '
      '($requirements)', () {
    final File catalogue = _localisationCatalogue();
    expect(
      catalogue.existsSync(),
      isTrue,
      reason:
          'the localisation catalogue was not found, so the scan is '
          'incomplete',
    );

    final List<TokenOccurrence> found = <TokenOccurrence>[
      ...occurrencesIn(shippedSources(), credentialTokens),
      ...findOccurrences(
        catalogue.readAsStringSync(),
        credentialTokens,
        path: pathOf(catalogue),
      ),
    ];
    expect(
      found,
      isNotEmpty,
      reason:
          'the scan found nothing at all, including the instruction that '
          'states the rule, so it proves nothing',
    );
    expect(
      unauthorised(found, credentialAllowlist),
      isEmpty,
      reason:
          '[$nonGoal] the occurrences above are a password or a second secret '
          'this app would ask for, store or transmit ($requirements)',
    );
    expect(
      unmatchedEntries(found, credentialAllowlist),
      isEmpty,
      reason:
          '[$nonGoal] an allowlist entry that matches nothing is stale, and a '
          'stale entry is how this check would quietly stop working',
    );
  });

  test('[$nonGoal] the platform keystore is the only place a secret is '
      'stored, and it removes nothing else (NFR-SEC-001, BR-19)', () {
    const String plugin = 'package:flutter_secure_storage/';
    final List<TokenOccurrence> imports = occurrencesIn(
      shippedSources(),
      <String>[plugin],
    );

    expect(
      imports.map((TokenOccurrence occurrence) => occurrence.path).toList(),
      <String>['app/lib/features/wizard/data/keystore_token_store.dart'],
      reason:
          '[$nonGoal] the token is written through TokenStore and by nothing '
          'else (FR-CFG-004, $requirements)',
    );

    // `clear()` deletes the token's own entry: `deleteAll` would empty whatever else the plugin
    // holds for this application, which is a second store's business.
    final List<TokenOccurrence> deleteAll = occurrencesIn(
      shippedSources(),
      <String>['deleteAll'],
    );
    expect(
      unauthorised(deleteAll, const <String, String>{}),
      isEmpty,
      reason:
          '[$nonGoal] clearing must remove the token entry and nothing else '
          '($requirements)',
    );

    // One key, one entry — a second kind of secret would be a second credential.
    expect(KeystoreTokenStore.tokenKey, 'paperdrop.ninox.token');
  });

  test('[$nonGoal] the configuration file the app writes carries no credential '
      '(NFR-SEC-001, BR-19)', () async {
    final Directory root = Directory.systemTemp.createTempSync(
      'release-checklist-export',
    );
    addTearDown(() {
      if (root.existsSync()) {
        root.deleteSync(recursive: true);
      }
    });

    final FileDestinationStore store = FileDestinationStore(
      storage: TemporaryStorage(root),
    );
    await store.save(
      Destination(
        endpoint: NinoxEndpoint.parse('ninox.example.de')!,
        teamId: 'team-1',
        databaseId: 'db-1',
        tableId: 'T1',
        mappings: const <FieldMapping>[
          FieldMapping(
            coreField: CoreField.grossTotal,
            ninoxFieldId: 'B',
            ninoxFieldName: 'Amount',
          ),
        ],
      ),
    );

    final File written = File('${root.path}/${FileDestinationStore.fileName}');
    expect(
      written.existsSync(),
      isTrue,
      reason: 'the store wrote no file, so this test proves nothing',
    );
    final String content = written.readAsStringSync();
    expect(
      content.toLowerCase(),
      isNot(contains('token')),
      reason:
          '[$nonGoal] the configuration file is exportable and carried to '
          'another device (FR-CFG-002): a token in it would travel with it '
          '($requirements)',
    );
    expect(content, isNot(contains(KeystoreTokenStore.tokenKey)));
  });

  test('[$nonGoal] the forbidden environment variable is named nowhere in the '
      'product (AGENTS.md §1.4, GAP-012)', () {
    final List<File> scanned = <File>[
      ...shippedSources(),
      fileAt('app/pubspec.yaml'),
      fileAt('app/android/app/src/main/AndroidManifest.xml'),
      fileAt('app/android/app/src/debug/AndroidManifest.xml'),
    ];

    final List<TokenOccurrence> found = <TokenOccurrence>[
      for (final File file in scanned)
        ...findOccurrences(file.readAsStringSync(), <String>[
          forbiddenEnvironmentVariable,
        ], path: pathOf(file)),
    ];
    expect(
      unauthorised(found, const <String, String>{}),
      isEmpty,
      reason:
          '[$nonGoal] the product resolves no database identifier from the '
          'environment: the tuple is always explicit (AGENTS.md §1.4, $requirements)',
    );
  });
}
