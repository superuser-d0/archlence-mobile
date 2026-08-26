/// The services a screen can reach, and the scope that carries them.
///
/// One database connection and one [FieldCrypto] are shared by every service:
/// they hold a write lock and a decryption key respectively, and a second of
/// either would defeat both.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:path/path.dart' as p;

import 'backup/backup_service.dart';
import 'crypto/field_crypto.dart';
import 'crypto/key_provider.dart';
import 'data/database.dart';
import 'l10n/app_localizations.dart';
import 'services/account_service.dart';
import 'services/asset_purchase_service.dart';
import 'services/asset_sale_service.dart';
import 'services/asset_service.dart';
import 'services/budget_service.dart';
import 'services/recurring_service.dart';
import 'services/savings_service.dart';
import 'security/screen_lock.dart';
import 'services/transaction_service.dart';
import 'ui/app_locale.dart';

class AppServices {
  AppServices._(
    this.db,
    this.crypto,
    this.keyProtection,
    this.screenLock,
    this.backup,
  ) : accounts = AccountService(db, crypto),
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
    ScreenLock? screenLock,
    BackupService? backup,
  }) {
    final services = AppServices._(
      db,
      crypto,
      keyProtection,
      screenLock ?? ScreenLock(),
      backup,
    );
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
  ///
  /// A restore interrupted by the OS is undone FIRST, before the database is
  /// opened — the whole point of the journal is that nothing reads a profile
  /// that is half of one generation and half of another. It throws rather
  /// than continuing if it cannot decide, and the root shows that instead of
  /// a dashboard.
  static Future<AppServices> open() async {
    final directory = await applicationDataDirectory();
    final keyProvider = await createPlatformKeyProvider(directory);
    final backup = BackupService(
      databasePath: p.join(directory, 'finance.db'),
      keyProvider: keyProvider,
    );
    await backup.recoverInterruptedRestore();

    // The key is created HERE, with the profile, rather than lazily on the
    // first value that needs encrypting.
    //
    // It used to be lazy, and the consequence was found by using the app: a
    // fresh install that had opened an account but recorded no transaction
    // had a database and NO KEY — nothing on that path encrypts anything, so
    // nothing had asked for one — and Backup & Restore answered "there is no
    // encryption key to back up". The one moment a user is most likely to
    // make their first backup is the moment they have least data, and that
    // was exactly the moment it refused.
    //
    // It also makes the Settings row honest: it reports where the key is
    // held, and until now it could be describing a key that did not exist.
    await keyProvider.getOrCreateKey();

    final db = await ArchlenceDatabase.open();
    return AppServices.forDatabase(
      db,
      FieldCrypto(keyProvider),
      keyProtection: keyProvider.status,
      backup: backup,
    );
  }

  final ArchlenceDatabase db;
  final FieldCrypto crypto;

  /// The resume gate. Held here so Settings and the root see one instance
  /// and cannot disagree about whether it is on.
  ///
  /// Injectable for the same reason [keyProtection] is: a widget test has no
  /// platform behind `local_auth`, and a screen that only draws its real
  /// explanation on a capable device would go untested on exactly the path
  /// users see.
  final ScreenLock screenLock;

  /// Where the encryption key actually ended up, for Settings to report.
  ///
  /// Null in tests, which inject a fixed key with no platform store behind
  /// it. A screen must say it does not know rather than assume the best
  /// case — claiming Keystore protection that is not there is the worst
  /// possible thing to be wrong about on that screen.
  final KeyProtectionStatus? keyProtection;

  /// Backup and restore, or null in tests that have no profile on disk.
  ///
  /// Null rather than a stub for the same reason [keyProtection] is: a screen
  /// that cannot back anything up has to SAY so, not draw a button that
  /// quietly does nothing.
  final BackupService? backup;

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

/// Closes the whole app down to its files, runs [work] against a profile that
/// nothing has open, and builds everything again from scratch.
///
/// A restore REPLACES the database file. A drift connection still holding the
/// old one would go on writing into a file that is no longer the app's data,
/// so the swap cannot happen underneath a running app — it has to happen
/// between two of them.
typedef ProfileSwap = Future<void> Function(Future<void> Function() work);

/// Carries [ProfileSwap] down to whatever screen needs it.
///
/// Separate from [ServicesScope] because it outlives the services it replaces:
/// by the time [work] runs, the graph in the scope is already closed.
class AppRestartScope extends InheritedWidget {
  const AppRestartScope({
    required this.swapProfile,
    required super.child,
    super.key,
  });

  final ProfileSwap swapProfile;

  /// Null where nothing can restart the app — the widget tests, which build a
  /// screen directly rather than through the root.
  static ProfileSwap? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<AppRestartScope>()
      ?.swapProfile;

  @override
  bool updateShouldNotify(AppRestartScope oldWidget) =>
      swapProfile != oldWidget.swapProfile;
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
    this.swapProfile,
    this.locale,
    this.selectLocale,
    super.key,
  });

  final AppServices? services;
  final Widget home;
  final ThemeData theme;

  /// How a screen asks for the profile to be replaced under a closed app.
  /// Null in tests, where there is no root to restart.
  final ProfileSwap? swapProfile;

  /// The language chosen in Settings, or null to follow the device.
  ///
  /// Null in tests too, which is what puts them in English: the test binding
  /// reports an en-US device, and an unset choice means the device decides.
  final Locale? locale;

  /// How Settings changes [locale]. Null where nothing can.
  final Future<void> Function(Locale?)? selectLocale;

  @override
  Widget build(BuildContext context) {
    final resolved = services;
    final swap = swapProfile;
    final choose = selectLocale;
    return MaterialApp(
      title: 'Archlence',
      debugShowCheckedModeBanner: false,
      theme: theme,
      locale: locale,
      supportedLocales: supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: resolved == null
          ? null
          : (context, child) {
              Widget wrapped = ServicesScope(services: resolved, child: child!);
              if (swap != null) {
                wrapped = AppRestartScope(swapProfile: swap, child: wrapped);
              }
              if (choose != null) {
                wrapped = AppLocaleScope(
                  selected: locale,
                  select: choose,
                  child: wrapped,
                );
              }
              return wrapped;
            },
      home: home,
    );
  }
}
