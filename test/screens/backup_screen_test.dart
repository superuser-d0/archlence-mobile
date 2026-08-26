/// The backup screen's wording and its gates.
///
/// What the screen SAYS is under test as much as what it does. Two sentences
/// on it are the difference between a user who keeps their data and one who
/// does not: that the passphrase cannot be recovered, and that restoring
/// replaces everything. Both are pinned here so they cannot be quietly
/// softened into marketing.
///
/// Creating and restoring themselves are not driven from here — they end in
/// the platform's share sheet and file picker, which a widget test has no
/// plugin behind. What they do is proven against a real profile on disk in
/// `test/backup_service_test.dart`.
library;

import 'dart:io';

import 'package:archlence_mobile/app_services.dart';
import 'package:archlence_mobile/backup/backup_service.dart';
import 'package:archlence_mobile/crypto/field_crypto.dart';
import 'package:archlence_mobile/data/database.dart';
import 'package:archlence_mobile/screens/backup_screen.dart';
import 'package:archlence_mobile/widgets/surfaces.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fixed_key_provider.dart';
import '../support/test_app.dart';

/// How solidly the primary button is painted.
double _gradientOpacity(WidgetTester tester) => tester
    .widget<Opacity>(
      find.descendant(
        of: find.byType(GradientButton),
        matching: find.byType(Opacity),
      ),
    )
    .opacity;

void main() {
  late ArchlenceDatabase db;

  setUp(() => db = ArchlenceDatabase.memory());
  tearDown(() => db.close());

  AppServices servicesWith({required bool withBackup}) {
    BackupService? backup;
    if (withBackup) {
      final directory = Directory.systemTemp.createTempSync('backup-screen-');
      addTearDown(() => directory.deleteSync(recursive: true));
      backup = BackupService(
        databasePath: '${directory.path}/finance.db',
        keyProvider: FixedKeyProvider.arbitrary(),
      );
    }
    return AppServices.forDatabase(
      db,
      FieldCrypto(FixedKeyProvider.arbitrary()),
      backup: backup,
    );
  }

  Future<void> open(WidgetTester tester, {bool withBackup = true}) => pumpScreen(
    tester,
    servicesWith(withBackup: withBackup),
    const BackupScreen(),
  );

  testWidgets('it says the passphrase cannot be recovered', (tester) async {
    // Not softened. A user who expects a reset link finds out at the one
    // moment it cannot be fixed.
    await open(tester);

    expect(
      find.textContaining('THE PASSPHRASE IS NOT STORED ANYWHERE'),
      findsOneWidget,
    );
    expect(
      find.textContaining('not by this app, not by anyone'),
      findsOneWidget,
    );
  });

  testWidgets('it says restoring replaces everything, and what is kept', (
    tester,
  ) async {
    await open(tester);

    expect(find.textContaining('Replaces everything in this app'), findsOneWidget);
    // The second half matters as much as the first: "replaced" and "gone" are
    // different, and the difference is the backup written first.
    expect(
      find.textContaining('written to a backup of its own first'),
      findsOneWidget,
    );
  });

  testWidgets('neither action is offered until a passphrase could work', (
    tester,
  ) async {
    await open(tester);

    // Both halves: the callback is null AND the button is drawn as unusable.
    // Only the first was checked at first, and on the emulator the gradient
    // was painted at full strength the whole time — a button that looked
    // ready and did nothing.
    expect(tester.widget<GradientButton>(find.byType(GradientButton)).onPressed, isNull);
    expect(_gradientOpacity(tester), lessThan(1.0));
    expect(
      tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
      isNull,
    );

    // Eleven characters: one short of the floor the format sets.
    await tester.enterText(find.byType(TextField).at(0), 'elevenchars');
    await tester.enterText(find.byType(TextField).at(1), 'elevenchars');
    await tester.pumpAndSettle();
    expect(tester.widget<GradientButton>(find.byType(GradientButton)).onPressed, isNull);

    await tester.enterText(find.byType(TextField).at(0), 'twelve chars');
    await tester.enterText(find.byType(TextField).at(1), 'twelve chars');
    await tester.pumpAndSettle();
    expect(
      tester.widget<GradientButton>(find.byType(GradientButton)).onPressed,
      isNotNull,
    );
    expect(_gradientOpacity(tester), 1.0);
  });

  testWidgets('two passphrases that differ are reported, not written', (
    tester,
  ) async {
    // Caught before anything is derived or written: a mistyped confirmation
    // would otherwise produce a package whose passphrase nobody knows.
    await open(tester);

    await tester.enterText(find.byType(TextField).at(0), 'twelve chars');
    await tester.enterText(find.byType(TextField).at(1), 'twelve chairs');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create and share a backup'));
    await tester.pumpAndSettle();

    expect(find.text('The two passphrases are not the same.'), findsOneWidget);
  });

  testWidgets('with no profile behind it, it says so instead of pretending', (
    tester,
  ) async {
    await open(tester, withBackup: false);

    expect(find.textContaining('no profile on disk'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(0), 'twelve chars');
    await tester.enterText(find.byType(TextField).at(1), 'twelve chars');
    await tester.pumpAndSettle();
    expect(tester.widget<GradientButton>(find.byType(GradientButton)).onPressed, isNull);
  });
}
