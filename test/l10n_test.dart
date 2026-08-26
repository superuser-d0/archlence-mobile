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

import 'package:archlence_mobile/app_shell.dart';
import 'package:archlence_mobile/data/database.dart';
import 'package:archlence_mobile/l10n/app_localizations.dart';
import 'package:archlence_mobile/screens/settings_screen.dart';
import 'package:archlence_mobile/services/account_service.dart';
import 'package:archlence_mobile/ui/app_locale.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

Map<String, dynamic> _arb(String locale) =>
    jsonDecode(File('lib/l10n/app_$locale.arb').readAsStringSync())
        as Map<String, dynamic>;

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
    final englishOnly = <String>{};
    for (final key in keys) {
      final english = en[key] as String;
      // Templates render with their placeholders filled in, so an exact match
      // would never fire; and a value the two languages share is not evidence
      // of anything.
      if (english.contains('{') || english == tr[key]) continue;
      englishOnly.add(english);
      // `SectionLabel` upper-cases what it is given, so the heading on screen
      // is not the ARB value. Without this the section headings — the very
      // place the miss showed up — would be invisible to this test.
      englishOnly.add(english.toUpperCase());
    }

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

      final leaked = tester
          .widgetList<Text>(find.byType(Text))
          .map((widget) => widget.data)
          .whereType<String>()
          .where(englishOnly.contains)
          .toSet();
      expect(leaked, isEmpty, reason: 'left in English on the $tab tab');
    }
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
