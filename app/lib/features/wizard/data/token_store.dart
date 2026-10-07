/// Where the token lives between sessions (design §4).
///
/// Requirement served: FR-CFG-004 (`local-config-privacy/token-storage-in-the-platform-keystore`).
/// The token is accepted by the token step and written **here and nowhere else**: not to a file, not
/// to shared preferences, not to a log line and not to any widget state that outlives the step.
///
/// **Why this is an interface and not a plugin call.** The step's ordering rule — the token is
/// written only *after* the validating call succeeded — is a rule of the wizard, and the wizard
/// proves it against a store a test owns. The keystore implementation is
/// `data/keystore_token_store.dart`, and it is the only file that knows the plugin.
///
/// **The clearing action is R1's.** `TokenStore.clear()` exists so that R1's
/// `local-data-clearing` does not have to reopen this interface; nothing in the wizard calls it.
abstract interface class TokenStore {
  /// The stored token, or `null` when the device holds none.
  ///
  /// The send pipeline reads it; the wizard writes it. Nothing prints what this returns.
  Future<String?> read();

  /// Stores [token], replacing any token already stored.
  ///
  /// Called only after the call that proved the token succeeded (design §4).
  Future<void> write(String token);

  /// Removes the stored token. R1's clearing action; no step of the wizard calls it.
  Future<void> clear();
}
