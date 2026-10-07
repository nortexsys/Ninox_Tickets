import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ninox_client/ninox_client.dart';
import 'package:paperdrop/app/dependencies.dart';
import 'package:paperdrop/app/router.dart';
import 'package:paperdrop/features/capture/capture_controller.dart';
import 'package:paperdrop/features/capture/capture_screen.dart';
import 'package:paperdrop/features/wizard/data/destination_store.dart';
import 'package:paperdrop/features/wizard/destination.dart';
import 'package:paperdrop/features/wizard/token/token_screen.dart';
import 'package:paperdrop/features/wizard/wizard_routes.dart';
import 'package:paperdrop/l10n/generated/app_localizations.dart';

import '../tool/fakes.dart';

/// The first-run entry point: the shell opens on the wizard until a destination
/// exists (task 3.5 of `implement-setup-wizard`, design §10; FR-DST-002,
/// `destinations-mapping/no-default-destination-until-a-first-send`).
///
/// Four things are proved here, and nothing else:
///
/// 1. `buildAppRouter`'s `hasDestination` drives the shell both ways, and an
///    answer of `false` is the only thing that redirects.
/// 2. the wizard's own location is never redirected — the question is not even
///    asked for it — so the redirect cannot loop.
/// 3. once the answer turns `true`, the wizard's own closing offer
///    (`onFinished`, the router's `router.go(captureRoute)`) lands on capture.
/// 4. the production wiring — `deviceHasDestination` — answers `false` on a
///    store that reads and holds nothing, `true` on one that holds a
///    destination, and `true` on one that cannot be read at all (design §10).
///
/// **No test here touches a device and none needs a token.** The wizard is
/// rendered through its own entry point, which builds a real port factory and the
/// Keystore store; nothing is pressed, so no request is made and no keystore call
/// happens. The store tests write into a directory the test owns, through the
/// store's own path injection.
void main() {
  /// The shell's own router needs the Mobile lane's capture pipeline; a test
  /// hands it one built on fakes (design §1 of `setup-mvp-foundations`).
  CaptureController captureController() => CaptureController(
    intake: FakeDocumentIntake(root: Directory('paperdrop-entry-test')),
    scanner: FakeDocumentScanner(),
    picker: FakeFilePickerSource(),
    shareIn: FakeShareInSource(),
  );

  /// The application's smallest host: the localisations every screen reads.
  Widget host(GoRouter router) => MaterialApp.router(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    routerConfig: router,
  );

  testWidgets(
    '[destinations-mapping/no-default-destination-until-a-first-send] a fresh '
    'installation has nothing pre-loaded, so the app opens on the wizard',
    (WidgetTester tester) async {
      // The device's answer: the store was read and holds no destination.
      final GoRouter router = buildAppRouter(
        controller: captureController(),
        hasDestination: () async => false,
      );
      await tester.pumpWidget(host(router));
      await tester.pumpAndSettle();

      // The first step of the wizard, and none of capture.
      expect(find.byType(TokenScreen), findsOneWidget);
      expect(find.byType(CaptureScreen), findsNothing);
      expect(router.state.uri.path, wizardRoute);
    },
  );

  testWidgets('with a destination configured the shell still opens on capture', (
    WidgetTester tester,
  ) async {
    int asked = 0;
    final GoRouter router = buildAppRouter(
      controller: captureController(),
      hasDestination: () async {
        asked++;
        return true;
      },
    );
    await tester.pumpWidget(host(router));
    await tester.pumpAndSettle();

    expect(find.byType(CaptureScreen), findsOneWidget);
    expect(find.byType(TokenScreen), findsNothing);
    expect(router.state.uri.path, captureRoute);
    // The question was asked, and the no-redirect answer is what left the user
    // where the shell put them.
    expect(asked, 1);
  });

  testWidgets(
    'a router that says nothing about destinations is not redirected',
    (WidgetTester tester) async {
      // The default of `buildAppRouter`, which is what every caller before this
      // change passed: *yes*, and so every existing test of the shell behaves
      // exactly as it did (design §10).
      final GoRouter router = buildAppRouter(controller: captureController());
      await tester.pumpWidget(host(router));
      await tester.pumpAndSettle();

      expect(find.byType(CaptureScreen), findsOneWidget);
      expect(find.byType(TokenScreen), findsNothing);
    },
  );

  testWidgets('the wizard is reachable, and is never redirected to itself', (
    WidgetTester tester,
  ) async {
    int asked = 0;
    final GoRouter router = buildAppRouter(
      controller: captureController(),
      hasDestination: () async {
        asked++;
        return false;
      },
    );
    await tester.pumpWidget(host(router));
    await tester.pumpAndSettle();
    expect(find.byType(TokenScreen), findsOneWidget);
    final int afterRedirect = asked;

    // Going to the wizard while there is no destination leaves the user on the
    // wizard: the only location the redirect lets through, and it stays there.
    router.go(wizardRoute);
    await tester.pumpAndSettle();
    expect(router.state.uri.path, wizardRoute);
    expect(find.byType(TokenScreen), findsOneWidget);
    expect(find.byType(CaptureScreen), findsNothing);

    // And the loop cannot exist: `/wizard` is not even asked about, so the
    // redirect answers *nothing* for it rather than `/wizard` again.
    expect(afterRedirect, 1);
    expect(asked, afterRedirect);
  });

  testWidgets(
    'a finished wizard lands on capture once a destination exists, and stays '
    'on the wizard while none does',
    (WidgetTester tester) async {
      bool hasDestination = false;
      final GoRouter router = buildAppRouter(
        controller: captureController(),
        hasDestination: () async => hasDestination,
      );
      await tester.pumpWidget(host(router));
      await tester.pumpAndSettle();
      expect(find.byType(TokenScreen), findsOneWidget);

      // The wizard's closing screen offers capture through the callback this
      // file gave it — `router.go(captureRoute)`. While the store holds
      // nothing, that offer cannot take the user out of the wizard.
      router.go(captureRoute);
      await tester.pumpAndSettle();
      expect(find.byType(TokenScreen), findsOneWidget);
      expect(router.state.uri.path, wizardRoute);

      // The destination was saved, which is what turns the answer true: the
      // same call now arrives on capture.
      hasDestination = true;
      router.go(captureRoute);
      await tester.pumpAndSettle();
      expect(find.byType(CaptureScreen), findsOneWidget);
      expect(find.byType(TokenScreen), findsNothing);
      expect(router.state.uri.path, captureRoute);
    },
  );

  group('the production answer, on the store the wizard writes to', () {
    late Directory root;

    setUp(() {
      root = Directory.systemTemp.createTempSync('paperdrop-entry-test-');
    });

    tearDown(() {
      if (root.existsSync()) {
        root.deleteSync(recursive: true);
      }
    });

    /// The device's file store, over a directory this test owns — the store's own
    /// path injection, and the same store the wizard writes with.
    FileDestinationStore storeIn(Directory directory) =>
        FileDestinationStore(storage: TemporaryStorage(directory));

    test('a store that holds nothing answers no, and one that holds a '
        'destination answers yes', () async {
      final FileDestinationStore store = storeIn(root);
      expect(
        await deviceHasDestination(store: store),
        isFalse,
        reason: 'a fresh installation has nothing pre-loaded (FR-DST-002)',
      );

      await store.save(
        const Destination(
          endpoint: NinoxEndpoint.cloud,
          teamId: 'team-1',
          databaseId: 'database-1',
          tableId: 'table-1',
        ),
      );

      expect(await deviceHasDestination(store: store), isTrue);
    });

    test('a store that cannot be read answers yes, so the user is not sent to '
        'a wizard that cannot save', () async {
      // What an unreadable file is for the store (its own contract: a file that
      // cannot be read is a FormatException, never an empty list).
      expect(
        await deviceHasDestination(store: const _UnreadableDestinationStore()),
        isTrue,
      );
    });
  });
}

/// A store whose file cannot be read: the one answer that must not be taken for
/// "no destination" (design §10 of `implement-setup-wizard`).
final class _UnreadableDestinationStore implements DestinationStore {
  const _UnreadableDestinationStore();

  @override
  Future<List<Destination>> readAll() async {
    throw const FormatException('the stored destinations cannot be read');
  }

  @override
  Future<void> save(Destination destination) async {
    throw UnsupportedError('this double is never written to');
  }
}
