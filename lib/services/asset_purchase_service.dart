/// The atomic asset-purchase boundary: the holding, the wallet transaction,
/// the balance move and the ledger entry are one commit.
///
/// A port of `services/asset_purchase_service.py`. For a newly bought asset
/// this writes all four; for one the user already owned before opening this
/// app (`deductFromBalance: false`), only the holding row is written — it
/// must not retroactively touch today's balance or expense reports.
library;

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';

import '../crypto/field_crypto.dart';
import '../data/balance_events.dart';
import '../data/database.dart';
import '../money/financial_decimal.dart';
import 'account_service.dart';
import 'asset_service.dart';

/// What a completed purchase did.
class AssetPurchaseResult {
  const AssetPurchaseResult({
    required this.assetId,
    required this.transactionId,
    required this.investedAmount,
    required this.deductedFromBalance,
  });

  final int assetId;

  /// Null when [deductedFromBalance] is false — nothing was charged, so
  /// there is no wallet transaction to point at.
  final int? transactionId;
  final Decimal investedAmount;
  final bool deductedFromBalance;
}

class AssetPurchaseService {
  AssetPurchaseService(this._db, this._crypto, this._accounts);

  final ArchlenceDatabase _db;
  final FieldCrypto _crypto;
  final AccountService _accounts;

  /// Buys [quantity] units of an asset at [purchasePrice] per unit.
  ///
  /// If [accountId] is omitted and [deductFromBalance] is true, the checking
  /// account to charge is chosen by [_pickFundingAccount]. Credit cards are
  /// never auto-selected — charging a purchase to a card as debt is a
  /// separate product decision this method does not make silently — though a
  /// caller may still pass a card's id explicitly.
  Future<AssetPurchaseResult> createPurchase({
    required String assetName,
    required String assetCode,
    required String assetType,
    required Object? purchasePrice,
    required Object? quantity,
    int? accountId,
    DateTime? purchaseDate,
    bool deductFromBalance = true,
  }) async {
    final Decimal price;
    final Decimal qty;
    try {
      price = decimalFrom(purchasePrice);
      qty = decimalFrom(quantity);
    } on FinancialValueError catch (error) {
      throw AssetError(
        AssetErrorCode.invalidAmount,
        'Price and quantity must be finite numbers: ${error.message}',
      );
    }
    if (price <= Decimal.zero || qty <= Decimal.zero) {
      throw const AssetError(
        AssetErrorCode.invalidAmount,
        'Price and quantity must be greater than zero.',
      );
    }

    final investedAmount = fiat(price * qty);

    var fundingAccountId = accountId;
    if (deductFromBalance && fundingAccountId == null) {
      fundingAccountId = await _pickFundingAccount(investedAmount);
    }

    final stamp = sqliteTimestamp(purchaseDate ?? DateTime.now());
    final description =
        '$assetName (${assetCode.toUpperCase()}) alındı — '
        '$qty adet, birim fiyat ${formatWithThousands(price)} ₺';

    return _db.transaction(() async {
      // Checked BEFORE the asset row exists, so a rejection leaves nothing
      // behind — the desktop pins this down explicitly (a frozen account
      // must not create an orphan holding).
      if (deductFromBalance) {
        await _accounts.assertSpendingAllowed(
          fundingAccountId!,
          investedAmount,
          transactionType: 'expense',
        );
      }

      final assetId = await _db.customInsert(
        'INSERT INTO active_assets (asset_name, asset_code, asset_type, '
        'purchase_price, quantity, purchase_date) VALUES (?, ?, ?, ?, ?, ?)',
        variables: [
          Variable<String>(assetName),
          Variable<String>(assetCode.toUpperCase()),
          Variable<String>(assetType),
          Variable<String>((await _crypto.encryptField(price.toString()))!),
          Variable<String>((await _crypto.encryptField(qty.toString()))!),
          Variable<String>(stamp),
        ],
      );

      int? transactionId;
      if (deductFromBalance) {
        final amountAsDouble = investedAmount.toDouble();
        transactionId = await _db.customInsert(
          'INSERT INTO transactions (account_id, amount, type, category, '
          "description, transaction_date) VALUES (?, ?, 'expense', "
          "'Varlık Alımı', ?, ?)",
          variables: [
            Variable<int>(fundingAccountId!),
            Variable<String>(
              (await _crypto.encryptField(amountAsDouble.toString()))!,
            ),
            Variable<String>((await _crypto.encryptField(description))!),
            Variable<String>(stamp),
          ],
        );
        await adjustAccountBalance(
          _db,
          accountId: fundingAccountId!,
          transactionType: 'expense',
          amount: amountAsDouble,
          refId: transactionId,
          source: 'asset_purchase',
        );
      }

      return AssetPurchaseResult(
        assetId: assetId,
        transactionId: transactionId,
        investedAmount: investedAmount,
        deductedFromBalance: deductFromBalance,
      );
    });
  }

  /// Picks the checking account an unattributed purchase is deducted from:
  /// the first one that can cover it, or — if none can — the richest one,
  /// taken negative. Never a credit card; charging an asset purchase to one
  /// as debt is a decision this method does not make on its own.
  Future<int> _pickFundingAccount(Decimal investedAmount) async {
    final checkingAccounts = (await _accounts.getAccounts())
        .where((account) => account.accountType == AccountType.checking)
        .toList();
    if (checkingAccounts.isEmpty) {
      throw const AssetError(
        AssetErrorCode.invalidAmount,
        'No checking account exists to fund the purchase from.',
      );
    }

    for (final account in checkingAccounts) {
      if (account.balance >= investedAmount) return account.id;
    }
    return checkingAccounts.reduce((a, b) => a.balance >= b.balance ? a : b).id;
  }
}
