/// The wizard's routes: the one entry point `router.dart` imports (design §2).
///
/// Requirement served: FR-WIZ-001 (`setup-wizard/five-screens-at-most`) — the wizard is one route and
/// **one** screen at a time, the step the controller is on, and there is no sixth step to reach.
///
/// **Nothing here imports `router.dart`.** The wizard's last screen offers to capture a document, and
/// the router is the only thing that knows the capture route: the design's answer is an `onFinished`
/// callback the router supplies (design §2), so the wizard never needs the shell's own file and there
/// is no cycle. Dispatch 3.3–3.4 adds the closing screen that calls it; until then this file exports
/// the routes as a value and the parameterised builder beside it.
///
/// **The controller is built when the route is entered**, not when the module is loaded and not on
/// every rebuild: `WizardFlow` creates it in its own `initState`, so a second visit starts a fresh
/// run instead of continuing the last one.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:paperdrop/features/wizard/choose/choose_screen.dart';
import 'package:paperdrop/features/wizard/data/keystore_token_store.dart';
import 'package:paperdrop/features/wizard/data/port_factory.dart';
import 'package:paperdrop/features/wizard/token/system_browser.dart';
import 'package:paperdrop/features/wizard/token/token_screen.dart';
import 'package:paperdrop/features/wizard/wizard_controller.dart';
import 'package:paperdrop/features/wizard/wizard_step.dart';
import 'package:paperdrop/l10n/generated/app_localizations.dart';

/// The wizard's route: the location the shell hands to `router.dart` as `...wizardRoutes`.
const String wizardRoute = '/wizard';

/// The wizard's routes, exactly as `router.dart` splices them in.
///
/// A **value** and not a function, because the router's line is one line (task 2.2). It carries the
/// device's composition — the classic adapter, the Keystore and the platform's browser — and
/// [wizardRoutesFor] is what a test uses to splice in a fake instead.
final List<RouteBase> wizardRoutes = wizardRoutesFor();

/// The same routes over the composition a caller supplies.
///
/// [controllerFactory] is called once per visit, when the route is entered. Everything it does not
/// supply is the device's: [deviceWizardController] and [UrlLauncherSystemBrowser].
List<RouteBase> wizardRoutesFor({
  WizardController Function()? controllerFactory,
  SystemBrowser? browser,
}) => <RouteBase>[
  GoRoute(
    path: wizardRoute,
    builder: (BuildContext context, GoRouterState state) =>
        WizardFlow(controllerFactory: controllerFactory, browser: browser),
  ),
];

/// The wizard as the device runs it: the real port composition, the Keystore and the platform's
/// browser.
///
/// The application's other composition — `app/dependencies.dart` — is the Mobile lane's and is not
/// this lane's to write; this function is the wizard's half of it, and it is where the orchestrator
/// can move it once `dependencies.dart` is opened to the Ninox lane.
WizardController deviceWizardController() => WizardController(
  portFactory: classicNinoxPort,
  tokenStorage: const KeystoreTokenStore(),
);

/// The step the controller is on, rendered — one widget, and never two steps at once.
class WizardFlow extends StatefulWidget {
  /// Builds the flow over the composition the caller chose.
  const WizardFlow({super.key, this.controllerFactory, this.browser});

  /// Builds the controller for this visit; the device's when it is `null`.
  final WizardController Function()? controllerFactory;

  /// The platform's browser; the device's when it is `null`, and a fake in every test.
  final SystemBrowser? browser;

  @override
  State<WizardFlow> createState() => _WizardFlowState();
}

class _WizardFlowState extends State<WizardFlow> {
  /// The run's controller: built once, when the route is entered.
  late final WizardController _controller =
      widget.controllerFactory?.call() ?? deviceWizardController();

  late final SystemBrowser _browser =
      widget.browser ?? const UrlLauncherSystemBrowser();

  /// Redraws the step after something on it moved the state on.
  void _stepChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return switch (_controller.step) {
      WizardStep.token => TokenScreen(
        controller: _controller,
        browser: _browser,
        onStepChanged: _stepChanged,
      ),
      WizardStep.team || WizardStep.database || WizardStep.table =>
        ChooseScreen(controller: _controller, onStepChanged: _stepChanged),
      WizardStep.mapping => const _MappingStep(),
    };
  }
}

/// The mapping step, until its screen lands.
///
/// The mapping step's screen is dispatch 3.3's and its summary 3.4's. Until they exist this is the
/// wizard's own frame and nothing else: **no sixth screen** and no sentence invented for a screen
/// that is not written yet (`setup-wizard/five-screens-at-most`, design §3).
class _MappingStep extends StatelessWidget {
  const _MappingStep();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Scaffold(appBar: AppBar(title: Text(l10n.wizardTitle)));
  }
}
