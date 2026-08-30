/// Every tab, not just the one the app opens on.
///
/// **This file exists because of what it found.** `accessibility_test.dart`
/// applies Flutter's three guidelines to `AppShell`, and
/// `wide_layout_test.dart` lays `AppShell` out at 360x800. Both are good
/// tests and both see the same thing: the HOME tab. `AppShell` opens on it,
/// neither file taps anything, and the other four tabs are never built. Six
/// defects lived on those four tabs through 903 unit tests, 14 device tests
/// and a hand-driven walk of a release build — see the roadmap's "The
/// pre-release sweep".
///
/// So this one taps. Five tabs against: the three guidelines, a 1.5x and 2.0x
/// font scale, a 320dp phone, and Turkish at both the default scale and 2.0x.
///
/// **The font scale goes through `platformDispatcher`, not a `MediaQuery`.**
/// Wrapping the app in `MediaQuery(data: MediaQueryData(textScaler: ...))`
/// does not override one field — it REPLACES the whole `MediaQueryData`, so
/// size, padding and insets all fall back to defaults and every screen lays
/// out against a zero-size window. The first draft of this file did that and
/// produced overflows that were its own fault.
///
/// **A layout test only sees what gets laid out**, which is the lesson this
/// file is made of and does not escape: it walks tabs, not the sheets and
/// pushed routes behind them. Those are still uncovered, deliberately and
/// with a note in the roadmap rather than silently.
library;

import 'package:archlence_mobile/app_services.dart';
import 'package:archlence_mobile/app_shell.dart';
import 'package:archlence_mobile/data/database.dart';
import 'package:archlence_mobile/services/account_service.dart';
import 'package:archlence_mobile/services/recurring_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_app.dart';

void main() {
  late ArchlenceDatabase db;
  late AppServices services;

  setUp(() {
    db = ArchlenceDatabase.memory();
    services = testServices(db);
  });

  tearDown(() => db.close());

  /// Enough data that every tab has something to draw.
  ///
  /// An empty app passes all of this trivially: nothing on screen is
  /// unlabelled, too small, or too big for its box when there is nothing on
  /// screen.
  Future<void> seed() async {
    final id = await services.accounts.createAccount(
      name: 'Maaş',
      accountType: AccountType.checking,
      initialBalance: 25000,
    );
    await services.accounts.createAccount(
      name: 'Kart',
      accountType: AccountType.creditCard,
      initialBalance: 3500,
      creditLimit: 20000,
    );
    await services.transactions.addTransaction(
      accountId: id,
      amount: 1250,
      transactionType: 'expense',
      category: 'Market',
      description: 'haftalık alışveriş',
    );
    await services.savings.createGoal(goalName: 'Tatil', targetAmount: 20000);
    await services.recurring.insertRecurringPayment(
      name: 'Netflix',
      amount: 229.99,
      category: 'Dijital Abonelik',
      frequency: RecurrenceFrequency.monthly,
      nextDueDate: DateTime.now().add(const Duration(days: 5)),
      accountId: id,
    );
  }

  /// The tab labels, which are also how a tab is reached.
  ///
  /// Driving the shell by its visible text makes this file language-dependent
  /// in a way the rest of the suite is not — hence the second list rather
  /// than a lookup, so a renamed label fails here loudly instead of silently
  /// testing the Home tab five times.
  const enTabs = <String>['Home', 'Assets', 'Cards', 'Tools', 'Settings'];
  const trTabs = <String>[
    'Ana Sayfa',
    'Varlıklar',
    'Kartlar',
    'Araçlar',
    'Ayarlar',
  ];

  /// A phone-sized surface, not the 2400px one the other screen tests use.
  ///
  /// 1080x2400 at a device pixel ratio of 3 is 360x800 logical pixels, which
  /// is the width most of the mid-range still ships. The Tools overflow this
  /// file was written for does not happen on the 411dp emulator.
  Future<void> openTab(
    WidgetTester tester,
    String tab, {
    Size size = const Size(1080, 2400),
    double textScale = 1.0,
    Locale? locale,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    if (textScale != 1.0) {
      tester.platformDispatcher.textScaleFactorTestValue = textScale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    }
    await tester.pumpWidget(testApp(services, const AppShell(), locale: locale));
    await tester.pumpAndSettle();
    final tabs = locale?.languageCode == 'tr' ? trTabs : enTabs;
    if (tab != tabs.first) {
      await tester.tap(find.text(tab));
      await tester.pumpAndSettle();
    }
  }

  group('every tab says what its controls are', () {
    for (final tab in enTabs) {
      testWidgets(tab, (tester) async {
        await seed();
        await openTab(tester, tab);
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      });
    }
  });

  group('every tab has targets big enough to hit', () {
    for (final tab in enTabs) {
      testWidgets(tab, (tester) async {
        await seed();
        await openTab(tester, tab);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      });
    }
  });

  group('every tab keeps its text readable against what is behind it', () {
    for (final tab in enTabs) {
      testWidgets(tab, (tester) async {
        await seed();
        await openTab(tester, tab);
        await expectLater(tester, meetsGuideline(textContrastGuideline));
      });
    }
  });

  // The three groups below assert nothing explicitly, and that is the point:
  // a RenderFlex that overflows raises, and a raise inside a testWidgets body
  // fails the test. What is being checked is that the screen can be laid out
  // at all under a setting the user is free to choose.
  group('every tab lays out at a 1.5x font scale', () {
    for (final tab in enTabs) {
      testWidgets(tab, (tester) async {
        await seed();
        await openTab(tester, tab, textScale: 1.5);
      });
    }
  });

  group('every tab lays out at a 2.0x font scale', () {
    for (final tab in enTabs) {
      testWidgets(tab, (tester) async {
        await seed();
        await openTab(tester, tab, textScale: 2.0);
      });
    }
  });

  group('every tab lays out on a 320dp phone', () {
    for (final tab in enTabs) {
      testWidgets(tab, (tester) async {
        await seed();
        await openTab(tester, tab, size: const Size(960, 2400));
      });
    }
  });

  group('every tab lays out in Turkish', () {
    for (final tab in trTabs) {
      testWidgets(tab, (tester) async {
        await seed();
        await openTab(tester, tab, locale: const Locale('tr'));
      });
    }
  });

  group('every tab lays out in Turkish at a 2.0x font scale', () {
    for (final tab in trTabs) {
      testWidgets(tab, (tester) async {
        await seed();
        await openTab(
          tester,
          tab,
          textScale: 2.0,
          locale: const Locale('tr'),
        );
      });
    }
  });
}
