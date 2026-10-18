/// The review screen: the six core fields, the amounts block, the destination bar and the save.
///
/// Requirement served: FR-REV-001 (`review-screen/destination-bar`), FR-REV-002
/// (`review-screen/daily-destination-confirmation`), FR-REV-003's thumbnail half
/// (`review-screen/thumbnail-with-the-read-region`), FR-REV-004
/// (`review-screen/six-core-fields-in-fixed-order`), FR-REV-005 and FR-REV-010
/// (`review-screen/amounts-block-collapse-rule`), FR-REV-007 (`review-screen/duplicate-notice`),
/// FR-REV-008 (`review-screen/save-button-names-the-destination`), FR-REV-009
/// (`review-screen/never-block-a-save`) and FR-REV-011 (`review-screen/discard-a-document`), with
/// DEC-007 and NFR-ACC-001.
///
/// **It draws, it decides nothing.** Every rule — which field holds the focus, when the block
/// collapses, whether an edit is allowed, whether the save is enabled, what a save sends — is
/// [ReviewController]'s, and this file reads the state and renders it. That is what lets a host test
/// cover the rules and a widget test cover what a person sees (design §1).
///
/// **The save is fixed at the bottom and names the table** (FR-REV-008). It is drawn outside the
/// scrolling column, so a long document scrolled to any position still shows it, and its label is
/// the destination's table rather than a generic verb. It is disabled while the day's destination
/// acknowledgement is owed and on no other account: a missing, unreadable, amber or red field is a
/// document the user can still save (`never-block-a-save`).
///
/// **Every control is labelled and every state has a cue that is not a colour** (NFR-ACC-001): the
/// confidence of a value is an icon with the state's own name from `app_en.arb`, the *edited* mark
/// is an icon with its own, and every tappable control carries a label from the same file. No text
/// of this screen is a literal (NFR-I18N-001).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ninox_client/ninox_client.dart' show SendOutcome, TableRef;
import 'package:paperdrop/features/review/review_amounts.dart';
import 'package:paperdrop/features/review/review_confidence.dart';
import 'package:paperdrop/features/review/review_controller.dart';
import 'package:paperdrop/features/review/review_field.dart';
import 'package:paperdrop/features/review/review_messages.dart';
import 'package:paperdrop/features/review/review_thumbnail.dart';
import 'package:paperdrop/features/wizard/destination.dart';
import 'package:paperdrop/history/history_entry.dart';
import 'package:paperdrop/l10n/generated/app_localizations.dart';
import 'package:paperdrop_core/paperdrop_core.dart' show ConfidenceState, Money;

/// The review screen of one document.
class ReviewScreen extends StatefulWidget {
  /// Builds the screen over [controller], which owns everything it shows.
  ///
  /// [docId] is read only when the controller was not given the entry already. [onSaved] is the
  /// confirmation screen's seam: what follows a send belongs to `ninox-send`, so the screen hands it
  /// the pipeline's answer and keeps nothing back. [onDiscarded] is capture-intake's the same way,
  /// and [onOpenDuplicate] opens the record the duplicate notice links to — the screen builds the
  /// address and does not know how a host opens one.
  const ReviewScreen({
    super.key,
    required this.controller,
    this.docId,
    this.onSaved,
    this.onDiscarded,
    this.onOpenDuplicate,
  });

  /// The state and the actions.
  final ReviewController controller;

  /// The document to load, when the controller has no entry of its own.
  final String? docId;

  /// Called with the pipeline's answer once a save has been made.
  final void Function(SendOutcome outcome)? onSaved;

  /// Called once the local capture has been deleted by a discard.
  final VoidCallback? onDiscarded;

  /// Called with the address of the existing record, when the notice's link is tapped.
  final void Function(Uri link)? onOpenDuplicate;

  /// The tile of one core field.
  static Key fieldKey(ReviewField field) =>
      ValueKey<String>('review-field-${field.wireName}');

  /// The editor of one core field, once it is open.
  static Key editorKey(ReviewField field) =>
      ValueKey<String>('review-editor-${field.wireName}');

  /// The lock of one green field.
  static Key lockKey(ReviewField field) =>
      ValueKey<String>('review-lock-${field.wireName}');

