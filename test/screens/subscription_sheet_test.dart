/// Managing a subscription: its price, one skipped period, or stopping it.
library;

import 'package:archlence_mobile/app_services.dart';
import 'package:archlence_mobile/data/database.dart';
import 'package:archlence_mobile/screens/home_screen.dart';
import 'package:archlence_mobile/services/account_service.dart';
import 'package:archlence_mobile/services/recurring_service.dart';
import 'package:decimal/decimal.dart';
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

  Future<int> subscription({Object amount = 229.99}) async {
    final accountId = await services.accounts.createAccount(
      name: 'Maaş',
      accountType: AccountType.checking,
      initialBalance: 10000,
    );
    return services.recurring.insertRecurringPayment(
      name: 'Netflix',
      amount: amount,
      category: 'Dijital Abonelik',
      frequency: RecurrenceFrequency.monthly,
      nextDueDate: DateTime(2026, 9, 15),
      accountId: accountId,
    );
  }

  Future<void> openSheet(WidgetTester tester) async {
    await pumpScreen(tester, services, const HomeScreen());
    await tester.ensureVisible(find.text('MANAGE'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('MANAGE'));
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

  Future<void> press(WidgetTester tester, String label) async {
    await tester.ensureVisible(find.text(label).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  testWidgets('the price opens filled in with what it costs now', (
    tester,
  ) async {
    await subscription();
    await openSheet(tester);

    expect(
      tester
          .widget<TextField>(
            find.ancestor(
              of: find.text('Price'),
              matching: find.byType(TextField),
            ),
          )
          .controller!
          .text,
      '229.99',
    );
  });

  testWidgets('a price rise leaves the schedule where it is', (tester) async {
    // Which is why this is not "delete and re-add": that would reset the due
    // history and the alignment of the next charge.
    final id = await subscription();
    await openSheet(tester);
    await type(tester, 'Price', '299,99');
    await press(tester, 'Save new price');

    final payment =
        (await services.recurring.getActiveRecurringPayments()).single;
    expect(payment.id, id);
    expect(payment.amount, Decimal.parse('299.99'));
    expect(payment.nextDueDate, '2026-09-15');
    expect(find.text('299,99 ₺'), findsOneWidget, reason: 'the card re-read');
  });

  testWidgets('skipping moves it on one period and keeps it running', (
    tester,
  ) async {
    await subscription();
    await openSheet(tester);
    await press(tester, 'Skip the next one');

    final payment =
        (await services.recurring.getActiveRecurringPayments()).single;
    expect(payment.nextDueDate, '2026-10-15');
    expect(find.text('Next on 15.10.2026'), findsOneWidget);
  });

  testWidgets('skipping charges nothing', (tester) async {
    // "Not this month" is not "pay it now".
    await subscription();
    await openSheet(tester);
    await press(tester, 'Skip the next one');

    for (final account in await services.accounts.getAccounts()) {
      expect(
        await services.transactions.getRecentForAccount(account.id),
        isEmpty,
      );
      expect(account.balance, Decimal.parse('10000'));
    }
  });

  testWidgets('stopping asks first, and keeping it changes nothing', (
    tester,
  ) async {
    await subscription();
    await openSheet(tester);
    await press(tester, 'Stop tracking it');

    expect(find.text('Stop tracking this?'), findsOneWidget);
    await tester.tap(find.text('Keep it'));
    await tester.pumpAndSettle();

    expect(await services.recurring.getActiveRecurringPayments(), hasLength(1));
  });

  testWidgets('stopping deactivates the row rather than deleting it', (
    tester,
  ) async {
    // Past transactions and the radar's "already tracked" check both rely on
    // the row existing; a delete would turn settled history back into a fresh
    // candidate to rediscover.
    await subscription();
    await openSheet(tester);
    await press(tester, 'Stop tracking it');
    await tester.tap(find.text('Stop it'));
    await tester.pumpAndSettle();

    expect(await services.recurring.getActiveRecurringPayments(), isEmpty);
    final rows = await db
        .customSelect('SELECT * FROM recurring_payments')
        .get();
    expect(rows, hasLength(1), reason: 'the row stays');
    expect(rows.single.read<int>('is_active'), 0);
    expect(find.textContaining('Nothing recurring yet'), findsOneWidget);
  });

  testWidgets('a price that is not a number never reaches the service', (
    tester,
  ) async {
    await subscription();
    await openSheet(tester);
    await type(tester, 'Price', ',,,');
    await press(tester, 'Save new price');

    expect(find.text('Enter the new price.'), findsOneWidget);
    expect(
      (await services.recurring.getActiveRecurringPayments()).single.amount,
      Decimal.parse('229.99'),
    );
  });

  testWidgets('a zero price is refused with the service\'s own rule', (
    tester,
  ) async {
    await subscription();
    await openSheet(tester);
    await type(tester, 'Price', '0');
    await press(tester, 'Save new price');

    expect(find.text('Enter an amount above zero.'), findsOneWidget);
    expect(
      (await services.recurring.getActiveRecurringPayments()).single.amount,
      Decimal.parse('229.99'),
    );
  });

  testWidgets('the three actions are described, not just named', (
    tester,
  ) async {
    // Skip and stop are the pair a user is most likely to confuse.
    await subscription();
    await openSheet(tester);

    expect(find.textContaining('keeps running'), findsOneWidget);
    expect(find.textContaining('for good'), findsOneWidget);
    expect(find.textContaining('leaves the schedule'), findsOneWidget);
  });
}
