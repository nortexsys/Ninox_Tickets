/// The one credential this client takes: a Ninox personal access token.
///
/// BR-19 (`product-invariants/token-is-the-only-credential`): the token is the only credential
/// the app asks for, stores or transmits. Where it comes from — the platform's system browser,
/// the keystore — is the app's and the wizard's (FR-CFG-004, T1.10); this package only receives
/// it, and this class is the only place it is held.
///
/// The token never leaves the `Authorization` header: it is not in any [toString], exception
/// message or log line, and a contract test strings every failure of this package and searches
/// it for the token (design §1).
///
/// Immutable and compared by value.
final class NinoxCredentials {
  /// Wraps one personal access token.
  ///
  /// The value is **not** validated here — a token is checked by its effect, never by its
  /// shape, and the wizard's token step (T1.10, FR-CFG-004) is where that happens.
  const NinoxCredentials(this.token);

  /// The personal access token, as the user obtained it. Never printed.
  final String token;

  /// The single header it travels in, `Bearer <token>` (ADR-004, verified).
  String get authorizationHeader => 'Bearer $token';

  /// Prints the type and nothing else: a token in a log is a compromised token.
  @override
  String toString() => 'NinoxCredentials(***)';

  @override
  bool operator ==(Object other) =>
      other is NinoxCredentials && other.token == token;

  @override
  int get hashCode => token.hashCode;
}
