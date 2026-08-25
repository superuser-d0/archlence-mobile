/// Holdings CRUD and the pure P/L calculation, ported from the desktop's
/// `calculate_pnl` tests in `test_asset_pnl_precision.py` and the basic
/// `active_assets` CRUD in `database/db.py`.
library;

import 'package:archlence_mobile/crypto/field_crypto.dart';
import 'package:archlence_mobile/data/database.dart';
import 'package:archlence_mobile/money/financial_decimal.dart';
import 'package:archlence_mobile/services/asset_service.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fixed_key_provider.dart';

void main() {
  late ArchlenceDatabase db;
  late AssetService assets;

  setUp(() {
    db = ArchlenceDatabase.memory();
    assets = AssetService(db, FieldCrypto(FixedKeyProvider.arbitrary()));
  });

  tearDown(() => db.close());

  Decimal money(String value) => fiat(value);

  group('adding a holding', () {
    test('stores full precision, unrounded', () async {
      final id = await assets.insertAsset(
        assetName: 'Bitcoin',
        assetCode: 'btc-usd',
        assetType: 'Kripto',
        purchasePrice: '2456.78',
        quantity: '0.12345678',
      );
      final asset = (await assets.getAssetById(id))!;
      expect(asset.assetCode, 'BTC-USD', reason: 'the code is upper-cased');
      expect(asset.purchasePrice, Decimal.parse('2456.78'));
      expect(asset.quantity, Decimal.parse('0.12345678'));
    });

    test('rejects a non-positive price or quantity', () async {
      for (final (price, qty) in [(0, 1), (-5, 1), (10, 0), (10, -1)]) {
        await expectLater(
          () => assets.insertAsset(
            assetName: 'X',
            assetCode: 'X',
            assetType: 'Diğer',
            purchasePrice: price,
            quantity: qty,
          ),
          throwsA(
            isA<AssetError>().having(
              (e) => e.code,
              'code',
              AssetErrorCode.invalidAmount,
            ),
          ),
        );
      }
      expect(await assets.getAllAssets(), isEmpty);
    });

    test('rejects a non-finite price or quantity', () async {
      await expectLater(
        () => assets.insertAsset(
          assetName: 'X',
          assetCode: 'X',
          assetType: 'Diğer',
          purchasePrice: double.nan,
          quantity: 1,
        ),
        throwsA(isA<AssetError>()),
      );
    });
  });

  group('reading holdings', () {
    test('newest first', () async {
      final firstId = await assets.insertAsset(
        assetName: 'A',
        assetCode: 'A',
        assetType: 'Diğer',
        purchasePrice: 1,
        quantity: 1,
      );
      final secondId = await assets.insertAsset(
        assetName: 'B',
        assetCode: 'B',
        assetType: 'Diğer',
        purchasePrice: 1,
        quantity: 1,
      );
      expect((await assets.getAllAssets()).map((a) => a.id), [
        secondId,
        firstId,
      ]);
    });

    test('a missing id reads as null', () async {
      expect(await assets.getAssetById(404), isNull);
    });

    test(
      'a row that will not decrypt fails the whole read, not just itself',
      () async {
        // The desktop's get_all_assets raises immediately rather than dropping
        // one bad row and continuing — a portfolio total built by silently
        // skipping a holding would understate itself without saying so.
        await assets.insertAsset(
          assetName: 'Good',
          assetCode: 'GOOD',
          assetType: 'Diğer',
          purchasePrice: 1,
          quantity: 1,
        );
        await db.customStatement(
          "INSERT INTO active_assets (asset_name, asset_code, asset_type, "
          "purchase_price, quantity) VALUES ('Bad', 'BAD', 'Diğer', "
          "'AEADv1:broken', 'AEADv1:broken')",
        );

        await expectLater(
          assets.getAllAssets(),
          throwsA(isA<AssetDataIntegrityError>()),
        );
        await expectLater(
          assets.getAssetById(2),
          throwsA(isA<AssetDataIntegrityError>()),
        );
      },
    );
  });

  group('deleting a holding', () {
    test('removes the row', () async {
      final id = await assets.insertAsset(
        assetName: 'X',
        assetCode: 'X',
        assetType: 'Diğer',
        purchasePrice: 1,
        quantity: 1,
      );
      expect(await assets.deleteAsset(id), isTrue);
      expect(await assets.getAssetById(id), isNull);
    });

    test('a missing id is not an error', () async {
      expect(await assets.deleteAsset(404), isFalse);
    });
  });

  group('calculatePnl', () {
    // ─── Behaviour the Decimal migration must not change ──────────────────

    test('a profit', () {
      final result = AssetService.calculatePnl(
        currentPrice: 150.0,
        purchasePrice: 100.0,
        quantity: 10.0,
      );
      expect(result.totalCost, money('1000'));
      expect(result.totalValue, money('1500'));
      expect(result.pnlAmount, money('500'));
      expect(result.pnlPct, money('50'));
      expect(result.signal, PnlSignal.profit);
    });

    test('a loss', () {
      final result = AssetService.calculatePnl(
        currentPrice: 80.0,
        purchasePrice: 100.0,
        quantity: 10.0,
      );
      expect(result.pnlAmount, money('-200'));
      expect(result.pnlPct, money('-20'));
      expect(result.signal, PnlSignal.loss);
    });

    test('breakeven', () {
      final result = AssetService.calculatePnl(
        currentPrice: 100.0,
        purchasePrice: 100.0,
        quantity: 10.0,
      );
      expect(result.pnlAmount, Decimal.zero);
      expect(result.signal, PnlSignal.breakeven);
    });

    test('a zero purchase price reports breakeven despite a real gain', () {
      // A pre-existing quirk, deliberately preserved: a zero cost defines no
      // ratio, so the SIGNAL says breakeven while the AMOUNT says otherwise.
      // Fixing it is a product decision outside this port's scope.
      final result = AssetService.calculatePnl(
        currentPrice: 150.0,
        purchasePrice: 0.0,
        quantity: 10.0,
      );
      expect(result.totalCost, Decimal.zero);
      expect(result.pnlAmount, money('1500'));
      expect(result.pnlPct, Decimal.zero);
      expect(result.signal, PnlSignal.breakeven);
    });

    test(
      'a high-precision crypto quantity rounds money to zero, not the ratio',
      () {
        final result = AssetService.calculatePnl(
          currentPrice: 250.0,
          purchasePrice: 200.0,
          quantity: 0.00000001,
        );
        expect(result.totalCost, Decimal.zero);
        expect(result.pnlAmount, Decimal.zero);
        expect(result.pnlPct, money('25'));
        expect(result.signal, PnlSignal.profit);
      },
    );

    test('the signal comes from the unrounded ratio', () {
      // 1e9 / 999,999,999 is 0.0000001% — rounded it reads 0.00%, but the
      // position is still, genuinely, a profit.
      final result = AssetService.calculatePnl(
        currentPrice: 1e9,
        purchasePrice: 999999999.0,
        quantity: 1000.0,
      );
      expect(result.pnlPct, Decimal.zero);
      expect(result.signal, PnlSignal.profit);
    });

    // ─── The kurus the Decimal migration is meant to stop losing ──────────

    test('a sub-kurus unit price keeps its kurus', () {
      // 0.045 x 15 = 0.675 -> 0.68. In binary floating point 0.045 * 15 is
      // 0.6749999999999999, which a naive round() drops to 0.67 — the source
      // is representation error, not the rounding rule.
      final result = AssetService.calculatePnl(
        currentPrice: 0.05,
        purchasePrice: 0.045,
        quantity: 15.0,
      );
      expect(result.totalCost, money('0.68'));
    });

    test('a fractional unit price keeps the half kurus', () {
      // 1.005 x 3 = 3.015, which policy rounds to 3.02.
      final result = AssetService.calculatePnl(
        currentPrice: 1.005,
        purchasePrice: 1.0,
        quantity: 3.0,
      );
      expect(result.totalCost, money('3'));
      expect(result.totalValue, money('3.02'));
      expect(result.pnlAmount, money('0.02'));
      expect(result.pnlPct, money('0.5'));
      expect(result.signal, PnlSignal.profit);
    });

    test('the half-kurus boundary rounds by policy, not by representation', () {
      final result = AssetService.calculatePnl(
        currentPrice: 3.0,
        purchasePrice: 2.675,
        quantity: 1.0,
      );
      expect(result.totalCost, money('2.68'));
    });

    // ─── Non-finite input ──────────────────────────────────────────────────

    test('non-finite input reports error rather than a false signal', () {
      // The real caller runs this in an unguarded loop over the whole
      // portfolio; a NaN price used to read as "breakeven" and an infinite
      // quantity as "profit", both silently wrong.
      for (final result in [
        AssetService.calculatePnl(
          currentPrice: double.nan,
          purchasePrice: 100.0,
          quantity: 10.0,
        ),
        AssetService.calculatePnl(
          currentPrice: 150.0,
          purchasePrice: 100.0,
          quantity: double.infinity,
        ),
        AssetService.calculatePnl(
          currentPrice: 150.0,
          purchasePrice: null,
          quantity: 10.0,
        ),
      ]) {
        expect(result.signal, PnlSignal.error);
        expect(result.pnlAmount, isNull);
        expect(result.pnlPct, isNull);
        expect(result.totalValue, isNull);
        expect(result.totalCost, isNull);
      }
    });
  });

  group('formatWithThousands', () {
    test('groups by three with a Western decimal point', () {
      expect(formatWithThousands(money('2456.78')), '2,456.78');
      expect(formatWithThousands(money('100')), '100.00');
      expect(formatWithThousands(money('67234.56')), '67,234.56');
      expect(formatWithThousands(money('-500.5')), '-500.50');
      expect(formatWithThousands(money('1000000')), '1,000,000.00');
    });
  });
}
