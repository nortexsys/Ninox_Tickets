import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ninox_client/ninox_client.dart';
import 'package:paperdrop/app/router.dart';
import 'package:paperdrop/features/capture/capture_controller.dart';
import 'package:paperdrop/features/wizard/choose/choose_screen.dart';
import 'package:paperdrop/features/wizard/token/token_screen.dart';
import 'package:paperdrop/features/wizard/wizard_routes.dart';
import 'package:paperdrop/features/wizard/wizard_step.dart';
import 'package:paperdrop/l10n/generated/app_localizations.dart';

import '../../tool/fakes.dart';
import 'wizard_fakes.dart';

/// The wizard as the router reaches it (design §2, task 2.2).
///
/// **No test here makes a network call and none needs a token.** The route that the *shell* carries
/// is entered with the device's composition — a real `http.Client`, the Keystore and the platform's
/// browser — and nothing is pressed, so no request is made and no keystore call happens; the walk
/// through the steps runs on `wizardRoutesFor` and the fakes of `wizard_fakes.dart`.
void main() {
  /// Synthetic values, as everywhere in this suite.
  const String token = 'pasted-token-1';

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
    ],
  );

  /// The shell's own router, over the capture pipeline the Mobile lane's tests fake.
  CaptureController captureController() => CaptureController(
    intake: FakeDocumentIntake(root: Directory('paperdrop-wizard-route-test')),
    scanner: FakeDocumentScanner(),
    picker: FakeFilePickerSource(),
    shareIn: FakeShareInSource(),
  );

  /// The application's smallest host: the localisations the screens read.
  Widget host(GoRouter router) => MaterialApp.router(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    routerConfig: router,
  );

  testWidgets('the router reaches the wizard, and the wizard opens on its '
      'first step', (WidgetTester tester) async {
    // The shell's own router, with the single line this change adds to it.
    final GoRouter router = buildAppRouter(controller: captureController());
    await tester.pumpWidget(host(router));
    await tester.pumpAndSettle();
    expect(find.byType(TokenScreen), findsNothing);

    router.go(wizardRoute);
    await tester.pumpAndSettle();

    // The token step, with its text from the resources and its action ready.
    expect(find.byType(TokenScreen), findsOneWidget);
    expect(find.text(en.wizardTokenInstructions), findsOneWidget);
    expect(find.text(en.wizardTokenConnectAction), findsOneWidget);
    // A wizard is a run of its own: nothing was asked of Ninox to open it.
    expect(find.text(en.captureHeadline), findsNothing);
  });

  testWidgets('the flow walks the steps of its own route, one step at a time', (
    WidgetTester tester,
  ) async {
    final wizard = wizardHarness(
      teams: <NinoxTeam>[team('team-1'), team('team-2')],
      databases: <NinoxDatabase>[database('db-1'), database('db-2')],
      tables: <NinoxTable>[table('table-1'), table('table-2')],
    );
    final GoRouter router = GoRouter(
      initialLocation: wizardRoute,
      routes: wizardRoutesFor(
        controllerFactory: () => wizard.controller,
        browser: FakeSystemBrowser(),
      ),
    );
    await tester.pumpWidget(host(router));
    await tester.pumpAndSettle();

    // The token step, and the one call that validates and delivers the team list.
    expect(find.byType(TokenScreen), findsOneWidget);
    await tester.enterText(find.byKey(TokenScreen.tokenFieldKey), token);
    await tester.tap(find.text(en.wizardTokenConnectAction));
    await tester.pumpAndSettle();

    // The same route, now the team step: the flow redrew what the controller's step says.
    expect(find.byType(TokenScreen), findsNothing);
    expect(find.byType(ChooseScreen), findsOneWidget);
    expect(find.text(en.wizardTeamStepTitle), findsOneWidget);
    expect(wizard.port.calls, <String>['listTeams']);

    await tester.tap(find.byKey(ChooseScreen.optionKey('team-1')));
    await tester.pumpAndSettle();
    expect(find.text(en.wizardDatabaseStepTitle), findsOneWidget);

    await tester.tap(find.byKey(ChooseScreen.optionKey('db-1')));
    await tester.pumpAndSettle();
    expect(find.text(en.wizardTableStepTitle), findsOneWidget);

    await tester.tap(find.byKey(ChooseScreen.optionKey('table-1')));
    await tester.pumpAndSettle();

    // The mapping step is the fifth, and its screen is dispatch 3.3's: the flow shows the wizard's
    // own frame and no other step's screen, and the tables arrived with their fields.
    expect(wizard.controller.step, WizardStep.mapping);
    expect(find.byType(TokenScreen), findsNothing);
    expect(find.byType(ChooseScreen), findsNothing);
    expect(find.text(en.wizardTitle), findsOneWidget);
    expect(
      wizard.controller.state.tables.every(
        (NinoxTable table) => table.fields.isNotEmpty,
      ),
      isTrue,
      reason: 'the tables arrive with their fields (FR-WIZ-004)',
    );
    expect(wizard.port.calls, hasLength(3));
  });

  testWidgets('a second visit is a fresh run, not the state of the first', (
    WidgetTester tester,
  ) async {
    int built = 0;
    final GoRouter router = GoRouter(
      initialLocation: captureRoute,
      routes: <RouteBase>[
        GoRoute(
          path: captureRoute,
          builder: (BuildContext context, GoRouterState state) =>
              const Scaffold(),
        ),
        ...wizardRoutesFor(
          controllerFactory: () {
            built++;
            return wizardHarness(
              teams: <NinoxTeam>[team('team-1'), team('team-2')],
            ).controller;
          },
        ),
      ],
    );
    await tester.pumpWidget(host(router));
    await tester.pumpAndSettle();
    expect(built, 0);

    router.go(wizardRoute);
    await tester.pumpAndSettle();
    expect(built, 1);
    await tester.enterText(find.byKey(TokenScreen.tokenFieldKey), token);
    await tester.tap(find.text(en.wizardTokenConnectAction));
    await tester.pumpAndSettle();
    // The first run went as far as the team step.
    expect(find.text(en.wizardTeamStepTitle), findsOneWidget);

    router.go(captureRoute);
    await tester.pumpAndSettle();
    router.go(wizardRoute);
    await tester.pumpAndSettle();

    // A second visit is a second run: a new controller, and its first step.
    expect(built, 2);
    expect(find.byType(TokenScreen), findsOneWidget);
    expect(find.text(en.wizardTeamStepTitle), findsNothing);
  });
}
