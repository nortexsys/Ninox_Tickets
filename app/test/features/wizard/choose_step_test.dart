import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ninox_client/ninox_client.dart';
import 'package:paperdrop/features/wizard/choose/choose_screen.dart';
import 'package:paperdrop/features/wizard/wizard_controller.dart';
import 'package:paperdrop/features/wizard/wizard_errors.dart';
import 'package:paperdrop/features/wizard/wizard_messages.dart';
import 'package:paperdrop/features/wizard/wizard_step.dart';
import 'package:paperdrop/l10n/generated/app_localizations.dart';

import 'wizard_fakes.dart';

/// The team, database and table steps of design §2–§3 on the fake port: **no test here makes a
/// network call and none needs a token.**
///
/// What the widget owes: one widget serves the three steps, a selection is the step's completion,
/// the call behind it is made exactly once, the tables arrive with their fields so the mapping step
/// needs no further call, an empty list is explained, and a call that failed keeps the user on the
/// step with the token step's own sentence and a retry that works.
///
/// FR-WIZ-002's two scenarios are covered by the controller's tests (`wizard_controller_test.dart`),
/// which is where the auto-omit rule lives; this file covers what the *screen* does with the lists
/// it is given, and FR-WIZ-004's *one round trip per list* is tagged here.
void main() {
  /// Synthetic values, as everywhere in this suite: the test base's identifiers appear in no
  /// fixture and the token is one the test invented.
  const String host = 'api.ninox.com';
  const String token = 'pasted-token-1';

  /// The resources, in English: every sentence these steps show is a `wizard`-prefixed key of
  /// `app_en.arb`.
  late AppLocalizations en;

  setUpAll(() async {
    en = await AppLocalizations.delegate.load(const Locale('en'));
  });

  NinoxTeam team(String id) => NinoxTeam(id: id, name: 'Team $id');

  NinoxDatabase database(String id) =>
      NinoxDatabase(id: id, name: 'Database $id');

  NinoxTable table(String id) => NinoxTable(
    id: id,
    name: 'Table $id',
    fields: <NinoxField>[
      const NinoxField(id: 'field-1', name: 'Belegdatum', type: 'date'),
      const NinoxField(id: 'field-2', name: 'Betrag', type: 'number'),
    ],
  );

  /// The three lists, each with two options, so every step is shown and the user chooses.
  ({WizardController controller, FakeNinoxPort port, FakeTokenStore store})
  everyStep() => wizardHarness(
    teams: <NinoxTeam>[team('team-1'), team('team-2')],
    databases: <NinoxDatabase>[database('db-1'), database('db-2')],
    tables: <NinoxTable>[table('table-1'), table('table-2')],
  );

  /// Pumps the screen over [controller], which is already past its token step.
  Future<void> pumpChoose(WidgetTester tester, WizardController controller) =>
      tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ChooseScreen(controller: controller),
        ),
      );

  testWidgets('one widget serves the three steps, and a selection is the '
      'step\'s completion', (WidgetTester tester) async {
    final wizard = everyStep();
    await wizard.controller.connect(host: host, token: token);
    await pumpChoose(tester, wizard.controller);

    // The team step, from the list the token call already returned.
    expect(find.text(en.wizardTeamStepTitle), findsOneWidget);
    expect(find.text('Team team-1'), findsOneWidget);
    expect(find.text('Team team-2'), findsOneWidget);

    await tester.tap(find.byKey(ChooseScreen.optionKey('team-1')));
    await tester.pumpAndSettle();

    // The same widget, now the database step, with the step's own call already made.
    expect(find.text(en.wizardDatabaseStepTitle), findsOneWidget);
    expect(find.text('Database db-2'), findsOneWidget);
    expect(wizard.port.calls, <String>['listTeams', 'listDatabases']);
    // The choice is the state's.
    expect(wizard.controller.state.teamId, 'team-1');

    await tester.tap(find.byKey(ChooseScreen.optionKey('db-2')));
    await tester.pumpAndSettle();

    expect(find.text(en.wizardTableStepTitle), findsOneWidget);
    expect(wizard.port.calls, <String>[
      'listTeams',
      'listDatabases',
      'listTables',
    ]);
    expect(wizard.controller.state.databaseId, 'db-2');

    await tester.tap(find.byKey(ChooseScreen.optionKey('table-1')));
    await tester.pumpAndSettle();

    // The table step's completion is the mapping step, and no call was made for it.
    expect(wizard.controller.step, WizardStep.mapping);
    expect(wizard.controller.state.tableId, 'table-1');
    expect(wizard.port.calls, <String>[
      'listTeams',
      'listDatabases',
      'listTables',
    ]);
  });

  testWidgets('[setup-wizard/table-listing-returns-the-schema] '
      'one round trip per list, and the tables carry their fields', (
    WidgetTester tester,
  ) async {
    final wizard = everyStep();
    await wizard.controller.connect(host: host, token: token);
    await pumpChoose(tester, wizard.controller);
    await tester.tap(find.byKey(ChooseScreen.optionKey('team-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ChooseScreen.optionKey('db-1')));
    await tester.pumpAndSettle();

    // Each list was asked for exactly once, and the tables arrived with the fields the mapping step
    // needs — so reaching it costs no further call (FR-WIZ-004).
    expect(wizard.port.calls, hasLength(3));
    expect(wizard.controller.state.tables.first.fields, <NinoxField>[
      const NinoxField(id: 'field-1', name: 'Belegdatum', type: 'date'),
      const NinoxField(id: 'field-2', name: 'Betrag', type: 'number'),
    ]);
    await tester.tap(find.byKey(ChooseScreen.optionKey('table-1')));
    await tester.pumpAndSettle();
    expect(wizard.controller.step, WizardStep.mapping);
    expect(wizard.port.calls, hasLength(3));
  });

  testWidgets('a list with no option is explained and offers nothing to '
      'choose', (WidgetTester tester) async {
    final wizard = wizardHarness(
      teams: <NinoxTeam>[team('team-1'), team('team-2')],
      databases: const <NinoxDatabase>[],
    );
    await wizard.controller.connect(host: host, token: token);
    await pumpChoose(tester, wizard.controller);

    await tester.tap(find.byKey(ChooseScreen.optionKey('team-1')));
    await tester.pumpAndSettle();

    expect(find.text(en.wizardNoticeNoDatabases), findsOneWidget);
    expect(find.byKey(ChooseScreen.optionKey('db-1')), findsNothing);
    // Nothing to retry: the call succeeded and answered with nothing.
    expect(find.byKey(ChooseScreen.retryKey), findsNothing);
    expect(wizard.controller.state.notice, WizardNotice.noDatabases);
  });

  testWidgets(
    'a failure on the databases call keeps the user on the step, with '
    'the token step\'s own sentence and a retry that works',
    (WidgetTester tester) async {
      final wizard = everyStep();
      await wizard.controller.connect(host: host, token: token);
      wizard.port.failures['listDatabases'] = const NotFound();
      await pumpChoose(tester, wizard.controller);

      await tester.tap(find.byKey(ChooseScreen.optionKey('team-1')));
      await tester.pumpAndSettle();

      // The step did not move, the sentence is the resources' — not Ninox's own words — and there is
      // no "there is no database" claim about a call that did not answer.
      expect(wizard.controller.step, WizardStep.database);
      expect(find.text(en.wizardErrorNinoxError), findsOneWidget);
      expect(find.text(en.wizardNoticeNoDatabases), findsNothing);
      expect(wizard.port.calls, <String>['listTeams', 'listDatabases']);

      // The retry runs that same call again, and only that one.
      wizard.port.failures.clear();
      await tester.tap(find.byKey(ChooseScreen.retryKey));
      await tester.pumpAndSettle();

      expect(wizard.port.calls, <String>[
        'listTeams',
        'listDatabases',
        'listDatabases',
      ]);
      expect(find.text(en.wizardErrorNinoxError), findsNothing);
      expect(find.text('Database db-1'), findsOneWidget);
      expect(wizard.controller.state.databases, hasLength(2));
    },
  );

  testWidgets('a failure on the tables call is treated the same way', (
    WidgetTester tester,
  ) async {
    final wizard = everyStep();
    await wizard.controller.connect(host: host, token: token);
    await pumpChoose(tester, wizard.controller);
    await tester.tap(find.byKey(ChooseScreen.optionKey('team-1')));
    await tester.pumpAndSettle();
    wizard.port.failures['listTables'] = const TransportFailure();
    await tester.tap(find.byKey(ChooseScreen.optionKey('db-1')));
    await tester.pumpAndSettle();

    expect(wizard.controller.step, WizardStep.table);
    expect(find.text(en.wizardErrorHostUnreachable), findsOneWidget);
    expect(find.text(en.wizardNoticeNoTables), findsNothing);

    wizard.port.failures.clear();
    await tester.tap(find.byKey(ChooseScreen.retryKey));
    await tester.pumpAndSettle();

    expect(find.text(en.wizardErrorHostUnreachable), findsNothing);
    expect(find.text('Table table-1'), findsOneWidget);
    expect(wizard.controller.step, WizardStep.table);
  });

  test(
    'a list call that fails takes the token step\'s own table, in full',
    () async {
      // The orchestrator's decision of 2026-10-07: the three list calls are shown with the same
      // sentences as the token step, the user stays on the step that made the call, and nothing else
      // is invented for them.
      const List<(NinoxFailure, WizardError)> table =
          <(NinoxFailure, WizardError)>[
            (Unauthorized(), WizardError.tokenNotAccepted),
            (TransportFailure(), WizardError.hostUnreachable),
            (UnexpectedResponse(), WizardError.notANinoxApi),
            (ServerError(500), WizardError.ninoxError),
            (RateLimited(), WizardError.ninoxError),
            (NotFound(), WizardError.ninoxError),
          ];

      for (final (NinoxFailure failure, WizardError expected) in table) {
        final wizard = everyStep();
        await wizard.controller.connect(host: host, token: token);
        wizard.port.failures['listDatabases'] = failure;

        await wizard.controller.chooseTeam('team-1');

        expect(wizard.controller.state.error, expected, reason: '$failure');
        expect(wizard.controller.step, WizardStep.database, reason: '$failure');
        expect(
          wizardErrorMessage(en, expected),
          isNotEmpty,
          reason: '$failure',
        );
      }
    },
  );

  testWidgets('the chosen option is marked, and the back action returns to the '
      'previous visible step', (WidgetTester tester) async {
    final wizard = everyStep();
    await wizard.controller.connect(host: host, token: token);
    await pumpChoose(tester, wizard.controller);

    // The team step has the token step behind it, and nothing is chosen yet.
    expect(find.byKey(ChooseScreen.backKey), findsOneWidget);
    await tester.tap(find.byKey(ChooseScreen.optionKey('team-1')));
    await tester.pumpAndSettle();
    expect(wizard.controller.step, WizardStep.database);
    expect(wizard.controller.state.teamId, 'team-1');

    // Back to the team step: the choice the user made is shown as the chosen one.
    await tester.tap(find.byKey(ChooseScreen.backKey));
    await tester.pumpAndSettle();

    expect(wizard.controller.step, WizardStep.team);
    expect(find.text(en.wizardTeamStepTitle), findsOneWidget);
    expect(
      tester
          .widget<ListTile>(find.byKey(ChooseScreen.optionKey('team-1')))
          .selected,
      isTrue,
    );
    expect(
      tester
          .widget<ListTile>(find.byKey(ChooseScreen.optionKey('team-2')))
          .selected,
      isFalse,
    );
  });

  testWidgets('the back action is not offered on the first step', (
    WidgetTester tester,
  ) async {
    // The token step has nothing behind it, and this screen says so by offering nothing.
    final wizard = wizardHarness();
    await pumpChoose(tester, wizard.controller);

    expect(wizard.controller.canGoBack, isFalse);
    expect(find.byKey(ChooseScreen.backKey), findsNothing);
  });
}
