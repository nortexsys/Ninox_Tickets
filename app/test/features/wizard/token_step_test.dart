import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ninox_client/ninox_client.dart';
import 'package:paperdrop/features/wizard/token/token_screen.dart';
import 'package:paperdrop/features/wizard/wizard_errors.dart';
import 'package:paperdrop/features/wizard/wizard_messages.dart';
import 'package:paperdrop/features/wizard/wizard_step.dart';
import 'package:paperdrop/l10n/generated/app_localizations.dart';

import 'wizard_fakes.dart';

/// The token step of design §4, on a fake port, a fake store and a fake browser: **no test here
/// makes a network call and none needs a token** — every Ninox answer is a failure or a list the
/// test put in the fake, and the token is a synthetic value the test invented.
///
/// The three scenarios of `token-step-via-the-system-browser` are covered by name:
///
/// * *the login is presented outside the app's process* — the step opens the settings address
///   through the [SystemBrowser] port and through nothing else, and `token_no_webview_test.dart`
///   scans the package for a browser the app would render itself;
/// * *an invalid token keeps the user on the step* — the message is shown, the step is not passed
///   and nothing was stored;
/// * *a valid token also delivers the next list* — the one validating call is the list of the next
///   step, and it is not made twice.
///
/// Every row of the design's outcome table has a test below, and so do the two cases the table does
/// not cover: a host that is not an accepted form (reported at the field, with no call at all) and
/// the order of the validating call and the keystore write.
void main() {
  /// The host and the token a test pastes. Both are synthetic: the test base's identifiers appear
  /// in no fixture, and this token is one the test invented.
  const String host = 'api.ninox.com';
  const String token = 'pasted-token-1';

  /// A settings address of the test's own. `.invalid` is reserved by RFC 2606 and resolves nowhere:
  /// the real address is not established (see `ninoxApiTokenSettingsUri`) and this test must not
  /// invent it either.
  final Uri settings = Uri.parse('https://ninox.example.invalid/settings');

  /// The resources, in English. Every sentence the step shows is a `wizard`-prefixed key of
  /// `app_en.arb`, and the test reads the same values the screen does.
  late AppLocalizations en;

  setUpAll(() async {
    en = await AppLocalizations.delegate.load(const Locale('en'));
  });

  NinoxTeam team(String id) => NinoxTeam(id: id, name: 'Team $id');

  NinoxTable table(String id) => NinoxTable(
    id: id,
    name: 'Table $id',
    fields: <NinoxField>[
      const NinoxField(id: 'field-1', name: 'Belegdatum', type: 'date'),
    ],
  );

  /// Puts [text] on the clipboard, as the platform would. `null` is a clipboard the platform
  /// answers nothing for.
  void putOnClipboard(WidgetTester tester, String? text) {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall call) async {
        if (call.method != 'Clipboard.getData') {
          return null;
        }
        return text == null ? null : <String, dynamic>{'text': text};
      },
    );
  }

  // The second literal is double-quoted because the scenario's own wording carries an apostrophe,
  // and `scenario_coverage.py` reads a test's name out of the source without reading escapes.
  testWidgets('[setup-wizard/token-step-via-the-system-browser] '
      "the login is presented outside the app's process", (
    WidgetTester tester,
  ) async {
    final wizard = wizardHarness();
    final FakeSystemBrowser browser = FakeSystemBrowser();

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: TokenScreen(
          controller: wizard.controller,
          browser: browser,
          settingsUri: settings,
        ),
      ),
    );

    await tester.tap(find.text(en.wizardTokenOpenSettingsAction));
    await tester.pumpAndSettle();

    // The step asked the platform's browser, once, for the settings address — and asked nothing
    // else: the port is the only way out of this screen, and no request of the app's own was made.
    expect(browser.opened, <Uri>[settings]);
    expect(wizard.port.calls, isEmpty);
  });

  testWidgets('the settings action is not offered while the address is not '
      'established', (WidgetTester tester) async {
    // The address is `null` (the `ninox` skill states none), and the orchestrator decided on
    // 2026-10-07 that no URL is invented: the action is not shown, so neither a guessed address nor
    // a dead button is ever put in front of the user.
    final wizard = wizardHarness();
    final FakeSystemBrowser browser = FakeSystemBrowser();

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: TokenScreen(
          controller: wizard.controller,
          browser: browser,
          settingsUri: null,
        ),
      ),
    );

    expect(
      find.widgetWithText(OutlinedButton, en.wizardTokenOpenSettingsAction),
      findsNothing,
    );
    // Everything else the step offers is there, and the browser was never asked for anything.
    expect(find.text(en.wizardTokenPasteAction), findsOneWidget);
    expect(find.text(en.wizardTokenConnectAction), findsOneWidget);
    expect(browser.opened, isEmpty);
  });

  testWidgets('[setup-wizard/token-step-via-the-system-browser] '
      'an invalid token keeps the user on the step', (
    WidgetTester tester,
  ) async {
    final wizard = wizardHarness();
    wizard.port.failures['listTeams'] = const Unauthorized();

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: TokenScreen(
          controller: wizard.controller,
          browser: FakeSystemBrowser(),
        ),
      ),
    );
    await tester.enterText(find.byKey(TokenScreen.tokenFieldKey), token);
    await tester.tap(find.text(en.wizardTokenConnectAction));
    await tester.pumpAndSettle();

    // Not passed, and said so: the message is the resources' sentence, not the API's own words.
    expect(wizard.controller.step, WizardStep.token);
    expect(find.text(en.wizardErrorTokenNotAccepted), findsOneWidget);
    // Nothing was stored, and the field still holds what the user pasted so it can be corrected.
    expect(wizard.store.writes, isEmpty);
    expect(
      tester
          .widget<TextField>(find.byKey(TokenScreen.tokenFieldKey))
          .controller
          ?.text,
      token,
    );
  });

  testWidgets('[setup-wizard/token-step-via-the-system-browser] '
      'a valid token also delivers the next list', (WidgetTester tester) async {
    final wizard = wizardHarness(
      teams: <NinoxTeam>[team('team-1'), team('team-2')],
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: TokenScreen(
          controller: wizard.controller,
          browser: FakeSystemBrowser(),
        ),
      ),
    );
    await tester.enterText(find.byKey(TokenScreen.tokenFieldKey), token);
    await tester.tap(find.text(en.wizardTokenConnectAction));
    await tester.pumpAndSettle();

    // The one call is also the next step's list, and it was made exactly once.
    expect(wizard.controller.state.teams, <NinoxTeam>[
      team('team-1'),
      team('team-2'),
    ]);
    expect(wizard.controller.step, WizardStep.team);
    expect(
      wizard.port.calls.where((String call) => call == 'listTeams'),
      hasLength(1),
    );
    // The token is in the keystore and nowhere the step can leak it from: the field is empty.
    expect(wizard.store.writes, <String>[token]);
    expect(
      tester
          .widget<TextField>(find.byKey(TokenScreen.tokenFieldKey))
          .controller
          ?.text,
      isEmpty,
    );
  });

  testWidgets('a one-option subscription reaches the mapping step in the same '
      'call', (WidgetTester tester) async {
    final wizard = wizardHarness(
      teams: <NinoxTeam>[team('team-1')],
      databases: <NinoxDatabase>[NinoxDatabase(id: 'db-1', name: 'Database')],
      tables: <NinoxTable>[table('table-1')],
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: TokenScreen(
          controller: wizard.controller,
          browser: FakeSystemBrowser(),
        ),
      ),
    );
    await tester.enterText(find.byKey(TokenScreen.tokenFieldKey), token);
    await tester.tap(find.text(en.wizardTokenConnectAction));
    await tester.pumpAndSettle();

    expect(wizard.controller.visibleSteps, <WizardStep>[
      WizardStep.token,
      WizardStep.mapping,
    ]);
    expect(wizard.controller.step, WizardStep.mapping);
  });

  testWidgets('an unreachable host is reported at this step', (
    WidgetTester tester,
  ) async {
    final wizard = wizardHarness();
    wizard.port.failures['listTeams'] = const TransportFailure();

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: TokenScreen(
          controller: wizard.controller,
          browser: FakeSystemBrowser(),
        ),
      ),
    );
    await tester.enterText(find.byKey(TokenScreen.tokenFieldKey), token);
    await tester.tap(find.text(en.wizardTokenConnectAction));
    await tester.pumpAndSettle();

    // Reported here and not deferred to the first send (FR-DST-008).
    expect(wizard.controller.step, WizardStep.token);
    expect(find.text(en.wizardErrorHostUnreachable), findsOneWidget);
    expect(wizard.store.writes, isEmpty);
  });

  testWidgets('a host that is not an accepted form is reported at the field, '
      'with no call', (WidgetTester tester) async {
    final wizard = wizardHarness();

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: TokenScreen(
          controller: wizard.controller,
          browser: FakeSystemBrowser(),
        ),
      ),
    );
    await tester.tap(find.text(en.wizardTokenAdvancedTitle));
    await tester.pumpAndSettle();
    // A plain-text scheme would put the token on the wire in clear (NinoxEndpoint.parse).
    await tester.enterText(
      find.byKey(TokenScreen.hostFieldKey),
      'http://api.ninox.com',
    );
    await tester.enterText(find.byKey(TokenScreen.tokenFieldKey), token);
    await tester.tap(find.text(en.wizardTokenConnectAction));
    await tester.pumpAndSettle();

    expect(find.text(en.wizardErrorHostNotValid), findsOneWidget);
    expect(wizard.port.calls, isEmpty);
    expect(wizard.store.writes, isEmpty);
    expect(wizard.controller.state.endpoint, NinoxEndpoint.cloud);
  });

  testWidgets('the paste action fills the obscured field, trimmed', (
    WidgetTester tester,
  ) async {
    final wizard = wizardHarness();
    putOnClipboard(tester, '  $token  ');

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: TokenScreen(
          controller: wizard.controller,
          browser: FakeSystemBrowser(),
        ),
      ),
    );
    expect(
      tester
          .widget<TextField>(find.byKey(TokenScreen.tokenFieldKey))
          .obscureText,
      isTrue,
    );

    await tester.tap(find.text(en.wizardTokenPasteAction));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<TextField>(find.byKey(TokenScreen.tokenFieldKey))
          .controller
          ?.text,
      token,
    );
  });

  testWidgets('an empty clipboard changes nothing', (
    WidgetTester tester,
  ) async {
    final wizard = wizardHarness();
    putOnClipboard(tester, null);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: TokenScreen(
          controller: wizard.controller,
          browser: FakeSystemBrowser(),
        ),
      ),
    );
    await tester.tap(find.text(en.wizardTokenPasteAction));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<TextField>(find.byKey(TokenScreen.tokenFieldKey))
          .controller
          ?.text,
      isEmpty,
    );
  });

  /// One row of the design's outcome table, through the controller a screen drives.
  ///
  /// The expected sentence is a closure and not a value: the resources are loaded in `setUpAll`,
  /// which runs after this body has registered the tests.
  void outcome(
    NinoxFailure failure,
    WizardError expected,
    String Function(AppLocalizations) sentence,
  ) {
    test('the outcome table: $failure', () async {
      final wizard = wizardHarness();
      wizard.port.failures['listTeams'] = failure;

      await wizard.controller.connect(host: host, token: token);

      expect(wizard.controller.state.error, expected);
      expect(wizard.controller.step, WizardStep.token);
      expect(wizardErrorMessage(en, expected), sentence(en));
      expect(wizard.store.writes, isEmpty);
      expect(wizard.port.calls, <String>['listTeams']);
    });
  }

  group('every failure design 4 maps, in full', () {
    outcome(
      const Unauthorized(),
      WizardError.tokenNotAccepted,
      (AppLocalizations l) => l.wizardErrorTokenNotAccepted,
    );
    outcome(
      const TransportFailure(),
      WizardError.hostUnreachable,
      (AppLocalizations l) => l.wizardErrorHostUnreachable,
    );
    outcome(
      const UnexpectedResponse(),
      WizardError.notANinoxApi,
      (AppLocalizations l) => l.wizardErrorNotANinoxApi,
    );
    outcome(
      const ServerError(500),
      WizardError.ninoxError,
      (AppLocalizations l) => l.wizardErrorNinoxError,
    );
    outcome(
      const RateLimited(),
      WizardError.ninoxError,
      (AppLocalizations l) => l.wizardErrorNinoxError,
    );
    outcome(
      const NotFound(),
      WizardError.ninoxError,
      (AppLocalizations l) => l.wizardErrorNinoxError,
    );
  });

  test(
    'the token reaches the store only after the validating call succeeded',
    () async {
      final List<String> events = <String>[];
      final wizard = wizardHarness(
        teams: <NinoxTeam>[team('team-1'), team('team-2')],
        log: events,
      );

      await wizard.controller.connect(host: host, token: token);

      expect(events, <String>['listTeams', 'writeToken']);
      expect(wizard.store.writes, <String>[token]);
    },
  );

  test('a call that failed writes nothing at all', () async {
    final List<String> events = <String>[];
    final wizard = wizardHarness(log: events);
    wizard.port.failures['listTeams'] = const Unauthorized();

    await wizard.controller.connect(host: host, token: token);

    expect(events, <String>['listTeams']);
    expect(wizard.store.writes, isEmpty);
    expect(wizard.store.stored, isNull);
  });

  test('no message the step can show, and nothing it stringifies, holds the '
      'token', () async {
    // The proof design §1 asks for: the controller, the state and every sentence the step can show
    // are stringified and searched for the token the test pasted.
    final wizard = wizardHarness();
    wizard.port.failures['listTeams'] = const Unauthorized();
    await wizard.controller.connect(host: host, token: token);

    final StringBuffer everything = StringBuffer()
      ..writeln(wizard.controller)
      ..writeln(wizard.controller.state)
      ..writeln(wizard.store)
      ..writeln(settings);
    for (final WizardError error in WizardError.values) {
      everything.writeln(wizardErrorMessage(en, error));
    }
    for (final WizardNotice notice in WizardNotice.values) {
      everything.writeln(wizardNoticeMessage(en, notice));
    }

    expect(everything.toString(), isNot(contains(token)));
    // And the state itself is where it must be: the failure it reports is a sentence's code, not
    // the value the user typed.
    expect(wizard.controller.state.error, WizardError.tokenNotAccepted);
  });

  test('no sentence of the resources holds the token either', () {
    // Every wizard sentence a screen can show, stringified: none of them is a token, and the
    // resources are the only place the step takes text from (design §1, NFR-I18N-001).
    final String all = <String>[
      en.wizardTitle,
      en.wizardTokenInstructions,
      en.wizardTokenFieldLabel,
      en.wizardTokenFieldHint,
      en.wizardTokenPasteAction,
      en.wizardTokenOpenSettingsAction,
      en.wizardTokenAdvancedTitle,
      en.wizardTokenHostLabel,
      en.wizardTokenHostHint,
      en.wizardTokenHostHelp,
      en.wizardTokenConnectAction,
      en.wizardTeamStepTitle,
      en.wizardDatabaseStepTitle,
      en.wizardTableStepTitle,
      en.wizardBackAction,
      en.wizardTryAgainAction,
      en.wizardErrorHostNotValid,
      en.wizardErrorTokenNotAccepted,
      en.wizardErrorHostUnreachable,
      en.wizardErrorNotANinoxApi,
      en.wizardErrorNinoxError,
      en.wizardNoticeNoTeams,
      en.wizardNoticeNoDatabases,
      en.wizardNoticeNoTables,
    ].join('\n');

    expect(all, isNot(contains(token)));
    expect(all.toLowerCase(), isNot(contains('bearer')));
  });
}
