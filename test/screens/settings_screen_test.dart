/// Settings: the rows that report real state, and the one that opens a screen.
library;

import 'dart:io';

import 'package:archlence_mobile/app_services.dart';
import 'package:archlence_mobile/backup/backup_service.dart';
import 'package:archlence_mobile/screens/backup_screen.dart';
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
    BackupService? backup,
  }) => AppServices.forDatabase(
    db,
    FieldCrypto(FixedKeyProvider.arbitrary()),
    keyProtection: status,
    backup: backup,
    screenLock: ScreenLock(
      storage: FakeSecureStorage({}),
      auth: FakePlatformAuth()..supported = lockAvailable,
    ),
  );

  /// A backup service over a directory that exists but holds nothing.
  ///
  /// The row only asks whether there IS one; what it can do is proven in
  /// `test/backup_service_test.dart` against a real profile.
  BackupService backupService() {
    final directory = Directory.systemTemp.createTempSync('settings-');
    addTearDown(() => directory.deleteSync(recursive: true));
    return BackupService(
      databasePath: '${directory.path}/finance.db',
      keyProvider: FixedKeyProvider.arbitrary(),
    );
  }

  testWidgets('a hardware-backed key is reported as such', (tester) async {
    await pumpScreen(
      tester,
      servicesWith(const KeyProtectionStatus(KeyProtectionMethod.androidKeystore, true)),
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
          KeyProtectionMethod.ownerOnlyFile,
          false,
          KeyProtectionWarning.osKeyStoreUnavailable,
        ),
      ),
      const SettingsScreen(),
    );

    expect(find.textContaining('NOT in an OS key store'), findsOneWidget);
    expect(
      find.textContaining('The OS key store is unavailable'),
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
        const KeyProtectionStatus(KeyProtectionMethod.androidKeystore, true),
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
        keyProtection: const KeyProtectionStatus(KeyProtectionMethod.androidKeystore, true),
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
        keyProtection: const KeyProtectionStatus(KeyProtectionMethod.androidKeystore, true),
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
      servicesWith(const KeyProtectionStatus(KeyProtectionMethod.androidKeystore, true)),
      const SettingsScreen(),
    );

    expect(find.textContaining('does not add encryption'), findsOneWidget);
  });

  testWidgets('every row without a destination is marked, none is tappable', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      servicesWith(const KeyProtectionStatus(KeyProtectionMethod.androidKeystore, true)),
      const SettingsScreen(),
    );

    // Eleven rows. Three do something real — the encryption key and the lock
    // report state without going anywhere, and Language opens its picker —
    // and Backup & Restore is unavailable here because this graph has no
    // profile on disk behind it.
    expect(find.byType(NotYetChip), findsNWidgets(9));
    // Exactly one switch: the screen lock, which does something. The two that
    // used to be here moved local state and nothing else, so a user could
    // turn Dark Mode off and watch nothing happen.
    expect(find.byType(Switch), findsOneWidget);
    expect(find.text('Lock when I come back'), findsOneWidget);
    // One chevron: Language. A chevron promises a destination, and with no
    // backup service behind it that row has none.
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
  });

  testWidgets('Backup & Restore opens when there is a profile behind it', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      servicesWith(
        const KeyProtectionStatus(KeyProtectionMethod.androidKeystore, true),
        backup: backupService(),
      ),
      const SettingsScreen(),
    );

    // Two chevrons now: Language and Backup & Restore, the two rows that go
    // somewhere.
    expect(find.byIcon(Icons.chevron_right), findsNWidgets(2));
    expect(find.byType(NotYetChip), findsNWidgets(8));

    await tester.tap(find.text('Backup & Restore'));
    await tester.pumpAndSettle();

    expect(find.byType(BackupScreen), findsOneWidget);
  });

  testWidgets('the language row offers a choice and reports it back', (
    tester,
  ) async {
    // The row used to be a dead tile whose subtitle said "English" whatever
    // the app was actually drawing.
    final language = LocaleChoice();
    await pumpScreen(
      tester,
      servicesWith(
        const KeyProtectionStatus(KeyProtectionMethod.androidKeystore, true),
      ),
      const SettingsScreen(),
      language: language,
    );

    // No explicit choice yet, so the row says it is following the phone.
    expect(find.text('System language'), findsOneWidget);

    await tester.tap(find.text('Language'));
    await tester.pumpAndSettle();

    // Each language is named in its OWN language, in either interface, so a
    // reader stranded in one they cannot read can still find their way out.
    expect(find.text('Türkçe'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);

    await tester.tap(find.text('Türkçe'));
    await tester.pumpAndSettle();

    expect(language.asked, isTrue);
    expect(language.chosen, const Locale('tr'));
  });

  testWidgets('a dismissed language sheet changes nothing', (tester) async {
    // A sheet swiped away is not a choice of "follow the device", and
    // treating it as one would silently undo a language the user had set.
    final language = LocaleChoice();
    await pumpScreen(
      tester,
      servicesWith(
        const KeyProtectionStatus(KeyProtectionMethod.androidKeystore, true),
      ),
      const SettingsScreen(),
      language: language,
    );

    await tester.tap(find.text('Language'));
    await tester.pumpAndSettle();
    // Outside the sheet: the barrier dismisses it.
    await tester.tapAt(const Offset(400, 20));
    await tester.pumpAndSettle();

    expect(language.asked, isFalse);
  });

  testWidgets('and says so plainly when there is not', (tester) async {
    // Not a button that opens a screen which then reports it can do nothing:
    // the row itself carries the chip, like every other row that leads
    // nowhere.
    await pumpScreen(
      tester,
      servicesWith(const KeyProtectionStatus(KeyProtectionMethod.androidKeystore, true)),
      const SettingsScreen(),
    );

    expect(find.text('Not available in this build.'), findsOneWidget);
    await tester.tap(find.text('Backup & Restore'));
    await tester.pumpAndSettle();
    expect(find.byType(BackupScreen), findsNothing);
  });
}
