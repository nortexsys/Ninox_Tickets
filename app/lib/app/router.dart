import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:paperdrop/features/capture/capture_controller.dart';
import 'package:paperdrop/features/capture/capture_screen.dart';
import 'package:paperdrop/features/capture/intake_screen.dart';
import 'package:paperdrop/features/wizard/wizard_routes.dart';
import 'package:paperdrop/intake/intake_result.dart';

/// The shell's routes (design §2).
///
/// One entry point reached by several paths (FR-CAP-001), so there is one
/// capture route and none of its own for share-in: a shared document arrives on
/// the capture pipeline and lands on the intake route like the other two.
///
/// The wizard and the send screens are the Ninox lane's, and they are registered
/// **here and only here** — from `wizard_routes.dart` and `send_routes.dart`,
/// exported one entry point per feature (setup-mvp-foundations §2). This change
/// imports nothing from those folders.
const String captureRoute = '/capture';

/// The route a stored document is shown on; `:docId` is its content-free id.
const String intakeRoute = '/intake/:docId';

/// The location of the placeholder for one stored document.
String intakeLocationFor(String docId) => '/intake/$docId';

/// Builds the router of the application.
///
/// [hasDestination] answers whether the device already holds a destination, and it is what makes a
/// **first run** open on the wizard (design §10 of `implement-setup-wizard`, task 3.5): while it
/// answers `false`, any location but the wizard's own is redirected there, and the wizard's own is
/// let through — which is the clause that keeps the redirect from looping. **Its default answers
/// `true`**, so a caller that says nothing about destinations — every test of this shell among
/// them, and every caller of this router before the first run existed — behaves exactly as before
/// and opens on capture. The wizard's closing `onFinished` is this file's `() => router.go(captureRoute)`,
/// and it lands on capture as soon as the answer turns `true`, which the wizard's own store makes it
/// do the moment the destination is saved.
///
/// go_router allows the redirect to be asynchronous, which is what lets the question be asked of the
/// device's file store through the wizard's own `DestinationStore` (design §10).
GoRouter buildAppRouter({
  required CaptureController controller,
  Future<bool> Function()? hasDestination,
}) {
  /// The router itself, so that the wizard's closing screen can hand the user to capture: the
  /// callback is the router's, because the router is what knows [captureRoute] (design §2 of
  /// `implement-setup-wizard` — the wizard imports nothing from this file).
  late final GoRouter router;
  router = GoRouter(
    initialLocation: captureRoute,
    // The first-run redirect (design §10). The wizard is never redirected and the question is not
    // even asked for it: redirecting `/wizard` to `/wizard` is the loop this line exists to avoid.
    redirect: (BuildContext context, GoRouterState state) async {
      if (state.matchedLocation == wizardRoute) {
        return null;
      }
      final bool configured = await (hasDestination ?? _destinationAssumed)();
      return configured ? null : wizardRoute;
    },
    routes: <RouteBase>[
      GoRoute(
        path: captureRoute,
        builder: (BuildContext context, GoRouterState state) =>
            CaptureScreen(controller: controller),
      ),
      GoRoute(
        path: intakeRoute,
        builder: (BuildContext context, GoRouterState state) => IntakeScreen(
          result: state.extra is IntakeResult
              ? state.extra! as IntakeResult
              : null,
        ),
      ),
      // The wizard's own routes, from the Ninox lane's one entry point: the setup wizard
      // (`wizard_routes.dart`) renders the step its controller is on, and a second visit
      // starts a fresh run. The callback is this file's, so the wizard can offer the first
      // capture without knowing this file's routes.
      ...wizardRoutes(onFinished: () => router.go(captureRoute)),
      // Ninox lane: `...sendRoutes` is added here once
      // `app/lib/features/send/send_routes.dart` exists (setup-mvp-foundations
      // §2). Until then the shell has no route to a screen that does not exist.
    ],
  );
  return router;
}

/// The default of [buildAppRouter]'s `hasDestination`: **yes**, the device already holds one.
///
/// A caller that does not say otherwise is not asking for a first-run redirect, so nothing is
/// redirected and the shell opens on capture exactly as it did before the wizard had an entry point
/// (design §10: the existing router tests pass a fake that answers *yes* and are unaffected). The
/// application is not such a caller — `main.dart` hands the device's real answer in.
Future<bool> _destinationAssumed() async => true;
