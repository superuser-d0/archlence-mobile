/// Opening a savings goal, and moving money in and out of one.
library;

import 'package:archlence_mobile/app_services.dart';
import 'package:archlence_mobile/data/database.dart';
import 'package:archlence_mobile/screens/savings_screen.dart';
import 'package:archlence_mobile/services/account_service.dart';
import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show Variable;
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

  Future<int> cashAccount({String name = 'Maaş', Object balance = 10000}) =>
      services.accounts.createAccount(
        name: name,
        accountType: AccountType.checking,
        initialBalance: balance,
      );

  Future<void> open(WidgetTester tester) =>
      pumpScreen(tester, services, const SavingsScreen());

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

  Future<void> submit(WidgetTester tester, String label) async {
    await tester.ensureVisible(find.text(label).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  Future<void> openNewGoal(WidgetTester tester) async {
    await open(tester);
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
  }

  group('opening a goal', () {
    testWidgets('creates it and the list shows it without a refresh', (
      tester,
    ) async {
      await openNewGoal(tester);
      await type(tester, 'What it is for', 'Acil Durum Fonu');
      await type(tester, 'Target amount', '350.000');
      await submit(tester, 'Create goal');

      final goal = (await services.savings.getGoals()).single;
      expect(goal.goalName, 'Acil Durum Fonu');
      expect(goal.targetAmount, Decimal.parse('350000'));
      expect(find.text('Acil Durum Fonu'), findsOneWidget);
      expect(find.text('350.000,00 ₺'), findsOneWidget);
    });

    testWidgets('says a goal is not spending, where the user will read it', (
      tester,
    ) async {
      // The one thing about the feature a user could reasonably get wrong.
      await openNewGoal(tester);
      // Twice: the screen's own intro, and the sheet's — a user who opened
      // the form straight from a notification would only see the second.
      expect(find.text('Create goal'), findsOneWidget, reason: 'sheet is open');
      expect(find.textContaining('not spending'), findsNWidgets(2));
    });

    testWidgets('a nameless goal is refused by the service', (tester) async {
      await openNewGoal(tester);
      await type(tester, 'Target amount', '1.000');
      await submit(tester, 'Create goal');

      expect(find.text('Say what the goal is for.'), findsOneWidget);
      expect(await services.savings.getGoals(), isEmpty);
    });

    testWidgets('the name is stored trimmed', (tester) async {
      await openNewGoal(tester);
      await type(tester, 'What it is for', '   Tatil   ');
      await type(tester, 'Target amount', '1.000');
      await submit(tester, 'Create goal');

      expect((await services.savings.getGoals()).single.goalName, 'Tatil');
    });

    testWidgets('a target that is not a number is refused', (tester) async {
      await openNewGoal(tester);
      await type(tester, 'What it is for', 'Tatil');
      await type(tester, 'Target amount', ',,,');
      await submit(tester, 'Create goal');

      expect(find.text('Enter a target amount.'), findsOneWidget);
      expect(await services.savings.getGoals(), isEmpty);
    });

    testWidgets('a zero target is refused with the service\'s own rule', (
      tester,
    ) async {
      await openNewGoal(tester);
      await type(tester, 'What it is for', 'Tatil');
      await type(tester, 'Target amount', '0');
      await submit(tester, 'Create goal');

      expect(find.text('Enter an amount above zero.'), findsOneWidget);
      expect(await services.savings.getGoals(), isEmpty);
    });
  });

  group('moving money', () {
    Future<int> goalWith({Object target = 5000}) async {
      await cashAccount();
      return services.savings.createGoal(
        goalName: 'Tatil',
        targetAmount: target,
      );
    }

    Future<void> openMove(WidgetTester tester) async {
      await open(tester);
      await submit(tester, 'Save');
    }

    testWidgets('a deposit leaves the account and lands in the goal', (
      tester,
    ) async {
      final goalId = await goalWith();
      await openMove(tester);
      await type(tester, 'Amount', '1.500');
      await submit(tester, 'Set aside');

      expect(
        (await services.savings.getGoal(goalId))!.currentAmount,
        Decimal.parse('1500'),
      );
      expect(
        (await services.accounts.getAccounts()).single.balance,
        Decimal.parse('8500'),
      );
      expect(find.text('1.500,00 ₺'), findsWidgets, reason: 'list re-read');
    });

    testWidgets('it is not spending, so no transaction is written', (
      tester,
    ) async {
      final accountId = await cashAccount(name: 'İkinci');
      await goalWith();
      await openMove(tester);
      await type(tester, 'Amount', '500');
      await submit(tester, 'Set aside');

      for (final account in await services.accounts.getAccounts()) {
        expect(
          await services.transactions.getRecentForAccount(account.id),
          isEmpty,
          reason: 'setting money aside must not appear as an expense',
        );
      }
      expect(accountId, isNotNull);
    });

    testWidgets('an amount that is not a number never reaches the service', (
      tester,
    ) async {
      final goalId = await goalWith();
      await openMove(tester);
      await type(tester, 'Amount', ',,,');
      await submit(tester, 'Set aside');

      expect(find.text('Enter an amount.'), findsOneWidget);
      expect(
        (await services.savings.getGoal(goalId))!.currentAmount,
        Decimal.zero,
      );
      expect(
        (await services.accounts.getAccounts()).single.balance,
        Decimal.parse('10000'),
      );
    });

    testWidgets('a withdrawal puts it back', (tester) async {
      final goalId = await goalWith();
      await openMove(tester);
      await type(tester, 'Amount', '1.500');
      await submit(tester, 'Set aside');

      await submit(tester, 'Save');
      await tester.tap(find.text('Take back'));
      await tester.pumpAndSettle();
      await type(tester, 'Amount', '500');
      await submit(tester, 'Take back');

      expect(
        (await services.savings.getGoal(goalId))!.currentAmount,
        Decimal.parse('1000'),
      );
      expect(
        (await services.accounts.getAccounts()).single.balance,
        Decimal.parse('9000'),
      );
    });

    testWidgets('taking back more than the goal holds is refused', (
      tester,
    ) async {
      final goalId = await goalWith();
      await openMove(tester);
      await tester.tap(find.text('Take back'));
      await tester.pumpAndSettle();
      await type(tester, 'Amount', '500');
      await submit(tester, 'Take back');

      expect(find.text('The goal does not hold that much.'), findsOneWidget);
      expect(
        (await services.savings.getGoal(goalId))!.currentAmount,
        Decimal.zero,
      );
    });

    testWidgets('the account may go negative, and the form says so', (
      tester,
    ) async {
      // The deliberate absence of a guard in the service, said out loud.
      await cashAccount(name: 'Az Para', balance: 100);
      await services.savings.createGoal(goalName: 'Tatil', targetAmount: 5000);
      await openMove(tester);

      expect(find.textContaining('may go negative'), findsOneWidget);

      await type(tester, 'Amount', '500');
      await submit(tester, 'Set aside');

      expect(
        (await services.accounts.getAccounts()).first.balance,
        Decimal.parse('-400'),
      );
    });

    testWidgets('a credit card is not offered to move money between', (
      tester,
    ) async {
      // A goal holds money aside from a BALANCE, and a card has none.
      await goalWith();
      await services.accounts.createAccount(
        name: 'Bonus Kart',
        accountType: AccountType.creditCard,
        creditLimit: 20000,
      );
      await openMove(tester);
      await tester.tap(find.byKey(const Key('field-account')));
      await tester.pumpAndSettle();

      expect(find.text('Maaş'), findsWidgets);
      expect(find.text('Bonus Kart'), findsNothing);
    });

    testWidgets('a stale card is refused before any money moves', (
      tester,
    ) async {
      // The reason goalUid exists: a numeric id freed by a restore and taken
      // by a different goal, while a screen still holds the old card.
      final goalId = await goalWith();
      await open(tester);

      // The goal behind the card is replaced under it.
      await db.customUpdate(
        'UPDATE savings_goals SET goal_uid = ? WHERE id = ?',
        variables: [
          Variable<String>('00000000-0000-4000-8000-000000000000'),
          Variable<int>(goalId),
        ],
        updates: const {},
      );

      await submit(tester, 'Save');
      await type(tester, 'Amount', '500');
      await submit(tester, 'Set aside');

      expect(find.textContaining('Nothing was moved'), findsOneWidget);
      expect(
        (await services.savings.getGoal(goalId))!.currentAmount,
        Decimal.zero,
      );
      expect(
        (await services.accounts.getAccounts()).single.balance,
        Decimal.parse('10000'),
      );
    });

    testWidgets('a completed goal offers taking money back, not adding', (
      tester,
    ) async {
      await cashAccount();
      await services.savings.createGoal(
        goalName: 'Bitti',
        targetAmount: 100,
        currentAmount: 100,
      );
      await open(tester);

      expect(find.text('Take back'), findsOneWidget);
      expect(find.text('Save'), findsNothing);
    });
  });
}
