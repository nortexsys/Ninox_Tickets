import 'package:flutter/material.dart';
import 'package:paperdrop/intake/intake_result.dart';
import 'package:paperdrop/l10n/generated/app_localizations.dart';

/// What the user sees once a document is stored, before extraction and review
/// exist (design §2): the media type, the size, and the first twelve hex digits
/// of the SHA-256 of the stored original.
///
/// It is a placeholder for M2's review screen, and it is deliberately quiet: it
/// shows no filename, because the intake store keeps none.
class IntakeScreen extends StatelessWidget {
  const IntakeScreen({super.key, this.result});

  /// Null on a deep link or a restore, where the document was not carried in
  /// this navigation. The local store of T1.14 is what will answer instead.
  final IntakeResult? result;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final IntakeResult? intake = result;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.intakeTitle)),
      body: SafeArea(
        child: intake == null
            ? const SizedBox.shrink()
            : Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _Field(
                      label: l10n.intakeMediaTypeLabel,
                      value: intake.mediaType,
                    ),
                    _Field(
                      label: l10n.intakeByteLengthLabel,
                      value: l10n.intakeSizeInBytes(intake.byteLength),
                    ),
                    _Field(
                      label: l10n.intakeSha256Label,
                      value: intake.sha256Prefix,
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

/// One labelled value of the placeholder.
class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: theme.textTheme.labelLarge),
          const SizedBox(height: 4),
          Text(value, style: theme.textTheme.bodyLarge),
        ],
      ),
    );
  }
}
