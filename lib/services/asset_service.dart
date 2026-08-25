/// Portfolio holdings: CRUD on `active_assets`, and the pure profit/loss
/// calculation.
///
/// A port of the parts of the desktop's `database/db.py`
/// (`insert_asset`/`get_all_assets`/`get_asset_by_id`/`delete_asset`) and
/// `services/asset_service.py` (`calculate_pnl`) that do not depend on live
/// price fetching.
///
/// PRICE FETCHING IS NOT PORTED. The desktop's `fetch_current_price`, its
/// portfolio cache and its warm-up thread pull from `yfinance` in the
/// background; the roadmap's open question records that this needs its own
/// decision — Android has no second Python interpreter to spawn, and
/// `yfinance` has no Dart equivalent. Holdings and profit/loss are usable
/// without it: [calculatePnl] takes a current price as a plain argument,
/// wherever the caller gets it from.
///
/// `get_pnl_color` is likewise not ported. It maps a [PnlSignal] to an RGBA
/// list for the UI to paint with — a decision that belongs to whatever
/// renders the signal, the same reasoning that dropped `type_label` from the
/// account service.
library;

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';

import '../crypto/field_crypto.dart';
import '../crypto/key_provider.dart';
import '../data/database.dart';
import '../money/financial_decimal.dart';

/// The kinds of holding, as stored in `active_assets.asset_type`.
///
/// These are DATA, not labels: `quantity()` in the money layer picks its
/// precision from them — four digits for gold, six for a share, eight for
/// crypto — and the desktop's price fetcher decides how to resolve a symbol
/// from them too. Translating one would change how much of a holding the app
/// can even record.
const List<String> assetTypes = [
  'Hisse',
  'Altın',
  'Tahvil',
  'Döviz',
  'Kripto',
  'Diğer',
];

/// A stored holding, decrypted.
class Asset {
  const Asset({
    required this.id,
    required this.assetName,
    required this.assetCode,
    required this.assetType,
    required this.purchasePrice,
    required this.quantity,
    required this.purchaseDate,
  });

  final int id;
  final String assetName;
  final String assetCode;
  final String assetType;

  /// Per-unit cost, in lira, at full stored precision — never rounded to the
  /// kurus on the way in. [AssetService.calculatePnl] is where rounding
  /// happens, and only on the result.
  final Decimal purchasePrice;
  final Decimal quantity;
  final String? purchaseDate;
}

enum AssetErrorCode { invalidAmount, assetNotFound }

class AssetError implements Exception {
  const AssetError(this.code, this.message);

  final AssetErrorCode code;
  final String message;

  @override
  String toString() => 'AssetError(${code.name}): $message';
}

/// A stored `active_assets` row whose encrypted field failed to open or
/// parse as a number.
///
/// Unlike a transaction row, an asset row is NOT skipped and reported —
/// `getAllAssets`/`getAssetById` fail the whole read. A portfolio total built
/// by silently dropping one holding would understate itself without saying
/// so; the desktop's `get_all_assets` makes the same choice.
class AssetDataIntegrityError implements Exception {
  const AssetDataIntegrityError(this.assetId, this.field, this.message);

  final int assetId;
  final String field;
  final String message;

  @override
  String toString() =>
      'AssetDataIntegrityError(active_assets#$assetId.$field): $message';
}

enum PnlSignal { profit, loss, breakeven, error }

/// The result of [AssetService.calculatePnl].
///
/// All four figures are null together, only for [PnlSignal.error]: a value
/// that could not be read is never quietly reported as zero.
class PnlResult {
  const PnlResult({
    required this.pnlAmount,
    required this.pnlPct,
    required this.totalValue,
    required this.totalCost,
    required this.signal,
  });

  const PnlResult.error()
    : pnlAmount = null,
      pnlPct = null,
      totalValue = null,
      totalCost = null,
      signal = PnlSignal.error;

  final Decimal? pnlAmount;
  final Decimal? pnlPct;
  final Decimal? totalValue;
  final Decimal? totalCost;
  final PnlSignal signal;
}

class AssetService {
  AssetService(this._db, this._crypto);

  final ArchlenceDatabase _db;
  final FieldCrypto _crypto;

