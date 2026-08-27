/// The Tools launcher and the two screens behind it.
library;

import 'package:archlence_mobile/app_services.dart';
import 'package:archlence_mobile/data/database.dart';
import 'package:archlence_mobile/screens/budget_screen.dart';
import 'package:archlence_mobile/screens/calendar_screen.dart';
import 'package:archlence_mobile/screens/savings_screen.dart';
import 'package:archlence_mobile/screens/tools_screen.dart';
import 'package:archlence_mobile/services/account_service.dart';
import 'package:archlence_mobile/services/recurring_service.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';

import 'package:archlence_mobile/widgets/surfaces.dart';

import '../support/test_app.dart';

void main() {
  late ArchlenceDatabase db;
  late AppServices services;

  setUp(() {
    db = ArchlenceDatabase.memory();
    services = testServices(db);
  });

  tearDown(() => db.close());

  Future<int> cashAccount({Object balance = 1000000}) =>
      services.accounts.createAccount(
        name: 'Maaş',
        accountType: AccountType.checking,
        initialBalance: balance,
      );

  /// Writes a plan row directly — the point is a known state, not the write
  /// rules, which `budget_service_test.dart` covers.
  Future<void> plan({
    required int month,
    required int year,
    required Object amount,
    String? category,
    String type = 'expense',
    String name = 'Kalem',
  }) async {
    await db.customInsert(
      'INSERT INTO monthly_budget_plan (type, name, amount, target_month, '
      'target_year, category_name, rollover_enabled, is_template, '
      'alert_threshold_pct) VALUES (?, ?, ?, ?, ?, ?, 0, 0, 80)',
      variables: [
        Variable<String>(type),
        Variable<String>(name),
        Variable<double>(double.parse(amount.toString())),
        Variable<int>(month),
        Variable<int>(year),
        Variable<String>(category),
      ],
    );
  }

  group('the launcher', () {
    testWidgets('a tool with nothing behind it is marked, not left tappable', (
      tester,
    ) async {
      // A card that looks live and does nothing on tap is a defect the user
      // cannot tell from a slow one.
      await pumpScreen(tester, services, const ToolsScreen());

      // Six now, not seven: Calendar stopped being a placeholder. The count
      // has to move DOWN as cards are wired, or a card could be given a
      // destination and keep its chip.
      expect(find.text('NOT YET'), findsNWidgets(6));
      expect(find.text('Monthly\nBudget'), findsOneWidget);
      expect(find.text('Savings\nGoal'), findsOneWidget);
      expect(find.text('Calendar'), findsOneWidget);
    });

    testWidgets('Calendar opens the calendar screen', (tester) async {
      await pumpScreen(tester, services, const ToolsScreen());
      await tester.tap(find.text('Calendar'));
      await tester.pumpAndSettle();

      expect(find.byType(CalendarScreen), findsOneWidget);
    });

    testWidgets('Monthly Budget opens the budget screen', (tester) async {
      await pumpScreen(tester, services, const ToolsScreen());
      await tester.tap(find.text('Monthly\nBudget'));
      await tester.pumpAndSettle();

      expect(find.byType(BudgetScreen), findsOneWidget);
    });

    testWidgets('Savings Goal opens the savings screen', (tester) async {
      await pumpScreen(tester, services, const ToolsScreen());
      await tester.tap(find.text('Savings\nGoal'));
      await tester.pumpAndSettle();

      expect(find.byType(SavingsScreen), findsOneWidget);
    });

    testWidgets('an unavailable tool is not even tappable', (tester) async {
      // Not merely "tapping does nothing": the card must not OFFER the tap.
      // A guard inside the handler leaves the ripple and the pointer
      // affordance in place, which is the defect — the user cannot tell it
      // from a screen that is slow to open.
      await pumpScreen(tester, services, const ToolsScreen());

      AppCard cardFor(String label) => tester.widget<AppCard>(
        find.ancestor(of: find.text(label), matching: find.byType(AppCard)),
      );

      expect(cardFor('Calculator').onTap, isNull);
      expect(cardFor('Monthly\nBudget').onTap, isNotNull);

      await tester.tap(find.text('Calculator'));
      await tester.pumpAndSettle();
      expect(find.byType(BudgetScreen), findsNothing);
    });
  });

  group('the budget screen', () {
    testWidgets('reports the plan, the reservation and what is left', (
      tester,
    ) async {
      final accountId = await cashAccount();
      final now = DateTime.now();
      await plan(
        month: now.month,
        year: now.year,
        amount: 30000,
        name: 'Maaş Planı',
        type: 'income',
      );
      await plan(
        month: now.month,
        year: now.year,
        amount: 12000,
        category: 'Kira',
      );
      await services.recurring.insertRecurringPayment(
        name: 'Netflix',
        amount: 229.99,
        category: 'Dijital Abonelik',
        frequency: RecurrenceFrequency.monthly,
        nextDueDate: DateTime(now.year, now.month, 28),
        accountId: accountId,
      );

      await pumpScreen(tester, services, const BudgetScreen());

      expect(find.text('30.000,00 ₺'), findsOneWidget);
      // Twice: the planned total, and the category row's own "Left", since
      // nothing has been spent against it.
      expect(find.text('12.000,00 ₺'), findsNWidgets(2));
      expect(find.text('229,99 ₺'), findsWidgets, reason: 'reserved');
      expect(find.text('17.770,01 ₺'), findsOneWidget, reason: 'left to spend');
      expect(find.text('Netflix'), findsOneWidget);
    });

    testWidgets('a category tracks what has been spent against it', (
      tester,
    ) async {
      final accountId = await cashAccount();
      final now = DateTime.now();
      await plan(
        month: now.month,
        year: now.year,
        amount: 500,
        category: 'Süpermarket',
      );
      await services.transactions.addTransaction(
        accountId: accountId,
        amount: 125,
        transactionType: 'expense',
        category: 'Süpermarket',
      );

      await pumpScreen(tester, services, const BudgetScreen());

      expect(find.text('Süpermarket'), findsOneWidget);
      expect(find.text('%25'), findsOneWidget);
      expect(find.text('Spent'), findsOneWidget);
      expect(find.text('Left'), findsOneWidget);
      expect(find.text('375,00 ₺'), findsOneWidget);
    });

    testWidgets('an overspent category says how far over, not how much left', (
      tester,
    ) async {
      final accountId = await cashAccount();
      final now = DateTime.now();
      await plan(
        month: now.month,
        year: now.year,
        amount: 300,
        category: 'Kıyafet',
      );
      await services.transactions.addTransaction(
        accountId: accountId,
        amount: 450,
        transactionType: 'expense',
        category: 'Kıyafet',
      );

      await pumpScreen(tester, services, const BudgetScreen());

      expect(find.text('Over by'), findsOneWidget);
      expect(find.text('Left'), findsNothing);
      expect(find.text('150,00 ₺'), findsOneWidget);
      expect(find.text('%150'), findsOneWidget);
    });

    testWidgets('no plan for the month says so', (tester) async {
      await pumpScreen(tester, services, const BudgetScreen());
      expect(find.textContaining('No category plans'), findsOneWidget);
      expect(find.text('0,00 ₺'), findsWidgets);
    });

    testWidgets('a weekly subscription reserves every occurrence', (
      tester,
    ) async {
      // One fee would understate a weekly charge four- or five-fold.
      final accountId = await cashAccount();
      final now = DateTime.now();
      await services.recurring.insertRecurringPayment(
        name: 'Haftalık',
        amount: 100,
        frequency: RecurrenceFrequency.weekly,
        nextDueDate: DateTime(now.year, now.month),
        accountId: accountId,
        recurrenceDay: 1,
      );

      await pumpScreen(tester, services, const BudgetScreen());

      expect(find.textContaining('×'), findsOneWidget);
    });

    testWidgets('the planner offers this month through December', (
      tester,
    ) async {
      await pumpScreen(tester, services, const BudgetScreen());
      const names = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      final thisMonth = DateTime.now().month;
      expect(find.text(names[thisMonth - 1]), findsOneWidget);
      expect(find.text('Dec'), findsOneWidget);
      if (thisMonth > 1) {
        expect(find.text('Jan'), findsNothing);
      }
    });
  });

  group('the savings screen', () {
    testWidgets('lists every goal', (tester) async {
      await services.savings.createGoal(goalName: 'Tatil', targetAmount: 20000);
      await services.savings.createGoal(
        goalName: 'Araba',
        targetAmount: 500000,
      );

      await pumpScreen(tester, services, const SavingsScreen());

      expect(find.text('Tatil'), findsOneWidget);
      expect(find.text('Araba'), findsOneWidget);
    });

    testWidgets('says a goal is not spending', (tester) async {
      // The one thing a user could reasonably get wrong about the feature.
      await pumpScreen(tester, services, const SavingsScreen());
      expect(find.textContaining('not spending'), findsOneWidget);
    });

    testWidgets('no goals says so', (tester) async {
      await pumpScreen(tester, services, const SavingsScreen());
      expect(find.textContaining('No savings goals yet'), findsOneWidget);
    });
  });
}
