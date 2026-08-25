/// The services a screen can reach, and the scope that carries them.
///
/// One database connection and one [FieldCrypto] are shared by every service:
/// they hold a write lock and a decryption key respectively, and a second of
/// either would defeat both.
library;

import 'package:flutter/material.dart';

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
  AppServices._(this.db, this.crypto, this.keyProtection)
    : accounts = AccountService(db, crypto),
      assets = AssetService(db, crypto),
      savings = SavingsService(db, crypto);

  /// Builds the whole graph over an already-open database.
  ///
  /// Tests use this with an in-memory database and a fixed key; production
  /// goes through [open].
  factory AppServices.forDatabase(
    ArchlenceDatabase db,
    FieldCrypto crypto, {
    KeyProtectionStatus? keyProtection,
  }) {
    final services = AppServices._(db, crypto, keyProtection);
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
    return AppServices.forDatabase(
      db,
      FieldCrypto(keyProvider),
      keyProtection: keyProvider.status,
    );
  }

  final ArchlenceDatabase db;
  final FieldCrypto crypto;

  /// Where the encryption key actually ended up, for Settings to report.
  ///
  /// Null in tests, which inject a fixed key with no platform store behind
  /// it. A screen must say it does not know rather than assume the best
  /// case — claiming Keystore protection that is not there is the worst
  /// possible thing to be wrong about on that screen.
  final KeyProtectionStatus? keyProtection;

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

  /// Whether the app has anything to show yet.
  ///
  /// The onboarding gate, and it asks the DATA rather than a preference
  /// flag. "Has the user seen a welcome screen" is the wrong question: a flag
  /// would survive a database that was wiped or restored empty, and strand a
  /// fresh install on a dashboard of zeroes with no way to add anything.
  Future<bool> get isSetUp => accounts.hasAnyAccount();

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

/// The app's `MaterialApp`, with the services scope placed correctly.
///
/// THE PLACEMENT IS THE POINT. `builder` sits ABOVE the Navigator; `home`
/// sits below it. With the scope in `home`, a pushed route is a SIBLING of
/// home rather than a descendant, and every screen opened from the Tools grid
/// finds no scope at all — an assertion in production, and a blank screen if
/// assertions are off.
///
/// It lives here, shared by `main.dart` and the device test, so that the test
/// exercises the real placement instead of a copy of it that could drift.
class ArchlenceRoot extends StatelessWidget {
  const ArchlenceRoot({
    required this.services,
    required this.home,
    required this.theme,
    super.key,
  });

  final AppServices? services;
  final Widget home;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final resolved = services;
    return MaterialApp(
      title: 'Archlence',
      debugShowCheckedModeBanner: false,
      theme: theme,
      builder: resolved == null
          ? null
          : (context, child) =>
                ServicesScope(services: resolved, child: child!),
      home: home,
    );
  }
}