  /// The always-visible destination bar.
  static const Key destinationBarKey = Key('review-destination-bar');

  /// The acknowledgement of the day's destination.
  static const Key acknowledgeKey = Key('review-acknowledge');

  /// The save action, fixed at the bottom.
  static const Key saveKey = Key('review-save');

  /// The discard action.
  static const Key discardKey = Key('review-discard');

  /// The duplicate notice.
  static const Key duplicateNoticeKey = Key('review-duplicate-notice');

  /// The notice's link to the existing record.
  static const Key duplicateLinkKey = Key('review-duplicate-link');

  /// The notice's *save anyway* action.
  static const Key duplicateProceedKey = Key('review-duplicate-proceed');

  /// The amounts block.
  static const Key amountsKey = Key('review-amounts');

  /// The line the block shows when it is collapsed.
  static const Key amountsConfirmedKey = Key('review-amounts-confirmed');

  /// The line the block shows for one amount when it is expanded.
  static Key amountLineKey(AmountLineKind kind, int index) =>
      ValueKey<String>('review-amount-${kind.name}-$index');

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  /// One focus node per core field, so the first unread one can hold the focus on opening.
  final Map<ReviewField, FocusNode> _focus = <ReviewField, FocusNode>{
    for (final ReviewField field in ReviewField.values)
      field: FocusNode(debugLabel: 'review-field-${field.wireName}'),
  };

  final TextEditingController _editor = TextEditingController();

  /// The field whose editor is open, or `null` when the values are read-only.
  ReviewField? _editing;

  @override
  void initState() {
    super.initState();
    unawaited(_open());
  }

  @override
  void dispose() {
    for (final FocusNode node in _focus.values) {
      node.dispose();
    }
    _editor.dispose();
    super.dispose();
  }

