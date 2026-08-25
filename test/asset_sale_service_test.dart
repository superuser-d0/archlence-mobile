/// Atomic asset sales, ported from `test_asset_sale_cash_amount.py` (proceeds
/// quantization and the description's audit trail) and
/// `test_asset_sale_atomicity.py` (full and partial sale, the whole-position
/// case).
library;

import 'package:archlence_mobile/crypto/field_crypto.dart';
import 'package:archlence_mobile/data/database.dart';
import 'package:archlence_mobile/money/financial_decimal.dart';
import 'package:archlence_mobile/services/account_service.dart';
import 'package:archlence_mobile/services/asset_purchase_service.dart';
import 'package:archlence_mobile/services/asset_sale_service.dart';
import 'package:archlence_mobile/services/asset_service.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fixed_key_provider.dart';

void main() {
  late ArchlenceDatabase db;
  late FieldCrypto crypto;
  late AccountService accounts;
  late AssetService assets;
  late AssetPurchaseService purchases;
  late AssetSaleService sales;

  setUp(() {
    db = ArchlenceDatabase.memory();
    crypto = FieldCrypto(FixedKeyProvider.arbitrary());
    accounts = AccountService(db, crypto);
    assets = AssetService(db, crypto);
    purchases = AssetPurchaseService(db, crypto, accounts);
    sales = AssetSaleService(db, crypto);
  });

  tearDown(() => db.close());

  Decimal money(String value) => fiat(value);

  Future<int> count(String table) async {
    final row = await db
        .customSelect('SELECT COUNT(*) AS n FROM $table')
        .getSingle();
    return row.read<int>('n');
  }

  Future<int> newAccount({Object? balance = 1000}) => accounts.createAccount(
    name: 'Audit Hesabı',
    accountType: AccountType.checking,
    initialBalance: balance,
  );

  Future<int> buy({
    Object price = 100,
    Object quantity = 2,
    required int accountId,
    String assetName = 'Audit',
    String assetCode = 'AUD',
    String assetType = 'Altın',
  }) async {
    final result = await purchases.createPurchase(
      assetName: assetName,
      assetCode: assetCode,
      assetType: assetType,
      purchasePrice: price,
      quantity: quantity,
      accountId: accountId,
    );
    return result.assetId;
  }

  test('a full sale has one asset effect and one cash effect', () async {
    final accountId = await newAccount();
    final assetId = await buy(accountId: accountId);

    final proceeds = await sales.sell(
      assetId: assetId,
      sellPricePerUnit: 150,
      accountId: accountId,
    );

    expect(proceeds, money('300'));
    // 1000 opening, minus 200 (100 x 2) to buy, plus 300 to sell.
    expect((await accounts.getAccount(accountId))!.balance, money('1100'));
    expect(await assets.getAssetById(assetId), isNull, reason: 'fully sold');
  });

  test('a partial sale leaves the remainder in place', () async {
    final accountId = await newAccount(balance: 1000000);
    final assetId = await buy(
      accountId: accountId,
      price: 2000,
      quantity: 2.5,
      assetName: 'Gram Altın',
      assetCode: 'GC=F',
    );

    await sales.sell(
      assetId: assetId,
      sellPricePerUnit: 2400,
      accountId: accountId,
      quantity: 1.0,
    );

    final remaining = (await assets.getAssetById(assetId))!;
    expect(remaining.quantity, money('1.5'));
  });

  test('proceeds are quantized to the kurus', () async {
    final accountId = await newAccount(balance: 10000000);
    final assetId = await buy(
      accountId: accountId,
      price: 2000.0,
      quantity: 0.12345678,
      assetType: 'Kripto',
    );

    final proceeds = await sales.sell(
      assetId: assetId,
      sellPricePerUnit: 2456.78,
      accountId: accountId,
    );

    expect(proceeds, money('303.31'));
    final row = await db
        .customSelect(
          "SELECT amount FROM transactions WHERE category = 'Varlık Satışı'",
        )
        .getSingle();
    expect(
      fiat(await crypto.decryptField(row.read<String>('amount'))),
      money('303.31'),
    );
  });

  test('a binary-representation artefact never reaches the ledger', () async {
    final accountId = await newAccount(balance: 10000);
    final assetId = await buy(
      accountId: accountId,
      price: 100.0,
      quantity: 17.0,
      assetType: 'Kripto',
    );
    await sales.sell(
      assetId: assetId,
      sellPricePerUnit: 142.30,
      accountId: accountId,
    );
    final row = await db
        .customSelect(
          "SELECT amount FROM transactions WHERE category = 'Varlık Satışı'",
        )
        .getSingle();
    expect(
      fiat(await crypto.decryptField(row.read<String>('amount'))),
      money('2419.10'),
    );
  });

  test('the credited balance matches what was written to the ledger', () async {
    final accountId = await newAccount(balance: 10000000);
    final assetId = await buy(
      accountId: accountId,
      price: 2000.0,
      quantity: 0.12345678,
      assetType: 'Kripto',
    );
    final before = (await accounts.getAccount(accountId))!.balance;

    await sales.sell(
      assetId: assetId,
      sellPricePerUnit: 2456.78,
      accountId: accountId,
    );

    final after = (await accounts.getAccount(accountId))!.balance;
    expect(after - before, money('303.31'));
  });

  test('a sale writes exactly one transaction and one ledger row', () async {
    final accountId = await newAccount(balance: 10000000);
    final assetId = await buy(accountId: accountId, price: 2000, quantity: 1);
    await sales.sell(
      assetId: assetId,
      sellPricePerUnit: 2456.78,
      accountId: accountId,
    );
    expect(await count("transactions WHERE category = 'Varlık Satışı'"), 1);
    expect(await count("balance_events WHERE source = 'asset_sale'"), 1);
  });

  group('the sale description', () {
    test('names the asset and how much was sold', () async {
      final accountId = await newAccount(balance: 1000000);
      final assetId = await buy(
        accountId: accountId,
        price: 2000,
        quantity: 2.5,
        assetName: 'Gram Altın',
        assetCode: 'GC=F',
      );
      await sales.sell(
        assetId: assetId,
        sellPricePerUnit: 2400,
        accountId: accountId,
        quantity: 1.0,
      );
      final row = await db
          .customSelect(
            "SELECT description FROM transactions "
            "WHERE category = 'Varlık Satışı'",
          )
          .getSingle();
      final description = await crypto.decryptField(
        row.read<String>('description'),
      );
      expect(description, contains('Gram Altın'));
      expect(description, contains('GC=F'));
      expect(description, contains('satıldı'));
      expect(description, contains('2,400.00'));
      expect(description, contains('K/Z'));
      expect(description, contains('+400.00'));
    });

    test('signs a loss correctly', () async {
      final accountId = await newAccount(balance: 1000000);
      final assetId = await buy(accountId: accountId, price: 2000, quantity: 1);
      await sales.sell(
        assetId: assetId,
        sellPricePerUnit: 1500,
        accountId: accountId,
        quantity: 1.0,
      );
      final row = await db
          .customSelect(
            "SELECT description FROM transactions "
            "WHERE category = 'Varlık Satışı'",
          )
          .getSingle();
      expect(
        await crypto.decryptField(row.read<String>('description')),
        contains('-500.00'),
      );
    });
  });

  group('rejections write nothing', () {
    test('a missing asset', () async {
      final accountId = await newAccount();
      await expectLater(
        () => sales.sell(
          assetId: 404,
          sellPricePerUnit: 100,
          accountId: accountId,
        ),
        throwsA(
          isA<AssetError>().having(
            (e) => e.code,
            'code',
            AssetErrorCode.assetNotFound,
          ),
        ),
      );
    });

    test('a non-positive sale price', () async {
      final accountId = await newAccount();
      final assetId = await buy(accountId: accountId);
      for (final price in [0, -10]) {
        await expectLater(
          () => sales.sell(
            assetId: assetId,
            sellPricePerUnit: price,
            accountId: accountId,
          ),
          throwsA(isA<AssetError>()),
        );
      }
      expect((await assets.getAssetById(assetId))!.quantity, money('2'));
    });

    test('selling more than is owned', () async {
      final accountId = await newAccount();
      final assetId = await buy(accountId: accountId, quantity: 2);
      await expectLater(
        () => sales.sell(
          assetId: assetId,
          sellPricePerUnit: 100,
          accountId: accountId,
          quantity: 2.01,
        ),
        throwsA(isA<AssetError>()),
      );
      expect((await assets.getAssetById(assetId))!.quantity, money('2'));
      expect(await count("transactions WHERE category = 'Varlık Satışı'"), 0);
    });

    test('a zero or negative quantity', () async {
      final accountId = await newAccount();
      final assetId = await buy(accountId: accountId, quantity: 2);
      for (final quantity in [0, -1]) {
        await expectLater(
          () => sales.sell(
            assetId: assetId,
            sellPricePerUnit: 100,
            accountId: accountId,
            quantity: quantity,
          ),
          throwsA(isA<AssetError>()),
        );
      }
    });
  });

  test('sale is not blocked by a frozen account, unlike a purchase', () async {
    // Freezing stops new debt, not access to money a sale is realising —
    // AssetSaleService does not check it at all, matching the desktop.
    final accountId = await newAccount();
    final assetId = await buy(accountId: accountId);
    await accounts.setCardFrozen(accountId, true);

    final proceeds = await sales.sell(
      assetId: assetId,
      sellPricePerUnit: 150,
      accountId: accountId,
    );
    expect(proceeds, money('300'));
  });

  test(
    'a stored quantity that will not decrypt is reported, not swallowed',
    () async {
      final accountId = await newAccount();
      await db.customStatement(
        "INSERT INTO active_assets (asset_name, asset_code, asset_type, "
        "purchase_price, quantity) VALUES ('Bad', 'BAD', 'Diğer', "
        "'AEADv1:broken', 'AEADv1:broken')",
      );
      final row = await db
          .customSelect('SELECT id FROM active_assets')
          .getSingle();

      await expectLater(
        () => sales.sell(
          assetId: row.read<int>('id'),
          sellPricePerUnit: 100,
          accountId: accountId,
        ),
        throwsA(isA<AssetDataIntegrityError>()),
      );
    },
  );
}
