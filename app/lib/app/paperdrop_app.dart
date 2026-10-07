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
  const PaperdropApp({super.key, this.controller, this.hasDestination});

  /// The capture pipeline to use. A widget test passes one built on fakes; the
  /// application passes none and gets the device's own.
  final CaptureController? controller;

  /// Whether the device already holds a destination, and so whether the shell
  /// opens on capture rather than on the wizard (design §10 of
  /// `implement-setup-wizard`, task 3.5).
  ///
  /// It is handed to [buildAppRouter] untouched, and `null` — what a widget test
  /// and every caller before the first run passes — keeps the router's own
  /// default of *yes*, so nothing is redirected and the shell opens on capture.
  /// `main.dart` passes the device's real answer.
  final Future<bool> Function()? hasDestination;

  @override
  State<PaperdropApp> createState() => _PaperdropAppState();
}

class _PaperdropAppState extends State<PaperdropApp> {
  late final CaptureController _controller =
      widget.controller ?? deviceCaptureController();
  late final GoRouter _router = buildAppRouter(
    controller: _controller,
    hasDestination: widget.hasDestination,
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
