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
import 'package:archlence_mobile/backup/key_recovery_service.dart';
import 'package:archlence_mobile/crypto/field_crypto.dart';
import 'package:archlence_mobile/data/database.dart';
import 'package:archlence_mobile/screens/backup_screen.dart';
import 'package:archlence_mobile/widgets/surfaces.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fixed_key_provider.dart';
import '../support/test_app.dart';

/// Whether the outlined button carrying [label] refuses to be pressed.
bool _outlinedDisabled(WidgetTester tester, String label) =>
    tester
        .widget<OutlinedButton>(
          find.ancestor(
            of: find.text(label),
            matching: find.byType(OutlinedButton),
          ),
        )
        .onPressed ==
    null;

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
    KeyRecoveryService? recovery;
    if (withBackup) {
      final directory = Directory.systemTemp.createTempSync('backup-screen-');
      addTearDown(() => directory.deleteSync(recursive: true));
      final provider = FixedKeyProvider.arbitrary();
      backup = BackupService(
        databasePath: '${directory.path}/finance.db',
        keyProvider: provider,
      );
      recovery = KeyRecoveryService(
        databasePath: '${directory.path}/finance.db',
        keyProvider: provider,
        backup: backup,
      );
    }
    return AppServices.forDatabase(
      db,
      FieldCrypto(FixedKeyProvider.arbitrary()),
      backup: backup,
      keyRecovery: recovery,
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
    // Three outlined buttons now — restore, export the key, put one back —
    // and `find.byType` alone would match all three and throw. Each is
    // addressed by its own label, because "one of them is disabled" is not
    // the claim being made.
    for (final label in const [
      'Choose a file and restore',
      'Export and share the key',
      'Choose a file and put the key back',
    ]) {
      expect(_outlinedDisabled(tester, label), isTrue, reason: label);
    }

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

  testWidgets('the key rows say what a whole backup does not answer', (
    tester,
  ) async {
    // The two are easy to confuse, and confusing them is expensive in one
    // direction: restoring a backup when only the key was missing throws away
    // everything recorded since it was made. The screen has to draw the line.
    await open(tester);

    expect(
      find.textContaining('holds the encryption key and nothing else'),
      findsOneWidget,
    );
    expect(
      find.textContaining('the data is still here and the key is not'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Restoring one would also throw away'),
      findsOneWidget,
    );
    // And the import side's promise, which is the one that makes it safe to
    // try: a key that does not fit changes nothing.
    expect(
      find.textContaining('a key that does not open them changes nothing'),
      findsOneWidget,
    );
  });

  testWidgets('exporting the key waits for both passphrase fields', (
    tester,
  ) async {
    await open(tester);
    // 0,1 create · 2 restore · 3,4 export the key · 5 put one back.
    const exportPassphrase = 3;
    const confirmExport = 4;

    await tester.enterText(
      find.byType(TextField).at(exportPassphrase),
      'twelve chars',
    );
    await tester.pumpAndSettle();
    expect(
      _outlinedDisabled(tester, 'Export and share the key'),
      isTrue,
      reason: 'one field filled is not a confirmed passphrase',
    );

    await tester.enterText(
      find.byType(TextField).at(confirmExport),
      'twelve chars',
    );
    await tester.pumpAndSettle();
    expect(_outlinedDisabled(tester, 'Export and share the key'), isFalse);
  });

  testWidgets('two key passphrases that differ are reported, not written', (
    tester,
  ) async {
    await open(tester);

    await tester.enterText(find.byType(TextField).at(3), 'twelve chars');
    await tester.enterText(find.byType(TextField).at(4), 'twelve chairs');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Export and share the key'));
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
    await tester.enterText(find.byType(TextField).at(3), 'twelve chars');
    await tester.enterText(find.byType(TextField).at(4), 'twelve chars');
    await tester.enterText(find.byType(TextField).at(5), 'twelve chars');
    await tester.pumpAndSettle();
    expect(tester.widget<GradientButton>(find.byType(GradientButton)).onPressed, isNull);
    // The key rows go dead with it. They lead somewhere real, so a build
    // without a profile has to draw them as unusable rather than let a tap
    // find nothing behind it.
    expect(_outlinedDisabled(tester, 'Export and share the key'), isTrue);
    expect(
      _outlinedDisabled(tester, 'Choose a file and put the key back'),
      isTrue,
    );
  });
  testWidgets('every passphrase is obscured, and can be revealed', (
    tester,
  ) async {
    // Found by running it: all six were typed in the clear. This screen has
    // no input on it that is NOT a passphrase, so "every TextField" is the
    // whole rule rather than a sample of it.
    await open(tester);

    final fields = tester.widgetList<TextField>(find.byType(TextField));
    expect(fields, hasLength(6));
    expect(
      fields.every((field) => field.obscureText),
      isTrue,
      reason: 'A displayed credential is one a shoulder can read — the rule '
          'this project already holds for the shares API key.',
    );

    // Not decoration either: an autocorrect dictionary and a suggestion strip
    // both LEARN what is typed into them, which would put the passphrase
    // somewhere this app neither controls nor can clear.
    expect(fields.every((field) => field.autocorrect == false), isTrue);
    expect(fields.every((field) => field.enableSuggestions == false), isTrue);

    // And the way back, which this screen needs more than most: the
    // passphrase is stored nowhere, so a typo the user cannot see is a
    // package that never opens again.
    expect(find.byIcon(Icons.visibility_outlined), findsNWidgets(6));
    await tester.tap(find.byIcon(Icons.visibility_outlined).first);
    await tester.pumpAndSettle();
    expect(
      tester.widgetList<TextField>(find.byType(TextField)).first.obscureText,
      isFalse,
    );
  });
}
