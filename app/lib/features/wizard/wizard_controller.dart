/// The wizard's state machine (design §3 and §4).
///
/// Requirement served: FR-WIZ-001 (`setup-wizard/five-screens-at-most`), FR-WIZ-002
/// (`setup-wizard/steps-auto-omit-when-there-is-nothing-to-choose`), FR-WIZ-003
/// (`setup-wizard/token-step-via-the-system-browser`), FR-WIZ-004
/// (`setup-wizard/table-listing-returns-the-schema`) and FR-DST-008's validation half
/// (`destinations-mapping/configurable-ninox-host`).
///
/// **Every call is made here, and only when the previous step completes.** `listTeams` when the
/// token step's call succeeds, `listDatabases` when a team is chosen, `listTables` when a database
/// is — and the tables arrive with their fields, so the mapping step makes no further call.
///
/// **Which steps are shown is computed.** [visibleSteps] is a function of the lists, so a
/// one-option list produces no step at all rather than a pre-confirmed one, and the wizard never
/// rests on a step it does not show.
///
/// **The token is not in the state.** The port this controller holds is the only thing that carries
/// the credential, and it is built here from the parsed endpoint and the pasted token (design §1:
/// the token never lives in widget state that outlives the step).
///
/// **What this class does not do.** It is not a `ChangeNotifier` and it holds no route: a screen
/// calls a method, awaits it, and redraws from [state]. Navigation is the router's (dispatch B) and
/// the closing summary is the mapping step's (dispatch D).
library;

import 'package:ninox_client/ninox_client.dart';

import 'data/port_factory.dart';
import 'data/token_store.dart';
import 'destination.dart';
import 'wizard_errors.dart';
import 'wizard_step.dart';

/// The wizard's state machine.
final class WizardController {
  /// Builds a controller for the first run, or for [initial] — an already configured destination
  /// being edited through the same sequence (design §3).
  ///
  /// The factory and the store are held privately on purpose: nothing outside this controller may
  /// build a port or write a token, which is what keeps "the token is written only after the
  /// validating call succeeded" a property of one place.
  WizardController({
    required NinoxPortFactory portFactory,
    required TokenStore tokenStorage,
    Destination? initial,
  }) : _factory = portFactory,
       _tokenStore = tokenStorage,
       _state = initial == null
           ? const WizardState()
           : WizardState.fromDestination(initial);

  final NinoxPortFactory _factory;
  final TokenStore _tokenStore;

  /// The port the token step built, or `null` until that call succeeded.
  ///
  /// It holds the endpoint and the credential, and it is the controller's and never the state's:
  /// `NinoxCredentials.toString` prints `***`, and nothing else here can print it either.
  NinoxPort? _port;

  /// The team whose databases [_state] holds, and the database whose tables it holds.
  ///
  /// They are the record of which of the three calls has already been made, so a step whose list is
  /// already in the state makes no second call — and so a valid token costs one round trip and no
  /// second one (FR-WIZ-003).
  String? _databasesOf;
  String? _tablesOf;

  WizardState _state;

  /// The state the screens are drawn from.
  WizardState get state => _state;

  /// The step the user is on.
  WizardStep get step => _state.step;

  /// Which steps are shown, computed and never stored (design §3).
  List<WizardStep> get visibleSteps => _state.visibleSteps;

  /// The table the user chose, with the fields the port returned with it, or `null` while the table
  /// step is unanswered.
  ///
  /// It is what the mapping step is drawn from, and it is already in the state: the listing carries
  /// each table's fields, so reaching the mapping step costs no round trip (FR-WIZ-004).
  NinoxTable? get table {
    final String? tableId = _state.tableId;
    if (tableId == null) {
      return null;
    }
    for (final NinoxTable candidate in _state.tables) {
      if (candidate.id == tableId) {
        return candidate;
      }
    }
    return null;
  }

  /// The mapping the user built, as the destination's field mappings.
  List<FieldMapping> get mappings => _state.mappings;

  /// The mapping step's completion: the wizard stops asking and the destination is what it is
  /// (FR-WIZ-007 — the list may be empty, partly filled or complete).
  void mapFields(List<FieldMapping> mappings) =>
      _state = _state.copyWith(mappings: mappings);

  /// The destination the wizard has configured, or `null` while one of the three choices is missing.
  ///
  /// It holds identifiers and no secret (design §6): the host, the team, the database, the table and
  /// the field mappings. The token is not here and never is — the device's keystore holds it.
  Destination? get destination {
    final String? teamId = _state.teamId;
    final String? databaseId = _state.databaseId;
    final String? tableId = _state.tableId;
    if (teamId == null || databaseId == null || tableId == null) {
      return null;
    }
    return Destination(
      endpoint: _state.endpoint,
      teamId: teamId,
      databaseId: databaseId,
      tableId: tableId,
      mappings: _state.mappings,
    );
  }

