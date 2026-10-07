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
import 'package:paperdrop/features/wizard/destination.dart';
import 'package:paperdrop/features/wizard/mapping/mapping_screen.dart';
import 'package:paperdrop/features/wizard/token/system_browser.dart';
import 'package:paperdrop/features/wizard/token/token_screen.dart';
import 'package:paperdrop/features/wizard/wizard_controller.dart';
import 'package:paperdrop/features/wizard/wizard_step.dart';

/// The wizard's route: the location the shell hands to `router.dart` as `...wizardRoutes`.
const String wizardRoute = '/wizard';

/// The wizard's routes: the one entry point `router.dart` imports (design §2).
///
/// It is a **function** and not the value design §2 sketches, and the reason is the same sentence of
/// that design: the routes *"take what they need (controller factory, `onFinished`) from deps passed
/// by the router"*. A value can carry neither, and the shell is the only thing that knows
/// `captureRoute`, so the closing screen's offer to capture has to arrive from there.
///
/// [controllerFactory] is called once per visit, when the route is entered; [browser] and
/// [onFinished] are what a test replaces. Everything a caller does not supply is the device's:
/// [deviceWizardController] and [UrlLauncherSystemBrowser].
List<RouteBase> wizardRoutes({
  WizardController Function()? controllerFactory,
  SystemBrowser? browser,
  VoidCallback? onFinished,
}) => <RouteBase>[
  GoRoute(
    path: wizardRoute,
    builder: (BuildContext context, GoRouterState state) => WizardFlow(
      controllerFactory: controllerFactory,
      browser: browser,
      onFinished: onFinished,
    ),
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
  const WizardFlow({
    super.key,
    this.controllerFactory,
    this.browser,
    this.onFinished,
  });

  /// Builds the controller for this visit; the device's when it is `null`.
  final WizardController Function()? controllerFactory;

  /// The platform's browser; the device's when it is `null`, and a fake in every test.
  final SystemBrowser? browser;

  /// What the wizard calls when the user accepts its offer to capture the first document — the
  /// router's, because the router is what knows the capture route (design §2).
  final VoidCallback? onFinished;

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
      WizardStep.mapping => MappingScreen(
        controller: _controller,
        onCompleted: _mappingCompleted,
      ),
    };
  }

  /// The mapping step's completion.
  ///
  /// The mapping belongs to the run's state; what comes next is dispatch 3.4's closing summary, which
  /// takes this step's place rather than becoming a sixth step (design §3). Until it lands the wizard
  /// hands the user on through the callback the router supplied.
  Future<void> _mappingCompleted(List<FieldMapping> mappings) async {
    _controller.mapFields(mappings);
    final VoidCallback? finished = widget.onFinished;
    if (finished != null && mounted) {
      finished();
    }
  }
}
