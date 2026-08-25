/// The services a screen can reach, and the scope that carries them.
///
/// One database connection and one [FieldCrypto] are shared by every service:
/// they hold a write lock and a decryption key respectively, and a second of
/// either would defeat both.
library;

import 'package:flutter/widgets.dart';

import 'crypto/field_crypto.dart';
import 'crypto/key_provider.dart';
import 'data/database.dart';
import 'services/account_service.dart';
import 'services/asset_purchase_service.dart';
import 'services/asset_sale_service.dart';
import 'services/asset_service.dart';
import 'services/budget_service.dart';
import 'services/recurring_service.dart';
import 'services/savings_service.dart';
import 'services/transaction_service.dart';

class AppServices {
  AppServices._(this.db, this.crypto)
    : accounts = AccountService(db, crypto),
      assets = AssetService(db, crypto),
      savings = SavingsService(db, crypto);

  /// Builds the whole graph over an already-open database.
  ///
  /// Tests use this with an in-memory database and a fixed key; production
  /// goes through [open].
  factory AppServices.forDatabase(ArchlenceDatabase db, FieldCrypto crypto) {
    final services = AppServices._(db, crypto);
    services.transactions = TransactionService(db, crypto, services.accounts);
    services.recurring = RecurringService(db, crypto, services.accounts);
    services.budget = BudgetService(db, crypto, services.recurring);
    services.assetPurchases = AssetPurchaseService(
      db,
      crypto,
      services.accounts,
    );
    services.assetSales = AssetSaleService(db, crypto);
    return services;
  }

  /// Opens the app's database and key store, then builds the graph.
  static Future<AppServices> open() async {
    final db = await ArchlenceDatabase.open();
    final keyProvider = await createPlatformKeyProvider(
      await applicationDataDirectory(),
    );
    return AppServices.forDatabase(db, FieldCrypto(keyProvider));
  }

  final ArchlenceDatabase db;
  final FieldCrypto crypto;

  final AccountService accounts;
  final AssetService assets;
  final SavingsService savings;

  late final TransactionService transactions;
  late final RecurringService recurring;
  late final BudgetService budget;
  late final AssetPurchaseService assetPurchases;
  late final AssetSaleService assetSales;

  /// Work that has to happen once, before the first screen draws.
  ///
  /// Settling is here because NOTHING ELSE posts a future-dated transaction:
  /// `addTransaction` records it as `pending` and walks away, so without this
  /// call a scheduled rent or salary is recorded and never reaches a balance.
  ///
  /// It returns rather than throwing on a partial result: a due row that could
  /// not be applied leaves the rest posted, and the caller decides whether to
  /// say so.
  Future<SettleOutcome> startUp() => transactions.settleDueTransactions();

  Future<void> close() => db.close();
}

/// Makes [AppServices] reachable from any widget below it.
class ServicesScope extends InheritedWidget {
  const ServicesScope({
    required this.services,
    required super.child,
    super.key,
  });

  final AppServices services;

  static AppServices of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ServicesScope>();
    assert(scope != null, 'No ServicesScope above this widget.');
    return scope!.services;
  }

  @override
  bool updateShouldNotify(ServicesScope oldWidget) =>
      services != oldWidget.services;
}
