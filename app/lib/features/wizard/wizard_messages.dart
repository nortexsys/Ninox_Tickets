/// The wizard's two message mappings (design §3 and §4), in one place.
///
/// Requirement served: FR-WIZ-003 (`setup-wizard/token-step-via-the-system-browser`) for the token
/// step's messages and FR-WIZ-002 (`setup-wizard/steps-auto-omit-when-there-is-nothing-to-choose`)
/// for a step whose list came back empty.
///
/// **Exhaustive by construction.** Each function switches over its enum without a default, so a new
/// failure or notice cannot be added without the compiler asking for its sentence — the pattern
/// `features/capture/capture_messages.dart` already uses. Dispatch B moves these two switches onto
/// the generated `AppLocalizations` keys the report lists; nothing else about them changes.
library;

import 'token/token_errors.dart';
import 'wizard_step.dart';
import 'wizard_strings.dart';

/// What the token step tells the user about [error] (design §4).
String tokenStepErrorMessage(WizardStrings strings, TokenStepError error) =>
    switch (error) {
      TokenStepError.hostNotValid => strings.errorHostNotValid,
      TokenStepError.tokenNotAccepted => strings.errorTokenNotAccepted,
      TokenStepError.hostUnreachable => strings.errorHostUnreachable,
      TokenStepError.notANinoxApi => strings.errorNotANinoxApi,
      TokenStepError.ninoxError => strings.errorNinoxError,
    };

/// What a step says when its list holds no option at all (design §3).
///
/// The functional does not specify this case: the design decides the step stays where it is with a
/// plain-language explanation and that no way to continue is invented. The lane reports it as a
/// case it decided.
String wizardNoticeMessage(WizardStrings strings, WizardNotice notice) =>
    switch (notice) {
      WizardNotice.noTeams => strings.noticeNoTeams,
      WizardNotice.noDatabases => strings.noticeNoDatabases,
      WizardNotice.noTables => strings.noticeNoTables,
    };
