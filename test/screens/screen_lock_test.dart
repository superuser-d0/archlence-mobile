/// The resume gate.
library;

import 'package:archlence_mobile/data/database.dart';
import 'package:archlence_mobile/screens/locked_screen.dart';
import 'package:archlence_mobile/security/screen_lock.dart';
import 'package:archlence_mobile/l10n/app_localizations.dart';
import 'package:archlence_mobile/ui/app_locale.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_platform_auth.dart';

void main() {
  late Map<String, String> stored;
  late FakePlatformAuth auth;
  late ScreenLock lock;

  setUp(() {
    stored = {};
    auth = FakePlatformAuth();
    lock = ScreenLock(storage: FakeSecureStorage(stored), auth: auth);
  });

  group('the preference', () {
    test('is off until it is turned on', () async {
      expect(await lock.isEnabled(), isFalse);
      await lock.setEnabled(true);
      expect(await lock.isEnabled(), isTrue);
    });

    test('does not live in the finance database', () async {
      // That file's schema is a contract with the desktop app, and a UI
      // preference is not financial data.
      final db = ArchlenceDatabase.memory();
      addTearDown(db.close);
      await lock.setEnabled(true);

      final tables = await db.tableNames();
      for (final table in tables) {
        final rows = await db.customSelect('SELECT * FROM $table').get();
        expect(
          rows.any(
            (row) => row.data.values.any(
              (value) => value.toString().contains('screen-lock'),
            ),
          ),
          isFalse,
          reason: table,
        );
      }
    });

    test('a storage failure reads as off, not as locked out', () async {
      // Refusing entry over a preference read is the worst way to fail: the
      // data is the user's and the lock is a convenience.
      final broken = ScreenLock(
        storage: const ThrowingSecureStorage(),
        auth: auth,
      );
      expect(await broken.isEnabled(), isFalse);
    });
  });

  group('the prompt', () {
    test('accepts a device credential, not only a fingerprint', () async {
      // `biometricOnly: true` would lock out anyone who has a PIN but no
      // fingerprint enrolled — out of an app they set up themselves.
      await lock.authenticate(reason: 'Unlock Archlence');
      expect(auth.lastBiometricOnly, isFalse);
    });
  });

  group('availability', () {
    test('a device with no credential cannot turn it on', () async {
      // Otherwise a user enables a lock that then refuses to open.
      auth.supported = false;
      expect(await lock.isAvailable(), isFalse);
    });
  });

  group('the gate', () {
    var clock = DateTime(2026, 8, 26, 12);

    Future<void> pumpGate(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          // The real delegates: `LockedScreen` reads its labels from them,
          // and a bare `MaterialApp` would have none to give it.
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: supportedLocales,
          home: ScreenLockGate(
            lock: lock,
            now: () => clock,
            locked: (context, unlock) => LockedScreen(
              onAuthenticate: () =>
                  lock.authenticate(reason: 'Unlock Archlence'),
              onUnlocked: unlock,
            ),
            child: const Scaffold(body: Text('the dashboard')),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    /// Sends the app away and brings it back after [away].
    Future<void> leaveAndReturn(
      WidgetTester tester, {
      required Duration away,
    }) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      // The gate stamps the time it LEFT and compares on the way back, so
      // what has to move is ITS clock. `tester.pump(duration)` advances the
      // frame scheduler, not the wall clock, and the first version of this
      // test failed for exactly that reason.
      clock = clock.add(away);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
    }

    testWidgets('does nothing while the preference is off', (tester) async {
      await pumpGate(tester);
      await leaveAndReturn(tester, away: const Duration(minutes: 10));

      expect(find.text('the dashboard'), findsOneWidget);
      expect(find.byType(LockedScreen), findsNothing);
      expect(auth.prompts, 0);
    });

    testWidgets('a short absence does not lock', (tester) async {
      // Asking on every return is how a lock gets switched off in the first
      // week, and a lock the user disabled protects nothing.
      await lock.setEnabled(true);
      await pumpGate(tester);
      await leaveAndReturn(tester, away: const Duration(seconds: 5));

      expect(find.byType(LockedScreen), findsNothing);
      expect(auth.prompts, 0);
    });

    testWidgets('a long absence locks and asks straight away', (tester) async {
      await lock.setEnabled(true);
      auth.passes = false;
      await pumpGate(tester);
      await leaveAndReturn(tester, away: const Duration(minutes: 2));

      expect(find.byType(LockedScreen), findsOneWidget);
      expect(auth.prompts, 1, reason: 'asked without waiting for a tap');
      expect(find.text('Not unlocked.'), findsOneWidget);
    });

    testWidgets('the figures behind it cannot be read while locked', (
      tester,
    ) async {
      // The whole point. A translucent cover would defeat it.
      await lock.setEnabled(true);
      auth.passes = false;
      await pumpGate(tester);
      await leaveAndReturn(tester, away: const Duration(minutes: 2));

      final cover = tester.widget<ColoredBox>(
        find.descendant(
          of: find.byType(LockedScreen),
          matching: find.byType(ColoredBox),
        ),
      );
      expect(cover.color.a, 1.0, reason: 'the cover must be opaque');
    });

    testWidgets('passing puts the user back where they were', (tester) async {
      await lock.setEnabled(true);
      await pumpGate(tester);
      await leaveAndReturn(tester, away: const Duration(minutes: 2));

      expect(find.byType(LockedScreen), findsNothing);
      expect(find.text('the dashboard'), findsOneWidget);
    });

    testWidgets('refusing leaves it locked, and it can be asked again', (
      tester,
    ) async {
      await lock.setEnabled(true);
      auth.passes = false;
      await pumpGate(tester);
      await leaveAndReturn(tester, away: const Duration(minutes: 2));
      expect(find.byType(LockedScreen), findsOneWidget);

      auth.passes = true;
      await tester.tap(find.text('Unlock'));
      await tester.pumpAndSettle();

      expect(find.byType(LockedScreen), findsNothing);
      expect(auth.prompts, 2);
    });
  });
}
