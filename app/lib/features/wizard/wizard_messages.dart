/// The wizard's two message mappings (design §3 and §4), in one place.
///
/// Requirement served: FR-WIZ-003 (`setup-wizard/token-step-via-the-system-browser`) for a failed
/// call's sentence and FR-WIZ-002 (`setup-wizard/steps-auto-omit-when-there-is-nothing-to-choose`)
/// for a step whose list came back empty.
///
/// **Exhaustive by construction.** Each function switches over its enum without a default, so a new
/// failure or notice cannot be added without the compiler asking for its sentence — the pattern
/// `features/capture/capture_messages.dart` already uses.
///
/// **Dispatch 2.2 moves these two switches onto the generated `AppLocalizations`**, whose keys the
/// dispatch A report listed; the shape stays, and the strings move out of code into `app_en.arb`
/// (design §1: no user-visible text in a widget).
library;

import 'wizard_errors.dart';
import 'wizard_step.dart';
import 'wizard_strings.dart';

/// What the user is told about [error] (design §4) — at the token step and at the three list steps
/// behind it, in the same words (the orchestrator's decision of 2026-10-07).
String wizardErrorMessage(WizardStrings strings, WizardError error) =>
    switch (error) {
      WizardError.hostNotValid => strings.errorHostNotValid,
      WizardError.tokenNotAccepted => strings.errorTokenNotAccepted,
      WizardError.hostUnreachable => strings.errorHostUnreachable,
      WizardError.notANinoxApi => strings.errorNotANinoxApi,
      WizardError.ninoxError => strings.errorNinoxError,
    };

/// What a step says when its list holds no option at all (design §3).
///
/// The functional does not specify this case: the design decides the step stays where it is with a
/// plain-language explanation and that no way to continue is invented. The lane reported it as a
/// case it decided, and the design kept it.
String wizardNoticeMessage(WizardStrings strings, WizardNotice notice) =>
    switch (notice) {
      WizardNotice.noTeams => strings.noticeNoTeams,
      WizardNotice.noDatabases => strings.noticeNoDatabases,
      WizardNotice.noTables => strings.noticeNoTables,
    };