  /// Adds a holding and returns its id.
  ///
  /// Stores at full precision — the price and quantity are encrypted as
  /// given, not quantized. Quantizing here would throw away the digits
  /// [calculatePnl] and a future sale need.
  Future<int> insertAsset({
    required String assetName,
    required String assetCode,
    required String assetType,
    required Object? purchasePrice,
    required Object? quantity,
    DateTime? purchaseDate,
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

    final stamp = sqliteTimestamp(purchaseDate ?? DateTime.now());
    return _db.customInsert(
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
  }

  /// Every holding, most recently added first.
  Future<List<Asset>> getAllAssets() async {
    final rows = await _db
        .customSelect('SELECT * FROM active_assets ORDER BY id DESC')
        .get();
    return [for (final row in rows) await _decrypt(row.data)];
  }

  /// One holding, or null if it does not exist.
  Future<Asset?> getAssetById(int assetId) async {
    final row = await _db
        .customSelect(
          'SELECT * FROM active_assets WHERE id = ?',
          variables: [Variable<int>(assetId)],
        )
        .getSingleOrNull();
    return row == null ? null : _decrypt(row.data);
  }

  /// Removes a holding. Returns whether a row existed.
  ///
  /// A missing id is not an error — the desktop's `delete_asset` does not
  /// check either, on the view that deleting something already gone reaches
  /// the same end state the caller wanted.
  Future<bool> deleteAsset(int assetId) async {
    final deleted = await _db.customUpdate(
      'DELETE FROM active_assets WHERE id = ?',
      variables: [Variable<int>(assetId)],
      updates: const {},
    );
    return deleted > 0;
  }

  Future<Asset> _decrypt(Map<String, Object?> row) async {
    final id = row['id']! as int;
    final Decimal price;
    final Decimal qty;
    try {
      price = decimalFrom(await _crypto.decryptField(row['purchase_price']));
      qty = decimalFrom(await _crypto.decryptField(row['quantity']));
    } on KeyUnavailableError {
      rethrow;
    } on Exception catch (error) {
      throw AssetDataIntegrityError(
        id,
        'purchase_price/quantity',
        error.toString(),
      );
    }
    return Asset(
      id: id,
      assetName: row['asset_name']! as String,
      assetCode: row['asset_code']! as String,
      assetType: row['asset_type']! as String,
      purchasePrice: price,
      quantity: qty,
      purchaseDate: row['purchase_date'] as String?,
    );
  }

  /// Profit/loss for one holding at [currentPrice].
  ///
  /// THE ARITHMETIC IS DECIMAL THROUGHOUT; only the RESULT is quantized.
  /// Rounding the inputs first would be wrong twice over — a unit price of
  /// 0.045 would drop to 0.04, and an eight-decimal crypto quantity would be
  /// zeroed outright.
  ///
  /// [PnlResult.signal] is decided from the UNROUNDED ratio, not the rounded
  /// percentage: a position up 0.0000001% is still a `profit`, even though
  /// the rounded figure reads 0.00%.
  ///
  /// `purchasePrice <= 0` reports [PnlSignal.breakeven] despite a real
  /// [PnlResult.pnlAmount] — a zero cost defines no ratio. That is a
  /// pre-existing product quirk, deliberately preserved rather than fixed
  /// here: changing it is a product decision, not part of this port.
  ///
  /// Non-finite input (`NaN`, `±infinity`, unparsable text, a missing value)
  /// returns [PnlResult.error] rather than throwing. The real callers run
  /// this in an unguarded loop over every holding in the portfolio; one bad
  /// row must not take the whole screen down with it.
  static PnlResult calculatePnl({
    required Object? currentPrice,
    required Object? purchasePrice,
    required Object? quantity,
  }) {
    final Decimal current;
    final Decimal purchase;
    final Decimal units;
    try {
      current = decimalFrom(currentPrice);
      purchase = decimalFrom(purchasePrice);
      units = decimalFrom(quantity);
    } on FinancialValueError {
      return const PnlResult.error();
    }

    final totalCost = purchase * units;
    final totalValue = current * units;
    final pnlAmount = totalValue - totalCost;
    final pnlRatio = purchase > Decimal.zero
        ? ((current - purchase) / purchase).toDecimal(
                scaleOnInfinitePrecision: 20,
              ) *
              Decimal.fromInt(100)
        : Decimal.zero;

    final PnlSignal signal;
    if (pnlRatio > Decimal.zero) {
      signal = PnlSignal.profit;
    } else if (pnlRatio < Decimal.zero) {
      signal = PnlSignal.loss;
    } else {
      signal = PnlSignal.breakeven;
    }

    return PnlResult(
      pnlAmount: fiat(pnlAmount),
      pnlPct: percentage(pnlRatio),
      totalValue: fiat(totalValue),
      totalCost: fiat(totalCost),
      signal: signal,
    );
  }
}

/// Formats [value] the way the purchase/sale descriptions do: Western
/// grouping, two decimals — `f"{value:,.2f}"`.
///
/// Deliberately NOT the Turkish `₺1.234,56` grouping the rest of this app
/// avoids putting into data at all (see `AccountService`'s plain-English
/// errors). This one is different: the string becomes part of a
/// `transactions.description`, encrypted and stored, which a restored backup
/// carries to the other app — so it has to match what the desktop actually
/// writes, warts included.
String formatWithThousands(Decimal value) {
  final quantized = fiat(value);
  final negative = quantized.sign < 0;
  final absValue = quantized.abs();
  final wholeDigits = absValue.truncate().toBigInt().toString();
  final fractionDigits =
      (absValue.shift(FinancialPrecision.fiat.scale).toBigInt() %
              BigInt.from(100))
          .toString()
          .padLeft(FinancialPrecision.fiat.scale, '0');

  final grouped = StringBuffer();
  for (var i = 0; i < wholeDigits.length; i++) {
    if (i > 0 && (wholeDigits.length - i) % 3 == 0) grouped.write(',');
    grouped.write(wholeDigits[i]);
  }
  return '${negative ? '-' : ''}$grouped.$fractionDigits';
}