  /// Whether there is a visible step before the current one.
  bool get canGoBack => visibleSteps.indexOf(_state.step) > 0;

  /// Moves to the previous visible step, skipping the steps the lists omitted (design §3).
  ///
  /// "Back" is the same list read the other way: a step that a one-option list omitted is not
  /// visited on the way back either.
  void back() {
    final List<WizardStep> steps = visibleSteps;
    final int index = steps.indexOf(_state.step);
    if (index <= 0) {
      return;
    }
    _state = _state.copyWith(step: steps[index - 1], error: null);
  }

  /// The token step's one call (design §4, FR-WIZ-003).
  ///
  /// [host] is what the advanced setup holds, as the user typed it, and [token] is what the field
  /// holds. The host is parsed first: an unaccepted form is reported at the field and **no call is
  /// made**. Otherwise one call — `listTeams` — validates the token and the host together and
  /// returns the next step's list.
  ///
  /// The token is written to the [TokenStore] **only after** that call succeeded, and it is written
  /// nowhere else: not to a file, not to shared preferences, not to a log line.
  ///
  /// Never throws for a Ninox failure: every one of them becomes [WizardState.error], which a
  /// screen turns into its sentence through `wizardErrorMessage`.
  Future<void> connect({required String host, required String token}) async {
    final NinoxEndpoint? endpoint = NinoxEndpoint.parse(host);
    if (endpoint == null) {
      _state = _state.copyWith(error: WizardError.hostNotValid, busy: false);
      return;
    }
    _state = _state.copyWith(endpoint: endpoint, error: null, busy: true);

    final NinoxPort port = _factory(endpoint, NinoxCredentials(token));
    final List<NinoxTeam> teams;
    try {
      teams = await port.listTeams();
    } on NinoxFailure catch (failure) {
      _state = _state.copyWith(error: wizardErrorFor(failure), busy: false);
      return;
    }

    // The call proved the token: this is the first and only place it is written.
    await _tokenStore.write(token);
    _port = port;
    _state = _withTeams(teams);
    await _walk(WizardStep.token);
  }

  /// The team step's completion (design §3): the team is chosen and the step's own call — the
  /// databases of that team — is made at once. The databases and the table of any previous team are
  /// dropped, because they belonged to it.
  Future<void> chooseTeam(String teamId) async {
    _databasesOf = null;
    _tablesOf = null;
    _state = _state.copyWith(
      teamId: teamId,
      databases: const <NinoxDatabase>[],
      databaseId: null,
      tables: const <NinoxTable>[],
      tableId: null,
    );
    await _walk(WizardStep.team);
  }

  /// The database step's completion: the database is chosen and `listTables` is made at once. The
  /// tables arrive **with their fields**, so the mapping step needs no further call (FR-WIZ-004).
  Future<void> chooseDatabase(String databaseId) async {
    _tablesOf = null;
    _state = _state.copyWith(
      databaseId: databaseId,
      tables: const <NinoxTable>[],
      tableId: null,
    );
    await _walk(WizardStep.database);
  }

  /// The table step's completion: the table is chosen, and the step that follows it is the mapping
  /// step — whose completion is the closing summary.
  Future<void> chooseTable(String tableId) async {
    _state = _state.copyWith(tableId: tableId);
    await _walk(WizardStep.table);
  }

  /// Re-runs the call the current step owes, so that a user who met a failure can try again without
  /// leaving the step (the orchestrator's decision of 2026-10-07).
  ///
  /// The three list calls are the only ones this can repeat: the token step's call is repeated by
  /// its own action, and the mapping step makes none. A retry that fails again leaves the same
  /// sentence and the same step — nothing is hidden and nothing is invented.
  Future<void> retry() async {
    switch (_state.step) {
      case WizardStep.database:
        // The list in the state is not this team's: the call has to be made again.
        _databasesOf = null;
        await _walk(WizardStep.team);
      case WizardStep.table:
        _tablesOf = null;
        await _walk(WizardStep.database);
      case WizardStep.token || WizardStep.team || WizardStep.mapping:
        return;
    }
  }

  /// The state after `listTeams` answered: the list, and the team the list implies.
  ///
  /// The call is over, so `busy` goes back to `false` here whatever the step the walk stops on: a
  /// screen that holds its action while a call is in flight would otherwise hold it for ever (found
  /// by the choose screen's progress line; `wizard_controller_test.dart` pins it).
  WizardState _withTeams(List<NinoxTeam> teams) {
    final String? teamId = _choiceFrom(<String>[
      for (final NinoxTeam team in teams) team.id,
    ], _state.teamId);
    if (teamId == _state.teamId) {
      return _state.copyWith(teams: teams, busy: false, error: null);
    }
    _databasesOf = null;
    _tablesOf = null;
    return _state.copyWith(
      teams: teams,
      teamId: teamId,
      databases: const <NinoxDatabase>[],
      databaseId: null,
      tables: const <NinoxTable>[],
      tableId: null,
      busy: false,
      error: null,
    );
  }

