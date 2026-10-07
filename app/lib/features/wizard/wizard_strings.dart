/// The wizard's user-visible text, in one seam (design §1, plan §2).
///
/// **This class is temporary and dispatch B replaces it.** The project's rule is that no
/// user-visible text is a literal in a widget: every string is an `app_en.arb` key read through the
/// generated `AppLocalizations` (NFR-I18N-001). This dispatch may not touch `app/lib/l10n/`, so the
/// token step's text is read through this seam instead, in the same shape it will have afterwards —
/// a widget holds a [WizardStrings] and never a literal. Dispatch B moves every value below into
/// `app_en.arb` under a `wizard`-prefixed key and deletes this class; the lane's report lists the
/// keys it will need.
///
/// **What this seam must not become.** It is not a licence to keep text in code: a screen that adds
/// a string here without listing it for the ARB file would leave the wizard untranslatable, and the
/// German interface of R1 would meet a literal.
library;

/// The wizard's text, as one immutable, replaceable value.
final class WizardStrings {
  /// The one instance a screen needs. A test may build another, but nothing else varies.
  const WizardStrings();

  /// The wizard's own title, for the app bar of any of its screens.
  String get wizardTitle => 'Set up Ninox';

  /// The token step: what the user is asked to do, in plain language.
  String get tokenInstructions =>
      'Open Ninox in your browser, copy an API token and paste it below.';

  /// The token field's label.
  String get tokenFieldLabel => 'API token';

  /// The token field's hint.
  String get tokenFieldHint => 'Paste the token from Ninox';

  /// The action that fills the field from the clipboard.
  String get tokenPasteAction => 'Paste';

  /// The action that opens Ninox's own page in the platform's browser.
  String get tokenOpenSettingsAction => 'Open Ninox settings';

  /// The collapsed section holding the host.
  String get tokenAdvancedTitle => 'Advanced setup';

  /// The host field's label.
  String get tokenHostLabel => 'Ninox host';

  /// The host field's hint, which is the vendor's cloud host.
  String get tokenHostHint => 'api.ninox.com';

  /// Why the host field exists at all: a private cloud has another host.
  String get tokenHostHelp => 'Change this only for a Ninox private cloud.';

  /// The action that validates the host and the token.
  String get tokenConnectAction => 'Connect';

  /// The team step's question.
  String get teamStepTitle => 'Which team should Paperdrop use?';

  /// The database step's question.
  String get databaseStepTitle => 'Which database?';

  /// The table step's question.
  String get tableStepTitle => 'Which table should the documents go to?';

  /// The action that returns to the previous step.
  String get backAction => 'Back';

  /// The action that runs a failed call again, from the step it failed on.
  String get tryAgainAction => 'Try again';

  /// What the host field says when what was typed is not an accepted form.
  String get errorHostNotValid => 'That is not a valid host.';

  /// What the token step says when Ninox did not accept the token.
  String get errorTokenNotAccepted => 'Ninox did not accept that token.';

  /// What the token step says when the host did not answer at all.
  String get errorHostUnreachable =>
      'The host could not be reached. Check the address and your connection.';

  /// What the token step says when the address answered but is not a Ninox API.
  String get errorNotANinoxApi =>
      'That address answered, but it is not a Ninox API.';

  /// What the token step says for every other failure Ninox reported.
  String get errorNinoxError => 'Ninox answered with an error. Try again.';

  /// What the team step says when the account can see no team.
  String get noticeNoTeams => 'This account can see no team.';

  /// What the database step says when the chosen team holds no database.
  String get noticeNoDatabases => 'This team holds no database.';

  /// What the table step says when the chosen database holds no table.
  String get noticeNoTables => 'This database holds no table.';
}
