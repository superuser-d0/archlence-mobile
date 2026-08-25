/// Paying down a credit card — the last write flow.
library;

import 'package:archlence_mobile/app_services.dart';
import 'package:archlence_mobile/data/database.dart';
import 'package:archlence_mobile/screens/cards_screen.dart';
import 'package:archlence_mobile/services/account_service.dart';
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

  Future<int> cash({String name = 'Maaş', Object balance = 50000}) =>
      services.accounts.createAccount(
        name: name,
        accountType: AccountType.checking,
        initialBalance: balance,
      );

  Future<int> card({Object debt = 2400, Object limit = 20000}) =>
      services.accounts.createAccount(
        name: 'Bonus Kart',
        accountType: AccountType.creditCard,
        initialBalance: debt,
        creditLimit: limit,
      );

  Future<void> openCards(WidgetTester tester) =>
      pumpScreen(tester, services, const CardsScreen());

  Future<void> openSheet(WidgetTester tester) async {
    await openCards(tester);
    await tester.ensureVisible(find.text('Pay Debt'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pay Debt'));
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

  Future<void> pay(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Pay').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pay').last);
    await tester.pumpAndSettle();
  }

  testWidgets('moves the money and both sides show it', (tester) async {
    final sourceId = await cash();
    final cardId = await card();
    await openSheet(tester);
    await type(tester, 'Amount to pay', '900');
    await pay(tester);

    expect(
      (await services.accounts.getAccount(sourceId))!.balance,
      Decimal.parse('49100'),
    );
    final paidCard = (await services.accounts.getAccount(cardId))!;
    expect(paidCard.debt, Decimal.parse('1500'));
    expect(paidCard.availableLimit, Decimal.parse('18500'));
    expect(find.text('1.500,00 ₺'), findsWidgets, reason: 'the page re-read');
  });

  testWidgets('it lands on both statements, as a payment not an expense', (
    tester,
  ) async {
    // The card side is deliberately not 'income': the desktop's reports count
    // income, and clearing a debt is not earnings.
    final sourceId = await cash();
    final cardId = await card();
    await openSheet(tester);
    await type(tester, 'Amount to pay', '900');
    await pay(tester);

    final onCard = await services.transactions.getRecentForAccount(cardId);
    final onCash = await services.transactions.getRecentForAccount(sourceId);
    expect(onCard.single.type, 'payment');
    expect(onCash.single.type, 'expense');
    expect(onCard.single.amount, Decimal.parse('900'));
  });

  testWidgets('"pay it all off" fills in exactly what is owed', (tester) async {
    // Typing the figure by hand is the step most likely to go wrong by a
    // kurus, and paying more than is owed is refused.
    await cash();
    final cardId = await card(debt: '2400.55');
    await openSheet(tester);
    await tester.tap(find.textContaining('Pay it all off'));
    await tester.pumpAndSettle();
    await pay(tester);

    expect((await services.accounts.getAccount(cardId))!.debt, Decimal.zero);
  });

  testWidgets('paying more than is owed is refused, and nothing moves', (
    tester,
  ) async {
    final sourceId = await cash();
    final cardId = await card();
    await openSheet(tester);
    await type(tester, 'Amount to pay', '5.000');
    await pay(tester);

    expect(find.textContaining('more than the card owes'), findsOneWidget);
    expect(
      (await services.accounts.getAccount(sourceId))!.balance,
      Decimal.parse('50000'),
    );
    expect(
      (await services.accounts.getAccount(cardId))!.debt,
      Decimal.parse('2400'),
    );
  });

  testWidgets('an amount that is not a number never reaches the service', (
    tester,
  ) async {
    await cash();
    final cardId = await card();
    await openSheet(tester);
    await type(tester, 'Amount to pay', ',,,');
    await pay(tester);

    expect(find.text('Enter an amount.'), findsOneWidget);
    expect(
      (await services.accounts.getAccount(cardId))!.debt,
      Decimal.parse('2400'),
    );
  });

  testWidgets('a card is not offered as somewhere to pay from', (tester) async {
    // The service refuses one; offering it would invite the error rather than
    // prevent it.
    await cash();
    await card();
    await services.accounts.createAccount(
      name: 'İkinci Kart',
      accountType: AccountType.creditCard,
      creditLimit: 5000,
    );
    await openSheet(tester);
    // The card carousel behind the sheet also shows the card's name, so the
    // measurement is what OPENING the menu adds — not what is on screen.
    final beforeCard = find.textContaining('İkinci Kart').evaluate().length;
    final beforeCash = find.textContaining('Maaş').evaluate().length;

    await tester.tap(find.byKey(const Key('field-source')));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Maaş').evaluate().length,
      greaterThan(beforeCash),
      reason: 'the cash account is in the menu',
    );
    expect(
      find.textContaining('İkinci Kart').evaluate().length,
      beforeCard,
      reason: 'the menu offered a card to pay from',
    );
  });

  testWidgets('a frozen card can still be paid, and the sheet says so', (
    tester,
  ) async {
    // Freezing stops new debt. Trapping the user with a balance they cannot
    // clear would be the opposite of what the switch is for.
    final sourceId = await cash();
    final cardId = await card();
    await services.accounts.setCardFrozen(cardId, true);
    await openSheet(tester);

    expect(find.textContaining('can still be paid'), findsOneWidget);

    await type(tester, 'Amount to pay', '400');
    await pay(tester);

    expect(
      (await services.accounts.getAccount(cardId))!.debt,
      Decimal.parse('2000'),
    );
    expect(
      (await services.accounts.getAccount(sourceId))!.balance,
      Decimal.parse('49600'),
    );
  });

  testWidgets('a card with nothing owing offers no payment at all', (
    tester,
  ) async {
    // The service refuses it; the button does not offer it in the first
    // place, so the affordance and the rule agree.
    await cash();
    await card(debt: 0);
    await openCards(tester);

    expect(
      tester
          .widget<OutlinedButton>(
            find.ancestor(
              of: find.text('Pay Debt'),
              matching: find.byType(OutlinedButton),
            ),
          )
          .onPressed,
      isNull,
    );
  });
}
