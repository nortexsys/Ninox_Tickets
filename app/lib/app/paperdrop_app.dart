import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:paperdrop/app/router.dart';
import 'package:paperdrop/app/theme.dart';
import 'package:paperdrop/l10n/generated/app_localizations.dart';

/// The application shell: routing, theme and the localisation delegates
/// (design §2). Owned by the Mobile lane (setup-mvp-foundations §2).
class PaperdropApp extends StatefulWidget {
  const PaperdropApp({super.key, this.router});

  /// A router to use instead of the application's own. Widget tests pass one so
  /// that they can drive the shell without the platform adapters.
  final GoRouter? router;

  @override
  State<PaperdropApp> createState() => _PaperdropAppState();
}

class _PaperdropAppState extends State<PaperdropApp> {
  late final GoRouter _router = widget.router ?? buildAppRouter();

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