  /// Walks forward from [answered], the step whose answer has just arrived (design §3).
  ///
  /// The loop is the sequence's own rule, in one place. It leaves the answered step, arrives on the
  /// next step of the sequence, and makes that step's own call before deciding anything: a step's
  /// call is made when the previous step completes.
  ///
  /// * a step whose list holds exactly one option is **omitted** — its answer is automatic, so it is
  ///   complete the moment it arrives and the walk goes on, which is how a one-option subscription
  ///   reaches the mapping step without a screen in between;
  /// * a step the lists still show is where the walk stops, whether or not it has an answer: the
  ///   user is the one who confirms or changes it.
  ///
  /// Every list is fetched at most once per choice, so a valid token costs one round trip and no
  /// second one (FR-WIZ-003), and reaching the mapping step needs no further call (FR-WIZ-004).
  Future<void> _walk(WizardStep answered) async {
    WizardStep? step = answered;
    while (step != null) {
      step = _stepAfter(step);
      if (step == null) {
        return;
      }
      if (step == WizardStep.database) {
        await _loadDatabases();
      }
      if (step == WizardStep.table) {
        await _loadTables();
      }
      if (visibleSteps.contains(step)) {
        _state = _state.copyWith(step: step);
        return;
      }
    }
  }

  /// The databases of the chosen team, and the database that list implies.
  ///
  /// Nothing is fetched twice: the list in the state already belongs to the chosen team, so the
  /// step makes no second call.
  ///
  /// A Ninox failure does not leave the controller: it becomes [WizardState.error] — the same
  /// sentence the token step would show — the step stays where it is, and [retry] is what makes the
  /// call again (the orchestrator's decision of 2026-10-07).
  Future<void> _loadDatabases() async {
    final NinoxPort? port = _port;
    final String? teamId = _state.teamId;
    if (port == null || teamId == null || _databasesOf == teamId) {
      return;
    }
    _state = _state.copyWith(busy: true, error: null);
    final List<NinoxDatabase> databases;
    try {
      databases = await port.listDatabases(teamId);
    } on NinoxFailure catch (failure) {
      _state = _state.copyWith(busy: false, error: wizardErrorFor(failure));
      return;
    }
    _databasesOf = teamId;
    _state = _state.copyWith(
      databases: databases,
      databaseId: _choiceFrom(<String>[
        for (final NinoxDatabase database in databases) database.id,
      ], _state.databaseId),
      busy: false,
      error: null,
    );
  }

  /// The tables of the chosen database, with their fields, and the table that list implies.
  ///
  /// A failure is shown exactly as [NinoxPort.listDatabases]'s is: same sentence, same step, same
  /// retry.
  Future<void> _loadTables() async {
    final NinoxPort? port = _port;
    final String? teamId = _state.teamId;
    final String? databaseId = _state.databaseId;
    if (port == null ||
        teamId == null ||
        databaseId == null ||
        _tablesOf == databaseId) {
      return;
    }
    _state = _state.copyWith(busy: true, error: null);
    final List<NinoxTable> tables;
    try {
      tables = await port.listTables(teamId, databaseId);
    } on NinoxFailure catch (failure) {
      _state = _state.copyWith(busy: false, error: wizardErrorFor(failure));
      return;
    }
    _tablesOf = databaseId;
    _state = _state.copyWith(
      tables: tables,
      tableId: _choiceFrom(<String>[
        for (final NinoxTable table in tables) table.id,
      ], _state.tableId),
      busy: false,
      error: null,
    );
  }

  /// The step that follows [step] in the sequence, or `null` after the last one.
  ///
  /// The order of [WizardStep]'s values is the order of the sequence; nothing keeps a second list of
  /// steps, which is what makes "no sixth step" a property of the type rather than a promise.
  static WizardStep? _stepAfter(WizardStep step) {
    final int index = WizardStep.values.indexOf(step);
    if (index < 0 || index + 1 >= WizardStep.values.length) {
      return null;
    }
    return WizardStep.values[index + 1];
  }

  /// The choice a list implies (design §3): a one-option list is chosen automatically, a previous
  /// choice the list no longer holds is dropped rather than kept against it, and anything else is
  /// left for the user.
  static String? _choiceFrom(List<String> ids, String? current) {
    if (ids.length == 1) {
      return ids.single;
    }
    return ids.contains(current) ? current : null;
  }
}
