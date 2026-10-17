/// Group 5 of the negative release checklist: **no telemetry artefact**
/// (Funcional §10.6, §1.2).
///
/// The non-goal: *the app never collects telemetry in a public build*. The requirement it
/// protects is NFR-PRV-006 (*no analytics call exists in a public build; the release process
/// includes the supervised-measurement protocol instead*), with ADR-012 (no telemetry; §10.4's
/// supervised protocol), NFR-PRV-002/NFR-PRV-003 (no document content in a diagnostic) and
/// NFR-PRV-001 behind them.
///
/// **What this file proves.** No `pubspec.yaml` of the workspace and no package of the resolved
/// graph is an analytics, crash-reporting or advertising SDK; the shipped Android manifest asks
/// for one permission (`INTERNET`, which the Ninox API needs) and declares no advertising,
/// analytics or crash component, and the extra manifest that also asks for `INTERNET` is the
/// development one under `src/debug/`; and no log line exists that could carry a document value —
/// the app logs nothing at all, and the strings a log line would print of a record, a request or
/// an outcome carry counts and identifiers, never a value.
///
/// **Where it stops.** It reads declarations, not traffic: §10.4's measured half — observed
/// sessions and a benchmark run — is a release protocol, not a test. A dependency list scan also
/// cannot see a native SDK vendored into the Android project by hand; the manifest half is what
/// covers that direction, and it reads one manifest per flavour.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ninox_client/ninox_client.dart';

import 'checklist_support.dart';

/// The names an analytics, crash-reporting or advertising SDK answers to, as a substring of a
/// package name. `track` and `metric` are deliberately absent: `leak_tracker` is the test
/// framework's own leak tracking (a dev-only dependency of `flutter_test`) and the two words are
/// too common outside telemetry to be a signal.
const List<String> telemetryTokens = <String>[
  'firebase',
  'sentry',
  'crashlytics',
  'analytics',
  'amplitude',
  'mixpanel',
  'appsflyer',
  'onesignal',
  'bugsnag',
  'datadog',
  'appcenter',
  'newrelic',
  'instabug',
  'posthog',
  'fullstory',
  'smartlook',
  'telemetry',
  'admob',
  'google_mobile_ads',
  'facebook_app_events',
  'umeng',
  'appmetrica',
  'adjust_sdk',
  'branch_flutter',
];

/// The same names in the manifest, where they appear as a permission or a component class.
const List<String> telemetryManifestTokens = <String>[
  'firebase',
  'crashlytics',
  'analytics',
  'com.google.android.gms.ads',
  'com.facebook',
  'appsflyer',
  'sentry',
  'datadog',
  'bugsnag',
  'amplitude',
  'mixpanel',
  'onesignal',
  'instabug',
  'posthog',
];

/// The calls a log line would be written with. `avoid_print` already forbids one of them;
/// `dart:developer`'s `log` is what a lane reaches for next.
const List<String> loggingTokens = <String>[
  'dart:developer',
  'print(',
  'debugPrint(',
  'developer.log(',
  'stdout.write',
  'stderr.write',
];

/// The package names [pubspec] declares, each with the section it was declared in.
///
/// Read lexically: a dependency line is two spaces of indentation and a name, inside a
/// `dependencies:` or `dev_dependencies:` block. That is the format every pubspec in this
/// workspace uses, and a package added anywhere else is a change to the file this reads.
List<String> _declaredPackages(File pubspec) {
  final List<String> names = <String>[];
  String section = '';
  for (final String line in pubspec.readAsStringSync().split('\n')) {
    if (line.startsWith('dependencies:') ||
        line.startsWith('dev_dependencies:')) {
      section = line.substring(0, line.indexOf(':'));
      continue;
    }
    if (line.isNotEmpty && !line.startsWith(' ')) {
      section = '';
      continue;
    }
    if (section.isEmpty) {
      continue;
    }
    final RegExpMatch? match = RegExp(r'^  ([a-z0-9_]+):').firstMatch(line);
    if (match != null) {
      names.add('${match.group(1)} ($section, ${pathOf(pubspec)})');
    }
  }
  return names;
}

/// The package names the workspace resolved (`pubspec.lock`), which is where a transitive
/// analytics SDK would hide.
List<String> _resolvedPackages() {
  final File lock = fileAt('pubspec.lock');
  expect(
    lock.existsSync(),
    isTrue,
    reason: 'the resolved graph was not found, so half of this scan is missing',
  );
  return <String>[
    for (final String line in lock.readAsStringSync().split('\n'))
      if (RegExp(r'^  ([a-z0-9_]+):$').firstMatch(line) != null)
        RegExp(r'^  ([a-z0-9_]+):$').firstMatch(line)!.group(1)!,
  ];
}

/// The permissions [manifest] declares.
Set<String> _permissions(File manifest) => <String>{
  for (final RegExpMatch match in RegExp(
    r'<uses-permission[^>]*android:name="([^"]+)"',
  ).allMatches(manifest.readAsStringSync()))
    match.group(1)!,
};

