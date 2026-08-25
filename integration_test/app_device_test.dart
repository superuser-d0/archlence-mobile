/// Runs the real app on a real device: the real database file, the real
/// Android Keystore, the real screens.
///
/// The widget tests under `test/screens/` prove the join between a screen and
/// its services over an IN-MEMORY database and a fixed key. What they cannot
/// say is whether the app works when those are the real thing — whether the
/// file opens where the key lives, whether the Keystore answers before the
/// first draw, whether a figure encrypted through the platform store comes
/// back the same on screen. That is what this covers.
///
/// Run: `flutter test integration_test/app_device_test.dart -d DEVICE`
library;

import 'package:archlence_mobile/app_services.dart';
import 'package:archlence_mobile/app_shell.dart';
import 'package:archlence_mobile/data/database.dart';
import 'package:archlence_mobile/services/account_service.dart';
import 'package:archlence_mobile/services/recurring_service.dart';
import 'package:archlence_mobile/theme/obsidian_prime.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late AppServices services;

  setUp(() async {
    services = await AppServices.open();
    // The device carries whatever a previous run left behind, so start from a
    // known state rather than adding to it.
    for (final table in [
      'transactions',
      'balance_events',
      'recurring_payments',
      'recurring_operation_markers',
      'active_assets',
      'savings_goals',
      'monthly_budget_plan',
      'accounts',
    ]) {
      await services.db.customStatement('DELETE FROM $table');
    }
  });

  tearDown(() => services.close());

  /// Scrolls the current tab until [target] is on screen AND reachable.
  ///
  /// A real phone shows a fraction of these pages at once, so anything below
  /// the fold is not merely invisible but absent from the tree. Scrolling to
  /// it — rather than pretending the surface is 2400px tall, as the widget
  /// tests do — also proves the content is reachable the way a user reaches
  /// it, past the translucent bars that overlay the list.
  ///
  /// BEING IN THE TREE IS NOT BEING ON SCREEN. A lazy list builds a cache
  /// extent beyond the viewport, so a finder can match a widget that is still
  /// off-screen; `tester.tap` on one computes a point outside the viewport and
  /// the tap lands nowhere. That cost a session's worth of wrong diagnosis —
  /// it looked like a screen opening without its data, when the screen had
  /// never opened. `ensureVisible` is what closes the gap.
  Future<void> scrollTo(WidgetTester tester, Finder target, Key list) async {
    for (var attempt = 0; attempt < 12; attempt++) {
      if (target.evaluate().isNotEmpty) {
        // `.first`: a figure can legitimately appear twice on one page — the
        // ring and the stat beside it both show net worth — and
        // `ensureVisible` insists on a single match.
        await tester.ensureVisible(target.first);
        await tester.pumpAndSettle();
        return;
      }
      await tester.drag(find.byKey(list), const Offset(0, -400));
      await tester.pumpAndSettle();
    }
    fail('Could not scroll to $target: it never entered the widget tree.');
  }

  Future<void> pumpApp(WidgetTester tester) async {
    // ArchlenceRoot, not a hand-built MaterialApp: the services scope has to
    // sit above the Navigator for a pushed route to reach it, and a copy of
    // that placement here would let the real one drift without a test
    // noticing.
    await tester.pumpWidget(
      ArchlenceRoot(
        services: services,
        theme: obsidianPrimeTheme(),
        home: const AppShell(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'the dashboard shows figures written through the real key store',
    (tester) async {
      await services.accounts.createAccount(
        name: 'Maaş Hesabı',
        accountType: AccountType.checking,
        initialBalance: 17300,
      );
      await services.accounts.createAccount(
        name: 'Bonus Kart',
        accountType: AccountType.creditCard,
        initialBalance: 3500,
        creditLimit: 20000,
        cardNumberFull: '5555444433337391',
      );
      await services.recurring.insertRecurringPayment(
        name: 'Netflix',
        amount: 229.99,
        category: 'Dijital Abonelik',
        frequency: RecurrenceFrequency.monthly,
        nextDueDate: DateTime(2026, 9, 15),
        accountId: 1,
      );

      await pumpApp(tester);

      expect(find.text('13.800,00 ₺'), findsOneWidget, reason: 'net worth');

      // The name and the amount are AES-GCM values that went through the
      // Keystore and came back; an in-memory test cannot say that.
      await scrollTo(
        tester,
        find.text('Netflix'),
        const PageStorageKey('home'),
      );
      expect(find.text('Netflix'), findsOneWidget);
      expect(find.text('229,99 ₺'), findsOneWidget);
    },
  );

  testWidgets('a future-dated transaction posts on start-up, not before', (
    tester,
  ) async {
    // Nothing else applies a pending row. If start-up stops calling
    // settleDueTransactions, a scheduled salary silently never arrives — and
    // no unit test would notice, because the call site is the app's own
    // bootstrap.
    final yesterday = sqliteTimestamp(
      DateTime.now().subtract(const Duration(days: 1)),
    );
    final accountId = await services.accounts.createAccount(
      name: 'Maaş Hesabı',
      accountType: AccountType.checking,
      initialBalance: 0,
    );
    // Written straight to the table, not through addTransaction: a past date
    // posts immediately, and flipping the row to 'pending' afterwards would
    // leave the balance already applied — settling would then add it a second
    // time and the test would pass on a doubled figure.
    await services.db.customInsert(
      'INSERT INTO transactions (account_id, amount, type, category, '
      'description, transaction_date, execution_date, status) '
      "VALUES (?, ?, 'income', 'Maaş', ?, ?, ?, 'pending')",
      variables: [
        Variable<int>(accountId),
        Variable<String>((await services.crypto.encryptField('5000.0'))!),
        Variable<String>((await services.crypto.encryptField('Maaş'))!),
        Variable<String>(yesterday),
        Variable<String>(yesterday),
      ],
    );
    expect(
      (await services.accounts.getAccount(accountId))!.balance,
      Decimal.zero,
      reason: 'a pending row must not have touched the balance yet',
    );

    final outcome = await services.startUp();

    expect(outcome.settled, 1);
    expect(outcome.skipped, 0);
    await pumpApp(tester);
    await scrollTo(
      tester,
      find.text('5.000,00 ₺'),
      const PageStorageKey('home'),
    );
    expect(find.text('5.000,00 ₺'), findsWidgets);
  });

  testWidgets('the assets tab draws holdings and a distribution', (
    tester,
  ) async {
    final accountId = await services.accounts.createAccount(
      name: 'Maaş Hesabı',
      accountType: AccountType.checking,
      initialBalance: 100000,
    );
    await services.assets.insertAsset(
      assetName: 'Euro',
      assetCode: 'EURTRY=X',
      assetType: 'Döviz',
      purchasePrice: '37.80',
      quantity: 400,
    );
    await services.transactions.addTransaction(
      accountId: accountId,
      amount: 250,
      transactionType: 'expense',
      category: 'Süpermarket',
    );

    await pumpApp(tester);
    await tester.tap(find.text('Assets'));
    await tester.pumpAndSettle();

    // The purchase price and quantity are AES-GCM values from the real key
    // store; the cost is derived from both.
    await scrollTo(
      tester,
      find.text('Euro (EURTRY=X)'),
      const PageStorageKey('assets'),
    );
    expect(find.text('15.120,00 ₺'), findsWidgets);
    expect(find.text('Süpermarket'), findsOneWidget);
  });

  testWidgets('a tool opens as a pushed route and still sees the services', (
    tester,
  ) async {
    // The scope lives in MaterialApp's `builder`, above the Navigator. In
    // `home` it would sit BELOW: a pushed route is a sibling of home, not a
    // descendant, and every tool screen would find no services at all.
    await services.savings.createGoal(
      goalName: 'Acil Durum Fonu',
      targetAmount: 350000,
    );

    await pumpApp(tester);
    await tester.tap(find.text('Tools'));
    await tester.pumpAndSettle();
    // Seventh in the grid, below the fold on a phone.
    await scrollTo(
      tester,
      find.text('Savings\nGoal'),
      const PageStorageKey('tools'),
    );
    await tester.tap(find.text('Savings\nGoal'));
    await tester.pumpAndSettle();

    expect(find.text('Acil Durum Fonu'), findsOneWidget);
    expect(find.text('350.000,00 ₺'), findsOneWidget);
  });

  testWidgets('Settings reports the key store this device actually has', (
    tester,
  ) async {
    // The one claim in the app that only a real device can settle. The row
    // used to be a hard-coded sentence saying the key sat in a local file;
    // on a device with a working Keystore that was the opposite of the truth.
    await pumpApp(tester);
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(
      services.keyProtection,
      isNotNull,
      reason: 'the device build must know where its key is',
    );
    expect(find.textContaining(services.keyProtection!.method), findsOneWidget);
    expect(find.textContaining('Not known in this build'), findsNothing);
  });

  testWidgets('an account added through the form survives on the real file', (
    tester,
  ) async {
    // The first write flow, end to end: a form, the service, the real
    // database file and the real key store — then read back and drawn.
    await pumpApp(tester);
    await tester.tap(find.text('Cards'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('+  ADD'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.ancestor(of: find.text('Name'), matching: find.byType(TextField)),
      'Maaş Hesabı',
    );
    await tester.enterText(
      find.ancestor(
        of: find.text('Opening balance'),
        matching: find.byType(TextField),
      ),
      '17.300,50',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add account'));
    await tester.pumpAndSettle();

    final account = (await services.accounts.getAccounts()).single;
    expect(account.name, 'Maaş Hesabı');
    expect(account.balance.toString(), '17300.5');
    expect(find.text('17.300,50 ₺'), findsWidgets);
  });

  testWidgets('a transaction recorded through the form reaches the balance', (
    tester,
  ) async {
    final accountId = await services.accounts.createAccount(
      name: 'Maaş Hesabı',
      accountType: AccountType.checking,
      initialBalance: 10000,
    );

    await pumpApp(tester);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.ancestor(of: find.text('Amount'), matching: find.byType(TextField)),
      '1.234,56',
    );
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('Record'), const Key('field-category'));
    await tester.tap(find.text('Record'));
    await tester.pumpAndSettle();

    // Through the form, the service, the real key store and back onto the
    // dashboard — the round trip an in-memory test cannot speak for.
    expect(
      (await services.accounts.getAccount(accountId))!.balance.toString(),
      '8765.44',
    );
    expect(find.text('8.765,44 ₺'), findsWidgets);
  });

  testWidgets('the cards tab reads the same account the dashboard did', (
    tester,
  ) async {
    await services.accounts.createAccount(
      name: 'Bonus Kart',
      accountType: AccountType.creditCard,
      initialBalance: 3500,
      creditLimit: 20000,
      cardNumberFull: '5555444433337391',
    );

    await pumpApp(tester);
    await tester.tap(find.text('Cards'));
    await tester.pumpAndSettle();

    expect(find.text('Bonus Kart'), findsWidgets);
    expect(find.text('MC'), findsOneWidget);
    expect(find.text('16.500,00 ₺'), findsOneWidget, reason: 'available limit');
  });
}
