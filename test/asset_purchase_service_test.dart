/// Atomic asset purchases, ported from `test_asset_purchase_flow.py` (the
/// service-boundary tests; the Kivy UI-boundary tests have no counterpart
/// here) and the amount-quantization case in the same file.
library;

import 'package:archlence_mobile/crypto/field_crypto.dart';
import 'package:archlence_mobile/data/database.dart';
import 'package:archlence_mobile/money/financial_decimal.dart';
import 'package:archlence_mobile/services/account_service.dart';
import 'package:archlence_mobile/services/asset_purchase_service.dart';
import 'package:archlence_mobile/services/asset_service.dart';
import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';

import 'support/fixed_key_provider.dart';

void main() {
  late ArchlenceDatabase db;
  late AccountService accounts;
  late AssetService assets;
  late AssetPurchaseService purchases;

  setUp(() {
    db = ArchlenceDatabase.memory();
    final crypto = FieldCrypto(FixedKeyProvider.arbitrary());
    accounts = AccountService(db, crypto);
    assets = AssetService(db, crypto);
    purchases = AssetPurchaseService(db, crypto, accounts);
  });

  tearDown(() => db.close());

  Decimal money(String value) => fiat(value);

  Future<int> count(String table) async {
    final row = await db
        .customSelect('SELECT COUNT(*) AS n FROM $table')
        .getSingle();
    return row.read<int>('n');
  }

  test(
    'commits the asset, the transaction, the balance and the ledger once',
    () async {
      final id = await accounts.createAccount(
        name: 'Asset test',
        accountType: AccountType.checking,
        initialBalance: 10000,
      );

      final result = await purchases.createPurchase(
        assetName: 'Gram Altın',
        assetCode: 'GC=F',
        assetType: 'Altın',
        purchasePrice: 100.0,
        quantity: 2.0,
        accountId: id,
      );

      expect(await count('active_assets'), 1);
      expect(await count("transactions WHERE category = 'Varlık Alımı'"), 1);
      expect((await accounts.getAccount(id))!.balance, money('9800'));

      final event = await db
          .customSelect(
            "SELECT * FROM balance_events WHERE source = 'asset_purchase'",
          )
          .getSingle();
      expect(event.read<double>('delta'), -200.0);
      expect(event.read<int>('ref_id'), result.transactionId);
      expect(result.investedAmount, money('200'));
    },
  );

  test(
    'the cash amount is quantized to the kurus, not a raw product',
    () async {
      // Unlike the desktop's float arithmetic, Decimal multiplication here
      // carries no representation artefact on its own — 2456.78 x 0.12345678
      // is an EXACT decimal, just one with more than two fractional digits.
      // The point of quantizing is still real: turning that exact-but-long
      // value into a clean kurus BEFORE it is dropped to a double is what
      // keeps the stored string "303.31" rather than a double's approximation
      // of the untruncated product. The price and quantity stored on the
      // holding itself stay at full precision — only the CASH MOVEMENT is
      // rounded.
      for (final (price, qty, expected) in [
        (142.30, 17.0, '2419.10'),
        (2456.78, 0.12345678, '303.31'),
        (67234.56, 0.003125, '210.11'),
      ]) {
        final id = await accounts.createAccount(
          name: 'Nakit $price-$qty',
          accountType: AccountType.checking,
          initialBalance: 100000,
        );
        await purchases.createPurchase(
          assetName: 'Test',
          assetCode: 'TST',
          assetType: 'Kripto',
          purchasePrice: price,
          quantity: qty,
          accountId: id,
        );
        final row = await db
            .customSelect(
              "SELECT amount FROM transactions WHERE account_id = ? "
              "AND category = 'Varlık Alımı'",
              variables: [Variable<int>(id)],
            )
            .getSingle();
        final crypto = FieldCrypto(FixedKeyProvider.arbitrary());
        final stored = Decimal.parse(
          (await crypto.decryptField(row.read<String>('amount')))!,
        );
        // Stored as a double's own text form ("2419.1", not "2419.10"), so
        // compare it parsed rather than byte for byte — matching how a real
        // reader (this app or the desktop) treats the column.
        expect(stored, money(expected), reason: '$price x $qty');
        // The idempotence check IS the guard: if the amount had NOT been
        // quantized before hitting the ledger, `stored` would carry more
        // than two fractional digits and re-quantizing it here would move
        // it — this fails on a raw, un-rounded product even when it happens
        // to match `expected` after quantizing it a second time.
        expect(
          fiat(stored),
          stored,
          reason: 'the stored amount was not already quantized to the kurus',
        );
        expect(
          (await accounts.getAccount(id))!.balance,
          money('100000') - money(expected),
        );
      }
    },
  );

  test('a failure after the asset insert rolls back every row', () async {
    final id = await accounts.createAccount(
      name: 'Rollback test',
      accountType: AccountType.checking,
      initialBalance: 1000,
    );
    // A frozen account fails the check made INSIDE the purchase's own
    // transaction, after the asset row would otherwise have been staged —
    // exactly the failure-after-insert path.
    await accounts.setCardFrozen(id, true);

    await expectLater(
      () => purchases.createPurchase(
        assetName: 'Rollback',
        assetCode: 'ROLL',
        assetType: 'Diğer',
        purchasePrice: 10.0,
        quantity: 1.0,
        accountId: id,
      ),
      throwsA(isA<AccountError>()),
    );
    expect(await count('active_assets'), 0);
    expect(await count('transactions'), 0);
    expect((await accounts.getAccount(id))!.balance, money('1000'));
  });

  test(
    'an asset already owned does not touch the wallet or create an expense',
    () async {
      await accounts.createAccount(
        name: 'Untouched',
        accountType: AccountType.checking,
        initialBalance: 10000,
      );

      final result = await purchases.createPurchase(
        assetName: 'Eski Altın',
        assetCode: 'GC=F',
        assetType: 'Altın',
        purchasePrice: 100.0,
        quantity: 2.0,
        deductFromBalance: false,
      );

      expect(await count('active_assets'), 1);
      expect(await count('transactions'), 0);
      expect(await count("balance_events WHERE source = 'asset_purchase'"), 0);
      expect(result.transactionId, isNull);
      expect(result.deductedFromBalance, isFalse);
    },
  );

  test(
    'an already-owned asset can be added with no wallet account at all',
    () async {
      final result = await purchases.createPurchase(
        assetName: 'Eski Bitcoin',
        assetCode: 'BTC-USD',
        assetType: 'Kripto',
        purchasePrice: 100.0,
        quantity: 1.0,
        deductFromBalance: false,
      );

      expect(await count('active_assets'), 1);
      expect(result.deductedFromBalance, isFalse);
    },
  );

  test('a frozen account is rejected before the asset insert', () async {
    final id = await accounts.createAccount(
      name: 'Frozen',
      accountType: AccountType.checking,
      initialBalance: 1000,
    );
    await accounts.setCardFrozen(id, true);

    await expectLater(
      () => purchases.createPurchase(
        assetName: 'Frozen',
        assetCode: 'FRZN',
        assetType: 'Diğer',
        purchasePrice: 10.0,
        quantity: 1.0,
        accountId: id,
      ),
      throwsA(
        isA<AccountError>().having(
          (e) => e.code,
          'code',
          AccountErrorCode.cardFrozen,
        ),
      ),
    );
    expect(await count('active_assets'), 0);
    expect(await count('transactions'), 0);
  });

  test(
    'rejects a non-positive price or quantity before picking an account',
    () async {
      for (final (price, qty) in [(0, 1), (10, 0), (-5, 1)]) {
        await expectLater(
          () => purchases.createPurchase(
            assetName: 'X',
            assetCode: 'X',
            assetType: 'Diğer',
            purchasePrice: price,
            quantity: qty,
          ),
          throwsA(isA<AssetError>()),
        );
      }
      expect(await count('active_assets'), 0);
    },
  );

  group('picking a funding account with no id given', () {
    test(
      'charges the first account that can afford it, not the richest',
      () async {
        await accounts.createAccount(
          name: 'Too little',
          accountType: AccountType.checking,
          initialBalance: 50,
        );
        // First affordable AND poorer than the account after it — the case
        // that tells "first that can afford it" apart from "the richest one".
        final firstAffordableId = await accounts.createAccount(
          name: 'Can afford it',
          accountType: AccountType.checking,
          initialBalance: 200,
        );
        await accounts.createAccount(
          name: 'Richer still',
          accountType: AccountType.checking,
          initialBalance: 5000,
        );

        await purchases.createPurchase(
          assetName: 'X',
          assetCode: 'X',
          assetType: 'Diğer',
          purchasePrice: 100.0,
          quantity: 1.0,
        );

        expect(
          (await accounts.getAccount(firstAffordableId))!.balance,
          money('100'),
        );
      },
    );

    test('when none can afford it, the richest one goes negative', () async {
      final richerId = await accounts.createAccount(
        name: 'Richer',
        accountType: AccountType.checking,
        initialBalance: 80,
      );
      await accounts.createAccount(
        name: 'Poorer',
        accountType: AccountType.checking,
        initialBalance: 20,
      );

      await purchases.createPurchase(
        assetName: 'X',
        assetCode: 'X',
        assetType: 'Diğer',
        purchasePrice: 100.0,
        quantity: 1.0,
      );

      expect((await accounts.getAccount(richerId))!.balance, money('-20'));
    });

    test('never auto-selects a credit card', () async {
      await accounts.createAccount(
        name: 'Kart',
        accountType: AccountType.creditCard,
        creditLimit: 5000,
      );
      await expectLater(
        () => purchases.createPurchase(
          assetName: 'X',
          assetCode: 'X',
          assetType: 'Diğer',
          purchasePrice: 100.0,
          quantity: 1.0,
        ),
        throwsA(isA<AssetError>()),
      );
      expect(await count('active_assets'), 0);
    });
  });

  test('a bought holding reads back through AssetService', () async {
    final id = await accounts.createAccount(
      name: 'X',
      accountType: AccountType.checking,
      initialBalance: 10000,
    );
    final result = await purchases.createPurchase(
      assetName: 'Ethereum',
      assetCode: 'eth-usd',
      assetType: 'Kripto',
      purchasePrice: '2000.5',
      quantity: '0.5',
      accountId: id,
    );
    final asset = (await assets.getAssetById(result.assetId))!;
    expect(asset.assetCode, 'ETH-USD');
    expect(asset.purchasePrice, money('2000.5'));
    expect(asset.quantity, money('0.5'));
  });
}