void main() {
  const String nonGoal = 'no telemetry artefact';
  const String requirements = 'NFR-PRV-006, ADR-012, NFR-PRV-002, NFR-PRV-003';

  test('[$nonGoal] no declared or resolved dependency is an analytics, '
      'crash-reporting or advertising SDK ($requirements)', () {
    final List<File> pubspecs = pubspecFiles();
    expect(
      pubspecs.length,
      greaterThanOrEqualTo(3),
      reason:
          'the scan found ${pubspecs.length} pubspec files, so it proves '
          'nothing about this workspace',
    );

    final List<String> declared = <String>[
      for (final File pubspec in pubspecs) ..._declaredPackages(pubspec),
    ];
    expect(
      declared.length,
      greaterThan(10),
      reason:
          'the pubspec parse found ${declared.length} packages, so it '
          'proves nothing',
    );

    final List<String> resolved = _resolvedPackages();
    expect(
      resolved.length,
      greaterThan(50),
      reason:
          'the lockfile parse found ${resolved.length} packages, so it '
          'proves nothing',
    );

    final List<String> findings = <String>[
      for (final String name in declared)
        if (_hasTelemetryToken(name)) 'declared: $name',
      for (final String name in resolved)
        if (_hasTelemetryToken(name)) 'resolved: $name (pubspec.lock)',
    ];
    expect(
      findings,
      isEmpty,
      reason:
          '[$nonGoal] an analytics, crash-reporting or advertising SDK in the '
          'graph is a telemetry artefact in the build ($requirements): '
          '${findings.join(', ')}',
    );
  });

  test('[$nonGoal] the shipped manifest asks for INTERNET and declares no '
      'analytics or advertising component ($requirements)', () {
    final File main = fileAt('app/android/app/src/main/AndroidManifest.xml');
    final File debug = fileAt('app/android/app/src/debug/AndroidManifest.xml');

    expect(
      _permissions(main),
      <String>{'android.permission.INTERNET'},
      reason:
          '[$nonGoal] the Ninox API is the only host this app talks to, so '
          '`INTERNET` is the only permission it needs; anything else is a '
          'capability the product does not have ($requirements)',
    );

    final String manifestText = main.readAsStringSync().toLowerCase();
    for (final String token in telemetryManifestTokens) {
      expect(
        manifestText,
        isNot(contains(token)),
        reason:
            '[$nonGoal] the shipped manifest names `$token`, an analytics, '
            'crash-reporting or advertising component ($requirements)',
      );
    }

    expect(
      _permissions(debug),
      <String>{'android.permission.INTERNET'},
      reason:
          '[$nonGoal] the development manifest asks for the same permission '
          'the Flutter tool needs and nothing more',
    );
    expect(
      debug.path.toLowerCase().replaceAll(r'\', '/'),
      contains('/src/debug/'),
      reason:
          '[$nonGoal] the second `INTERNET` permission is the debug flavour\'s '
          'and does not reach a release build ($requirements)',
    );
  });

  test('[$nonGoal] no log line can carry a document value ($requirements)', () {
    final List<TokenOccurrence> found = occurrencesIn(
      shippedSources(),
      loggingTokens,
    );
    expect(
      unauthorised(found, const <String, String>{}),
      isEmpty,
      reason:
          '[$nonGoal] the app writes no log line at all today, and one that '
          'names a document\'s values must not be the way a diagnostic leaves '
          'the device ($requirements)',
    );

    // And the strings a log line *would* print, if one were written, carry no value: these are
    // the `toString`s of the objects that pass through the reading and the send.
    const String supplier = 'ACME Beispiel GmbH';
    const int amount = 1999;
    final NinoxRecord record = const NinoxRecord(
      id: RecordId('1416'),
      fields: <String, Object?>{'Supplier': supplier, 'Amount': amount},
    );
    expect(record.toString(), isNot(contains(supplier)));
    expect(record.toString(), isNot(contains('$amount')));

    final String request = testRequest().toString();
    expect(request, isNot(contains('1999')));
    expect(request, contains('fields'));

    const Sent sent = Sent(
      recordId: RecordId('1416'),
      readBack: NinoxRecord(
        id: RecordId('1416'),
        fields: <String, Object?>{'Supplier': supplier},
      ),
      files: <NinoxFile>[],
    );
    expect(sent.toString(), isNot(contains(supplier)));
  });

  test('[$nonGoal] the scan catches a planted analytics dependency', () {
    // A guard is only worth having if it would catch the thing it is written for.
    expect(
      _hasTelemetryToken('firebase_analytics (dependencies, planted)'),
      isTrue,
    );
    expect(
      _hasTelemetryToken('sentry_flutter (dependencies, planted)'),
      isTrue,
    );
    expect(
      _hasTelemetryToken('google_mobile_ads (dependencies, planted)'),
      isTrue,
    );
    expect(
      _hasTelemetryToken('leak_tracker (transitive, flutter_test)'),
      isFalse,
    );
    expect(
      _hasTelemetryToken('share_handler (dependencies, app/pubspec.yaml)'),
      isFalse,
    );
  });
}

/// Whether [name] reads as one of [telemetryTokens].
bool _hasTelemetryToken(String name) {
  final String lowered = name.toLowerCase();
  return telemetryTokens.any(lowered.contains);
}
