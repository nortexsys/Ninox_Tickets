import 'package:flutter_test/flutter_test.dart';
import 'package:ninox_client/ninox_client.dart';
import 'package:paperdrop/features/wizard/destination.dart';
import 'package:paperdrop/features/wizard/token/token_errors.dart';
import 'package:paperdrop/features/wizard/wizard_step.dart';

import 'wizard_fakes.dart';

/// The state machine of design §3, on the fake port and the fake store of `wizard_fakes.dart`: no
/// test here makes a network call and none needs a token.
///
/// The two scenarios of `steps-auto-omit-when-there-is-nothing-to-choose` and the one of
/// `five-screens-at-most` are covered by name. The cases the design leaves to the lane — a list with
/// no option at all, "back" over omitted steps, and an initial destination — are covered beside them
/// and reported.
void main() {
  /// The host and the token a test pastes. Both are synthetic: the test base's identifiers appear
  /// in no fixture, and the token a test uses is one it invented for itself.
  const String host = 'api.ninox.com';
  const String token = 'pasted-token-1';

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

  /// A controller over the fakes, with the lists a test chose; the construction itself is shared
  /// with the token step's tests (`wizard_fakes.dart`), so the two files cannot drift apart.
  test('[setup-wizard/steps-auto-omit-when-there-is-nothing-to-choose] '
      'a single-option subscription sees two screens', () async {
    final wizard = wizardHarness(
      teams: <NinoxTeam>[team('team-1')],
      databases: <NinoxDatabase>[database('db-1')],
      tables: <NinoxTable>[table('table-1')],
    );

    await wizard.controller.connect(host: host, token: token);

    expect(wizard.controller.visibleSteps, <WizardStep>[
      WizardStep.token,
      WizardStep.mapping,
    ]);
    expect(wizard.controller.step, WizardStep.mapping);
    // The one option of each list is the choice, and it was made without a screen.
    expect(wizard.controller.state.teamId, 'team-1');
    expect(wizard.controller.state.databaseId, 'db-1');
    expect(wizard.controller.state.tableId, 'table-1');
    // One call per list, in the sequence's order, and none of them twice.
    expect(wizard.port.calls, <String>[
      'listTeams',
      'listDatabases',
      'listTables',
    ]);
    expect(wizard.store.writes, <String>[token]);
  });

  test('[setup-wizard/steps-auto-omit-when-there-is-nothing-to-choose] '
      'omission rather than a hidden step', () async {
    final wizard = wizardHarness(
      teams: <NinoxTeam>[team('team-1')],
      databases: <NinoxDatabase>[database('db-1')],
      tables: <NinoxTable>[table('table-1')],
    );

    await wizard.controller.connect(host: host, token: token);

    // The step does not appear at all: it is absent from the sequence...
    expect(wizard.controller.visibleSteps, isNot(contains(WizardStep.team)));
    expect(
      wizard.controller.visibleSteps,
      isNot(contains(WizardStep.database)),
    );
    expect(wizard.controller.visibleSteps, isNot(contains(WizardStep.table)));
    // ...and the user was never asked to confirm the single choice: the wizard went from the
    // token step straight to the mapping step and rested on nothing in between.
    expect(wizard.controller.step, WizardStep.mapping);
    // "Back" reads the same list, so it does not visit an omitted step either.
    wizard.controller.back();
    expect(wizard.controller.step, WizardStep.token);
  });

  test('[setup-wizard/five-screens-at-most] no sixth screen exists', () async {
    final wizard = wizardHarness(
      teams: <NinoxTeam>[team('team-1'), team('team-2')],
      databases: <NinoxDatabase>[database('db-1'), database('db-2')],
      tables: <NinoxTable>[table('table-1'), table('table-2')],
    );

    // Five values, and the sequence is their order.
    expect(WizardStep.values, hasLength(5));

    // Every step the flow rests on, the first run's first step included.
    final List<WizardStep> visited = <WizardStep>[wizard.controller.step];
    await wizard.controller.connect(host: host, token: token);
    for (int i = 0; i < 8; i++) {
      visited.add(wizard.controller.step);
      // Whatever state the wizard is in, it presents at most the five named steps and no sixth.
      expect(wizard.controller.visibleSteps.length, lessThanOrEqualTo(5));
      expect(
        wizard.controller.visibleSteps,
        everyElement(isIn(WizardStep.values)),
      );
      switch (wizard.controller.step) {
        case WizardStep.token:
          await wizard.controller.connect(host: host, token: token);
        case WizardStep.team:
          await wizard.controller.chooseTeam('team-1');
        case WizardStep.database:
          await wizard.controller.chooseDatabase('db-1');
        case WizardStep.table:
          await wizard.controller.chooseTable('table-1');
        case WizardStep.mapping:
          break;
      }
      if (wizard.controller.step == WizardStep.mapping) {
        visited.add(wizard.controller.step);
        break;
      }
    }

    expect(visited, <WizardStep>[
      WizardStep.token,
      WizardStep.team,
      WizardStep.database,
      WizardStep.table,
      WizardStep.mapping,
    ]);
  });

  test(
    'several options show every step, and each choice is the user\'s',
    () async {
      final wizard = wizardHarness(
        teams: <NinoxTeam>[team('team-1'), team('team-2')],
        databases: <NinoxDatabase>[database('db-1'), database('db-2')],
        tables: <NinoxTable>[table('table-1'), table('table-2')],
      );

      await wizard.controller.connect(host: host, token: token);

      // Nothing is chosen for the user, and the list is the token call's own result.
      expect(wizard.controller.step, WizardStep.team);
      expect(wizard.controller.visibleSteps, WizardStep.values);
      expect(wizard.controller.state.teamId, isNull);
      expect(wizard.controller.state.teams, <NinoxTeam>[
        team('team-1'),
        team('team-2'),
      ]);
      expect(wizard.port.calls, <String>['listTeams']);

      await wizard.controller.chooseTeam('team-1');
      expect(wizard.controller.step, WizardStep.database);
      expect(wizard.controller.state.databaseId, isNull);
      expect(wizard.port.calls, <String>['listTeams', 'listDatabases']);

      await wizard.controller.chooseDatabase('db-2');
      expect(wizard.controller.step, WizardStep.table);
      expect(wizard.controller.state.tableId, isNull);
      // The tables arrive with their fields, so the mapping step adds no call (FR-WIZ-004) — and no
      // list was fetched twice.
      expect(wizard.port.calls, <String>[
        'listTeams',
        'listDatabases',
        'listTables',
      ]);

      await wizard.controller.chooseTable('table-2');
      expect(wizard.controller.step, WizardStep.mapping);
      expect(wizard.controller.state.tableId, 'table-2');
      expect(wizard.port.calls, <String>[
        'listTeams',
        'listDatabases',
        'listTables',
      ]);
    },
  );

  test('a list with no option stays on its step with its message', () async {
    // The design's case: a zero-option list is not specified by the functional, so the step stays
    // where it is with a plain-language explanation and no way to continue is invented.
    final noTeams = wizardHarness(teams: const <NinoxTeam>[]);
    await noTeams.controller.connect(host: host, token: token);

    expect(noTeams.controller.step, WizardStep.team);
    expect(noTeams.controller.state.notice, WizardNotice.noTeams);
    expect(noTeams.controller.state.teamId, isNull);
    // No way on: no call was made for a team that does not exist.
    expect(noTeams.port.calls, <String>['listTeams']);

    final noDatabases = wizardHarness(
      teams: <NinoxTeam>[team('team-1'), team('team-2')],
      databases: const <NinoxDatabase>[],
    );
    await noDatabases.controller.connect(host: host, token: token);
    await noDatabases.controller.chooseTeam('team-1');

    expect(noDatabases.controller.step, WizardStep.database);
    expect(noDatabases.controller.state.notice, WizardNotice.noDatabases);
    expect(noDatabases.controller.state.databaseId, isNull);
    expect(noDatabases.port.calls, <String>['listTeams', 'listDatabases']);

    final noTables = wizardHarness(
      teams: <NinoxTeam>[team('team-1'), team('team-2')],
      databases: <NinoxDatabase>[database('db-1'), database('db-2')],
      tables: const <NinoxTable>[],
    );
    await noTables.controller.connect(host: host, token: token);
    await noTables.controller.chooseTeam('team-1');
    await noTables.controller.chooseDatabase('db-1');

    expect(noTables.controller.step, WizardStep.table);
    expect(noTables.controller.state.notice, WizardNotice.noTables);
    expect(noTables.controller.state.tableId, isNull);
  });

  test('back skips the omitted steps, and only them', () async {
    final one = wizardHarness(
      teams: <NinoxTeam>[team('team-1')],
      databases: <NinoxDatabase>[database('db-1')],
      tables: <NinoxTable>[table('table-1')],
    );
    await one.controller.connect(host: host, token: token);
    expect(one.controller.step, WizardStep.mapping);
    expect(one.controller.canGoBack, isTrue);
    one.controller.back();
    expect(one.controller.step, WizardStep.token);
    expect(one.controller.canGoBack, isFalse);

    final many = wizardHarness(
      teams: <NinoxTeam>[team('team-1'), team('team-2')],
      databases: <NinoxDatabase>[database('db-1'), database('db-2')],
      tables: <NinoxTable>[table('table-1'), table('table-2')],
    );
    await many.controller.connect(host: host, token: token);
    await many.controller.chooseTeam('team-1');
    await many.controller.chooseDatabase('db-1');
    await many.controller.chooseTable('table-1');
    expect(many.controller.step, WizardStep.mapping);

    final List<WizardStep> backwards = <WizardStep>[];
    while (many.controller.canGoBack) {
      many.controller.back();
      backwards.add(many.controller.step);
    }
    expect(backwards, <WizardStep>[
      WizardStep.table,
      WizardStep.database,
      WizardStep.team,
      WizardStep.token,
    ]);
  });

  test('a controller built with an initial destination reopens at the step the '
      'sequence starts at, its choices seeded', () async {
    const FieldMapping mapping = FieldMapping(
      coreField: CoreField.grossTotal,
      ninoxFieldId: 'field-1',
      ninoxFieldName: 'Betrag',
    );
    final Destination destination = Destination(
      endpoint: NinoxEndpoint.cloud,
      teamId: 'team-2',
      databaseId: 'db-2',
      tableId: 'table-2',
      mappings: const <FieldMapping>[mapping],
    );
    final wizard = wizardHarness(
      teams: <NinoxTeam>[team('team-1'), team('team-2')],
      databases: <NinoxDatabase>[database('db-1'), database('db-2')],
      tables: <NinoxTable>[table('table-1'), table('table-2')],
      initial: destination,
    );

    // The sequence is the same one and nothing is wired to first-run state: it starts where it
    // starts, carrying the destination's host, its three identifiers and its mapping.
    expect(wizard.controller.step, WizardStep.token);
    expect(wizard.controller.state.endpoint, destination.endpoint);
    expect(wizard.controller.state.teamId, 'team-2');
    expect(wizard.controller.state.databaseId, 'db-2');
    expect(wizard.controller.state.tableId, 'table-2');
    expect(wizard.controller.state.mappings, destination.mappings);
    // Nothing is called before a token is offered, and the token is not in the destination.
    expect(wizard.port.calls, isEmpty);

    await wizard.controller.connect(host: host, token: token);

    // The destination's own team is the choice, and it is not dropped: the list holds it.
    expect(wizard.controller.step, WizardStep.team);
    expect(wizard.controller.state.teamId, 'team-2');
    expect(wizard.port.calls, <String>['listTeams']);
  });

  test(
    'the port is built from the parsed endpoint, never from what was typed',
    () async {
      final wizard = wizardHarness(teams: <NinoxTeam>[team('team-1')]);

      await wizard.controller.connect(host: 'NINOX.Example.DE', token: token);

      expect(
        wizard.port.builtWithEndpoint,
        NinoxEndpoint.parse('ninox.example.de'),
      );
      expect(
        wizard.controller.state.endpoint,
        NinoxEndpoint.parse('ninox.example.de'),
      );
    },
  );

  test(
    'a host that is not an accepted form is reported and no call is made',
    () async {
      final wizard = wizardHarness(teams: <NinoxTeam>[team('team-1')]);
      final NinoxEndpoint before = wizard.controller.state.endpoint;

      // A plain-text scheme would put the token on the wire in clear (NinoxEndpoint.parse).
      await wizard.controller.connect(
        host: 'http://api.ninox.com',
        token: token,
      );

      expect(wizard.controller.state.error, TokenStepError.hostNotValid);
      expect(wizard.controller.state.endpoint, before);
      expect(wizard.controller.step, WizardStep.token);
      expect(wizard.port.calls, isEmpty);
      expect(wizard.store.writes, isEmpty);
    },
  );
}
