import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:paperdrop/app/dependencies.dart';
import 'package:paperdrop/app/router.dart';
import 'package:paperdrop/app/theme.dart';
import 'package:paperdrop/features/capture/capture_controller.dart';
import 'package:paperdrop/l10n/generated/app_localizations.dart';

/// The application shell: routing, theme and the localisation delegates
/// (design §2). Owned by the Mobile lane (setup-mvp-foundations §2).
class PaperdropApp extends StatefulWidget {
  const PaperdropApp({super.key, this.controller, this.onScan});

  /// The capture pipeline to use. A widget test passes one built on fakes; the
  /// application passes none and gets the device's own.
  final CaptureController? controller;

  /// The scanner path, wired by task 1.5 (design §3).
  final Future<void> Function()? onScan;

  @override
  State<PaperdropApp> createState() => _PaperdropAppState();
}

class _PaperdropAppState extends State<PaperdropApp> {
  late final CaptureController _controller =
      widget.controller ?? deviceCaptureController();
  late final GoRouter _router = buildAppRouter(
    controller: _controller,
    onScan: widget.onScan,
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      onGenerateTitle: (BuildContext context) =>
          AppLocalizations.of(context).appTitle,
      theme: PaperdropTheme.light(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }
}
