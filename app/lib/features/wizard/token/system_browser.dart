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
import 'package:ninox_client/ninox_client.dart';
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

/// The address of the Ninox page that hands a user an API token (design §4).
///
/// The vendor's own documentation settles it (forum.ninox.com, *Introduction to Ninox API*): on the
/// **public cloud** the token is created at `https://admin.ninox.com` — open **Integrations**, then
/// **New API Key** — and on a **private cloud** at `https://<domain>/admin`. So the address is a
/// function of the endpoint the token step is pointed at, and not a compiled constant (ADR-017: the
/// host is configuration), which is what the placeholder this replaces asked for: the `ninox` skill
/// states no address, and one is not invented here — it is read from the vendor.
///
/// A private cloud keeps **its own port**: the host the user configured is the host whose admin page
/// they are sent to, and the scheme is always `https`, because the token they are about to copy must
/// never travel in clear.
Uri ninoxApiTokenSettingsUri(NinoxEndpoint endpoint) =>
    endpoint == NinoxEndpoint.cloud
    ? Uri(scheme: 'https', host: 'admin.ninox.com')
    : Uri(
        scheme: 'https',
        host: endpoint.host,
        port: endpoint.port,
        path: '/admin',
      );
