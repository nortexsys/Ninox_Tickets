/// The mapping step: every core field, its proposal, its picker and its absent setting (design §5).
///
/// Requirement served: FR-WIZ-005 (`setup-wizard/pre-filled-proposals`) — *each of the six core
/// fields shown as a pre-filled proposal over the table's real fields, so that the user corrects only
/// what is wrong, and where nothing plausible exists the field SHALL be visibly unmapped rather than
/// shown as an empty selector* — FR-WIZ-006 through the matcher it is drawn from,
/// FR-WIZ-007 (`setup-wizard/no-mapping-is-mandatory`) and FR-DST-006
/// (`destinations-mapping/per-field-absent-setting`), whose *default is empty* half is this screen's.
///
/// **It makes no call.** The step is given the table the port already returned — the one the table
/// step chose, with its fields — and the proposals come from `field_matcher.dart` over that table
/// (FR-WIZ-004: reaching the mapping step costs no round trip). Nothing here holds a URL, a client or
/// a token: a widget takes a controller and draws what the state and the matcher say.
///
/// **What the user sees per field.** Its plain-language name; the **picker**, which is the field's
/// whole display of state — the proposed or chosen column when there is one, and the words *Not
/// mapped* when there is not, so an unmapped field is visibly unmapped rather than an empty selector;
/// and, for a mapped field, the absent setting, *leave it empty* (the default) or *write zero*.
///
/// **The picker offers only candidates of the right kind.** It is built from `typeCandidates`, the
/// first stage of the matcher, so a date is never offered against a number column and the columns the
/// filter removed cannot be chosen by hand either — the same rule the proposal obeys governs what the
/// user may correct it to.
///
/// **Nothing is mandatory.** The action that finishes the step is always enabled, and it produces as
/// many mappings as the user made: all of them, one of them, or none at all (FR-WIZ-007).
///
/// **No text is a literal here.** Every sentence is a `wizard`-prefixed key of `app_en.arb`
/// (design §1, NFR-I18N-001).
library;

import 'package:flutter/material.dart';
import 'package:ninox_client/ninox_client.dart';
import 'package:paperdrop/l10n/generated/app_localizations.dart';

import '../destination.dart';
import '../matching/field_matcher.dart';
import '../matching/type_rules.dart';
import '../wizard_controller.dart';
import '../wizard_messages.dart';

/// The fifth step of the wizard: the six core fields and the two the design adds, each with what the
/// matcher proposed and what the user decided.
class MappingScreen extends StatefulWidget {
  /// Builds the step over the controller that holds the chosen table.
  const MappingScreen({super.key, required this.controller, this.onCompleted});

  /// The state machine: its state is where the table and the table's fields are.
  final WizardController controller;

  /// Called with the mapping the user built, when they finish the step.
  ///
  /// The host decides what comes next — dispatch 3.4's closing summary, and behind it the offer to
  /// capture — so this screen knows nothing about a route or a callback of the shell's.
  final Future<void> Function(List<FieldMapping> mappings)? onCompleted;

  /// The row of one core field.
  static Key fieldKey(CoreField field) =>
      ValueKey<String>('wizard-mapping-${field.wireName}');

  /// The picker of one core field, whose display *is* the field's state.
  static Key pickerKey(CoreField field) =>
      ValueKey<String>('wizard-picker-${field.wireName}');

  /// The absent-setting control of one mapped core field.
  static Key absentKey(CoreField field) =>
      ValueKey<String>('wizard-absent-${field.wireName}');

  /// The action that finishes the step.
  static const Key continueKey = Key('wizard-mapping-continue');

  @override
  State<MappingScreen> createState() => _MappingScreenState();
}

class _MappingScreenState extends State<MappingScreen> {
  /// The table the table step chose, with the fields the port returned. `null` only if this screen
  /// is built before that step is answered, which the sequence does not do.
  late final NinoxTable? _table = widget.controller.table;

  /// The candidates of each core field: the fields of the right kind, in the table's own order.
  late final Map<CoreField, List<NinoxField>> _candidates =
      <CoreField, List<NinoxField>>{
        for (final CoreField coreField in CoreField.values)
          coreField: _table == null
              ? const <NinoxField>[]
              : typeCandidates(coreField, _table),
      };

  /// What the matcher proposed, over the same table, in the canonical order.
  late final List<FieldProposal> _proposals = _table == null
      ? const <FieldProposal>[]
      : proposeMappings(_table);

