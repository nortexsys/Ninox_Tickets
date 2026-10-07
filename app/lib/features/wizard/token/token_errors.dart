/// Why the token step did not pass, as the one table design §4 states it.
///
/// Requirement served: FR-WIZ-003 (`setup-wizard/token-step-via-the-system-browser`) and, through
/// it, FR-DST-008's validation half (`destinations-mapping/configurable-ninox-host`): the host is
/// validated by its effect at this step, exactly as the token is, so an unreachable host is
/// reported here and not deferred to the first send.
///
/// **One call decides.** The step builds the port from the parsed endpoint and the pasted token and
/// calls `listTeams()`. That single call validates the token **and** the host, and its result is the
/// next step's list, so a valid token costs one round trip (design §4).
///
/// **No message this file produces can carry the token.** Every message is a fixed string from
/// [WizardStrings], and the failure's own text — which `packages/ninox_client` already redacts — is
/// deliberately not shown: what the user needs is what to do next, not what Ninox answered.
library;

import 'package:ninox_client/ninox_client.dart';

/// The five outcomes design §4 maps, and nothing else.
enum TokenStepError {
  /// The host as typed is not an accepted form. Reported **at the field**, and the validating call
  /// is not made at all.
  hostNotValid,

  /// `Unauthorized`: Ninox did not accept the token.
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

/// Maps a failure of the validating call to what the user is told, in full (design §4's table).
///
/// The last row of that table — *Ninox answered with an error — try again* — takes `NotFound` and
/// **any other** [NinoxFailure], which is why the switch has no default and the sealed class is
/// what makes that checkable: a new failure type cannot be added without this function asking for
/// its row.
TokenStepError tokenStepErrorFor(NinoxFailure failure) => switch (failure) {
  Unauthorized() => TokenStepError.tokenNotAccepted,
  TransportFailure() => TokenStepError.hostUnreachable,
  UnexpectedResponse() => TokenStepError.notANinoxApi,
  ServerError() || RateLimited() || NotFound() => TokenStepError.ninoxError,
};
