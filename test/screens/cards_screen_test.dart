/// The Cards screen against a real service graph.
///
/// These do not check pixels. What they pin is the JOIN: that the screen
/// reads the same numbers the services produce, that a control writes through
/// and the page re-reads, and — the one that matters most — that a figure
/// which cannot be read is never drawn as a zero.
library;

import 'package:archlence_mobile/app_services.dart';
import 'package:archlence_mobile/data/database.dart';
import 'package:archlence_mobile/screens/cards_screen.dart';
import 'package:archlence_mobile/services/account_service.dart';
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

  Future<void> pump(WidgetTester tester) =>
      pumpScreen(tester, services, const CardsScreen());

  testWidgets('shows the net worth the account service computes', (
    tester,
  ) async {
    await services.accounts.createAccount(
      name: 'Maaş',
      accountType: AccountType.checking,
      initialBalance: 17300,
    );
    await services.accounts.createAccount(
      name: 'Bonus Kart',
      accountType: AccountType.creditCard,
      initialBalance: 3500,
      creditLimit: 20000,
    );

    await pump(tester);

    expect(find.text('17.300,00 ₺'), findsWidgets);
    expect(find.text('3.500,00 ₺'), findsWidgets);
    expect(find.text('13.800,00 ₺'), findsOneWidget);
  });

  testWidgets('draws a card with its own limit and debt', (tester) async {
    await services.accounts.createAccount(
      name: 'World Platinum',
      accountType: AccountType.creditCard,
      initialBalance: 49535.50,
      creditLimit: 120000,
      cardNumberFull: '4532123456784826',
    );

    await pump(tester);

    expect(find.text('World Platinum'), findsWidgets);
    expect(find.text('VISA'), findsOneWidget);
    // The stored mask is '**** **** **** 4826'; the face swaps the asterisks
    // for bullets and keeps the spacing the column was stored with.
    expect(find.text('•••• •••• •••• 4826'), findsOneWidget);
    expect(find.text('70.464,50 ₺'), findsOneWidget, reason: 'available limit');
    expect(find.text('49.535,50 ₺'), findsWidgets, reason: 'current debt');
  });

  testWidgets('the network label comes from the card, not a constant', (
    tester,
  ) async {
    // With only a Visa on file, hard-coding 'VISA' would read as correct.
    await services.accounts.createAccount(
      name: 'Bonus Flexi',
      accountType: AccountType.creditCard,
      creditLimit: 50000,
      cardNumberFull: '5555444433337391',
    );

    await pump(tester);

    expect(find.text('MC'), findsOneWidget);
    expect(find.text('VISA'), findsNothing);
  });

  testWidgets('freezing a card writes through and the page re-reads', (
    tester,
  ) async {
    final cardId = await services.accounts.createAccount(
      name: 'Kart',
      accountType: AccountType.creditCard,
      creditLimit: 20000,
    );
    await pump(tester);

    // The second switch is Freeze Card; the first is online shopping.
    await tester.tap(find.byType(Switch).last);
    await tester.pumpAndSettle();

    expect((await services.accounts.getAccount(cardId))!.isFrozen, isTrue);
    expect(
      tester.widget<Switch>(find.byType(Switch).last).value,
      isTrue,
      reason: 'the switch must show the value that was stored',
    );
  });

  testWidgets(
    'says so when there are no cards rather than drawing an empty one',
    (tester) async {
      await services.accounts.createAccount(
        name: 'Maaş',
        accountType: AccountType.checking,
        initialBalance: 100,
      );

      await pump(tester);

      expect(find.textContaining('No credit cards yet'), findsOneWidget);
      expect(find.text('Maaş'), findsOneWidget, reason: 'the account lists');
    },
  );

  testWidgets('an unreadable statement amount is named, never shown as zero', (
    tester,
  ) async {
    // The whole point of every nullable amount in the service layer: a screen
    // that rendered 0,00 ₺ here would undo it at the last step.
    final cardId = await services.accounts.createAccount(
      name: 'Kart',
      accountType: AccountType.creditCard,
      creditLimit: 20000,
    );
    await db.customInsert(
      'INSERT INTO transactions (account_id, amount, type, category, '
      "description, transaction_date, status) "
      "VALUES (?, 'AEADv1:broken', 'expense', 'Test', 'AEADv1:broken', "
      "'2026-08-06 12:00:00', 'completed')",
      variables: [Variable<int>(cardId)],
    );

    await pump(tester);

    expect(find.text('unreadable'), findsOneWidget);
    // Scoped to the statement's own format: an amount there always carries a
    // sign, so these are the strings a zeroed row would produce. A bare
    // '0,00 ₺' is legitimate elsewhere on this page — an untouched card
    // really does owe nothing.
    expect(find.text('-0,00 ₺'), findsNothing);
    expect(find.text('+0,00 ₺'), findsNothing);
  });

  testWidgets('a statement row reads its stored description and date', (
    tester,
  ) async {
    // A cash account too, so the summary row's Net Worth is not the same
    // figure as the statement line and cannot stand in for it.
    await services.accounts.createAccount(
      name: 'Maaş',
      accountType: AccountType.checking,
      initialBalance: 50000,
    );
    final cardId = await services.accounts.createAccount(
      name: 'Kart',
      accountType: AccountType.creditCard,
      creditLimit: 20000,
    );
    await services.transactions.addTransaction(
      accountId: cardId,
      amount: 1893.95,
      transactionType: 'expense',
      category: 'Akaryakıt',
      description: 'Fuel',
      transactionDate: DateTime(2026, 8, 6, 12),
    );

    await pump(tester);

    expect(find.text('Fuel'), findsOneWidget);
    expect(find.text('06.08'), findsOneWidget);
    expect(find.text('-1.893,95 ₺'), findsOneWidget);
  });

  testWidgets('holdings are labelled at cost, not as a market value', (
    tester,
  ) async {
    // There is no price source yet; calling a cost basis a value would be a
    // lie the user cannot see through.
    await services.assets.insertAsset(
      assetName: 'Gram Altın',
      assetCode: 'GC=F',
      assetType: 'Altın',
      purchasePrice: 2000,
      quantity: 3,
    );

    await pump(tester);

    expect(find.text('My Active Assets'), findsOneWidget);
    expect(find.textContaining('at cost'), findsOneWidget);
    expect(find.text('6.000,00 ₺'), findsOneWidget);
  });
}