  /// What each field is mapped to: the proposal at first, and whatever the user corrects it to.
  ///
  /// `null` is a value here and not an absence: it is the *unmapped* state, and the screen shows it in
  /// words rather than by leaving the picker empty.
  late final Map<CoreField, NinoxField?> _mapped = <CoreField, NinoxField?>{
    for (final FieldProposal proposal in _proposals)
      proposal.coreField: proposal.ninoxField,
  };

  /// The absent setting of each field: [AbsentSetting.empty] unless the user says otherwise, which is
  /// FR-DST-006's default and is never chosen for them by this screen.
  final Map<CoreField, AbsentSetting> _absent = <CoreField, AbsentSetting>{
    for (final CoreField coreField in CoreField.values)
      coreField: AbsentSetting.empty,
  };

  /// Finishes the step with the mapping the user built, and hands it to the host.
  Future<void> _finish() async {
    await widget.onCompleted?.call(<FieldMapping>[
      for (final CoreField coreField in CoreField.values)
        if (_mapped[coreField] != null)
          FieldMapping(
            coreField: coreField,
            ninoxFieldId: _mapped[coreField]!.id,
            ninoxFieldName: _mapped[coreField]!.name,
            absent: _absent[coreField]!,
          ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.wizardTitle)),
      body: SafeArea(
        // A scroll view over a column and not a lazy list: every field's row is built, so the whole
        // form exists for the user who scrolls it, for a screen reader that walks it and for a test
        // that has to reach the last of the eight.
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                l10n.wizardMappingHeadline,
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.wizardMappingExplanation,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              for (final CoreField coreField in CoreField.values)
                _FieldRow(
                  coreField: coreField,
                  label: wizardCoreFieldLabel(l10n, coreField),
                  candidates: _candidates[coreField]!,
                  mapped: _mapped[coreField],
                  absent: _absent[coreField]!,
                  onMapped: (NinoxField? candidate) =>
                      setState(() => _mapped[coreField] = candidate),
                  onAbsent: (AbsentSetting absent) =>
                      setState(() => _absent[coreField] = absent),
                ),
              const SizedBox(height: 16),
              FilledButton(
                key: MappingScreen.continueKey,
                onPressed: _finish,
                child: Text(l10n.wizardMappingContinueAction),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One core field: its name, its picker, and — when it is mapped — its absent setting.
class _FieldRow extends StatelessWidget {
  const _FieldRow({
    required this.coreField,
    required this.label,
    required this.candidates,
    required this.mapped,
    required this.absent,
    required this.onMapped,
    required this.onAbsent,
  });

  final CoreField coreField;

  /// The field's plain-language name.
  final String label;

  /// The columns the first stage of the matcher kept for this field, and only those.
  final List<NinoxField> candidates;

  /// What the field is mapped to, or `null` for unmapped.
  final NinoxField? mapped;

  /// The absent setting, which only a mapped field shows.
  final AbsentSetting absent;

  final ValueChanged<NinoxField?> onMapped;
  final ValueChanged<AbsentSetting> onAbsent;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Padding(
      key: MappingScreen.fieldKey(coreField),
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          // The picker *is* the state: with a mapping it reads as that column, and without one it
          // reads as `Not mapped`, which is a word on the screen and not an empty selector.
          DropdownButton<NinoxField?>(
            key: MappingScreen.pickerKey(coreField),
            value: mapped,
            hint: Text(l10n.wizardMappingUnmapped),
            isExpanded: true,
            items: <DropdownMenuItem<NinoxField?>>[
              DropdownMenuItem<NinoxField?>(
                value: null,
                child: Text(l10n.wizardMappingUnmapped),
              ),
              for (final NinoxField candidate in candidates)
                DropdownMenuItem<NinoxField?>(
                  value: candidate,
                  child: Text(candidate.name),
                ),
            ],
            onChanged: onMapped,
          ),
          if (mapped != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              l10n.wizardMappingAbsentLabel,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            SegmentedButton<AbsentSetting>(
              key: MappingScreen.absentKey(coreField),
              showSelectedIcon: false,
              segments: <ButtonSegment<AbsentSetting>>[
                ButtonSegment<AbsentSetting>(
                  value: AbsentSetting.empty,
                  label: Text(l10n.wizardMappingAbsentEmpty),
                ),
                ButtonSegment<AbsentSetting>(
                  value: AbsentSetting.zero,
                  label: Text(l10n.wizardMappingAbsentZero),
                ),
              ],
              selected: <AbsentSetting>{absent},
              onSelectionChanged: (Set<AbsentSetting> selection) =>
                  onAbsent(selection.single),
            ),
          ],
        ],
      ),
    );
  }
}
