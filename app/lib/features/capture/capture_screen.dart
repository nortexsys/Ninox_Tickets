import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:paperdrop/app/router.dart';
import 'package:paperdrop/features/capture/capture_controller.dart';
import 'package:paperdrop/features/capture/capture_messages.dart';
import 'package:paperdrop/intake/intake_failure.dart';
import 'package:paperdrop/intake/intake_result.dart';
import 'package:paperdrop/l10n/generated/app_localizations.dart';

/// The one capture entry point of the MVP (capture-intake ·
/// `one-entry-point-four-paths`, design §2).
///
/// Two actions, no more: the platform's document scanner and the file picker.
/// Share-in needs no screen of its own — it arrives on the same pipeline, from
/// the same controller, and lands on the same route — and the `.msg`/`.eml` path
/// is R1 (plan v0.2 §4.1), so it is not offered.
///
/// Accessibility: every control renders its accessible name from
/// `AppLocalizations` — this screen holds no user-facing text of its own — and
/// every control is at least 48 dp high.
class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key, required this.controller, this.onScan});

  /// The three paths into the store, in one object.
  final CaptureController controller;

  /// The scanner path (FR-CAP-002), wired by task 1.5. Until then the control is
  /// disabled rather than enabled and doing nothing.
  final Future<void> Function()? onScan;

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  StreamSubscription<CaptureOutcome>? _shared;

  @override
  void initState() {
    super.initState();
    // A share can arrive at any time, including as the reason this application
    // started, so the stream is listened to for as long as the screen lives.
    _shared = widget.controller.sharedDocuments().listen(_report);
  }

  @override
  void dispose() {
    unawaited(_shared?.cancel());
    super.dispose();
  }

  Future<void> _chooseFile() async =>
      _report(await widget.controller.chooseFile());

  /// The single place where an outcome becomes something the user sees: a
  /// stored document opens the intake route, a refusal is said out loud, and a
  /// cancellation quietly leaves the screen as it was.
  void _report(CaptureOutcome outcome) {
    if (!mounted) {
      return;
    }
    switch (outcome) {
      case CaptureStored(result: final IntakeResult result):
        unawaited(context.push(intakeLocationFor(result.docId), extra: result));
      case CaptureCancelled():
        break;
      case CaptureRefused(failure: final IntakeFailure failure):
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              captureFailureMessage(AppLocalizations.of(context), failure.code),
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    final Future<void> Function()? onScan = widget.onScan;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.appTitle)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // The text scrolls rather than clips: at the system's largest
              // text scale it no longer fits on one screen, and it still has to
              // be readable (NFR-ACC-001).
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text(
                        l10n.captureHeadline,
                        style: theme.textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n.captureExplanation,
                        style: theme.textTheme.bodyLarge,
                      ),
                    ],
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: onScan == null ? null : () => unawaited(onScan()),
                icon: const Icon(Icons.document_scanner_outlined),
                label: Text(l10n.captureScanAction),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => unawaited(_chooseFile()),
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
