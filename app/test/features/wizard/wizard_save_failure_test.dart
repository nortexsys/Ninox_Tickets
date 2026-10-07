import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ninox_client/ninox_client.dart';
import 'package:paperdrop/features/wizard/mapping/mapping_screen.dart';
import 'package:paperdrop/features/wizard/summary/summary_screen.dart';
import 'package:paperdrop/features/wizard/token/token_screen.dart';
import 'package:paperdrop/features/wizard/wizard_controller.dart';
import 'package:paperdrop/features/wizard/wizard_routes.dart';
import 'package:paperdrop/l10n/generated/app_localizations.dart';

import 'wizard_fakes.dart';

/// A destination that could not be written (design §10.1): the summary says so, claims nothing as
/// saved, and offers a retry that works.
///
/// **No network and no token:** the port is a fake and the store is the in-memory one whose writes a
/// test can make fail. Nothing here reaches a device.
void main() {
  /// Synthetic values, as everywhere in this suite.
  const String token = 'pasted-token-1';

  late AppLocalizations en;

  setUpAll(() async {
    en = await AppLocalizations.delegate.load(const Locale('en'));
  });

  /// Walks the wizard to its summary, with a store that fails the first write.
  Future<({WizardController controller, FakeDestinationStore store})>
  summaryAfterAFailedSave(WidgetTester tester, {required bool failing}) async {
    final ({
      WizardController controller,
      FakeNinoxPort port,
      FakeTokenStore store,
    })
    wizard = wizardHarness(
      teams: <NinoxTeam>[NinoxTeam(id: 'team-1', name: 'Team')],
      databases: <NinoxDatabase>[NinoxDatabase(id: 'db-1', name: 'Database')],
      tables: <NinoxTable>[
        NinoxTable(
          id: 'table-1',
          name: 'Invoices',
          fields: <NinoxField>[
            const NinoxField(id: 'field-1', name: 'Belegdatum', type: 'date'),
          ],
        ),
      ],
    );
    final FakeDestinationStore destinations = FakeDestinationStore()
      ..failing = failing;

    tester.view.physicalSize = const Size(1000, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: GoRouter(
          initialLocation: wizardRoute,
          routes: wizardRoutes(
            controllerFactory: () => wizard.controller,
            browser: FakeSystemBrowser(),
            destinationStore: destinations,
            onFinished: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(TokenScreen.tokenFieldKey), token);
    await tester.tap(find.text(en.wizardTokenConnectAction));
    await tester.pumpAndSettle();
    expect(find.byType(MappingScreen), findsOneWidget);
    await tester.ensureVisible(find.byKey(MappingScreen.continueKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(MappingScreen.continueKey));
    await tester.pumpAndSettle();

    return (controller: wizard.controller, store: destinations);
  }

  testWidgets('a store that refuses the write shows the message and offers the '
      'retry, and claims nothing as saved', (WidgetTester tester) async {
    final ({WizardController controller, FakeDestinationStore store}) run =
        await summaryAfterAFailedSave(tester, failing: true);

    // The summary is there, and it says what could not be done.
    expect(find.byType(SummaryScreen), findsOneWidget);
    expect(
      find.text(en.wizardSummarySaveFailed),
      findsOneWidget,
      reason: 'the failure is a sentence on the step, not a silent loss',
    );
    // Nothing is claimed as saved: the store holds nothing, and the offer to capture — which would
    // hand the user to a document with nowhere to go — is not made.
    expect(run.store.saved, isEmpty);
    expect(run.store.stored, isEmpty);
    expect(find.byKey(SummaryScreen.captureKey), findsNothing);
    expect(find.byKey(SummaryScreen.retrySaveKey), findsOneWidget);
  });

  testWidgets('the retry writes the destination and clears the message', (
    WidgetTester tester,
  ) async {
    final ({WizardController controller, FakeDestinationStore store}) run =
        await summaryAfterAFailedSave(tester, failing: true);
    expect(find.text(en.wizardSummarySaveFailed), findsOneWidget);

    // The device can write again.
    run.store.failing = false;
    await tester.tap(find.byKey(SummaryScreen.retrySaveKey));
    await tester.pumpAndSettle();

    expect(find.text(en.wizardSummarySaveFailed), findsNothing);
    expect(find.byKey(SummaryScreen.retrySaveKey), findsNothing);
    // A destination is written now, and the offer to capture is made.
    expect(run.store.saved, hasLength(1));
    expect(run.store.saved.single.teamId, 'team-1');
    expect(find.byKey(SummaryScreen.captureKey), findsOneWidget);
  });

  testWidgets('a retry that fails again says so again', (
    WidgetTester tester,
  ) async {
    final ({WizardController controller, FakeDestinationStore store}) run =
        await summaryAfterAFailedSave(tester, failing: true);

    await tester.tap(find.byKey(SummaryScreen.retrySaveKey));
    await tester.pumpAndSettle();

    expect(find.text(en.wizardSummarySaveFailed), findsOneWidget);
    expect(run.store.saved, isEmpty);
    expect(find.byKey(SummaryScreen.captureKey), findsNothing);
  });

  testWidgets('a store that writes shows the offer and never the message', (
    WidgetTester tester,
  ) async {
    final ({WizardController controller, FakeDestinationStore store}) run =
        await summaryAfterAFailedSave(tester, failing: false);

    expect(find.text(en.wizardSummarySaveFailed), findsNothing);
    expect(find.byKey(SummaryScreen.retrySaveKey), findsNothing);
    expect(run.store.saved, hasLength(1));
    expect(find.byKey(SummaryScreen.captureKey), findsOneWidget);
  });
}
