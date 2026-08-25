/// Settings, and the one row on it that reports real state.
library;

import 'package:archlence_mobile/app_services.dart';
import 'package:archlence_mobile/crypto/field_crypto.dart';
import 'package:archlence_mobile/crypto/key_provider.dart';
import 'package:archlence_mobile/data/database.dart';
import 'package:archlence_mobile/screens/settings_screen.dart';
import 'package:archlence_mobile/widgets/not_yet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:archlence_mobile/security/screen_lock.dart';

import '../support/fake_platform_auth.dart';
import '../support/fixed_key_provider.dart';
import '../support/test_app.dart';

void main() {
  late ArchlenceDatabase db;

  setUp(() => db = ArchlenceDatabase.memory());
  tearDown(() => db.close());

  AppServices servicesWith(
    KeyProtectionStatus? status, {
    bool lockAvailable = true,
  }) => AppServices.forDatabase(
    db,
    FieldCrypto(FixedKeyProvider.arbitrary()),
    keyProtection: status,
    screenLock: ScreenLock(
      storage: FakeSecureStorage({}),
      auth: FakePlatformAuth()..supported = lockAvailable,
    ),
  );

  testWidgets('a hardware-backed key is reported as such', (tester) async {
    await pumpScreen(
      tester,
      servicesWith(const KeyProtectionStatus('Android Keystore', true)),
      const SettingsScreen(),
    );

    expect(find.textContaining('held by the operating system'), findsOneWidget);
    expect(find.textContaining('Android Keystore'), findsOneWidget);
  });

  testWidgets('a file fallback says so, and says it plainly', (tester) async {
    // The row this replaced was a hard-coded sentence claiming an owner-only
    // file. On a device with a working Keystore it said the opposite of the
    // truth — the worst thing on this screen to be wrong about.
    await pumpScreen(
      tester,
      servicesWith(
        const KeyProtectionStatus(
          'owner-only file',
          false,
          'The OS key store was unavailable.',
        ),
      ),
      const SettingsScreen(),
    );

    expect(find.textContaining('NOT in an OS key store'), findsOneWidget);
    expect(
      find.textContaining('The OS key store was unavailable.'),
      findsOneWidget,
    );
    expect(find.textContaining('held by the operating system'), findsNothing);
  });

  testWidgets('an unknown store is not reported as a safe one', (tester) async {
    // Assuming the best case is exactly the failure mode: a screen that says
    // "Keystore" when it does not know would be lying about security.
    await pumpScreen(tester, servicesWith(null), const SettingsScreen());

    expect(find.textContaining('Not known in this build'), findsOneWidget);
    expect(find.textContaining('Android Keystore'), findsNothing);
  });

  testWidgets('a device with no credential cannot turn the lock on', (
    tester,
  ) async {
    // Otherwise a user enables a lock that then refuses to open.
    await pumpScreen(
      tester,
      servicesWith(
        const KeyProtectionStatus('Android Keystore', true),
        lockAvailable: false,
      ),
      const SettingsScreen(),
    );

    expect(
      find.textContaining('no fingerprint or screen lock set up'),
      findsOneWidget,
    );
    expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNull);
  });

  testWidgets('turning the lock on asks for the credential first', (
    tester,
  ) async {
    // A lock switched on by someone who cannot then pass it is a lock on the
    // owner's own data.
    final auth = FakePlatformAuth();
    final storage = FakeSecureStorage({});
    final lock = ScreenLock(storage: storage, auth: auth);
    await pumpScreen(
      tester,
      AppServices.forDatabase(
        db,
        FieldCrypto(FixedKeyProvider.arbitrary()),
        keyProtection: const KeyProtectionStatus('Android Keystore', true),
        screenLock: lock,
      ),
      const SettingsScreen(),
    );

    await tester.tap(find.byType(Switch));
    // Twice: `pumpAndSettle` stops when no frame is scheduled, and the chain
    // here is await-only between the tap and the rebuild — it schedules no
    // frame of its own until the future behind the switch completes.
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();

    expect(auth.prompts, 1);
    expect(await lock.isEnabled(), isTrue);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
  });

  testWidgets('a refused credential leaves the lock off', (tester) async {
    final auth = FakePlatformAuth()..passes = false;
    final lock = ScreenLock(storage: FakeSecureStorage({}), auth: auth);
    await pumpScreen(
      tester,
      AppServices.forDatabase(
        db,
        FieldCrypto(FixedKeyProvider.arbitrary()),
        keyProtection: const KeyProtectionStatus('Android Keystore', true),
        screenLock: lock,
      ),
      const SettingsScreen(),
    );

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();

    expect(auth.prompts, 1);
    expect(await lock.isEnabled(), isFalse);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
  });

  testWidgets('the lock switch says what it does NOT buy', (tester) async {
    // A lock the app draws hides the screen from someone holding the phone.
    // It adds no encryption — the database key opens without it — and saying
    // "your data is protected" here would be a claim the app cannot back.
    await pumpScreen(
      tester,
      servicesWith(const KeyProtectionStatus('Android Keystore', true)),
      const SettingsScreen(),
    );

    expect(find.textContaining('does not add encryption'), findsOneWidget);
  });

  testWidgets('every row without a destination is marked, none is tappable', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      servicesWith(const KeyProtectionStatus('Android Keystore', true)),
      const SettingsScreen(),
    );

    // Ten rows; only the encryption-key one reports something real.
    expect(find.byType(NotYetChip), findsNWidgets(9));
    // Exactly one switch: the screen lock, which does something. The two that
    // used to be here moved local state and nothing else, so a user could
    // turn Dark Mode off and watch nothing happen.
    expect(find.byType(Switch), findsOneWidget);
    expect(find.text('Lock when I come back'), findsOneWidget);
    // No chevron anywhere — a chevron promises a destination.
    expect(find.byIcon(Icons.chevron_right), findsNothing);
  });
}
