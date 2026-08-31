/// The label layer: that both languages are complete, that they agree on
/// their placeholders, and that a screen actually comes out in Turkish.
///
/// The ARB files are read as FILES here rather than through the generated
/// class. A key missing from `app_tr.arb` compiles perfectly well — Flutter
/// falls back to the template — so nothing but a check on the files
/// themselves can tell an English label rendered on purpose from one nobody
/// has translated yet.
library;

import 'dart:convert';
import 'dart:io';

import 'package:archlence_mobile/app_services.dart';
import 'package:archlence_mobile/app_shell.dart';
import 'package:archlence_mobile/backup/backup_service.dart';
import 'package:archlence_mobile/backup/key_recovery_service.dart';
import 'package:archlence_mobile/crypto/field_crypto.dart';
import 'package:archlence_mobile/data/database.dart';
import 'package:archlence_mobile/l10n/app_localizations.dart';
import 'package:archlence_mobile/screens/backup_screen.dart';
import 'package:archlence_mobile/screens/settings_screen.dart';
import 'package:archlence_mobile/services/account_service.dart';
import 'package:archlence_mobile/ui/app_locale.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fixed_key_provider.dart';
import 'support/test_app.dart';

Map<String, dynamic> _arb(String locale) =>
    jsonDecode(File('lib/l10n/app_$locale.arb').readAsStringSync())
        as Map<String, dynamic>;

/// Every English value whose Turkish differs, plus its upper-cased form.
///
/// Templates are skipped: they render with their placeholders filled in, so an
/// exact match would never fire. A value the two languages SHARE is skipped
/// too — `Archlence`, `Android Keystore`, `What-If Sandbox` — because seeing
/// it on a Turkish screen is evidence of nothing.
///
/// The upper-cased variant is not decoration. `SectionLabel` upper-cases what
/// it is given, so the heading on screen is never the ARB value, and without
/// this the section headings — the very place the first miss showed up —
/// would be invisible.
Set<String> _englishTurkishChanges(
  Map<String, dynamic> en,
  Map<String, dynamic> tr,
  List<String> keys,
) {
  final englishOnly = <String>{};
  for (final key in keys) {
    final english = en[key] as String;
    if (english.contains('{') || english == tr[key]) continue;
    englishOnly.add(english);
    englishOnly.add(english.toUpperCase());
  }
  return englishOnly;
}

/// Which of [englishOnly] is currently on screen.
Set<String> _leaked(WidgetTester tester, Set<String> englishOnly) => tester
    .widgetList<Text>(find.byType(Text))
    .map((widget) => widget.data)
    .whereType<String>()
    .where(englishOnly.contains)
    .toSet();

/// The `{placeholder}` names in a message, as a set.
Set<String> _placeholders(String message) => RegExp(r'\{(\w+)\}')
    .allMatches(message)
    .map((match) => match.group(1)!)
    .toSet();

