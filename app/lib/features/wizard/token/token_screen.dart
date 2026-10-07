/// The token step (design §4).
///
/// Requirement served: FR-WIZ-003 (`setup-wizard/token-step-via-the-system-browser`), with
/// FR-DST-008's validation half (`destinations-mapping/configurable-ninox-host`) — the host is
/// validated by its effect here, as the token is — and FR-CFG-004's storage half, which the
/// controller's single write to the token store implements.
///
/// **What the screen offers.** The instructions — *Integrations*, then *New API Key*, in Ninox's own
/// settings — a field for the token, a *Paste* action that reads the clipboard and trims it, an action
/// that opens that settings page in the platform's browser, and, collapsed, the advanced setup holding
/// the host, which defaults to the vendor's cloud. One action validates: it parses the host, makes the
/// single call that validates the token **and** the host, and takes the next step's list from that
/// same call.
///
/// **The action that opens Ninox's own page.** Design §4 puts it behind the `SystemBrowser` port and
/// says the platform's browser shows the page, never one the app renders itself. The address follows
/// the endpoint the step is pointed at — `https://admin.ninox.com` on the public cloud, and
/// `https://<the configured host>/admin` for a private cloud — and it comes from the vendor's own
/// documentation (`system_browser.dart`).
///
/// **The token does not linger.** It is read from the field when the action is pressed, and the
/// field is emptied as soon as the step has passed: after that the device's keystore is the only
/// place it lives (design §1, FR-CFG-004).
///
/// **No text is a literal here.** Every sentence is a `wizard`-prefixed key of `app_en.arb`, read
/// through the generated localisations (design §1, NFR-I18N-001).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ninox_client/ninox_client.dart';
import 'package:paperdrop/l10n/generated/app_localizations.dart';

import '../wizard_controller.dart';
import '../wizard_errors.dart';
import '../wizard_messages.dart';
import '../wizard_step.dart';
import 'system_browser.dart';

/// The first screen of the wizard.
class TokenScreen extends StatefulWidget {
  /// Builds the step over a controller and the platform's browser.
  const TokenScreen({
    super.key,
    required this.controller,
    required this.browser,
    this.onStepChanged,
  });

  /// The state machine this step drives.
  final WizardController controller;

  /// The platform's browser; a fake in every test.
  final SystemBrowser browser;

  /// Called after the validating call completed, so a host that draws the whole wizard — one widget
  /// per step — can redraw the step it should be showing.
  final VoidCallback? onStepChanged;

  /// The token field, so a test finds the obscured one without guessing.
  static const Key tokenFieldKey = Key('wizard-token-field');

  /// The advanced setup's host field.
  static const Key hostFieldKey = Key('wizard-host-field');

  /// The host as the field shows it and reads it back: the endpoint's host, and its port when it has
  /// one, which is the form `NinoxEndpoint.parse` accepts.
  ///
  /// A private cloud configured on `ninox.example.de:8443` would otherwise come back as
  /// `ninox.example.de` the moment the field was prefilled from the state, and the next call would go
  /// to the default port instead of the user's.
  static String hostText(NinoxEndpoint endpoint) => endpoint.port == null
      ? endpoint.host
      : '${endpoint.host}:${endpoint.port}';

  @override
  State<TokenScreen> createState() => _TokenScreenState();
}

class _TokenScreenState extends State<TokenScreen> {
  final TextEditingController _token = TextEditingController();
  late final TextEditingController _host = TextEditingController(
    text: TokenScreen.hostText(widget.controller.state.endpoint),
  );

  @override
  void dispose() {
    _token.dispose();
    _host.dispose();
    super.dispose();
  }

  /// The failure the field itself reports: the host as typed is not an accepted form.
  String? _hostError(AppLocalizations l10n) =>
      widget.controller.state.error == WizardError.hostNotValid
      ? wizardErrorMessage(l10n, WizardError.hostNotValid)
      : null;

  /// The failure the step reports below the field: everything except the one above.
  String? _message(AppLocalizations l10n) {
    final WizardError? error = widget.controller.state.error;
    if (error == null || error == WizardError.hostNotValid) {
      return null;
    }
    return wizardErrorMessage(l10n, error);
  }

  /// Fills the field from the clipboard, trimmed (design §4).
  ///
  /// An empty clipboard changes nothing: a token is never invented and an empty one is never
  /// submitted for the user.
  Future<void> _paste() async {
    final ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
    final String? pasted = data?.text?.trim();
    if (pasted == null || pasted.isEmpty) {
      return;
    }
    _token.text = pasted;
  }

  /// Opens Ninox's own page in the platform's browser.
  ///
  /// The address follows the endpoint the step is pointed at: the field's host when it is one
  /// `NinoxEndpoint.parse` accepts, and the endpoint the state already holds otherwise — which is the
  /// vendor's cloud until a token has been accepted — so a half-typed host never opens a page nobody
  /// meant. The page is the platform's, never one this app renders (NFR-SEC-002).
  Future<void> _openSettings() async {
    final NinoxEndpoint endpoint =
        NinoxEndpoint.parse(_host.text) ?? widget.controller.state.endpoint;
    await widget.browser.open(ninoxApiTokenSettingsUri(endpoint));
  }

  /// The one validating call (design §4).
  Future<void> _connect() async {
    final Future<void> attempt = widget.controller.connect(
      host: _host.text,
      token: _token.text,
    );
    // The call is in flight: the action holds until it answers.
    setState(() {});
    await attempt;
    if (!mounted) {
      return;
    }
    if (widget.controller.step != WizardStep.token) {
      // The token has done its job; the keystore holds it from here on (FR-CFG-004).
      _token.clear();
    }
    setState(() {});
    widget.onStepChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool busy = widget.controller.state.busy;
    final String? message = _message(l10n);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.wizardTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: <Widget>[
            Text(
              l10n.wizardTokenInstructions,
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            TextField(
              key: TokenScreen.tokenFieldKey,
              controller: _token,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: l10n.wizardTokenFieldLabel,
                hintText: l10n.wizardTokenFieldHint,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              children: <Widget>[
                OutlinedButton.icon(
                  onPressed: _paste,
                  icon: const Icon(Icons.content_paste),
                  label: Text(l10n.wizardTokenPasteAction),
                ),
                // The page is the vendor's own settings page, in the platform's browser and never a
                // browser this app renders (NFR-SEC-002).
                OutlinedButton.icon(
                  onPressed: _openSettings,
                  icon: const Icon(Icons.open_in_new),
                  label: Text(l10n.wizardTokenOpenSettingsAction),
                ),
              ],
            ),
            if (message != null) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 24),
            ExpansionTile(
              title: Text(l10n.wizardTokenAdvancedTitle),
              children: <Widget>[
                TextField(
                  key: TokenScreen.hostFieldKey,
                  controller: _host,
                  autocorrect: false,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    labelText: l10n.wizardTokenHostLabel,
                    hintText: l10n.wizardTokenHostHint,
                    helperText: l10n.wizardTokenHostHelp,
                    errorText: _hostError(l10n),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (busy) const LinearProgressIndicator(),
            FilledButton(
              onPressed: busy ? null : _connect,
              child: Text(l10n.wizardTokenConnectAction),
            ),
          ],
        ),
      ),
    );
  }
}
