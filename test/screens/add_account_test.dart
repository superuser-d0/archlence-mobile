/// Opening an account — the first write flow in the app.
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

  Future<void> openSheet(WidgetTester tester) async {
    await pumpScreen(tester, services, const CardsScreen());
    await tester.tap(find.text('+  ADD'));
    await tester.pumpAndSettle();
  }

  Future<void> type(WidgetTester tester, String label, String value) async {
    await tester.enterText(
      find.ancestor(of: find.text(label), matching: find.byType(TextField)),
      value,
    );
    await tester.pumpAndSettle();
  }

  Future<void> submit(WidgetTester tester) async {
    await tester.tap(find.text('Add account'));
    await tester.pumpAndSettle();
  }

  testWidgets('opens a cash account and the page shows it', (tester) async {
    await openSheet(tester);
    await type(tester, 'Name', 'Maaş Hesabı');
    await type(tester, 'Opening balance', '17.300,50');
    await submit(tester);

    final account = (await services.accounts.getAccounts()).single;
    expect(account.name, 'Maaş Hesabı');
    expect(account.accountType, AccountType.checking);
    expect(account.balance, Decimal.parse('17300.50'));

    // The sheet closed and the page behind it re-read.
    expect(find.text('Add account'), findsNothing);
    expect(find.text('17.300,50 ₺'), findsWidgets);
  });

  testWidgets('opens a card, and its debt is entered as a positive number', (
    tester,
  ) async {
    // The sign convention said in the form's own words: the user types what
    // they OWE, and the service stores it negative. A label saying "balance"
    // would invite a minus sign and double the debt.
    await openSheet(tester);
    await tester.tap(find.text('Credit card'));
    await tester.pumpAndSettle();
    await type(tester, 'Name', 'Bonus Flexi');
    await type(tester, 'Current debt', '3.500');
    await type(tester, 'Card limit', '20.000');
    await submit(tester);

    final card = (await services.accounts.getAccounts()).single;
    expect(card.accountType, AccountType.creditCard);
    expect(card.debt, Decimal.parse('3500'));
    expect(card.availableLimit, Decimal.parse('16500'));
    expect(card.balance, Decimal.parse('-3500'), reason: 'stored signed');
  });

  testWidgets('a card number leaves only its last four digits behind', (
    tester,
  ) async {
    await openSheet(tester);
    await tester.tap(find.text('Credit card'));
    await tester.pumpAndSettle();
    await type(tester, 'Name', 'Kart');
    await type(tester, 'Card limit', '20.000');
    await type(tester, 'Card number (optional)', '5555 4444 3333 2222');
    await submit(tester);

    final row = await db.customSelect('SELECT * FROM accounts').getSingle();
    expect(row.data['card_number_full'], isNull);
    expect(row.data['masked_number'], '**** **** **** 2222');
    expect(row.data['network_logo'], 'assets/mastercard.png');
  });

  testWidgets('the service\'s rule is shown, and nothing is written', (
    tester,
  ) async {
    // The form does not re-implement the rule; it shows what createAccount
    // said. Duplicating validation in a form is how a rule ends up living
    // where the next caller never sees it.
    await openSheet(tester);
    await tester.tap(find.text('Credit card'));
    await tester.pumpAndSettle();
    await type(tester, 'Name', 'Kart');
    await type(tester, 'Current debt', '5.000');
    await type(tester, 'Card limit', '1.000');
    await submit(tester);

    expect(
      find.text('The debt is larger than the limit you entered.'),
      findsOneWidget,
    );
    expect(await services.accounts.getAccounts(), isEmpty);
    expect(
      find.text('Add account'),
      findsOneWidget,
      reason: 'sheet stays open',
    );
  });

  testWidgets('a nameless account is refused by the service', (tester) async {
    await openSheet(tester);
    await type(tester, 'Opening balance', '100');
    await submit(tester);

    expect(find.text('Give the account a name.'), findsOneWidget);
    expect(await services.accounts.getAccounts(), isEmpty);
  });

  testWidgets('text that is not a number is refused, never read as zero', (
    tester,
  ) async {
    // The difference between opening an empty account and telling the user
    // their typo was ignored.
    await openSheet(tester);
    await type(tester, 'Name', 'Maaş');
    await type(tester, 'Opening balance', ',,,');
    await submit(tester);

    expect(find.text('That is not an amount.'), findsOneWidget);
    expect(await services.accounts.getAccounts(), isEmpty);
  });

  testWidgets('a blank amount really does mean zero', (tester) async {
    // Distinct from the case above: nothing typed is a real answer.
    await openSheet(tester);
    await type(tester, 'Name', 'Boş Hesap');
    await submit(tester);

    expect(
      (await services.accounts.getAccounts()).single.balance,
      Decimal.zero,
    );
  });

  testWidgets('dismissing the sheet writes nothing', (tester) async {
    await openSheet(tester);
    await type(tester, 'Name', 'Yazılmayacak');
    await tester.tapAt(const Offset(400, 30));
    await tester.pumpAndSettle();

    expect(await services.accounts.getAccounts(), isEmpty);
    expect(find.text('Add account'), findsNothing);
  });

  testWidgets('the card-only fields appear only for a card', (tester) async {
    await openSheet(tester);
    expect(find.text('Card limit'), findsNothing);
    expect(find.text('Opening balance'), findsOneWidget);

    await tester.tap(find.text('Credit card'));
    await tester.pumpAndSettle();
    expect(find.text('Card limit'), findsOneWidget);
    expect(find.text('Current debt'), findsOneWidget);
    expect(find.text('Opening balance'), findsNothing);
  });
}
