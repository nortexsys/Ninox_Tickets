/// The team, database and table steps, in one widget (design §2 and §3).
///
/// Requirement served: FR-WIZ-002 (`setup-wizard/steps-auto-omit-when-there-is-nothing-to-choose`)
/// and FR-WIZ-004 (`setup-wizard/table-listing-returns-the-schema`) — the tables come back with
/// their fields, so the step after this one needs no call of its own.
///
/// **One widget, three steps.** The three steps differ in one thing only: which list of the state
/// they read. So there is one screen, it reads the list of the step the controller is on, and a
/// selection advances and *is* the step's completion — the call behind it (`listDatabases` after a
/// team, `listTables` after a database) belongs to the controller and is made once.
///
/// **A step whose list is empty, and a call that failed.** An empty list is explained in plain
/// language and offers nothing to choose; a failed call is explained with the same sentence the
/// token step uses, the user stays here, and the retry action runs that same call again (the
/// orchestrator's decision of 2026-10-07). The two are never confused: see `WizardState.notice`.
///
/// **No text is a literal here.** Every sentence comes from a [WizardStrings] seam, which dispatch
/// 2.2 replaces with the generated localisations, key for key (design §1).
library;

import 'package:flutter/material.dart';

import '../wizard_controller.dart';
import '../wizard_errors.dart';
import '../wizard_messages.dart';
import '../wizard_step.dart';
import '../wizard_strings.dart';

/// One screen for the team, the database and the table step.
class ChooseScreen extends StatefulWidget {
  /// Builds the step over the controller's lists.
  const ChooseScreen({
    super.key,
    required this.controller,
    this.strings = const WizardStrings(),
    this.onStepChanged,
  });

  /// The state machine this step drives.
  final WizardController controller;

  /// The step's text (design §1): one seam, replaced by the localisations in dispatch 2.2.
  final WizardStrings strings;

  /// Called after an action of this screen completed, so a host that draws the whole wizard — one
  /// widget per step — can redraw the step it should be showing.
  final VoidCallback? onStepChanged;

  /// The tile of one option, so a test taps the option it means.
  static Key optionKey(String id) => ValueKey<String>('wizard-option-$id');

  /// The action that runs a failed call again.
  static const Key retryKey = Key('wizard-retry');

  /// The action that returns to the previous visible step.
  static const Key backKey = Key('wizard-back');

  @override
  State<ChooseScreen> createState() => _ChooseScreenState();
}

/// One choice on offer: the identifier a call quotes, and the name the user reads.
class _Option {
  const _Option({required this.id, required this.name, required this.chosen});

  final String id;
  final String name;
  final bool chosen;
}

class _ChooseScreenState extends State<ChooseScreen> {
  /// The options of the step the controller is on.
  ///
  /// The screen serves the three steps that choose from a list; on any other step it offers nothing,
  /// because the step that shows those is not this one.
  List<_Option> _options(WizardState state) => switch (state.step) {
    WizardStep.team => <_Option>[
      for (final team in state.teams)
        _Option(id: team.id, name: team.name, chosen: team.id == state.teamId),
    ],
    WizardStep.database => <_Option>[
      for (final database in state.databases)
        _Option(
          id: database.id,
          name: database.name,
          chosen: database.id == state.databaseId,
        ),
    ],
    WizardStep.table => <_Option>[
      for (final table in state.tables)
        _Option(
          id: table.id,
          name: table.name,
          chosen: table.id == state.tableId,
        ),
    ],
    WizardStep.token || WizardStep.mapping => const <_Option>[],
  };

  /// The step's own question.
  String _title(WizardStrings strings, WizardStep step) => switch (step) {
    WizardStep.team => strings.teamStepTitle,
    WizardStep.database => strings.databaseStepTitle,
    WizardStep.table => strings.tableStepTitle,
    WizardStep.token || WizardStep.mapping => strings.wizardTitle,
  };

  /// The step's completion: the controller makes the call of the step behind the choice.
  Future<void> _choose(String id) async {
    final Future<void> pending = switch (widget.controller.step) {
      WizardStep.team => widget.controller.chooseTeam(id),
      WizardStep.database => widget.controller.chooseDatabase(id),
      WizardStep.table => widget.controller.chooseTable(id),
      WizardStep.token || WizardStep.mapping => Future<void>.value(),
    };
    // The call is in flight: the step holds its action.
    setState(() {});
    await pending;
    _after();
  }

  /// Runs the call the current step owes again, after a failure.
  Future<void> _retry() async {
    final Future<void> pending = widget.controller.retry();
    setState(() {});
    await pending;
    _after();
  }

  /// Returns to the previous step the lists still show.
  void _back() {
    widget.controller.back();
    _after();
  }

  /// Redraws this screen, and tells a host that draws the whole wizard to redraw too.
  void _after() {
    if (!mounted) {
      return;
    }
    setState(() {});
    widget.onStepChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final WizardStrings strings = widget.strings;
    final WizardState state = widget.controller.state;
    final List<_Option> options = _options(state);
    final WizardNotice? notice = state.notice;
    final WizardError? error = state.error;
    return Scaffold(
      appBar: AppBar(
        title: Text(strings.wizardTitle),
        leading: widget.controller.canGoBack
            ? IconButton(
                key: ChooseScreen.backKey,
                tooltip: strings.backAction,
                onPressed: state.busy ? null : _back,
                icon: const Icon(Icons.arrow_back),
              )
            : null,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: <Widget>[
            Text(
              _title(strings, state.step),
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            if (state.busy) const LinearProgressIndicator(),
            for (final _Option option in options)
              ListTile(
                key: ChooseScreen.optionKey(option.id),
                title: Text(option.name),
                selected: option.chosen,
                trailing: option.chosen ? const Icon(Icons.check) : null,
                enabled: !state.busy,
                onTap: () => _choose(option.id),
              ),
            if (notice != null) ...<Widget>[
              const SizedBox(height: 16),
              Text(wizardNoticeMessage(strings, notice)),
            ],
            if (error != null) ...<Widget>[
              const SizedBox(height: 16),
              Text(
                wizardErrorMessage(strings, error),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
              const SizedBox(height: 8),
              FilledButton(
                key: ChooseScreen.retryKey,
                onPressed: state.busy ? null : _retry,
                child: Text(strings.tryAgainAction),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