void main() {
  final en = _arb('en');
  final tr = _arb('tr');
  final keys = en.keys.where((key) => !key.startsWith('@')).toList();

  test('every English label has a Turkish one', () {
    // Not a style point. A key missing here does not fail the build and does
    // not throw at runtime — it renders in English, on a Turkish screen,
    // next to Turkish labels, and only a user notices.
    expect(keys.where((key) => !tr.containsKey(key)), isEmpty);
  });

  test('and nothing is left over in Turkish', () {
    final live = keys.toSet();
    final leftOver = tr.keys.where(
      (key) => !key.startsWith('@') && !live.contains(key),
    );
    expect(
      leftOver,
      isEmpty,
      reason: 'a Turkish entry whose English key is gone is dead weight',
    );
  });

  test('the two languages substitute the same values', () {
    // `{amount}` dropped in translation is a sentence with a hole in it, and
    // `{amout}` is a literal brace on screen. Both compile.
    final mismatched = <String>[];
    for (final key in keys) {
      final expected = _placeholders(en[key] as String);
      final actual = _placeholders(tr[key] as String? ?? '');
      if (expected.difference(actual).isNotEmpty ||
          actual.difference(expected).isNotEmpty) {
        mismatched.add(key);
      }
    }
    expect(mismatched, isEmpty);
  });

  test('a label that says "your" in English says it politely in Turkish', () {
    // Turkish marks the second person on the noun, and it has two of them:
    // `-in` is the familiar form and `-iniz` the polite one. Both are correct
    // Turkish, only one is right for an app holding somebody's money, and a
    // release was pulled over the difference once. Nothing else in this file
    // can see it — the key exists, the placeholders match, and the sentence
    // is a good translation of the English.
    //
    // Three survived that rewrite and were found by opening the app:
    // `Verilerin şifreli`, `Paran nerede duruyor?` and the `Verilerin`
    // section heading. All three are short noun phrases, which is how they
    // passed for labels rather than for sentences addressed to the reader.
    //
    // The check reads the ENGLISH to decide where to look. Turkish `-in` is
    // also the genitive — `kartın limiti` is "the card's limit" and is
    // perfectly polite — so a scan of the Turkish alone flags every one of
    // those and cannot tell them apart. The English says whether a possessive
    // was meant at all.
    final polite = RegExp('(iniz|ınız|unuz|ünüz|niz|nız|nuz|nüz)');
    final addressed = RegExp(r'\byour\b', caseSensitive: false);

    // Words that merely contain those letters, removed before looking.
    // Without this, `Plan yalnızca aylık dağılımı izler` reads as polite to a
    // regular expression, and so does anything starting `Henüz`.
    final coincidence = RegExp('yalnız|henüz|deniz', caseSensitive: false);

    // Two labels answer an English "your" with no possessive at all, because
    // they were written impersonally: the categories belong to the `hane`
    // rather than to the reader, and the instalment note is about the bank's
    // limit rather than the reader's. Decisions, not misses.
    const impersonal = {'settingsCategorySubtitle', 'installmentNote'};

    final familiar = <String>[];
    for (final key in keys) {
      if (impersonal.contains(key)) continue;
      final english = en[key];
      final turkish = tr[key];
      if (english is! String || turkish is! String) continue;
      if (!addressed.hasMatch(english)) continue;
      if (!polite.hasMatch(turkish.replaceAll(coincidence, ''))) {
        familiar.add('$key — "$turkish"');
      }
    }

    expect(
      familiar,
      isEmpty,
      reason: 'these answer an English "your" without the polite -iniz, so '
          'they are either addressing the user as "sen" or should be added '
          'to the impersonal list with a reason',
    );
  });

  test('the app offers exactly the languages it has labels for', () {
    // `supportedLocales` is hand-written, because its ORDER decides what a
    // phone set to a third language falls back to. A locale added to the ARB
    // files and forgotten there would be a language nobody could select.
    expect(
      supportedLocales.toSet(),
      AppLocalizations.supportedLocales.toSet(),
    );
    expect(
      supportedLocales.first,
      const Locale('tr'),
      reason: 'an unsupported device locale falls back to the first entry, '
          'and this is a Turkish app that also speaks English',
    );
  });

  group('upper case', () {
    test('keeps the dot on a Turkish i', () {
      // Unicode's default mapping turns `i` into `I`, which is a letter
      // Turkish uses for something else. GÜVENLIK is not a Turkish word.
      expect(localizedUpperCase('Güvenlik', const Locale('tr')), 'GÜVENLİK');
      expect(
        localizedUpperCase('Görünüm ve Gizlilik', const Locale('tr')),
        'GÖRÜNÜM VE GİZLİLİK',
      );
    });

    test('and takes the dot off a dotless one', () {
      expect(localizedUpperCase('Ayarları', const Locale('tr')), 'AYARLARI');
    });

    test('leaves English alone', () {
      expect(localizedUpperCase('Security', const Locale('en')), 'SECURITY');
    });
  });

  testWidgets('no tab leaves an English label on a Turkish screen', (
    tester,
  ) async {
    // THE TEST THAT WOULD HAVE CAUGHT THE ONE THAT GOT THROUGH. Every label on
    // the Settings screen was moved to the ARB files except the lock tile's
    // three, and nothing failed: the other 578 tests run in English, where a
    // wired label and an unwired one render exactly the same string. It took
    // running the app on a device, in Turkish, to see "Lock when I come back"
    // sitting under GÜVENLİK.
    //
    // So this walks the tabs in Turkish and fails on any string that is an
    // English ARB value the Turkish file translates differently. It cannot
    // catch a label that was never given a key at all — nothing but reading
    // can — but it does catch a key that exists and is not being used.
    final englishOnly = _englishTurkishChanges(en, tr, keys);

    final db = ArchlenceDatabase.memory();
    addTearDown(db.close);
    final services = testServices(db);
    // Turkish names on purpose: an account the user called "Cash" would be a
    // false positive, and the point is to test the app's own text.
    await services.accounts.createAccount(
      name: 'Maaş',
      accountType: AccountType.checking,
      initialBalance: 10000,
    );
    await services.accounts.createAccount(
      name: 'Kart',
      accountType: AccountType.creditCard,
      creditLimit: 20000,
    );
    await services.savings.createGoal(goalName: 'Tatil', targetAmount: 20000);

    await pumpScreen(
      tester,
      services,
      const AppShell(),
      locale: const Locale('tr'),
    );

    for (final tab in const [
      'Ana Sayfa',
      'Varlıklar',
      'Kartlar',
      'Araçlar',
      'Ayarlar',
    ]) {
      await tester.tap(find.text(tab));
      await tester.pumpAndSettle();

      expect(
        _leaked(tester, englishOnly),
        isEmpty,
        reason: 'left in English on the $tab tab',
      );
    }
  });

  testWidgets('nor does Backup & Restore, which no tab walk reaches', (
    tester,
  ) async {
    // The tab walk cannot see this screen: it is pushed from Settings, and it
    // carries more prose than any tab does — the passphrase warning, the two
    // key sections. A screen the leak check does not reach is a screen where
    // the next unwired label goes unnoticed, so it is pumped on its own.
    final englishOnly = _englishTurkishChanges(en, tr, keys);

    final db = ArchlenceDatabase.memory();
    addTearDown(db.close);
    // `createTempSync`, not `await createTemp`. A `testWidgets` body runs in
    // a fake-async zone, and real file I/O awaited inside it never completes:
    // the test simply hangs until the runner gives up, with no failure to
    // read. `backup_screen_test.dart` uses the sync call for the same reason.
    final directory = Directory.systemTemp.createTempSync('archlence-l10n-');
    addTearDown(() => directory.deleteSync(recursive: true));

    final provider = FixedKeyProvider.arbitrary();
    final backup = BackupService(
      databasePath: '${directory.path}/finance.db',
      keyProvider: provider,
    );
    await pumpScreen(
      tester,
      AppServices.forDatabase(
        db,
        FieldCrypto(provider),
        backup: backup,
        keyRecovery: KeyRecoveryService(
          databasePath: '${directory.path}/finance.db',
          keyProvider: provider,
          backup: backup,
        ),
      ),
      const BackupScreen(),
      locale: const Locale('tr'),
    );

    expect(_leaked(tester, englishOnly), isEmpty);
  });

  testWidgets('a screen asked for Turkish is drawn in Turkish', (tester) async {
    // The end of the chain, not just the middle of it: the ARB files can be
    // complete and the delegates still not reach a screen.
    final db = ArchlenceDatabase.memory();
    addTearDown(db.close);

    await pumpScreen(
      tester,
      testServices(db),
      const SettingsScreen(),
      locale: const Locale('tr'),
    );

    expect(find.text('Şifreleme Anahtarı'), findsOneWidget);
    expect(find.text('GÜVENLİK'), findsOneWidget);
    expect(find.text('Encryption Key'), findsNothing);
  });
}
