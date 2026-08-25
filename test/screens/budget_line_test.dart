/// Adding a monthly budget line.
library;

import 'package:archlence_mobile/app_services.dart';
import 'package:archlence_mobile/data/database.dart';
import 'package:archlence_mobile/screens/budget_screen.dart';
import 'package:archlence_mobile/services/account_service.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_app.dart';

void main() {
  late ArchlenceDatabase db;
  late AppServices services;
  late int month;
  late int year;

  setUp(() {
    db = ArchlenceDatabase.memory();
    services = testServices(db);
    month = DateTime.now().month;
    year = DateTime.now().year;
  });

  tearDown(() => db.close());

  Future<void> openSheet(WidgetTester tester) async {
    await pumpScreen(tester, services, const BudgetScreen());
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
  }

  Future<void> type(WidgetTester tester, String label, String value) async {
    final field = find.ancestor(
      of: find.text(label),
      matching: find.byType(TextField),
    );
    await tester.ensureVisible(field.first);
    await tester.pumpAndSettle();
    await tester.enterText(field.first, value);
    await tester.pumpAndSettle();
  }

  Future<void> pick(WidgetTester tester, String field, String value) async {
    final target = find.byKey(Key('field-$field'));
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
    await tester.tap(find.text(value).last);
    await tester.pumpAndSettle();
  }

  Future<void> toggle(WidgetTester tester, String title) async {
    await tester.ensureVisible(find.text(title));
    await tester.pumpAndSettle();
    await tester.tap(find.text(title));
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Save line'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save line'));
    await tester.pumpAndSettle();
  }

  testWidgets('saves an expense line and the month re-reads', (tester) async {
    await openSheet(tester);
    await type(tester, 'Name', 'Kira');
    await type(tester, 'Amount for the month', '12.000');
    await pick(tester, 'category', 'Ev Kirası');
    await save(tester);

    final budget = await services.budget.calculateMonthlyBudget(month, year);
    expect(budget.plannedExpense, Decimal.parse('12000'));
    expect(find.text('12.000,00 ₺'), findsWidgets, reason: 'page re-read');
    expect(find.text('Ev Kirası'), findsOneWidget);
  });

  testWidgets('an income line raises what is left to spend', (tester) async {
    await openSheet(tester);
    await tester.tap(find.text('Income'));
    await tester.pumpAndSettle();
    await type(tester, 'Name', 'Maaş Planı');
    await type(tester, 'Amount for the month', '30.000');
    await save(tester);

    final budget = await services.budget.calculateMonthlyBudget(month, year);
    expect(budget.plannedIncome, Decimal.parse('30000'));
    expect(budget.remainingBudget, Decimal.parse('30000'));
  });

  testWidgets('the category list follows the type', (tester) async {
    await openSheet(tester);
    await pick(tester, 'category', 'Ev Kirası');
    expect(find.text('Ev Kirası'), findsOneWidget);

    await tester.tap(find.text('Income'));
    await tester.pumpAndSettle();
    expect(find.text('Ev Kirası'), findsNothing, reason: 'cleared with type');

    await tester.tap(find.byKey(const Key('field-category')));
    await tester.pumpAndSettle();
    expect(find.text('Maaş'), findsWidgets);
  });

  testWidgets('"every month" makes it a template that other months see', (
    tester,
  ) async {
    await openSheet(tester);
    await type(tester, 'Name', 'Aidat');
    await type(tester, 'Amount for the month', '1.500');
    await toggle(tester, 'Every month');
    await save(tester);

    // A later month, which has no line of its own, still sees it.
    final later = month == 12 ? 12 : month + 1;
    final budget = await services.budget.calculateMonthlyBudget(later, year);
    expect(budget.plannedExpense, Decimal.parse('1500'));
  });

  testWidgets('a plain line applies to its own month only', (tester) async {
    // The complement: without the toggle, next month must not inherit it.
    if (month == 12) return;
    await openSheet(tester);
    await type(tester, 'Name', 'Tek Seferlik');
    await type(tester, 'Amount for the month', '900');
    await save(tester);

    expect(
      (await services.budget.calculateMonthlyBudget(
        month + 1,
        year,
      )).plannedExpense,
      Decimal.zero,
    );
  });

  testWidgets('the rollover flag is stored', (tester) async {
    await openSheet(tester);
    await type(tester, 'Name', 'Market');
    await type(tester, 'Amount for the month', '3.000');
    await pick(tester, 'category', 'Süpermarket');
    await toggle(tester, 'Carry the balance over');
    await save(tester);

    final progress = (await services.budget.getCategoryBudgetProgress(
      month,
      year,
    )).single;
    expect(progress.rolloverEnabled, isTrue);
  });

  testWidgets('the alert threshold is stored, not left at the default', (
    tester,
  ) async {
    await openSheet(tester);
    await type(tester, 'Name', 'Market');
    await type(tester, 'Amount for the month', '3.000');
    await pick(tester, 'category', 'Süpermarket');
    await tester.ensureVisible(find.byType(Slider));
    await tester.pumpAndSettle();
    // Drag the slider to its minimum, which is unambiguously not the default.
    await tester.drag(find.byType(Slider), const Offset(-500, 0));
    await tester.pumpAndSettle();
    await save(tester);

    final progress = (await services.budget.getCategoryBudgetProgress(
      month,
      year,
    )).single;
    expect(progress.alertThresholdPct, 10);
  });

  testWidgets('the line lands in the month that is selected', (tester) async {
    // The planner offers this month through December, and a line saved while
    // a later one is chosen must land there — not in today's month.
    if (month == 12) return;
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
    await pumpScreen(tester, services, const BudgetScreen());
    await tester.tap(find.text(names[month]));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await type(tester, 'Name', 'Gelecek Ay');
    await type(tester, 'Amount for the month', '4.000');
    await save(tester);

    expect(
      (await services.budget.calculateMonthlyBudget(
        month + 1,
        year,
      )).plannedExpense,
      Decimal.parse('4000'),
    );
    expect(
      (await services.budget.calculateMonthlyBudget(
        month,
        year,
      )).plannedExpense,
      Decimal.zero,
      reason: 'this month must be untouched',
    );
  });

  testWidgets('the sheet says what leaving the category out costs', (
    tester,
  ) async {
    // The consequence is invisible otherwise: the line counts towards the
    // month and nothing tracks it.
    await openSheet(tester);
    expect(
      find.textContaining('Only a line with a category is tracked'),
      findsOneWidget,
    );
  });

  testWidgets('a nameless line is refused by the service', (tester) async {
    await openSheet(tester);
    await type(tester, 'Amount for the month', '100');
    await save(tester);

    expect(find.text('Give the line a name.'), findsOneWidget);
    expect(
      (await services.budget.calculateMonthlyBudget(
        month,
        year,
      )).plannedExpense,
      Decimal.zero,
    );
  });

  testWidgets('a zero amount is refused with the service\'s own rule', (
    tester,
  ) async {
    await openSheet(tester);
    await type(tester, 'Name', 'Sıfır');
    await type(tester, 'Amount for the month', '0');
    await save(tester);

    expect(find.text('Enter an amount above zero.'), findsOneWidget);
  });

  testWidgets('an amount that is not a number never reaches the service', (
    tester,
  ) async {
    await openSheet(tester);
    await type(tester, 'Name', 'X');
    await type(tester, 'Amount for the month', ',,,');
    await save(tester);

    expect(find.text('Enter an amount.'), findsOneWidget);
    expect(
      (await services.budget.calculateMonthlyBudget(
        month,
        year,
      )).plannedExpense,
      Decimal.zero,
    );
  });

  testWidgets('a line without a category is not tracked against spending', (
    tester,
  ) async {
    // The optional field's actual consequence, which the form spells out.
    final accountId = await services.accounts.createAccount(
      name: 'Maaş',
      accountType: AccountType.checking,
      initialBalance: 100000,
    );
    await services.transactions.addTransaction(
      accountId: accountId,
      amount: 500,
      transactionType: 'expense',
      category: 'Süpermarket',
    );

    await openSheet(tester);
    await type(tester, 'Name', 'Kategorisiz');
    await type(tester, 'Amount for the month', '3.000');
    await save(tester);

    expect(
      (await services.budget.calculateMonthlyBudget(
        month,
        year,
      )).plannedExpense,
      Decimal.parse('3000'),
      reason: 'it still counts towards the month',
    );
    expect(
      await services.budget.getCategoryBudgetProgress(month, year),
      isEmpty,
      reason: 'but nothing tracks it',
    );
    expect(
      find.textContaining('Only a line with a category is tracked'),
      findsNothing,
      reason: 'the sheet closed',
    );
  });
}
