/// Why a call the wizard made did not succeed, as the one table design §4 states it.
///
/// Requirement served: FR-WIZ-003 (`setup-wizard/token-step-via-the-system-browser`) and, through
/// it, FR-DST-008's validation half (`destinations-mapping/configurable-ninox-host`): the host is
/// validated by its effect at the token step, exactly as the token is, so an unreachable host is
/// reported there and not deferred to the first send.
///
/// **One table for every call the wizard makes.** The token step's validating call is where the
/// table was first needed, and the three list calls behind it fail in exactly the same ways — so
/// they are shown in the same words. The orchestrator decided this on 2026-10-07: a failure from
/// `listDatabases` or `listTables` takes the same sentence, the user stays on the step that made the
/// call and can retry it. Nothing here is the send pipeline's failure classification (T1.11): this
/// enum names what the *user is told*, not what the pipeline does next.
///
/// **One call decides.** At the token step the wizard builds the port from the parsed endpoint and
/// the pasted token and calls `listTeams()`. That single call validates the token **and** the host,
/// and its result is the next step's list, so a valid token costs one round trip (design §4).
///
/// **No message this file produces can carry the token.** Every message is a fixed string, read from
/// the string resources, and the failure's own text — which `packages/ninox_client` already redacts —
/// is deliberately not shown: what the user needs is what to do next, not what Ninox answered.
library;

import 'package:ninox_client/ninox_client.dart';

/// What the user is told when a wizard call did not succeed.
enum WizardError {
  /// The host as typed is not an accepted form. Reported **at the field**, and the validating call
  /// is not made at all. Only the token step can produce this one: every other step's host is the
  /// endpoint the token step already parsed.
  hostNotValid,

  /// `Unauthorized`: Ninox did not accept the token — for the first call, or for a list call made
  /// after a token that has since been revoked.
  tokenNotAccepted,

  /// `TransportFailure`: the host could not be reached — the address and the connection are the two
  /// things to check.
  hostUnreachable,

  /// `UnexpectedResponse`: the address answered, but not as a Ninox API.
  notANinoxApi,

  /// Everything Ninox answered with an error about: `ServerError`, `RateLimited`, `NotFound` and
  /// any other failure. The user is asked to try again.
  ninoxError,
}

/// Maps a failure of any of the wizard's calls to what the user is told, in full (design §4's
/// table).
///
/// The last row of that table — *Ninox answered with an error — try again* — takes `NotFound` and
/// **any other** [NinoxFailure], which is why the switch has no default and the sealed class is what
/// makes that checkable: a new failure type cannot be added without this function asking for its row.
WizardError wizardErrorFor(NinoxFailure failure) => switch (failure) {
  Unauthorized() => WizardError.tokenNotAccepted,
  TransportFailure() => WizardError.hostUnreachable,
  UnexpectedResponse() => WizardError.notANinoxApi,
  ServerError() || RateLimited() || NotFound() => WizardError.ninoxError,
};
