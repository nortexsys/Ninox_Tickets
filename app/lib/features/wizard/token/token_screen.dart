/// The token step (design §4).
///
/// Requirement served: FR-WIZ-003 (`setup-wizard/token-step-via-the-system-browser`), with
/// FR-DST-008's validation half (`destinations-mapping/configurable-ninox-host`) — the host is
/// validated by its effect here, as the token is — and FR-CFG-004's storage half, which the
/// controller's single write to the token store implements.
///
/// **What the screen offers.** The instructions, a field for the token, a *Paste* action that reads
/// the clipboard and trims it, an action that opens Ninox's own page in the platform's browser (and
/// never a browser the app renders itself), and — collapsed — the advanced setup holding the host,
/// which defaults to the vendor's cloud. One action validates: it parses the host, makes the single
/// call that validates the token **and** the host, and takes the next step's list from that same
/// call.
///
/// **The token does not linger.** It is read from the field when the action is pressed, and the
/// field is emptied as soon as the step has passed: after that the device's keystore is the only
/// place it lives (design §1, FR-CFG-004).
///
/// **No text is a literal here.** Every sentence comes from a [WizardStrings] seam, which dispatch B
/// replaces with the generated localisations, key for key (design §1).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../wizard_controller.dart';
import '../wizard_messages.dart';
import '../wizard_step.dart';
import '../wizard_strings.dart';
import 'system_browser.dart';
import 'token_errors.dart';

/// The first screen of the wizard.
class TokenScreen extends StatefulWidget {
  /// Builds the step over a controller and the platform's browser.
  const TokenScreen({
    super.key,
    required this.controller,
    required this.browser,
    this.settingsUri = ninoxApiTokenSettingsUri,
    this.strings = const WizardStrings(),
  });

  /// The state machine this step drives.
  final WizardController controller;

  /// The platform's browser; a fake in every test.
  final SystemBrowser browser;

  /// The address of Ninox's settings page, or `null` while it is not established — then the action
  /// that would open it is disabled rather than opening a guessed address.
  final Uri? settingsUri;

  /// The step's text (design §1): one seam, replaced by the localisations in dispatch B.
  final WizardStrings strings;

  /// The token field, so a test finds the obscured one without guessing.
  static const Key tokenFieldKey = Key('wizard-token-field');

  /// The advanced setup's host field.
  static const Key hostFieldKey = Key('wizard-host-field');

  @override
  State<TokenScreen> createState() => _TokenScreenState();
}

class _TokenScreenState extends State<TokenScreen> {
  final TextEditingController _token = TextEditingController();
  late final TextEditingController _host = TextEditingController(
    text: widget.controller.state.endpoint.host,
  );

  @override
  void dispose() {
    _token.dispose();
    _host.dispose();
    super.dispose();
  }

  /// The failure the field itself reports: the host as typed is not an accepted form.
  String? get _hostError =>
      widget.controller.state.error == TokenStepError.hostNotValid
      ? tokenStepErrorMessage(widget.strings, TokenStepError.hostNotValid)
      : null;

  /// The failure the step reports below the field: everything except the one above.
  String? get _message {
    final TokenStepError? error = widget.controller.state.error;
    if (error == null || error == TokenStepError.hostNotValid) {
      return null;
    }
    return tokenStepErrorMessage(widget.strings, error);
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
  Future<void> _openSettings() async {
    final Uri? settings = widget.settingsUri;
    if (settings == null) {
      return;
    }
    await widget.browser.open(settings);
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
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final WizardStrings strings = widget.strings;
    final bool busy = widget.controller.state.busy;
    final String? message = _message;
    return Scaffold(
      appBar: AppBar(title: Text(strings.wizardTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: <Widget>[
            Text(strings.tokenInstructions, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 24),
            TextField(
              key: TokenScreen.tokenFieldKey,
              controller: _token,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: strings.tokenFieldLabel,
                hintText: strings.tokenFieldHint,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              children: <Widget>[
                OutlinedButton.icon(
                  onPressed: _paste,
                  icon: const Icon(Icons.content_paste),
                  label: Text(strings.tokenPasteAction),
                ),
                OutlinedButton.icon(
                  onPressed: widget.settingsUri == null ? null : _openSettings,
                  icon: const Icon(Icons.open_in_new),
                  label: Text(strings.tokenOpenSettingsAction),
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
              title: Text(strings.tokenAdvancedTitle),
              children: <Widget>[
                TextField(
                  key: TokenScreen.hostFieldKey,
                  controller: _host,
                  autocorrect: false,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    labelText: strings.tokenHostLabel,
                    hintText: strings.tokenHostHint,
                    helperText: strings.tokenHostHelp,
                    errorText: _hostError,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: busy ? null : _connect,
              child: Text(strings.tokenConnectAction),
            ),
          ],
        ),
      ),
    );
  }
}
