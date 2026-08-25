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

import '../support/fixed_key_provider.dart';
import '../support/test_app.dart';

void main() {
  late ArchlenceDatabase db;

  setUp(() => db = ArchlenceDatabase.memory());
  tearDown(() => db.close());

  AppServices servicesWith(KeyProtectionStatus? status) =>
      AppServices.forDatabase(
        db,
        FieldCrypto(FixedKeyProvider.arbitrary()),
        keyProtection: status,
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
    // The switches are gone: they moved local state and nothing else, so a
    // user could turn Dark Mode off and watch nothing happen.
    expect(find.byType(Switch), findsNothing);
    // No chevron anywhere — a chevron promises a destination.
    expect(find.byIcon(Icons.chevron_right), findsNothing);
  });
}
