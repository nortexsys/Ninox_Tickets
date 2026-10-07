/// The wizard's five steps and the state the steps run on (design §3).
///
/// Requirement served: FR-WIZ-001 (`setup-wizard/five-screens-at-most`) and FR-WIZ-002
/// (`setup-wizard/steps-auto-omit-when-there-is-nothing-to-choose`).
///
/// **Five steps, and no sixth.** The closing summary is the mapping step's completion and not a
/// step of its own, so [WizardStep] carries exactly the five values the requirement names.
///
/// **Which steps are shown is computed, never stored.** [WizardState.visibleSteps] is a function of
/// the lists the port returned, so a step whose list holds exactly one option is *omitted* rather
/// than pre-confirmed, and a step whose list is empty keeps its place with a plain-language
/// explanation (design §3).
library;

import 'package:ninox_client/ninox_client.dart';

import 'destination.dart';
import 'token/token_errors.dart';

/// The wizard's steps, in the order of the sequence (FR-WIZ-001).
///
/// `token` → `team` → `database` → `table` → `mapping`. The order of the values **is** the order of
/// the sequence: nothing walks a list of steps of its own, and a step whose list holds one option
/// is absent from [WizardState.visibleSteps] rather than hidden.
enum WizardStep {
  /// The token step (FR-WIZ-003): the host, the token, and the call that validates both.
  token,

  /// The team step (FR-WIZ-002).
  team,

  /// The database step (FR-WIZ-002).
  database,

  /// The table step (FR-WIZ-002); its listing carries the fields the mapping step needs.
  table,

  /// The mapping step (FR-WIZ-004…FR-WIZ-007), whose completion is the closing summary.
  mapping,
}

/// What a step whose list came back empty tells the user (design §3).
///
/// The functional does not specify a zero-option list. The design decides the step stays where it
/// is with a plain-language explanation and that the wizard invents **no** way to continue — there
/// is no "skip" and no empty dropdown to confirm. Which of the three applies is derived from the
/// step and the list, never stored.
enum WizardNotice {
  /// The team step: the account can see no team at all.
  noTeams,

  /// The database step: the chosen team holds no database.
  noDatabases,

  /// The table step: the chosen database holds no table.
  noTables,
}

/// The "leave this field alone" marker of [WizardState.copyWith].
///
/// `null` is a value the three identifier fields and [WizardState.error] legitimately take — a team
/// is dropped when another one replaces it, an error is cleared when a new attempt starts — so the
/// default of a parameter that may be *set* to `null` cannot itself be `null`.
const Object _keep = Object();

/// The wizard's state (design §3): the host, the three lists, the three chosen identifiers and the
/// mapping. Immutable, and compared by value.
///
/// **It never holds a token.** Design §3 lists "the validated credentials" among the state's fields
/// and design §1 forbids the token in "widget state that outlives the step". The stricter rule
/// wins: the credential lives in the port the controller built, and `NinoxCredentials.toString`
/// prints `***`. A test stringifies the state, the controller and every message the token step can
/// show and searches all of them for the token.
final class WizardState {
  /// Builds a state. The defaults are the first run's: the token step, the vendor's cloud host, no
  /// lists, no choice and no mapping.
  const WizardState({
    this.step = WizardStep.token,
    this.endpoint = NinoxEndpoint.cloud,
    this.teams = const <NinoxTeam>[],
    this.databases = const <NinoxDatabase>[],
    this.tables = const <NinoxTable>[],
    this.teamId,
    this.databaseId,
    this.tableId,
    this.mappings = const <FieldMapping>[],
    this.error,
    this.busy = false,
  });

  /// The state a configured destination seeds (design §3).
  ///
  /// The wizard is **not** wired to first-run state: a destination being edited contributes its
  /// host, its three identifiers and its mapping, and the sequence then runs as it always does —
  /// nothing is asked twice and no choice is assumed to be the first one.
  factory WizardState.fromDestination(Destination destination) => WizardState(
    endpoint: destination.endpoint,
    teamId: destination.teamId,
    databaseId: destination.databaseId,
    tableId: destination.tableId,
    mappings: destination.mappings,
  );

  /// The step the user is on.
  final WizardStep step;

  /// The Ninox host that travels with this destination (FR-DST-008); the vendor's cloud until the
  /// advanced setup says otherwise. Public configuration, never a secret.
  final NinoxEndpoint endpoint;

  /// The teams the token can see, as `listTeams` returned them. Empty until that call answers.
  final List<NinoxTeam> teams;

  /// The databases of the chosen team. Cleared when another team is chosen.
  final List<NinoxDatabase> databases;

  /// The tables of the chosen database, **with their fields**, so the mapping step needs no second
  /// call (FR-WIZ-004). Cleared when another database is chosen.
  final List<NinoxTable> tables;

