/// Recording a transaction — the write flow the app is used for most.
library;

import 'package:archlence_mobile/app_services.dart';
import 'package:archlence_mobile/app_shell.dart';
import 'package:archlence_mobile/data/database.dart';
import 'package:archlence_mobile/services/account_service.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
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

  Future<int> cashAccount({String name = 'Maaş', Object balance = 10000}) =>
      services.accounts.createAccount(
        name: name,
        accountType: AccountType.checking,
        initialBalance: balance,
      );

  Future<int> card({Object debt = 0, Object limit = 20000}) =>
      services.accounts.createAccount(
        name: 'Kart',
        accountType: AccountType.creditCard,
        initialBalance: debt,
        creditLimit: limit,
      );

  Future<void> openSheet(WidgetTester tester) async {
    await pumpScreen(tester, services, const AppShell());
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
  }

  Future<void> typeAmount(WidgetTester tester, String value) async {
    final field = find.ancestor(
      of: find.text('Amount'),
      matching: find.byType(TextField),
    );
    await tester.ensureVisible(field);
    await tester.pumpAndSettle();
    await tester.enterText(field, value);
    await tester.pumpAndSettle();
  }

  /// Opens a dropdown and chooses a value.
  ///
  /// `ensureVisible` first, every time: the sheet grows past the surface once
  /// the card fields appear, and a tap on a widget that is in the tree but
  /// below the fold computes a point outside the viewport and lands nowhere —
  /// silently, so the test fails later and somewhere else.
  Future<void> pick(WidgetTester tester, String field, String value) async {
    // By KEY, not by label text: the label lives inside the field's
    // decoration, and tapping it hits the decoration rather than the button,
    // so the menu never opens. `ensureVisible` first because the sheet grows
    // past the surface once the card fields appear — a tap on a widget that
    // is in the tree but below the fold lands nowhere, silently.
    final target = find.byKey(Key('field-$field'));
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
    await tester.tap(find.text(value).last);
    await tester.pumpAndSettle();
  }

  Future<void> record(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Record'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Record'));
    await tester.pumpAndSettle();
  }

  testWidgets('records an expense and the balance moves', (tester) async {
    final id = await cashAccount();
    await openSheet(tester);
    await typeAmount(tester, '1.234,56');
    await pick(tester, 'category', 'Süpermarket');
    await record(tester);

    final entries = await services.transactions.getRecentForAccount(id);
    expect(entries.single.amount, Decimal.parse('1234.56'));
    expect(entries.single.category, 'Süpermarket');
    expect(
      (await services.accounts.getAccount(id))!.balance,
      Decimal.parse('8765.44'),
    );
  });

  testWidgets('income raises the balance instead', (tester) async {
    final id = await cashAccount(balance: 0);
    await openSheet(tester);
    await tester.tap(find.text('Income'));
    await tester.pumpAndSettle();
    await typeAmount(tester, '5.000');
    await pick(tester, 'category', 'Maaş');
    await record(tester);

    expect(
      (await services.accounts.getAccount(id))!.balance,
      Decimal.parse('5000'),
    );
  });

  testWidgets('the category list follows the type', (tester) async {
    // A category picked for one type does not belong to the other, so
    // switching clears it rather than carrying an expense category onto
    // income.
    await cashAccount();
    await openSheet(tester);
    await pick(tester, 'category', 'Süpermarket');
    expect(find.text('Süpermarket'), findsOneWidget);

    await tester.tap(find.text('Income'));
    await tester.pumpAndSettle();
    expect(find.text('Süpermarket'), findsNothing);

    await tester.tap(find.text('Category'));
    await tester.pumpAndSettle();
    expect(find.text('Maaş'), findsWidgets);
    expect(find.text('Süpermarket'), findsNothing);
  });

  testWidgets('the card limit is enforced and nothing is written', (
    tester,
  ) async {
    // The rule lives in the service; the form shows what it said.
    final cardId = await card(debt: 19500, limit: 20000);
    await openSheet(tester);
    await pick(tester, 'account', 'Kart');
    await typeAmount(tester, '5.000');
    await record(tester);

    expect(
      find.textContaining('past the card\'s available limit'),
      findsOneWidget,
    );
    expect(await services.transactions.getRecentForAccount(cardId), isEmpty);
    expect(find.text('Record'), findsOneWidget, reason: 'the sheet stays open');
  });

  testWidgets('a frozen card refuses the spend', (tester) async {
    final cardId = await card();
    await services.accounts.setCardFrozen(cardId, true);
    await openSheet(tester);
    await pick(tester, 'account', 'Kart');
    await typeAmount(tester, '100');
    await record(tester);

    expect(find.textContaining('frozen'), findsOneWidget);
    expect(await services.transactions.getRecentForAccount(cardId), isEmpty);
  });

  testWidgets('an amount that is not a number is refused', (tester) async {
    final id = await cashAccount();
    await openSheet(tester);
    await typeAmount(tester, ',,,');
    await record(tester);

    expect(find.text('Enter an amount.'), findsOneWidget);
    expect(await services.transactions.getRecentForAccount(id), isEmpty);
  });

  testWidgets('instalments are offered on a card and not on cash', (
    tester,
  ) async {
    await cashAccount();
    await card();
    await openSheet(tester);

    expect(find.text('Instalments'), findsNothing);
    await pick(tester, 'account', 'Kart');
    expect(find.text('Instalments'), findsOneWidget);

    await pick(tester, 'account', 'Maaş');
    expect(find.text('Instalments'), findsNothing);
  });

  testWidgets('an instalment purchase charges the card in full', (
    tester,
  ) async {
    // What the bank blocks against the limit is the whole amount; the plan
    // only tracks the monthly split.
    final cardId = await card();
    await openSheet(tester);
    await pick(tester, 'account', 'Kart');
    await typeAmount(tester, '1.200');
    await pick(tester, 'installments', '6 months');
    await record(tester);

    expect(
      (await services.accounts.getAccount(cardId))!.debt,
      Decimal.parse('1200'),
    );
    final plan = (await services.transactions.getInstallmentPlans(cardId))
        .single;
    expect(plan.totalInstallments, 6);
    expect(plan.monthlyAmount, Decimal.parse('200'));
  });

  testWidgets('instalments do not follow the account they were picked for', (
    tester,
  ) async {
    // Choosing six months on a card and then switching to cash must not send
    // an instalment count the card was the whole reason for. The service does
    // not reject it — it would simply write a plan against a cash account.
    await cashAccount();
    await card();
    await openSheet(tester);
    await pick(tester, 'account', 'Kart');
    await pick(tester, 'installments', '6 months');
    await pick(tester, 'account', 'Maaş');
    await typeAmount(tester, '1.200');
    await record(tester);

    // Through the service, not raw SQL: the table is created lazily, so on a
    // correct run it does not exist at all and a direct query would fail
    // rather than report nothing.
    for (final account in await services.accounts.getAccounts()) {
      expect(
        await services.transactions.getInstallmentPlans(account.id),
        isEmpty,
        reason: account.name,
      );
    }
  });

  testWidgets('a future date is recorded as scheduled and moves no money', (
    tester,
  ) async {
    // The behaviour the whole pending/settle path exists for, driven through
    // the form: the money does not leave until the day arrives.
    final id = await cashAccount();
    await openSheet(tester);
    await typeAmount(tester, '2.500');

    final target = DateTime.now().add(const Duration(days: 20));
    await tester.tap(find.byIcon(Icons.event));
    await tester.pumpAndSettle();
    // The calendar's own keyboard-entry mode: typing a date is stable across
    // month boundaries, where tapping a day cell is not.
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).last,
      '${target.month.toString().padLeft(2, '0')}/'
      '${target.day.toString().padLeft(2, '0')}/${target.year}',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('will not touch your balance'),
      findsOneWidget,
      reason: 'the form must say what a future date means',
    );
    await record(tester);

    expect(
      (await services.accounts.getAccount(id))!.balance,
      Decimal.parse('10000'),
      reason: 'a scheduled row moves nothing yet',
    );
    final pending = await services.transactions.getPendingTransactions();
    expect(pending.single.amount, Decimal.parse('2500'));
    expect(
      pending.single.executionDate,
      '${target.year}-${target.month.toString().padLeft(2, '0')}-'
      '${target.day.toString().padLeft(2, '0')}',
    );
  });

  testWidgets('a card expense that looks like a subscription is tracked', (
    tester,
  ) async {
    // The last piece of transaction_service.py to be connected: the radar
    // hook the desktop calls after a card expense.
    final cardId = await card();
    await openSheet(tester);
    await pick(tester, 'account', 'Kart');
    await typeAmount(tester, '229,99');
    await pick(tester, 'category', 'Dijital Abonelik');
    await tester.enterText(
      find.ancestor(
        of: find.text('Description (optional)'),
        matching: find.byType(TextField),
      ),
      'Netflix',
    );
    await tester.pumpAndSettle();
    await record(tester);

    final tracked =
        (await services.recurring.getActiveRecurringPayments()).single;
    expect(tracked.name, 'Netflix');
    expect(tracked.accountId, cardId);
    // And it is still an ordinary expense on the card.
    expect(
      (await services.accounts.getAccount(cardId))!.debt,
      Decimal.parse('229.99'),
    );
  });

  testWidgets('the same spend from cash is not tracked', (tester) async {
    // A card is the gate. Without it every supermarket run would fill the
    // radar; a subscription paid from cash is simply an expense.
    await cashAccount();
    await openSheet(tester);
    await typeAmount(tester, '229,99');
    await pick(tester, 'category', 'Dijital Abonelik');
    await record(tester);

    expect(await services.recurring.getActiveRecurringPayments(), isEmpty);
  });

  testWidgets('with no account there is nothing to record against', (
    tester,
  ) async {
    await openSheet(tester);

    expect(find.textContaining('Add an account first'), findsOneWidget);
    expect(
      tester.widget<GradientButton>(find.byType(GradientButton)).onPressed,
      isNull,
      reason: 'Record must not be offered with nothing to record against',
    );
  });
}
