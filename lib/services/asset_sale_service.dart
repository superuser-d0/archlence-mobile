/// The atomic asset-sale boundary: the holding update, the wallet
/// transaction and the balance move are one commit.
///
/// A port of `services/asset_sale_service.py`. Unlike a purchase, a sale is
/// never blocked by a frozen account — freezing stops new debt, not access
/// to money the sale is realising; `AccountService.assertSpendingAllowed` is
/// deliberately not called here, matching the desktop.
library;

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';

import '../crypto/field_crypto.dart';
import '../crypto/key_provider.dart';
import '../data/balance_events.dart';
import '../data/database.dart';
import '../money/financial_decimal.dart';
import 'asset_service.dart';

class AssetSaleService {
  AssetSaleService(this._db, this._crypto);

  final ArchlenceDatabase _db;
  final FieldCrypto _crypto;

  /// Sells [quantity] units of holding [assetId] at [sellPricePerUnit],
  /// crediting [accountId]. Selling the whole position (the default) deletes
  /// the holding row; a partial sale leaves the remainder in place. Returns
  /// the proceeds credited.
  Future<Decimal> sell({
    required int assetId,
    required Object? sellPricePerUnit,
    required int accountId,
    Object? quantity,
  }) async {
    final Decimal price;
    try {
      price = decimalFrom(sellPricePerUnit);
    } on FinancialValueError catch (error) {
      throw AssetError(
        AssetErrorCode.invalidAmount,
        'The sale price must be a finite number: ${error.message}',
      );
    }
    if (price <= Decimal.zero) {
      throw const AssetError(
        AssetErrorCode.invalidAmount,
        'The sale price must be greater than zero.',
      );
    }

    return _db.transaction(() async {
      final row = await _db
          .customSelect(
            'SELECT * FROM active_assets WHERE id = ?',
            variables: [Variable<int>(assetId)],
          )
          .getSingleOrNull();
      if (row == null) {
        throw AssetError(
          AssetErrorCode.assetNotFound,
          'No asset with id $assetId.',
        );
      }

      final owned = await _readAmount(assetId, 'quantity', row.data);
      final sold = quantity == null ? owned : _requireFinite(quantity);
      if (sold <= Decimal.zero || sold > owned) {
        throw const AssetError(
          AssetErrorCode.invalidAmount,
          'The quantity sold must be positive and not exceed the holding.',
        );
      }

      final proceeds = fiat(price * sold);
      final remaining = owned - sold;

      if (remaining == Decimal.zero) {
        await _db.customUpdate(
          'DELETE FROM active_assets WHERE id = ?',
          variables: [Variable<int>(assetId)],
          updates: const {},
        );
      } else {
        await _db.customUpdate(
          'UPDATE active_assets SET quantity = ? WHERE id = ?',
          variables: [
            Variable<String>(
              (await _crypto.encryptField(remaining.toString()))!,
            ),
            Variable<int>(assetId),
          ],
          updates: const {},
        );
      }

      final unitCost = await _readAmount(assetId, 'purchase_price', row.data);
      final costBasis = fiat(unitCost * sold);
      final pnl = proceeds - costBasis;
      final sign = pnl.sign >= 0 ? '+' : '-';
      final assetName = row.data['asset_name'] as String;
      final assetCode = row.data['asset_code'] as String;
      final description =
          '$assetName ($assetCode) satıldı — $sold adet, birim fiyat '
          '${formatWithThousands(price)} ₺ '
          '(K/Z: $sign${formatWithThousands(pnl.abs())} ₺)';

      final now = sqliteTimestamp(DateTime.now());
      final proceedsAsDouble = proceeds.toDouble();
      final transactionId = await _db.customInsert(
        'INSERT INTO transactions (account_id, amount, type, category, '
        "description, transaction_date) VALUES (?, ?, 'income', "
        "'Varlık Satışı', ?, ?)",
        variables: [
          Variable<int>(accountId),
          Variable<String>(
            (await _crypto.encryptField(proceedsAsDouble.toString()))!,
          ),
          Variable<String>((await _crypto.encryptField(description))!),
          Variable<String>(now),
        ],
      );

      await adjustAccountBalance(
        _db,
        accountId: accountId,
        transactionType: 'income',
        amount: proceedsAsDouble,
        refId: transactionId,
        source: 'asset_sale',
      );

      return proceeds;
    });
  }

  Future<Decimal> _readAmount(
    int assetId,
    String field,
    Map<String, Object?> row,
  ) async {
    try {
      return decimalFrom(await _crypto.decryptField(row[field]));
    } on KeyUnavailableError {
      rethrow;
    } on Exception catch (error) {
      throw AssetDataIntegrityError(assetId, field, error.toString());
    }
  }

  Decimal _requireFinite(Object? value) {
    try {
      return decimalFrom(value);
    } on FinancialValueError catch (error) {
      throw AssetError(
        AssetErrorCode.invalidAmount,
        'The quantity sold must be a finite number: ${error.message}',
      );
    }
  }
}
