/// The platform's own browser, and the address the token step opens in it (design §4).
///
/// Requirement served: FR-WIZ-003 (`setup-wizard/token-step-via-the-system-browser`) and
/// NFR-SEC-002 with it: the page is shown by the platform's browser — Custom Tabs on Android, the
/// platform's in-app browser view on iOS — and **never** through a browser view the app renders
/// itself. The scan in `app/test/features/wizard/` reads `app/pubspec.yaml` and `app/lib/` for that
/// forbidden thing, because a rule of this kind is only as good as the check behind it.
///
/// **Why a port.** The step needs one capability — ask the platform to show a page — and the
/// platform's launcher is not something a widget test installs. The port is small enough that its
/// implementation is one call, and a test drives the step with a fake (design §1: no test needs a
/// device).
library;

import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// The platform's browser, as the token step uses it.
abstract interface class SystemBrowser {
  /// Asks the platform to show [url] in its own browser.
  ///
  /// Returns `true` when the platform opened it and `false` when it would not — a platform with no
  /// browser for the address answers rather than throwing, so no caller has to know how the
  /// platform failed. The step does not show the difference: the design states no behaviour for a
  /// refused launch, so none is invented here, and the instructions on the screen still tell the
  /// user how to obtain a token by hand.
  Future<bool> open(Uri url);
}

/// The one implementation: `url_launcher`, in the platform's browser.
///
/// `LaunchMode.inAppBrowserView` is what design §4 names — a Custom Tab on Android, the platform's
/// in-app browser view on iOS: a view the **platform** owns, which is why this is the one
/// implementation and why the scan beside it keeps the package free of a browser of the app's own
/// (NFR-SEC-002).
class UrlLauncherSystemBrowser implements SystemBrowser {
  /// Builds the launcher. There is nothing to configure.
  const UrlLauncherSystemBrowser();

  @override
  Future<bool> open(Uri url) async {
    try {
      return await launchUrl(url, mode: LaunchMode.inAppBrowserView);
    } on PlatformException {
      // The port's contract is a boolean and not an exception: a platform that cannot open the page
      // answers false, and the caller decides what, if anything, to say about it.
      return false;
    }
  }
}

/// The address of the Ninox page that hands a user an API token.
///
/// TODO(orchestrator): **this address is not established, and this constant is deliberately not a
/// guess.** Design §4 requires the token step's *Open Ninox settings* action to open Ninox's
/// settings page in the platform's browser, and to take the address from the `ninox` skill's
/// reference; the skill states none. What it does state is the API's own base —
/// `https://api.ninox.com/v1` (`SKILL.md`, `references/rest-api.md`) — and nothing about the web
/// UI's settings path. So the constant stays `null` and the action is not shown while it is
/// (orchestrator, 2026-10-07: *do not invent a URL*); the instructions tell the user to create the
/// token in Ninox's own settings instead.
///
/// Replace it with the confirmed value, in this one file, before the demo of Fri 9 Oct: the step
/// takes it as a parameter (`TokenScreen.settingsUri`), so a test can also hand in an address of its
/// own, and [UrlLauncherSystemBrowser] is already wired to whatever it holds.
const Uri? ninoxApiTokenSettingsUri = null;