  /// Loads the document, redraws, and puts the focus where FR-REV-004 says it goes.
  Future<void> _open() async {
    final ReviewState state = widget.controller.state;
    if (!state.ready && state.loadFailure == null) {
      await widget.controller.load(widget.docId);
    }
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  /// Opens the editor of [field] with the value it shows, so the user corrects rather than retypes.
  void _startEdit(ReviewField field, String text) {
    if (!widget.controller.canEdit(field)) {
      return;
    }
    _editor.text = text;
    _editor.selection = TextSelection(baseOffset: 0, extentOffset: text.length);
    setState(() => _editing = field);
  }

  /// Takes what was typed, or shows why it cannot be taken.
  void _commit(ReviewField field) {
    widget.controller.edit(field, _editor.text);
    setState(() => _editing = null);
  }

  /// Acknowledges the day's destination (FR-REV-002).
  Future<void> _acknowledge() async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    try {
      await widget.controller.acknowledge();
    } on Exception {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.reviewAcknowledgeFailed)));
      return;
    }
    if (mounted) {
      setState(() {});
    }
  }

  /// Saves the document as it stands (FR-REV-008, FR-REV-009).
  Future<void> _save() async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    await widget.controller.save();
    if (!mounted) {
      return;
    }
    setState(() {});
    final ReviewState state = widget.controller.state;
    final SendOutcome? outcome = state.outcome;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          state.saveFailed
              ? l10n.reviewSaveStoreFailed
              : l10n.reviewSaveCompleted,
        ),
      ),
    );
    if (outcome != null) {
      widget.onSaved?.call(outcome);
    }
  }

  /// Discards the document: no record, no entry, no file (FR-REV-011).
  Future<void> _discard() async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool gone = await widget.controller.discardDocument();
    if (!mounted) {
      return;
    }
    setState(() {});
    if (!gone) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.reviewDiscardFailed)));
      return;
    }
    widget.onDiscarded?.call();
  }

  /// Opens the destination selection without leaving the document (FR-REV-001).
  Future<void> _chooseDestination() async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final List<Destination> destinations = widget.controller.state.destinations;
    await showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext sheet) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                l10n.reviewDestinationTitle,
                style: Theme.of(sheet).textTheme.titleLarge,
              ),
            ),
            for (final Destination destination in destinations)
              ListTile(
                key: ValueKey<String>(
                  'review-destination-${destination.teamId}-'
                  '${destination.databaseId}-${destination.tableId}',
                ),
                title: Text(
                  l10n.reviewDestinationBar(
                    destination.teamId,
                    destination.databaseId,
                    destination.tableId,
                  ),
                ),
                onTap: () {
                  widget.controller.chooseDestination(destination);
                  Navigator.of(sheet).pop();
                },
              ),
            if (destinations.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(l10n.reviewDestinationNone),
              ),
          ],
        ),
      ),
    );
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ReviewState state = widget.controller.state;
    if (state.loadFailure != null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.reviewTitle)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(l10n.reviewLoadFailed),
          ),
        ),
      );
    }
    if (!state.ready) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.reviewTitle)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final HistoryEntry entry = state.entry!;
    final ReviewAmounts? amounts = state.amounts;
    final TableRef destination = state.destination!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.reviewTitle),
        actions: <Widget>[
          IconButton(
            key: ReviewScreen.discardKey,
            tooltip: l10n.reviewDiscardAction,
            onPressed: _discard,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: <Widget>[
            ReviewThumbnail(path: entry.thumbnailPath),
            const SizedBox(height: 16),
            if (state.needsReview) ...<Widget>[
              Text(
                l10n.reviewNeedsReviewNotice,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: confidenceCues[ConfidenceState.amber]!.colour,
                ),
              ),
              const SizedBox(height: 16),
            ],
            _destinationBar(l10n, state, destination),
            if (state.acknowledgementRequired) ...<Widget>[
              const SizedBox(height: 8),
              Text(l10n.reviewAcknowledgePrompt),
              const SizedBox(height: 8),
              FilledButton.tonal(
                key: ReviewScreen.acknowledgeKey,
                onPressed: _acknowledge,
                child: Text(l10n.reviewAcknowledgeAction),
              ),
            ],
            const SizedBox(height: 16),
            if (state.duplicate != null) ...<Widget>[
              _duplicateNotice(l10n, state),
              const SizedBox(height: 16),
            ],
            for (final (int index, ReviewField field)
                in ReviewField.values.indexed)
              _fieldTile(context, l10n, field, state, index),
            if (state.editRefusal != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                reviewEditRefusalMessage(l10n, state.editRefusal!),
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: Theme.of(context).colorScheme.error),
              ),
            ],
            if (amounts != null) ...<Widget>[
              const SizedBox(height: 16),
              _amountsBlock(context, l10n, amounts),
            ],
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            key: ReviewScreen.saveKey,
            onPressed: state.saveEnabled ? _save : null,
            child: Text(l10n.reviewSaveAction(destination.tableId)),
          ),
        ),
      ),
    );
  }

  /// The full-width bar of FR-REV-001, highlighted while the day's acknowledgement is owed.
  ///
  /// It shows the three **identifiers** and not the names behind them: a destination stores
  /// identifiers on purpose (FR-DST-003) and resolves the names when a payload is built, so the
  /// identifier is the only thing the app can honour as *where the document goes*.
  Widget _destinationBar(
    AppLocalizations l10n,
    ReviewState state,
    TableRef destination,
  ) {
    final ThemeData theme = Theme.of(context);
    final bool highlighted = state.acknowledgementRequired;
    return Tooltip(
      message: l10n.reviewDestinationAction,
      child: MergeSemantics(
        child: Semantics(
          button: true,
          child: InkWell(
            key: ReviewScreen.destinationBarKey,
            onTap: _chooseDestination,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(
                  color: highlighted
                      ? theme.colorScheme.primary
                      : theme.dividerColor,
                  width: highlighted ? 2 : 1,
                ),
                color: highlighted ? theme.colorScheme.primaryContainer : null,
              ),
              child: Text(
                l10n.reviewDestinationBar(
                  destination.teamId,
                  destination.databaseId,
                  destination.tableId,
                ),
                style: theme.textTheme.titleLarge,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The notice of FR-REV-007: what already exists, a way to it, and a way past it.
  Widget _duplicateNotice(AppLocalizations l10n, ReviewState state) {
    final Uri? link = state.duplicateLink;
    final void Function(Uri link)? onOpen = widget.onOpenDuplicate;
    return Container(
      key: ReviewScreen.duplicateNoticeKey,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(
          color: confidenceCues[ConfidenceState.amber]!.colour,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(l10n.reviewDuplicateNotice),
          if (link != null) ...<Widget>[
            const SizedBox(height: 4),
            Text(link.toString()),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: <Widget>[
              if (link != null && onOpen != null)
                OutlinedButton(
                  key: ReviewScreen.duplicateLinkKey,
                  onPressed: () => onOpen(link),
                  child: Text(l10n.reviewDuplicateLink),
                ),
              if (!state.duplicateProceeded)
                FilledButton.tonal(
                  key: ReviewScreen.duplicateProceedKey,
                  onPressed: _save,
                  child: Text(l10n.reviewDuplicateProceed),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// One of the six core fields: its name, its value, its confidence or its edited mark.
  Widget _fieldTile(
    BuildContext context,
    AppLocalizations l10n,
    ReviewField field,
    ReviewState state,
    int index,
  ) {
    final ThemeData theme = Theme.of(context);
    final ReviewFieldValue value = state.fields[index];
    final String label = reviewFieldLabel(l10n, field);
    final String shown = l10n.reviewFieldValue(
      label,
      value.text.isEmpty ? l10n.reviewValueNotRead : value.text,
    );
    final ConfidenceState? confidence = value.confidence;
    final ConfidenceCue? cue = confidence == null
        ? null
        : confidenceCues[confidence];
    final bool locked =
        confidence == ConfidenceState.green && !state.unlocked.contains(field);
    final bool editing = _editing == field;
    return Focus(
      focusNode: _focus[field],
      // The node is focused when it is attached, which is the only moment a `Focus` can take the
      // focus: the tiles do not exist while the document is still loading (design §2).
      autofocus: field == state.focusField,
      child: MergeSemantics(
        child: Padding(
          key: ReviewScreen.fieldKey(field),
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: <Widget>[
              Expanded(
                child: editing
                    ? TextField(
                        key: ReviewScreen.editorKey(field),
                        controller: _editor,
                        autofocus: true,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontSize: 22,
                        ),
                        decoration: InputDecoration(labelText: label),
                        textInputAction: TextInputAction.done,
                        onSubmitted: (String text) => _commit(field),
                      )
                    : InkWell(
                        onTap: widget.controller.canEdit(field)
                            ? () => _startEdit(field, value.text)
                            : null,
                        child: Text(
                          shown,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontSize: 22,
                            color: cue?.colour,
                          ),
                        ),
                      ),
              ),
              if (cue != null && confidence != null)
                Icon(
                  cue.icon,
                  color: cue.colour,
                  semanticLabel: reviewConfidenceLabel(l10n, confidence),
                ),
              if (locked)
                IconButton(
                  key: ReviewScreen.lockKey(field),
                  tooltip: l10n.reviewLockAction,
                  onPressed: () {
                    widget.controller.unlock(field);
                    setState(() {});
                  },
                  icon: const Icon(lockIcon),
                ),
              if (value.edited)
                Icon(
                  editedIcon,
                  color: theme.colorScheme.onSurfaceVariant,
                  semanticLabel: reviewEditedLabel(l10n),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// The amounts block: one confirming line when the check passed, every amount when it did not.
  Widget _amountsBlock(
    BuildContext context,
    AppLocalizations l10n,
    ReviewAmounts amounts,
  ) {
    final ThemeData theme = Theme.of(context);
    final Money? total = amounts.total;
    return Column(
      key: ReviewScreen.amountsKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(l10n.reviewAmountsHeadline, style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        if (amounts.collapsed && total != null)
          Row(
            key: ReviewScreen.amountsConfirmedKey,
            children: <Widget>[
              Expanded(
                child: Text(
                  reviewAmountsConfirmedText(l10n, total.toDecimalString()),
                ),
              ),
              if (amounts.totalEdited)
                Icon(
                  editedIcon,
                  color: theme.colorScheme.onSurfaceVariant,
                  semanticLabel: reviewEditedLabel(l10n),
                ),
            ],
          )
        else
          for (final (int index, ReviewAmountLine line)
              in amounts.visibleLines.indexed)
            if (line.amount case final Money amount)
              Padding(
                key: ReviewScreen.amountLineKey(line.kind, index),
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  reviewAmountLineText(l10n, line, amount.toDecimalString()),
                ),
              ),
      ],
    );
  }
}
