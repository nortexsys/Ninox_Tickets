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

/// The wizard's final screen.
class SummaryScreen extends StatelessWidget {
  /// Builds the screen over the destination the wizard just wrote.
  const SummaryScreen({super.key, required this.destination, this.onFinished});

  /// The destination being described.
  final Destination destination;

  /// What accepting the offer does — the router's, because the router knows the capture route.
  final VoidCallback? onFinished;

  /// The action that opens capture for a first document.
  static const Key captureKey = Key('wizard-summary-capture');

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context);
    final SummaryText summary = summarise(destination, l10n);
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
              if (onFinished != null)
                FilledButton(
                  key: SummaryScreen.captureKey,
                  onPressed: onFinished,
                  child: Text(l10n.wizardSummaryCaptureAction),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
