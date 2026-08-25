/// Buying and selling a holding.
library;

import 'package:archlence_mobile/app_services.dart';
import 'package:archlence_mobile/data/database.dart';
import 'package:archlence_mobile/screens/assets_screen.dart';
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

  Future<int> cashAccount({String name = 'Maaş', Object balance = 100000}) =>
      services.accounts.createAccount(
        name: name,
        accountType: AccountType.checking,
        initialBalance: balance,
      );

  Future<void> openAssets(WidgetTester tester) =>
      pumpScreen(tester, services, const AssetsScreen());

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

  Future<void> submit(WidgetTester tester, String label) async {
    await tester.ensureVisible(find.text(label));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  Future<void> openBuy(WidgetTester tester) async {
    await openAssets(tester);
    // The "+" sits under "My Active Assets", far down the page: in the tree
    // but below the fold, where a tap lands nowhere.
    await tester.ensureVisible(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
  }

  group('buying', () {
    testWidgets('records the holding and takes the money from an account', (
      tester,
    ) async {
      final accountId = await cashAccount();
      await openBuy(tester);
      await type(tester, 'Name', 'Gram Altın');
      await type(tester, 'Code', 'GC=F');
      await type(tester, 'Unit price', '2.000');
      await type(tester, 'Quantity', '3');
      await submit(tester, 'Add holding');

      final holding = (await services.assets.getAllAssets()).single;
      expect(holding.assetName, 'Gram Altın');
      expect(holding.assetCode, 'GC=F');
      expect(holding.purchasePrice, Decimal.parse('2000'));
      expect(holding.quantity, Decimal.parse('3'));
      expect(
        (await services.accounts.getAccount(accountId))!.balance,
        Decimal.parse('94000'),
      );
    });

    testWidgets('shows the total before anything is written', (tester) async {
      // `1.234` meaning a thousand is a judgement the parser makes on the
      // user's behalf, so the form says what it understood.
      await cashAccount();
      await openBuy(tester);
      await type(tester, 'Unit price', '2.000');
      await type(tester, 'Quantity', '3');

      expect(find.textContaining('6.000,00 ₺ in total'), findsOneWidget);
    });

    testWidgets('"I already owned this" writes no transaction and no debit', (
      tester,
    ) async {
      // Getting this wrong either invents a purchase that never happened or
      // loses one that did.
      final accountId = await cashAccount();
      await openBuy(tester);
      await type(tester, 'Name', 'Eski Altın');
      await type(tester, 'Code', 'GC=F');
      await type(tester, 'Unit price', '2.000');
      await type(tester, 'Quantity', '3');
      await tester.tap(find.text('I already owned this'));
      await tester.pumpAndSettle();
      await submit(tester, 'Add holding');

      expect(await services.assets.getAllAssets(), hasLength(1));
      expect(
        (await services.accounts.getAccount(accountId))!.balance,
        Decimal.parse('100000'),
        reason: 'nothing may leave the account',
      );
      expect(
        await services.transactions.getRecentForAccount(accountId),
        isEmpty,
      );
    });

    testWidgets('with no cash account it says so instead of failing later', (
      tester,
    ) async {
      await openBuy(tester);
      expect(
        find.textContaining('No cash account to pay from'),
        findsOneWidget,
      );
    });

    testWidgets('an already-owned holding needs no account at all', (
      tester,
    ) async {
      await openBuy(tester);
      await tester.tap(find.text('I already owned this'));
      await tester.pumpAndSettle();
      await type(tester, 'Name', 'Eski Bitcoin');
      await type(tester, 'Code', 'BTC-USD');
      await type(tester, 'Unit price', '100');
      await type(tester, 'Quantity', '1');
      await submit(tester, 'Add holding');

      expect(await services.assets.getAllAssets(), hasLength(1));
    });

    testWidgets('the service refuses a zero price and the form says so', (
      tester,
    ) async {
      await cashAccount();
      await openBuy(tester);
      await type(tester, 'Name', 'X');
      await type(tester, 'Code', 'X');
      await type(tester, 'Unit price', '0');
      await type(tester, 'Quantity', '1');
      await submit(tester, 'Add holding');

      expect(find.textContaining('numbers above zero'), findsOneWidget);
      expect(await services.assets.getAllAssets(), isEmpty);
    });

    testWidgets('text that is not a number is refused before the service', (
      tester,
    ) async {
      // The input formatter blocks letters, so the reachable bad input is
      // punctuation — and it must not become a number on the way through.
      await cashAccount();
      await openBuy(tester);
      await type(tester, 'Name', 'X');
      await type(tester, 'Code', 'X');
      await type(tester, 'Unit price', ',,,');
      await type(tester, 'Quantity', '1');
      await submit(tester, 'Add holding');

      expect(find.text('Enter a price and a quantity.'), findsOneWidget);
      expect(await services.assets.getAllAssets(), isEmpty);
    });

    testWidgets('a credit card is not offered as somewhere to pay from', (
      tester,
    ) async {
      // Charging a purchase to a card as debt is a separate product decision;
      // the service refuses to make it silently and neither does the form.
      await cashAccount(name: 'Maaş');
      await services.accounts.createAccount(
        name: 'Bonus Kart',
        accountType: AccountType.creditCard,
        creditLimit: 20000,
      );
      await openBuy(tester);
      await tester.tap(find.byKey(const Key('field-account')));
      await tester.pumpAndSettle();

      expect(find.text('Maaş'), findsWidgets);
      expect(find.text('Bonus Kart'), findsNothing);
    });

    testWidgets('the new holding appears without a manual refresh', (
      tester,
    ) async {
      await cashAccount();
      await openBuy(tester);
      await type(tester, 'Name', 'Gram Altın');
      await type(tester, 'Code', 'GC=F');
      await type(tester, 'Unit price', '2.000');
      await type(tester, 'Quantity', '3');
      await submit(tester, 'Add holding');

      expect(find.text('Gram Altın (GC=F)'), findsOneWidget);
      expect(find.text('6.000,00 ₺'), findsWidgets);
    });

    testWidgets('the kind is stored as the desktop spells it', (tester) async {
      // asset_type is DATA: the money layer picks its quantity precision from
      // it, so a translated label would change what the app can record.
      await cashAccount();
      await openBuy(tester);
      await type(tester, 'Name', 'Bitcoin');
      await type(tester, 'Code', 'BTC-USD');
      await pick(tester, 'type', 'Kripto');
      await type(tester, 'Unit price', '100');
      await type(tester, 'Quantity', '0,12345678');
      await submit(tester, 'Add holding');

      final holding = (await services.assets.getAllAssets()).single;
      expect(holding.assetType, 'Kripto');
      expect(holding.quantity, Decimal.parse('0.12345678'));
    });
  });

  group('selling', () {
    Future<void> openSell(WidgetTester tester) async {
      await openAssets(tester);
      final tile = find.textContaining('Gram Altın').first;
      await tester.ensureVisible(tile);
      await tester.pumpAndSettle();
      await tester.tap(tile);
      await tester.pumpAndSettle();
    }

    Future<int> buyGold({Object quantity = 3}) async {
      final accountId = await cashAccount();
      await services.assetPurchases.createPurchase(
        assetName: 'Gram Altın',
        assetCode: 'GC=F',
        assetType: 'Altın',
        purchasePrice: 2000,
        quantity: quantity,
        accountId: accountId,
      );
      return accountId;
    }

    testWidgets('a full sale clears the holding and pays the account', (
      tester,
    ) async {
      final accountId = await buyGold();
      await openSell(tester);
      await type(tester, 'Sale price, per unit', '2.400');
      await submit(tester, 'Sell');

      expect(await services.assets.getAllAssets(), isEmpty);
      expect(
        (await services.accounts.getAccount(accountId))!.balance,
        // 100000 - 6000 paid + 7200 received.
        Decimal.parse('101200'),
      );
    });

    testWidgets('the sold holding leaves the page without a refresh', (
      tester,
    ) async {
      await buyGold();
      await openSell(tester);
      await type(tester, 'Sale price, per unit', '2.400');
      await submit(tester, 'Sell');

      expect(find.text('Gram Altın (GC=F)'), findsNothing);
      expect(find.textContaining('No holdings yet'), findsOneWidget);
    });

    testWidgets('the quantity defaults to everything held', (tester) async {
      await buyGold();
      await openSell(tester);

      expect(
        tester
            .widget<TextField>(
              find.ancestor(
                of: find.text('Quantity to sell'),
                matching: find.byType(TextField),
              ),
            )
            .controller!
            .text,
        '3',
      );
    });

    testWidgets('a partial sale leaves the rest', (tester) async {
      await buyGold();
      await openSell(tester);
      await type(tester, 'Sale price, per unit', '2.400');
      await type(tester, 'Quantity to sell', '1');
      await submit(tester, 'Sell');

      expect(
        (await services.assets.getAllAssets()).single.quantity,
        Decimal.parse('2'),
      );
    });

    testWidgets('the gain or loss is shown before selling', (tester) async {
      await buyGold();
      await openSell(tester);
      await type(tester, 'Sale price, per unit', '2.400');

      expect(find.textContaining('+1.200,00 ₺'), findsOneWidget);

      await type(tester, 'Sale price, per unit', '1.500');
      expect(find.textContaining('-1.500,00 ₺'), findsOneWidget);
    });

    testWidgets('selling more than is held is refused, and nothing moves', (
      tester,
    ) async {
      final accountId = await buyGold();
      final before = (await services.accounts.getAccount(accountId))!.balance;
      await openSell(tester);
      await type(tester, 'Sale price, per unit', '2.400');
      await type(tester, 'Quantity to sell', '10');
      await submit(tester, 'Sell');

      expect(find.textContaining('above zero'), findsOneWidget);
      expect(await services.assets.getAllAssets(), hasLength(1));
      expect((await services.accounts.getAccount(accountId))!.balance, before);
    });
  });
}
