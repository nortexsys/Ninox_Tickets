import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ninox_client/ninox_client.dart';
import 'package:paperdrop/features/wizard/destination.dart';
import 'package:paperdrop/features/wizard/mapping/mapping_screen.dart';
import 'package:paperdrop/features/wizard/matching/field_matcher.dart';
import 'package:paperdrop/features/wizard/wizard_controller.dart';
import 'package:paperdrop/l10n/generated/app_localizations.dart';

import '../wizard_fakes.dart';

/// The mapping step, on the fake port: **no test here makes a network call and none needs a token**,
/// and the step itself makes no call at all — the table the screen is drawn from is the one the table
/// step already chose, fields and all (FR-WIZ-004).
///
/// What the screen owes, and what these tests pin: a field opens **pre-filled** where the matcher
/// proposed one and **visibly unmapped** where it did not; the picker offers only columns of the
/// right kind; a mapped field carries its absent setting, empty by default; and the step finishes
/// with all, one or none of them mapped.
void main() {
  /// Synthetic values, as everywhere in this suite.
  const String host = 'api.ninox.com';
  const String token = 'pasted-token-1';

  late AppLocalizations en;

  setUpAll(() async {
    en = await AppLocalizations.delegate.load(const Locale('en'));
  });

  NinoxTable table(List<NinoxField> fields) =>
      NinoxTable(id: 'table-1', name: 'Invoices', fields: fields);

  NinoxField field(String id, String name, String type) =>
      NinoxField(id: id, name: name, type: type);

  /// A controller standing on the mapping step, over [fields] — the fields the port returned with
  /// the table.
  Future<WizardController> atMappingStep(List<NinoxField> fields) async {
    final ({
      WizardController controller,
      FakeNinoxPort port,
      FakeTokenStore store,
    })
    wizard = wizardHarness(
      teams: <NinoxTeam>[NinoxTeam(id: 'team-1', name: 'Team')],
      databases: <NinoxDatabase>[NinoxDatabase(id: 'db-1', name: 'Database')],
      tables: <NinoxTable>[table(fields)],
    );
    await wizard.controller.connect(host: host, token: token);
    await wizard.controller.chooseTable('table-1');
    expect(wizard.controller.step.name, 'mapping');
    return wizard.controller;
  }

  /// Pumps the step on a surface tall enough to hold the whole form: eight rows and the action that
  /// finishes them. A real phone scrolls it, and the widget's own scroll view is untouched — the
  /// tests simply do not have to scroll to reach what they are about.
  Future<void> pumpMapping(
    WidgetTester tester,
    WizardController controller, {
    Future<void> Function(List<FieldMapping>)? onCompleted,
  }) async {
    tester.view.physicalSize = const Size(1000, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MappingScreen(controller: controller, onCompleted: onCompleted),
      ),
    );
  }

  /// The picker of one core field.
  DropdownButton<NinoxField?> picker(
    WidgetTester tester,
    CoreField coreField,
  ) => tester.widget<DropdownButton<NinoxField?>>(
    find.byKey(MappingScreen.pickerKey(coreField)),
  );

  /// What a picker offers, by the column each entry stands for: `null` is the entry that leaves the
  /// field unmapped.
  List<String?> offered(DropdownButton<NinoxField?> button) => <String?>[
    for (final DropdownMenuItem<NinoxField?> item in button.items!)
      item.value?.name,
  ];

  /// Chooses one entry of a field's picker: the column itself, or `null` for the unmapped entry.
  ///
  /// The form is longer than the test surface, so the picker is scrolled into view first: a control
  /// a user cannot see is a control a user cannot tap either. The entry is addressed by key and not
  /// by its words, because the same words can also be on another field's picker — and, once a column
  /// is marked as used elsewhere, on more than one entry of this one. The **last** match is the open
  /// menu's, which is the one a user taps.
  Future<void> choose(
    WidgetTester tester,
    CoreField coreField,
    NinoxField? candidate,
  ) async {
    final Finder picker = find.byKey(MappingScreen.pickerKey(coreField));
    await tester.ensureVisible(picker);
    await tester.pumpAndSettle();
    await tester.tap(picker);
    await tester.pumpAndSettle();
    await tester.tap(
      find
          .byKey(
            candidate == null
                ? MappingScreen.unmappedEntryKey(coreField)
                : MappingScreen.candidateKey(coreField, candidate.id),
          )
          .last,
    );
    await tester.pumpAndSettle();
  }

  /// Finishes the step, scrolling the action into view first.
  Future<void> tapContinue(WidgetTester tester) async {
    final Finder action = find.byKey(MappingScreen.continueKey);
    await tester.ensureVisible(action);
    await tester.pumpAndSettle();
    await tester.tap(action);
    await tester.pumpAndSettle();
  }

  testWidgets(
    '[setup-wizard/pre-filled-proposals] a proposal is ready to correct',
    (WidgetTester tester) async {
      final WizardController controller = await atMappingStep(<NinoxField>[
        field('1', 'Belegdatum', 'date'),
        field('2', 'Lieferant', 'string'),
        field('3', 'Betrag', 'number'),
      ]);
      await pumpMapping(tester, controller);

      // The three columns the matcher recognises are already chosen: the user corrects rather than
      // constructs.
      expect(picker(tester, CoreField.docDate).value?.name, 'Belegdatum');
      expect(picker(tester, CoreField.supplierName).value?.name, 'Lieferant');
      expect(picker(tester, CoreField.grossTotal).value?.name, 'Betrag');

      // And it is a picker with entries, not an empty selector.
      expect(offered(picker(tester, CoreField.docDate)), <String?>[
        null,
        'Belegdatum',
      ]);

      // Every core field of the design is on the screen, named in plain language.
      for (final String label in <String>[
        en.wizardFieldDocDate,
        en.wizardFieldSupplierName,
        en.wizardFieldSupplierTaxId,
        en.wizardFieldDocNumber,
        en.wizardFieldGrossTotal,
        en.wizardFieldNetTotal,
        en.wizardFieldTaxTotal,
        en.wizardFieldCurrency,
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
    },
  );

  testWidgets(
    '[setup-wizard/pre-filled-proposals] nothing plausible is shown as unmapped',
    (WidgetTester tester) async {
      // A date column that is a genuine near miss, and nothing else that could be the document date.
      final WizardController controller = await atMappingStep(<NinoxField>[
        field('1', 'Fälligkeitsdatum', 'date'),
        field('2', 'Lieferant', 'string'),
      ]);
      await pumpMapping(tester, controller);

      // Unmapped, and visibly so: the words are on the screen, and the picker still offers the one
      // column of the right kind and the way back to unmapped.
      expect(picker(tester, CoreField.docDate).value, isNull);
      expect(find.text(en.wizardMappingUnmapped), findsWidgets);
      expect(offered(picker(tester, CoreField.docDate)), <String?>[
        null,
        'Fälligkeitsdatum',
      ]);
      // The supplier is proposed, so the two states are on the screen together and are told apart.
      expect(picker(tester, CoreField.supplierName).value?.name, 'Lieferant');
    },
  );

  testWidgets('the picker offers only the candidates of the right kind', (
    WidgetTester tester,
  ) async {
    // `FACTURA N.º` is the closest name of the two to the document number and it is a number
    // column: it is not offered to a text field at all, and the text column is.
    final WizardController controller = await atMappingStep(<NinoxField>[
      field('1', 'FACTURA N.º', 'number'),
      field('2', 'Factura', 'string'),
      field('3', 'Betrag', 'number'),
    ]);
    await pumpMapping(tester, controller);

    expect(offered(picker(tester, CoreField.docNumber)), <String?>[
      null,
      'Factura',
    ]);
    // The number column is offered where a number belongs, and only there.
    expect(offered(picker(tester, CoreField.grossTotal)), <String?>[
      null,
      'FACTURA N.º',
      'Betrag',
    ]);
  });

  testWidgets('a choice can be corrected, and the picked column is the one '
      'stored', (WidgetTester tester) async {
    final WizardController controller = await atMappingStep(<NinoxField>[
      field('1', 'Belegdatum', 'date'),
      field('2', 'Buchungsdatum', 'date'),
      field('3', 'Lieferant', 'string'),
    ]);
    List<FieldMapping>? handed;
    await pumpMapping(
      tester,
      controller,
      onCompleted: (List<FieldMapping> mappings) async => handed = mappings,
    );

    // Two date columns and one of them proposed: the user corrects it to the other.
    expect(picker(tester, CoreField.docDate).value?.name, 'Belegdatum');
    await choose(
      tester,
      CoreField.docDate,
      field('2', 'Buchungsdatum', 'date'),
    );
    expect(picker(tester, CoreField.docDate).value?.name, 'Buchungsdatum');

    await tapContinue(tester);

    final FieldMapping docDate = handed!.firstWhere(
      (FieldMapping mapping) => mapping.coreField == CoreField.docDate,
    );
    // The identifier is what is stored, and the name beside it is for display (FR-DST-003).
    expect(docDate.ninoxFieldId, '2');
    expect(docDate.ninoxFieldName, 'Buchungsdatum');
  });

  testWidgets(
    '[destinations-mapping/per-field-absent-setting] the default is empty',
    (WidgetTester tester) async {
      final WizardController controller = await atMappingStep(<NinoxField>[
        field('1', 'Belegdatum', 'date'),
        field('2', 'Lieferant', 'string'),
      ]);
      List<FieldMapping>? handed;
      await pumpMapping(
        tester,
        controller,
        onCompleted: (List<FieldMapping> mappings) async => handed = mappings,
      );

      // A mapped field shows the setting, and it opens on "leave it empty".
      expect(
        find.byKey(MappingScreen.absentKey(CoreField.docDate)),
        findsOneWidget,
      );
      expect(find.text(en.wizardMappingAbsentEmpty), findsWidgets);
      expect(find.text(en.wizardMappingAbsentZero), findsWidgets);

      await tapContinue(tester);

      // Every mapping carries the setting, and without the user touching it that setting is empty.
      for (final FieldMapping mapping in handed!) {
        expect(mapping.absent, AbsentSetting.empty);
      }

      // An unmapped field has no setting to make: nothing is written for it.
      expect(
        find.byKey(MappingScreen.absentKey(CoreField.grossTotal)),
        findsNothing,
      );
    },
  );

  testWidgets('the other absent setting is stored when the user chooses it', (
    WidgetTester tester,
  ) async {
    final WizardController controller = await atMappingStep(<NinoxField>[
      field('1', 'Betrag', 'number'),
    ]);
    List<FieldMapping>? handed;
    await pumpMapping(
      tester,
      controller,
      onCompleted: (List<FieldMapping> mappings) async => handed = mappings,
    );

    await tester.ensureVisible(find.text(en.wizardMappingAbsentZero));
    await tester.pumpAndSettle();
    await tester.tap(find.text(en.wizardMappingAbsentZero));
    await tester.pumpAndSettle();
    await tapContinue(tester);

    expect(handed!.single.absent, AbsentSetting.zero);
    expect(handed!.single.coreField, CoreField.grossTotal);
  });

  testWidgets(
    '[setup-wizard/no-mapping-is-mandatory] finishing with nothing mapped is possible',
    (WidgetTester tester) async {
      // A table whose columns are all of a kind no core field binds: nothing is proposed, and the
      // step still finishes.
      final WizardController controller = await atMappingStep(<NinoxField>[
        field('1', 'Geburtsdatum', 'choice'),
        field('2', 'Belegdatum Kopie', 'boolean'),
      ]);
      List<FieldMapping>? handed;
      await pumpMapping(
        tester,
        controller,
        onCompleted: (List<FieldMapping> mappings) async => handed = mappings,
      );

      expect(find.text(en.wizardMappingUnmapped), findsWidgets);
      await tester.tap(find.byKey(MappingScreen.continueKey));
      await tester.pumpAndSettle();

      expect(handed, isEmpty);
      expect(controller.mappings, isEmpty);
    },
  );

  testWidgets('the mapping the user kept is the one the host stores', (
    WidgetTester tester,
  ) async {
    final WizardController controller = await atMappingStep(<NinoxField>[
      field('1', 'Belegdatum', 'date'),
      field('2', 'Lieferant', 'string'),
      field('3', 'Betrag', 'number'),
    ]);
    // The host is what stores a mapping — the screen hands its answer on and knows nothing about the
    // state — so the test stands in for the flow of `wizard_routes.dart` here.
    await pumpMapping(
      tester,
      controller,
      onCompleted: (List<FieldMapping> mappings) async =>
          controller.mapFields(mappings),
    );

    // One field corrected away from what the matcher proposed, one kept, one left alone.
    await choose(tester, CoreField.supplierName, null);
    await tapContinue(tester);

    expect(
      controller.mappings.map((FieldMapping mapping) => mapping.coreField),
      <CoreField>[CoreField.docDate, CoreField.grossTotal],
    );
    // The two the user kept still carry their proposal and the default absent setting.
    expect(
      controller.mappings.map((FieldMapping mapping) => mapping.ninoxFieldName),
      <String>['Belegdatum', 'Betrag'],
    );
    expect(
      controller.mappings.every(
        (FieldMapping mapping) => mapping.absent == AbsentSetting.empty,
      ),
      isTrue,
    );
  });

  testWidgets('a column another field already uses is marked and stays '
      'selectable', (WidgetTester tester) async {
    // Two number columns and two number fields: the matcher proposes one to each, and the user may
    // still map both fields to the same column — the one-to-one rule is the matcher's, for its
    // proposals. The picker says whose the column is instead of hiding it (design §10.2).
    final WizardController controller = await atMappingStep(<NinoxField>[
      field('1', 'Total', 'number'),
      field('2', 'Subtotal', 'number'),
    ]);
    List<FieldMapping>? handed;
    await pumpMapping(
      tester,
      controller,
      onCompleted: (List<FieldMapping> mappings) async => handed = mappings,
    );

    expect(picker(tester, CoreField.grossTotal).value?.name, 'Total');
    expect(picker(tester, CoreField.netTotal).value?.name, 'Subtotal');
    // Before the user does anything, nothing is used twice and nothing is marked.
    expect(offered(picker(tester, CoreField.grossTotal)), <String?>[
      null,
      'Total',
      'Subtotal',
    ]);
    expect(
      find.text(en.wizardMappingAlsoUsed('Subtotal', en.wizardFieldNetTotal)),
      findsNothing,
    );

    // The gross total is corrected onto the column the net total already uses.
    await choose(
      tester,
      CoreField.grossTotal,
      field('2', 'Subtotal', 'number'),
    );
    expect(picker(tester, CoreField.grossTotal).value?.name, 'Subtotal');

    // The column carries the name of the field using it — and it is still there to be chosen.
    final DropdownButton<NinoxField?> pickerNow = picker(
      tester,
      CoreField.grossTotal,
    );
    expect(offered(pickerNow), <String?>[null, 'Total', 'Subtotal']);
    expect(
      find.text(en.wizardMappingAlsoUsed('Subtotal', en.wizardFieldNetTotal)),
      findsOneWidget,
    );
    expect(
      pickerNow.items!
          .lastWhere((DropdownMenuItem<NinoxField?> item) => item.value != null)
          .enabled,
      isTrue,
    );
    // The other field keeps its own column: a column may serve two fields.
    expect(picker(tester, CoreField.netTotal).value?.name, 'Subtotal');

    // The step completes with both, each carrying the identifier it was mapped to.
    await tapContinue(tester);
    expect(handed, hasLength(2));
    expect(
      handed!
          .firstWhere(
            (FieldMapping mapping) => mapping.coreField == CoreField.grossTotal,
          )
          .ninoxFieldId,
      '2',
    );
  });

  testWidgets('a column used twice leaves the matcher\'s proposals unchanged', (
    WidgetTester tester,
  ) async {
    // The marking is what the screen draws; what the matcher proposes is its own answer over the
    // table and does not move because the user mapped two fields to one column.
    final NinoxTable fixture = table(<NinoxField>[
      field('1', 'Total', 'number'),
      field('2', 'Subtotal', 'number'),
    ]);
    final List<FieldProposal> before = proposeMappings(fixture);

    final WizardController controller = await atMappingStep(fixture.fields);
    await pumpMapping(tester, controller);
    await choose(
      tester,
      CoreField.grossTotal,
      field('2', 'Subtotal', 'number'),
    );
    await tapContinue(tester);

    expect(proposeMappings(fixture), before);
    expect(
      before
          .firstWhere(
            (FieldProposal proposal) =>
                proposal.coreField == CoreField.grossTotal,
          )
          .ninoxField
          ?.name,
      'Total',
    );
    expect(
      before
          .firstWhere(
            (FieldProposal proposal) =>
                proposal.coreField == CoreField.netTotal,
          )
          .ninoxField
          ?.name,
      'Subtotal',
    );
  });

  testWidgets('the step makes no call of its own', (WidgetTester tester) async {
    // The table the screen is drawn from is the one the port already returned, fields included.
    final ({
      WizardController controller,
      FakeNinoxPort port,
      FakeTokenStore store,
    })
    wizard = wizardHarness(
      teams: <NinoxTeam>[NinoxTeam(id: 'team-1', name: 'Team')],
      databases: <NinoxDatabase>[NinoxDatabase(id: 'db-1', name: 'Database')],
      tables: <NinoxTable>[
        table(<NinoxField>[field('1', 'Belegdatum', 'date')]),
      ],
    );
    await wizard.controller.connect(host: host, token: token);
    await wizard.controller.chooseTable('table-1');
    final List<String> before = List<String>.of(wizard.port.calls);

    await pumpMapping(tester, wizard.controller);
    await tapContinue(tester);

    expect(wizard.port.calls, before);
    expect(before, <String>['listTeams', 'listDatabases', 'listTables']);
  });
}
