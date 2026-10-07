/// The platform's own browser, and the address the token step opens in it (design §4).
///
/// Requirement served: FR-WIZ-003 (`setup-wizard/token-step-via-the-system-browser`) and
/// NFR-SEC-002 with it: the token is obtained through the platform's browser — Custom Tabs on
/// Android, SFSafariViewController on iOS — and **never** through a browser view the app renders
/// itself. The scan in `app/test/features/wizard/` reads `app/pubspec.yaml` and `app/lib/` for that
/// forbidden thing, because a rule of this kind is only as good as the check behind it.
///
/// **Why a port.** The step needs one capability — ask the platform to show a page — and the
/// platform's launcher is not something a widget test installs. The port is small enough that its
/// implementation is one call, and a test drives the step with a fake (design §1: no test needs a
/// device).
library;

/// The platform's browser, as the token step uses it.
abstract interface class SystemBrowser {
  /// Asks the platform to show [url] in its own browser.
  ///
  /// Returns `true` when the platform opened it and `false` when it would not. The step does not
  /// show the difference: the design states no behaviour for a refused launch, so none is invented
  /// here (reported to the orchestrator), and the instructions on the screen still tell the user how
  /// to obtain a token by hand.
  Future<bool> open(Uri url);
}

/// The address of the Ninox page that hands a user an API token.
///
/// TODO(orchestrator): **this address is not established, and this constant is deliberately not a
/// guess.** Design §4 requires the token step's *Open Ninox settings* action to open Ninox's
/// settings page in the platform's browser, and to take the address from the `ninox` skill's
/// reference; the skill states none. What it does state is the API's own base —
/// `https://api.ninox.com/v1` (`SKILL.md`, `references/rest-api.md`) — and nothing about the web
/// UI's settings path. So the constant is `null`, the action is disabled while it is, and dispatch
/// A reports it blocked rather than inventing a URL.
///
/// Replace it with the confirmed value, in this one file, before the demo of Fri 9 Oct; the step
/// takes it as a parameter (`TokenScreen.settingsUri`), so a test can also hand in an address of
/// its own.
const Uri? ninoxApiTokenSettingsUri = null;
