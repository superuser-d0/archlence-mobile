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
import 'package:archlence_mobile/services/shares_api_key.dart';

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

    // ONE chip, and which one it is carries the whole distinction the chip
    // now makes. Seven rows used to wear it because the feature behind them
    // had never been built; those rows are not drawn at all any more — see
    // `showUnbuiltFeatures`. What is left is Backup & Restore, which is a
    // real screen, unavailable here only because this graph has no profile
    // on disk behind it. That is a control in a state the user can change,
    // and marking it is the honest thing. A row for a feature that does not
    // exist is not in that category and never was.
    expect(find.byType(NotYetChip), findsOneWidget);
    expect(
      find.ancestor(
        of: find.text('Backup & Restore'),
        matching: find.byType(Row),
      ),
      findsWidgets,
    );
    // Exactly one switch: the screen lock, which does something. The two that
    // used to be here moved local state and nothing else, so a user could
    // turn Dark Mode off and watch nothing happen.
    expect(find.byType(Switch), findsOneWidget);
    expect(find.text('Lock when I come back'), findsOneWidget);
    // Four chevrons: Category Settings, Language, BIST share prices and Open
    // source licences. A chevron promises a destination, and with no backup
    // service behind it that row has none.
    expect(find.byIcon(Icons.chevron_right), findsNWidgets(4));
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

    // Five chevrons now: Category Settings, Language, BIST share prices, Open
    // source licences, and Backup & Restore — the rows that go somewhere.
    expect(find.byIcon(Icons.chevron_right), findsNWidgets(5));
    // And no chip at all, for the same reason there is one more chevron:
    // Backup & Restore is the only row that could still carry one, and it
    // has a profile behind it here.
    expect(find.byType(NotYetChip), findsNothing);

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

  testWidgets('the BIST row reports no key, and saving one changes that', (
    tester,
  ) async {
    // The whole point of the row: it says which state the app is in, and
    // the Assets tab's behaviour follows from that state.
    final store = SharesApiKey(storage: FakeSecureStorage({}));
    await pumpScreen(
      tester,
      AppServices.forDatabase(
        db,
        FieldCrypto(FixedKeyProvider.arbitrary()),
        keyProtection: const KeyProtectionStatus(
          KeyProtectionMethod.androidKeystore,
          true,
        ),
        sharesApiKey: store,
      ),
      const SettingsScreen(),
    );

    expect(find.text('Not set — shares are shown at cost'), findsOneWidget);

    await tester.tap(find.text('BIST share prices'));
    await tester.pumpAndSettle();

    // The sheet says where the key comes from and what happens to it.
    expect(find.textContaining('nosyapi.com'), findsOneWidget);
    expect(find.textContaining('It is not in a backup'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'a-user-key');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save the key'));
    await tester.pumpAndSettle();

    expect(await store.read(), 'a-user-key');
    expect(find.text('A key is set — shares are priced live'), findsOneWidget);
  });

  testWidgets('and removing it puts shares back at cost', (tester) async {
    final store = SharesApiKey(
      storage: FakeSecureStorage({'archlence.shares-api-key': 'an-old-key'}),
    );
    await pumpScreen(
      tester,
      AppServices.forDatabase(
        db,
        FieldCrypto(FixedKeyProvider.arbitrary()),
        keyProtection: const KeyProtectionStatus(
          KeyProtectionMethod.androidKeystore,
          true,
        ),
        sharesApiKey: store,
      ),
      const SettingsScreen(),
    );

    expect(find.text('A key is set — shares are priced live'), findsOneWidget);

    await tester.tap(find.text('BIST share prices'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove the key'));
    await tester.pumpAndSettle();

    expect(await store.read(), isNull);
    expect(find.text('Not set — shares are shown at cost'), findsOneWidget);
  });

  testWidgets('the key itself is never put on screen', (tester) async {
    // A row that displayed a credential would put one in front of whoever
    // is looking over the user's shoulder, and seeing it buys nothing that
    // "a key is set" does not already say.
    await pumpScreen(
      tester,
      AppServices.forDatabase(
        db,
        FieldCrypto(FixedKeyProvider.arbitrary()),
        keyProtection: const KeyProtectionStatus(
          KeyProtectionMethod.androidKeystore,
          true,
        ),
        sharesApiKey: SharesApiKey(
          storage: FakeSecureStorage({
            'archlence.shares-api-key': 'secret-key-value',
          }),
        ),
      ),
      const SettingsScreen(),
    );

    expect(find.textContaining('secret-key-value'), findsNothing);

    await tester.tap(find.text('BIST share prices'));
    await tester.pumpAndSettle();

    // Not even prefilled into the field it would be edited in.
    expect(find.textContaining('secret-key-value'), findsNothing);
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
