/// The token, in the Android Keystore (design §4).
///
/// Requirement served: FR-CFG-004 (`local-config-privacy/token-storage-in-the-platform-keystore`):
/// the token the token step accepted is written to the platform's keystore **and nowhere else** —
/// not to a file, not to shared preferences, not to a log line. This class is the only
/// implementation of `TokenStore` that a device uses, and the only file in the wizard that knows the
/// plugin.
///
/// **The Keystore-backed mode, verified in this session.** `flutter_secure_storage` 10.3.4, asked
/// with no options, sends its Android platform call with
/// `encryptedSharedPreferences: false` and `keyCipherAlgorithm: RSA_ECB_OAEPwithSHA_256andMGF1Padding`
/// / `storageCipherAlgorithm: AES_GCM_NoPadding` — the Android Keystore-backed cipher, which is the
/// mode design §4 requires. The plugin's `encryptedSharedPreferences` parameter is deprecated in this
/// version ("will be removed in v11 … Remove this parameter — it will be ignored"), so the store
/// passes no options at all rather than a deprecated one.
///
/// **What the platform does with it is not claimed here.** That the Keystore keeps the key out of an
/// Android backup, and that a restore yields nothing in plaintext, is verified on the device in the
/// T1.12–T1.13 session (design §9); the test beside this file proves the plugin's own call shape and
/// nothing about the device.
library;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'token_store.dart';

/// The Ninox token, held by the platform's keystore.
final class KeystoreTokenStore implements TokenStore {
  /// Builds the store. There is nothing to configure: the plugin's default Android mode is the
  /// Keystore-backed one (see this file's header).
  const KeystoreTokenStore();

  /// The key the token is stored under: a name the app chose, never a value the user typed. A
  /// second kind of secret would take a key of its own rather than share this one.
  static const String tokenKey = 'paperdrop.ninox.token';

  /// The plugin's client, in its default mode.
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  @override
  Future<String?> read() => _storage.read(key: tokenKey);

  @override
  Future<void> write(String token) =>
      _storage.write(key: tokenKey, value: token);

  /// Removes **the token's own entry** and nothing else: `delete` with this key, not `deleteAll`,
  /// which would empty whatever else the plugin holds for this application.
  @override
  Future<void> clear() => _storage.delete(key: tokenKey);
}
