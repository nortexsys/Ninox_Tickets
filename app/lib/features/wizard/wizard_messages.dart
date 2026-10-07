/// The wizard's two message mappings (design §3 and §4), in one place.
///
/// Requirement served: FR-WIZ-003 (`setup-wizard/token-step-via-the-system-browser`) for a failed
/// call's sentence and FR-WIZ-002 (`setup-wizard/steps-auto-omit-when-there-is-nothing-to-choose`)
/// for a step whose list came back empty.
///
/// **Exhaustive by construction.** Each function switches over its enum without a default, so a new
/// failure or notice cannot be added without the compiler asking for its sentence — the pattern
/// `features/capture/capture_messages.dart` already uses. Every sentence is an `app_en.arb` key
/// (`wizardError*`, `wizardNotice*`), so nothing the wizard shows is a literal in code (design §1).
///
/// **One table for every call the wizard makes.** The token step's validating call is where the
/// four failure sentences were first needed; the three list calls behind it are shown in the same
/// words (the orchestrator's decision of 2026-10-07).
library;

import 'package:paperdrop/l10n/generated/app_localizations.dart';

import 'wizard_errors.dart';
import 'wizard_step.dart';

/// What the user is told about [error] (design §4) — at the token step and at the three list steps
/// behind it, in the same words.
String wizardErrorMessage(AppLocalizations l10n, WizardError error) =>
    switch (error) {
      WizardError.hostNotValid => l10n.wizardErrorHostNotValid,
      WizardError.tokenNotAccepted => l10n.wizardErrorTokenNotAccepted,
      WizardError.hostUnreachable => l10n.wizardErrorHostUnreachable,
      WizardError.notANinoxApi => l10n.wizardErrorNotANinoxApi,
      WizardError.ninoxError => l10n.wizardErrorNinoxError,
    };

/// What a step says when its list holds no option at all (design §3).
///
/// The functional does not specify this case: the design decides the step stays where it is with a
/// plain-language explanation and that no way to continue is invented. The lane reported it as a
/// case it decided, and the design kept it. Nothing is said while a call has failed — see
/// `WizardState.notice`.
String wizardNoticeMessage(AppLocalizations l10n, WizardNotice notice) =>
    switch (notice) {
      WizardNotice.noTeams => l10n.wizardNoticeNoTeams,
      WizardNotice.noDatabases => l10n.wizardNoticeNoDatabases,
      WizardNotice.noTables => l10n.wizardNoticeNoTables,
    };