  /// The chosen team, or `null` while the team step is unanswered.
  final String? teamId;

  /// The chosen database, or `null` while the database step is unanswered.
  final String? databaseId;

  /// The chosen table, or `null` while the table step is unanswered.
  final String? tableId;

  /// The destination's field mappings. Empty is a legitimate, complete answer: no mapping is
  /// mandatory (FR-WIZ-007).
  final List<FieldMapping> mappings;

  /// Why the token step did not pass, or `null`. Cleared when a new attempt starts and when the
  /// step is left; the message it becomes is the step's, and it never contains the token.
  final TokenStepError? error;

  /// Whether one of the wizard's calls is in flight, so a screen can hold its action.
  final bool busy;

  /// Which steps the wizard shows, computed and never stored (design §3): `token` and `mapping`
  /// always, and each of `team`, `database` and `table` only when its list does **not** hold
  /// exactly one option.
  ///
  /// A one-option list therefore produces no step at all — not a pre-confirmed one — and a
  /// zero-option list keeps its step, where [notice] explains it. Never more than the five values
  /// of [WizardStep], and always in the sequence's order.
  List<WizardStep> get visibleSteps => <WizardStep>[
    WizardStep.token,
    if (teams.length != 1) WizardStep.team,
    if (databases.length != 1) WizardStep.database,
    if (tables.length != 1) WizardStep.table,
    WizardStep.mapping,
  ];

  /// The explanation the current step shows when its list came back empty, or `null` (design §3).
  ///
  /// Derived from the step and the list, so it cannot go stale: nothing is said on the token step,
  /// whose list the call has not read yet, nor on the mapping step.
  WizardNotice? get notice => switch (step) {
    WizardStep.token => null,
    WizardStep.team => teams.isEmpty ? WizardNotice.noTeams : null,
    WizardStep.database => databases.isEmpty ? WizardNotice.noDatabases : null,
    WizardStep.table => tables.isEmpty ? WizardNotice.noTables : null,
    WizardStep.mapping => null,
  };

  /// The same state with the given fields replaced.
  ///
  /// A field whose parameter is omitted keeps its value; `null` passed for [teamId], [databaseId],
  /// [tableId] or [error] clears it.
  WizardState copyWith({
    WizardStep? step,
    NinoxEndpoint? endpoint,
    List<NinoxTeam>? teams,
    List<NinoxDatabase>? databases,
    List<NinoxTable>? tables,
    Object? teamId = _keep,
    Object? databaseId = _keep,
    Object? tableId = _keep,
    List<FieldMapping>? mappings,
    Object? error = _keep,
    bool? busy,
  }) => WizardState(
    step: step ?? this.step,
    endpoint: endpoint ?? this.endpoint,
    teams: teams ?? this.teams,
    databases: databases ?? this.databases,
    tables: tables ?? this.tables,
    teamId: identical(teamId, _keep) ? this.teamId : teamId as String?,
    databaseId: identical(databaseId, _keep)
        ? this.databaseId
        : databaseId as String?,
    tableId: identical(tableId, _keep) ? this.tableId : tableId as String?,
    mappings: mappings ?? this.mappings,
    error: identical(error, _keep) ? this.error : error as TokenStepError?,
    busy: busy ?? this.busy,
  );

  /// Prints the step, the sizes of the lists and the identifiers — nothing else, and there is no
  /// token here to leak (design §1).
  @override
  String toString() =>
      'WizardState($step, ${teams.length} teams, ${databases.length} databases, '
      '${tables.length} tables, team: $teamId, database: $databaseId, table: $tableId, '
      '${mappings.length} mappings, error: $error, busy: $busy)';

  @override
  bool operator ==(Object other) =>
      other is WizardState &&
      other.step == step &&
      other.endpoint == endpoint &&
      _sameList(other.teams, teams) &&
      _sameList(other.databases, databases) &&
      _sameList(other.tables, tables) &&
      other.teamId == teamId &&
      other.databaseId == databaseId &&
      other.tableId == tableId &&
      _sameList(other.mappings, mappings) &&
      other.error == error &&
      other.busy == busy;

  @override
  int get hashCode => Object.hash(
    step,
    endpoint,
    Object.hashAll(teams),
    Object.hashAll(databases),
    Object.hashAll(tables),
    teamId,
    databaseId,
    tableId,
    Object.hashAll(mappings),
    error,
    busy,
  );
}

/// Value equality over two lists, so that [WizardState] compares by value.
bool _sameList<T>(List<T> a, List<T> b) {
  if (identical(a, b)) {
    return true;
  }
  if (a.length != b.length) {
    return false;
  }
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}
