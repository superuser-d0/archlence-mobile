/// The pushed routes, at widths and font scales nothing laid them out at.
///
/// **The third and thinnest layer.** `tab_sweep_test.dart` walks the five
/// tabs and found six defects; `sheet_sweep_test.dart` walks the nine sheets
/// and found seven. The routes pushed from Tools and Settings were better
/// covered than either — `accessibility_test.dart` already holds each of them
/// to all three guidelines — so this file is not about the guidelines.
///
/// It is about the two things that file cannot vary. It lays out on
/// `pumpScreen`'s surface, which is 800x2400 at a device pixel ratio of 1, and
/// it lays out at one font scale. **No phone is 800dp wide**, and Android
/// offers a larger font three taps into Display settings. So this walks the
/// same screens at 360dp and 320dp, at 1.5x and 2.0x, and in Turkish.
///
/// **The calendar keeps its one exemption**, and only that one. Its month grid
/// is seven columns wide and cannot give each 48dp on a 360dp phone;
/// `accessibility_test.dart` argues that in full and pins the size its cells
/// do reach. The exemption is one screen and one guideline — the calendar is
/// still laid out here at every width and scale like everything else.
library;

import 'package:archlence_mobile/app_services.dart';
import 'package:archlence_mobile/data/database.dart';
import 'package:archlence_mobile/screens/backup_screen.dart';
import 'package:archlence_mobile/screens/budget_screen.dart';
import 'package:archlence_mobile/screens/calculator_screens.dart';
import 'package:archlence_mobile/screens/calendar_screen.dart';
import 'package:archlence_mobile/screens/category_settings_screen.dart';
import 'package:archlence_mobile/screens/savings_screen.dart';
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

  /// The same profile the other two sweeps use.
  ///
  /// An empty app passes every one of these trivially: there is nothing on
  /// screen to be unlabelled, too small, or too big for its box.
  Future<void> seed() async {
    final id = await services.accounts.createAccount(
      name: 'Maaş Hesabı',
      accountType: AccountType.checking,
      initialBalance: 25000,
    );
    await services.accounts.createAccount(
      name: 'Bonus Kart',
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
    await services.savings.createGoal(
      goalName: 'Tatil Fonu',
      targetAmount: 20000,
    );
    await services.recurring.insertRecurringPayment(
      name: 'Netflix Standart',
      amount: 229.99,
      category: 'Dijital Abonelik',
      frequency: RecurrenceFrequency.monthly,
      nextDueDate: DateTime.now().add(const Duration(days: 5)),
      accountId: id,
    );
  }

  final routes = <String, Widget Function()>{
    'budget': () => const BudgetScreen(),
    'savings': () => const SavingsScreen(),
    'calendar': () => const CalendarScreen(),
    'category settings': () => const CategorySettingsScreen(),
    'backup': () => const BackupScreen(),
    'basic calculator': () => const BasicCalculatorScreen(),
    'interest calculator': () => const InterestCalculatorScreen(),
    'compound calculator': () => const CompoundCalculatorScreen(),
    'loan calculator': () => const LoanCalculatorScreen(),
  };

  Future<void> open(
    WidgetTester tester,
    Widget screen, {
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
    await tester.pumpWidget(testApp(services, screen, locale: locale));
    await tester.pumpAndSettle();
  }

  void forEveryRoute(
    String description,
    Future<void> Function(WidgetTester, Widget) body, {
    Set<String> except = const {},
  }) {
    group(description, () {
      for (final entry in routes.entries) {
        if (except.contains(entry.key)) continue;
        testWidgets(entry.key, (tester) async {
          await seed();
          await body(tester, entry.value());
        });
      }
    });
  }

  // The guidelines, at a PHONE width rather than the 800dp one
  // `accessibility_test.dart` uses. A tap target's size does not change with
  // the window, but what is laid out does, and a guideline only reads what
  // was laid out.
  forEveryRoute('says what its controls are, on a phone', (tester, screen) async {
    await open(tester, screen);
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  });

  forEveryRoute(
    'has targets big enough to hit, on a phone',
    (tester, screen) async {
      await open(tester, screen);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    },
    // See the file comment: the month grid's seven columns cannot each have
    // 48dp on a 360dp phone, and its cells are 48 TALL, which is the
    // dimension that is free. Material's own date picker makes the same trade.
    except: {'calendar'},
  );

  // These assert nothing on purpose: a RenderFlex that overflows raises, and
  // a raise inside a testWidgets body fails the test.
  forEveryRoute('lays out at a 1.5x font scale', (tester, screen) async {
    await open(tester, screen, textScale: 1.5);
  });

  forEveryRoute('lays out at a 2.0x font scale', (tester, screen) async {
    await open(tester, screen, textScale: 2.0);
  });

  forEveryRoute('lays out on a 320dp phone', (tester, screen) async {
    await open(tester, screen, size: const Size(960, 2400));
  });

  forEveryRoute('lays out in Turkish', (tester, screen) async {
    await open(tester, screen, locale: const Locale('tr'));
  });

  forEveryRoute('lays out in Turkish at a 2.0x font scale', (
    tester,
    screen,
  ) async {
    await open(tester, screen, textScale: 2.0, locale: const Locale('tr'));
  });
}
