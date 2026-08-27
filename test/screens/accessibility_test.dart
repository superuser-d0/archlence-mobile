/// Every screen, against Flutter's own accessibility guidelines.
///
/// **A whole-app rule tested as one, like `dead_controls_test.dart`.** Left to
/// each screen's file, a new screen would arrive with no such check — and this
/// is a class of defect nobody notices from the outside, because it is
/// invisible to anyone not using a screen reader, a large font, or a phone
/// held at arm's length.
///
/// **The thresholds are Flutter's, not this file's.** `androidTapTargetGuideline`
/// is Material's 48x48; `textContrastGuideline` is WCAG AA. Inventing numbers
/// here would be inventing a standard, and the point of a guideline is that
/// somebody else set it.
///
/// **What this cannot see.** These guidelines read the semantics tree, which
/// is what a screen reader reads — so they catch an unlabelled control and a
/// target too small to hit. They do NOT catch a reading ORDER that makes no
/// sense, or a label that is technically present and useless ("button"). Those
/// need a person with TalkBack on, and this file does not pretend otherwise.
library;

import 'package:archlence_mobile/app_services.dart';
import 'package:archlence_mobile/app_shell.dart';
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

  /// Fills the profile so the screens have something to draw.
  ///
  /// An EMPTY app passes every one of these guidelines trivially — there is
  /// nothing on screen to be unlabelled or too small. The data is the point.
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

  /// The screens a user can reach, each on its own.
  ///
  /// A phone-sized surface, not the 2400px one the other screen tests use: a
  /// tap target's SIZE is the thing being measured, and measuring it on a
  /// surface no phone has would measure nothing.
  final screens = <String, Widget Function()>{
    'shell': () => const AppShell(),
    'category settings': () => const CategorySettingsScreen(),
    'calendar': () => const CalendarScreen(),
    'budget': () => const BudgetScreen(),
    'savings': () => const SavingsScreen(),
    'backup': () => const BackupScreen(),
    'basic calculator': () => const BasicCalculatorScreen(),
    'interest calculator': () => const InterestCalculatorScreen(),
    'compound calculator': () => const CompoundCalculatorScreen(),
    'loan calculator': () => const LoanCalculatorScreen(),
  };

  Future<void> open(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(testApp(services, screen));
    await tester.pumpAndSettle();
  }

  /// The screens this guideline is applied to.
  ///
  /// **The calendar is excluded, by name and with a number.** Its month grid
  /// is seven columns wide. Seven 48dp columns need 336dp; a 360dp phone has
  /// already spent 48 on the screen margin and 16 on the card, leaving 296 —
  /// 42dp a column. The cells are 48 TALL, the dimension that is free.
  /// Material's own date picker makes the same trade.
  ///
  /// The exclusion is one screen and one guideline, not a blanket: the
  /// calendar is still held to the other two, and the size its cells actually
  /// reach is pinned by its own test below, so they cannot shrink further
  /// under cover of this exemption.
  final tapTargetScreens = {
    for (final entry in screens.entries)
      if (entry.key != 'calendar') entry.key: entry.value,
  };

  group('every tappable thing is big enough to hit', () {
    for (final entry in tapTargetScreens.entries) {
      testWidgets(entry.key, (tester) async {
        await seed();
        await open(tester, entry.value());
        // Material's 48x48, which is Flutter's constant rather than a
        // number chosen here.
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      });
    }

    testWidgets('the calendar gets as close as seven columns allow', (
      tester,
    ) async {
      // Not "it is exempt" — the exemption is bounded. A cell must be the
      // full 48 tall, and no narrower than the grid forces, so a future
      // padding change that shrinks them fails here rather than passing
      // under the exclusion above.
      await seed();
      await open(tester, const CalendarScreen());

      final tappable = find.ancestor(
        of: find.text('15'),
        matching: find.byType(InkWell),
      );
      final size = tester.getSize(tappable.first);
      expect(size.height, greaterThanOrEqualTo(48));
      expect(
        size.width,
        greaterThanOrEqualTo(42),
        reason: '(360 - 48 margin - 16 card) / 7 = 42.3; less than that means '
            'padding was added back',
      );
    });
  });

  group('every tappable thing says what it is', () {
    for (final entry in screens.entries) {
      testWidgets(entry.key, (tester) async {
        await seed();
        await open(tester, entry.value());
        // An icon with no label is a button a screen reader announces as
        // nothing at all.
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      });
    }
  });

  group('text stands out from what is behind it', () {
    for (final entry in screens.entries) {
      testWidgets(entry.key, (tester) async {
        await seed();
        await open(tester, entry.value());
        // WCAG AA, via Flutter's own implementation.
        await expectLater(tester, meetsGuideline(textContrastGuideline));
      });
    }
  });
}
