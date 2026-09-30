import 'dart:async';

import 'package:flutter/material.dart';
import 'package:paperdrop/l10n/generated/app_localizations.dart';

/// The one capture entry point of the MVP (capture-intake ·
/// `one-entry-point-four-paths`, design §2).
///
/// Two actions, no more: the platform's document scanner and the file picker.
/// Share-in arrives through the same pipeline and mounts no screen of its own,
/// and the `.msg`/`.eml` path is R1 (plan v0.2 §4.1), so it is not offered.
///
/// Accessibility: both controls render their accessible name from
/// `AppLocalizations` — the screen holds no user-facing text of its own — and
/// both are at least [PaperdropTheme.minimumTapTarget] high.
class CaptureScreen extends StatelessWidget {
  const CaptureScreen({super.key, this.onScan, this.onChooseFile});

  /// Starts the platform document scanner (FR-CAP-002).
  ///
  /// Null until the intake pipeline is wired (tasks 1.3–1.5), which disables
  /// the control rather than letting it look active and do nothing.
  final Future<void> Function()? onScan;

  /// Opens the file picker (FR-CAP-001).
  final Future<void> Function()? onChooseFile;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.appTitle)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(l10n.captureHeadline, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 12),
              Text(l10n.captureExplanation, style: theme.textTheme.bodyLarge),
              const Spacer(),
              FilledButton.icon(
                onPressed: onScan == null ? null : () => unawaited(onScan!()),
                icon: const Icon(Icons.document_scanner_outlined),
                label: Text(l10n.captureScanAction),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onChooseFile == null
                    ? null
                    : () => unawaited(onChooseFile!()),
                icon: const Icon(Icons.folder_open_outlined),
                label: Text(l10n.captureChooseFileAction),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
