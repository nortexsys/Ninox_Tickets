import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperdrop/features/wizard/data/keystore_token_store.dart';
import 'package:paperdrop/features/wizard/data/token_store.dart';

/// FR-CFG-004 · `local-config-privacy/token-storage-in-the-platform-keystore`, the storage half:
/// the token goes to the platform's keystore and to nothing else.
///
/// **What runs here.** The package's own client — `FlutterSecureStorage`, the class the app calls —
/// over the plugin's own platform channel
/// (`plugins.it_nomads.com/flutter_secure_storage`), which is the seam the plugin's Android
/// implementation sits behind and the one its own test suite puts a double on. The test asserts what
/// the plugin sends and what it does with what comes back; **it does not claim any device
/// behaviour** (design §9: the backup half is verified on the phone in the T1.12–T1.13 session).
///
/// **Why the channel and not the platform interface.** `flutter_secure_storage` does not export
/// `FlutterSecureStoragePlatform`, and its platform-interface package is not a direct dependency of
/// the application, so importing it would be a `depend_on_referenced_packages` finding under
/// `flutter analyze --fatal-infos`. Mocking the channel keeps the app's dependency list the one the
/// orchestrator declared and still drives the package's real class.
///
/// The token in these tests is a synthetic value the test invented: the test base's identifiers
/// appear in no fixture, and no test needs a real token.
void main() {
  /// The plugin's own channel, as its `MissingPluginException` names it.
  const MethodChannel channel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );

  /// A synthetic token, and a second entry under a different key, so that "the token's own entry"
  /// can be told from "everything the plugin holds".
  const String token = 'pasted-token-1';
  const String otherKey = 'paperdrop.something.else';

  const TokenStore store = KeystoreTokenStore();
  late Map<String, String> platform;
  late List<MethodCall> calls;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    platform = <String, String>{};
    calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
          calls.add(call);
          final Map<Object?, Object?> arguments =
              (call.arguments as Map<Object?, Object?>?) ??
              <Object?, Object?>{};
          final String? key = arguments['key'] as String?;
          return switch (call.method) {
            'write' => platform[key!] = arguments['value']! as String,
            'read' => platform[key],
            'delete' => platform.remove(key),
            'deleteAll' => platform.clear(),
            'readAll' => Map<String, String>.from(platform),
            'containsKey' => platform.containsKey(key),
            _ => throw MissingPluginException(
              'the platform does not answer ${call.method}',
            ),
          };
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('the token is written under one key and read back from it', () async {
    await store.write(token);

    // One call, under the store's own key, with the token as the value — and nothing else carried
    // along with it.
    expect(calls, hasLength(1));
    expect(calls.single.method, 'write');
    expect(
      (calls.single.arguments as Map<Object?, Object?>)['key'],
      KeystoreTokenStore.tokenKey,
    );
    expect((calls.single.arguments as Map<Object?, Object?>)['value'], token);
    expect(platform, <String, String>{KeystoreTokenStore.tokenKey: token});

    expect(await store.read(), token);
  });

  test('a device that holds no token answers null, and reading it fails on '
      'nothing', () async {
    expect(await store.read(), isNull);

    // The store asked the platform, and the platform had nothing to answer with.
    expect(calls.map((MethodCall call) => call.method), <String>['read']);
  });

  test('clear removes the token\'s own entry and nothing else', () async {
    platform[otherKey] = 'something else the plugin holds';
    await store.write(token);

    await store.clear();

    expect(platform.containsKey(KeystoreTokenStore.tokenKey), isFalse);
    expect(platform[otherKey], 'something else the plugin holds');
    expect(calls.last.method, 'delete');
    expect(
      (calls.last.arguments as Map<Object?, Object?>)['key'],
      KeystoreTokenStore.tokenKey,
    );
    expect(await store.read(), isNull);
  });

  test(
    'a platform that is not there fails without carrying the token',
    () async {
      // The device's plugin can be absent — a plain `flutter test` process, or a platform the plugin
      // does not implement. What comes back must not be a message with the token in it.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);

      Object? thrown;
      try {
        await store.write(token);
      } catch (error) {
        thrown = error;
      }

      expect(thrown, isA<MissingPluginException>());
      expect(thrown.toString(), isNot(contains(token)));
      expect(store.toString(), isNot(contains(token)));
    },
  );

  test('the class hands the plugin no option that would move the token out '
      'of the keystore-backed mode', () async {
    await store.write(token);

    // The plugin's own Android defaults, as the call carried them in this session: the Keystore
    // cipher for the key and AES-GCM for the value, and EncryptedSharedPreferences off (deprecated
    // in this version, and the plugin sends the flag as the string 'false'). The store passes no
    // options at all, so these are the plugin's defaults and not the application's choice.
    final Map<Object?, Object?> options =
        ((calls.single.arguments as Map<Object?, Object?>)['options']
            as Map<Object?, Object?>);
    expect(options['encryptedSharedPreferences'].toString(), 'false');
    expect(
      options['keyCipherAlgorithm'],
      'RSA_ECB_OAEPwithSHA_256andMGF1Padding',
    );
    expect(options['storageCipherAlgorithm'], 'AES_GCM_NoPadding');
  });
}
