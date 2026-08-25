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
import 'package:drift/drift.dart' show Variable;
import 'package:flutter/material.dart';
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

  /// Scrolls the current tab until [target] is on screen.
  ///
  /// A real phone shows a fraction of these pages at once, so anything below
  /// the fold is not merely invisible but absent from the tree. Scrolling to
  /// it — rather than pretending the surface is 2400px tall, as the widget
  /// tests do — also proves the content is reachable the way a user reaches
  /// it, past the translucent bars that overlay the list.
  Future<void> scrollTo(WidgetTester tester, Finder target, Key list) async {
    // Explicit drags rather than `dragUntilVisible`: that helper gives up
    // silently when the target never enters the tree, which turns a wiring
    // failure into an unexplained "0 widgets found" at the assertion instead
    // of an error where the scrolling actually stopped.
    for (var attempt = 0; attempt < 12; attempt++) {
      if (target.evaluate().isNotEmpty) return;
      await tester.drag(find.byKey(list), const Offset(0, -400));
      // Settle BEFORE looking, and do not pump again after finding it: a
      // further settle can carry the list past the target and back out of
      // the tree, which reads at the assertion as if the data were never
      // there.
      await tester.pumpAndSettle();
    }
    fail('Could not scroll to $target: it never entered the widget tree.');
  }

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: obsidianPrimeTheme(),
        home: ServicesScope(services: services, child: const AppShell()),
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
