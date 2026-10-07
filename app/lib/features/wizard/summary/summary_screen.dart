/// The closing screen of the wizard (design §2, §6).
///
/// Requirement served: FR-WIZ-008 (`setup-wizard/plain-language-summary-and-first-document-offer`):
/// the summary of the consequence, and the offer *to capture a document of any kind rather than
/// returning the user to an empty application*.
///
/// **It is not a sixth step.** It is the closing view of the mapping step's completion
/// (`setup-wizard/five-screens-at-most`, design §3): the wizard shows it in the mapping step's
/// place, and the step the state is on is still `mapping`.
///
/// **The offer is the router's.** The action calls the `onFinished` callback the shell supplies,
/// because the shell is what knows the capture route; without a callback — only a test builds it
/// that way — the offer is not shown rather than shown and doing nothing.
///
/// **What it says** comes from `summarise`, a pure function over the resources: which core fields
/// will be saved, which will not, or that only the document will be attached with no data.
library;

import 'package:flutter/material.dart';
import 'package:paperdrop/l10n/generated/app_localizations.dart';

import '../destination.dart';
import 'summarise.dart';

/// What became of the destination on the device (design §10.1).
///
/// Three states and not two: the write is attempted while the summary is already on screen, and the
/// offer to capture must wait for it either way — an offer that appears before the answer, or after
/// a refusal, would hand the user a capture whose document has nowhere to go.
enum DestinationSave {
  /// The write is in flight, or has not been attempted.
  notAttempted,

  /// The destination is on the device.
  saved,

  /// The write failed. Nothing is claimed as saved, and the retry is offered.
  failed,
}

/// The wizard's final screen.
class SummaryScreen extends StatelessWidget {
  /// Builds the screen over the destination the wizard just wrote.
  const SummaryScreen({
    super.key,
    required this.destination,
    this.onFinished,
    this.save = DestinationSave.notAttempted,
    this.onRetry,
    this.onBack,
  });

  /// The destination being described.
  final Destination destination;

  /// What accepting the offer does — the router's, because the router knows the capture route.
  final VoidCallback? onFinished;

  /// What became of the destination on the device.
  ///
  /// On [DestinationSave.failed] the screen says so and offers the retry, and it does **not** offer
  /// capture: nothing is claimed as saved, and the first run's redirect of design §10 would send a
  /// user whose setup is not on the device straight back to the wizard — the retry is the way on.
  final DestinationSave save;

  /// Writes the destination again. The host owns the store, so the host owns the retry.
  final VoidCallback? onRetry;

  /// Returns to the mapping step, with the user's choices as they were left (design §10.3).
  ///
  /// A summary that a user cannot walk back from is a summary they have to accept: whoever notices a
  /// wrong column while reading it must be able to correct it.
  final VoidCallback? onBack;

  /// The action that opens capture for a first document.
  static const Key captureKey = Key('wizard-summary-capture');

  /// The action that tries the write again after a failure.
  static const Key retrySaveKey = Key('wizard-summary-retry');

  /// The sentence that says the setup could not be written.
  static const Key saveFailedKey = Key('wizard-summary-save-failed');

  /// The action that returns to the mapping step.
  static const Key backKey = Key('wizard-summary-back');

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context);
    final SummaryText summary = summarise(destination, l10n);
    final bool failed = save == DestinationSave.failed;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.wizardTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                l10n.wizardSummaryHeadline,
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              for (final String line in summary.lines)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(line, style: theme.textTheme.bodyLarge),
                ),
              const SizedBox(height: 12),
              if (failed) ...<Widget>[
                Text(
                  l10n.wizardSummarySaveFailed,
                  key: SummaryScreen.saveFailedKey,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  key: SummaryScreen.retrySaveKey,
                  onPressed: onRetry,
                  child: Text(l10n.wizardTryAgainAction),
                ),
              ],
              if (save == DestinationSave.saved && onFinished != null)
                FilledButton(
                  key: SummaryScreen.captureKey,
                  onPressed: onFinished,
                  child: Text(l10n.wizardSummaryCaptureAction),
                ),
              if (onBack != null) ...<Widget>[
                const SizedBox(height: 8),
                TextButton(
                  key: SummaryScreen.backKey,
                  onPressed: onBack,
                  child: Text(l10n.wizardBackAction),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
