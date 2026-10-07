import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ninox_client/ninox_client.dart';
import 'package:paperdrop/features/wizard/choose/choose_screen.dart';
import 'package:paperdrop/features/wizard/destination.dart';
import 'package:paperdrop/features/wizard/mapping/mapping_screen.dart';
import 'package:paperdrop/features/wizard/summary/summarise.dart';
import 'package:paperdrop/features/wizard/summary/summary_screen.dart';
import 'package:paperdrop/features/wizard/token/token_screen.dart';
import 'package:paperdrop/features/wizard/wizard_controller.dart';
import 'package:paperdrop/features/wizard/wizard_routes.dart';
import 'package:paperdrop/l10n/generated/app_localizations.dart';

import 'wizard_fakes.dart';

/// The wizard's ending, through its own route: the mapping step finishes, the destination is written
/// and the closing summary offers the first capture (design §3, §6; FR-WIZ-008).
///
/// **No network and no token:** the port is a fake and the token is a string the test invented. The
/// store is the in-memory one, because a widget test's clock cannot advance the file-backed store's
/// real I/O — the file itself, and that nothing of a credential reaches it, is proved in
/// `data/destination_store_test.dart`, a plain `test` over a directory the test owns.
void main() {
  /// Synthetic values, as everywhere in this suite.
  const String token = 'pasted-token-1';

  late AppLocalizations en;

  setUpAll(() async {
    en = await AppLocalizations.delegate.load(const Locale('en'));
  });

  /// A surface tall enough for the whole mapping form, so the tests do not have to scroll it.
  void sizeToTheForm(WidgetTester tester) {
    tester.view.physicalSize = const Size(1000, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  /// Pumps the wizard's own route over the fake port and the in-memory store.
  Future<void> pumpWizard(WidgetTester tester, GoRouter router) async {
    sizeToTheForm(tester);
    await tester.pumpWidget(
      MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('[setup-wizard/plain-language-summary-and-first-document-offer] '
      'the flow ends by offering a first document', (
    WidgetTester tester,
  ) async {
    final ({
      WizardController controller,
      FakeNinoxPort port,
      FakeTokenStore store,
    })
    wizard = wizardHarness(
      teams: <NinoxTeam>[
        NinoxTeam(id: 'team-1', name: 'Team one'),
        NinoxTeam(id: 'team-2', name: 'Team two'),
      ],
      databases: <NinoxDatabase>[
        NinoxDatabase(id: 'db-1', name: 'Database one'),
        NinoxDatabase(id: 'db-2', name: 'Database two'),
      ],
      tables: <NinoxTable>[
        NinoxTable(
          id: 'table-1',
          name: 'Invoices',
          fields: <NinoxField>[
            const NinoxField(id: 'field-1', name: 'Belegdatum', type: 'date'),
            const NinoxField(id: 'field-2', name: 'Betrag', type: 'number'),
          ],
        ),
        NinoxTable(id: 'table-2', name: 'Other', fields: <NinoxField>[]),
      ],
    );
    final FakeDestinationStore destinations = FakeDestinationStore();
    bool finished = false;

    await pumpWizard(
      tester,
      GoRouter(
        initialLocation: wizardRoute,
        routes: wizardRoutes(
          controllerFactory: () => wizard.controller,
          browser: FakeSystemBrowser(),
          destinationStore: destinations,
          onFinished: () => finished = true,
        ),
      ),
    );

    // The wizard, walked as the user walks it: the token, the team, the database, the table.
    expect(find.byType(TokenScreen), findsOneWidget);
    await tester.enterText(find.byKey(TokenScreen.tokenFieldKey), token);
    await tester.tap(find.text(en.wizardTokenConnectAction));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ChooseScreen.optionKey('team-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ChooseScreen.optionKey('db-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ChooseScreen.optionKey('table-1')));
    await tester.pumpAndSettle();

    // The mapping step, pre-filled from the table's fields.
    expect(find.byType(MappingScreen), findsOneWidget);
    await tester.ensureVisible(find.byKey(MappingScreen.continueKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(MappingScreen.continueKey));
    await tester.pumpAndSettle();

    // The closing summary, in the mapping step's place, saying what will be written.
    expect(find.byType(MappingScreen), findsNothing);
    expect(find.byType(SummaryScreen), findsOneWidget);
    expect(find.text(en.wizardSummaryHeadline), findsOneWidget);
    final SummaryText summary = summarise(wizard.controller.destination!, en);
    for (final String line in summary.lines) {
      expect(find.text(line), findsOneWidget, reason: line);
    }

    // The destination is the device's now: the three identifiers the user chose and the field the
    // matcher proposed, by identifier — and nothing of the token anywhere in its stored form.
    expect(destinations.saved, hasLength(1));
    final Destination written = destinations.saved.single;
    expect(written.teamId, 'team-2');
    expect(written.databaseId, 'db-1');
    expect(written.tableId, 'table-1');
    expect(written.mappings, hasLength(2));
    expect(
      <CoreField>[
        for (final FieldMapping mapping in written.mappings) mapping.coreField,
      ],
      <CoreField>[CoreField.docDate, CoreField.grossTotal],
    );
    expect(written.mappings.first.ninoxFieldId, 'field-1');
    expect(written.mappings.last.ninoxFieldId, 'field-2');
    expect(
      written.mappings.every(
        (FieldMapping mapping) => mapping.absent == AbsentSetting.empty,
      ),
      isTrue,
    );
    final String stored = jsonEncode(written.toJson());
    expect(stored, isNot(contains(token)));
    expect(stored.toLowerCase(), isNot(contains('token')));
    expect(wizard.store.writes, <String>[token]);

    // And the offer: capture a document of any kind, through the callback the router supplied.
    expect(find.byKey(SummaryScreen.captureKey), findsOneWidget);
    await tester.tap(find.byKey(SummaryScreen.captureKey));
    await tester.pumpAndSettle();
    expect(finished, isTrue);
  });

  testWidgets(
    'Back from the summary returns to the mapping with the choices intact',
    (WidgetTester tester) async {
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
              const NinoxField(id: 'field-2', name: 'Betrag', type: 'number'),
            ],
          ),
        ],
      );
      final FakeDestinationStore destinations = FakeDestinationStore();
      await pumpWizard(
        tester,
        GoRouter(
          initialLocation: wizardRoute,
          routes: wizardRoutes(
            controllerFactory: () => wizard.controller,
            browser: FakeSystemBrowser(),
            destinationStore: destinations,
            onFinished: () {},
          ),
        ),
      );

      await tester.enterText(find.byKey(TokenScreen.tokenFieldKey), token);
      await tester.tap(find.text(en.wizardTokenConnectAction));
      await tester.pumpAndSettle();
      expect(find.byType(MappingScreen), findsOneWidget);

      // Two changes the user makes: the document date is left unmapped, and the amount's absent
      // setting becomes `write zero` instead of the default.
      await tester.tap(find.byKey(MappingScreen.pickerKey(CoreField.docDate)));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(MappingScreen.unmappedEntryKey(CoreField.docDate)).last,
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(en.wizardMappingAbsentZero));
      await tester.pumpAndSettle();
      await tester.tap(find.text(en.wizardMappingAbsentZero));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(MappingScreen.continueKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(MappingScreen.continueKey));
      await tester.pumpAndSettle();
      expect(find.byType(SummaryScreen), findsOneWidget);

      // Back: the mapping step, with the date still unmapped and the amount still `write zero`.
      expect(find.byKey(SummaryScreen.backKey), findsOneWidget);
      await tester.tap(find.byKey(SummaryScreen.backKey));
      await tester.pumpAndSettle();

      expect(find.byType(MappingScreen), findsOneWidget);
      expect(find.byType(SummaryScreen), findsNothing);
      expect(
        tester
            .widget<DropdownButton<NinoxField?>>(
              find.byKey(MappingScreen.pickerKey(CoreField.docDate)),
            )
            .value,
        isNull,
        reason: 'a field the user left unmapped comes back unmapped',
      );
      expect(
        tester
            .widget<DropdownButton<NinoxField?>>(
              find.byKey(MappingScreen.pickerKey(CoreField.grossTotal)),
            )
            .value
            ?.name,
        'Betrag',
      );
      final SegmentedButton<AbsentSetting> absent = tester
          .widget<SegmentedButton<AbsentSetting>>(
            find.byKey(MappingScreen.absentKey(CoreField.grossTotal)),
          );
      expect(absent.selected, <AbsentSetting>{AbsentSetting.zero});

      // And finishing again keeps those two answers, in the mapping and in the summary.
      await tester.ensureVisible(find.byKey(MappingScreen.continueKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(MappingScreen.continueKey));
      await tester.pumpAndSettle();

      expect(find.byType(SummaryScreen), findsOneWidget);
      final List<FieldMapping> written = destinations.saved.last.mappings;
      expect(written, hasLength(1));
      expect(written.single.coreField, CoreField.grossTotal);
      expect(written.single.absent, AbsentSetting.zero);
    },
  );

  testWidgets('[setup-wizard/plain-language-summary-and-first-document-offer] '
      'the empty-record case is described', (WidgetTester tester) async {
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
    final FakeDestinationStore destinations = FakeDestinationStore();

    await pumpWizard(
      tester,
      GoRouter(
        initialLocation: wizardRoute,
        routes: wizardRoutes(
          controllerFactory: () => wizard.controller,
          browser: FakeSystemBrowser(),
          destinationStore: destinations,
          onFinished: () {},
        ),
      ),
    );

    // One team, one database and one table: the token step is followed by the mapping step alone
    // (FR-WIZ-002), and the one date proposal is ready.
    await tester.enterText(find.byKey(TokenScreen.tokenFieldKey), token);
    await tester.tap(find.text(en.wizardTokenConnectAction));
    await tester.pumpAndSettle();
    expect(find.byType(MappingScreen), findsOneWidget);
    expect(
      tester
          .widget<DropdownButton<NinoxField?>>(
            find.byKey(MappingScreen.pickerKey(CoreField.docDate)),
          )
          .value
          ?.name,
      'Belegdatum',
    );

    // The user takes the proposal away: nothing is mandatory.
    await tester.tap(find.byKey(MappingScreen.pickerKey(CoreField.docDate)));
    await tester.pumpAndSettle();
    await tester.tap(find.text(en.wizardMappingUnmapped).last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(MappingScreen.continueKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(MappingScreen.continueKey));
    await tester.pumpAndSettle();

    // The empty-record case, in the requirement's own words, and a destination with no mapping.
    expect(find.text(en.wizardSummaryNothingMapped), findsOneWidget);
    expect(wizard.controller.mappings, isEmpty);
    expect(destinations.saved.single.mappings, isEmpty);
    expect(wizard.controller.destination!.mappings, isEmpty);
  });
}
