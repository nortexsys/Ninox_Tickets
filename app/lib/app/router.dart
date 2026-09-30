import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:paperdrop/features/capture/capture_controller.dart';
import 'package:paperdrop/features/capture/capture_screen.dart';
import 'package:paperdrop/features/capture/intake_screen.dart';
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
GoRouter buildAppRouter({required CaptureController controller}) {
  return GoRouter(
    initialLocation: captureRoute,
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
      // Ninox lane: `...wizardRoutes` and `...sendRoutes` are added here once
      // `app/lib/features/wizard/wizard_routes.dart` and
      // `app/lib/features/send/send_routes.dart` exist (setup-mvp-foundations
      // §2). Until then the shell has no route to a screen that does not exist.
    ],
  );
}
