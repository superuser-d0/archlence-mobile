/// The Home screen against a real service graph.
library;

import 'package:archlence_mobile/app_services.dart';
import 'package:archlence_mobile/data/database.dart';
import 'package:archlence_mobile/screens/category_settings_screen.dart';
import 'package:archlence_mobile/screens/home_screen.dart';
import 'package:archlence_mobile/services/account_service.dart';
import 'package:archlence_mobile/services/recurring_service.dart';
import 'package:archlence_mobile/widgets/surfaces.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:flutter/material.dart';
import 'package:archlence_mobile/widgets/not_yet.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fixed_key_provider.dart';
import '../support/test_app.dart';

void main() {
  late ArchlenceDatabase db;
  late AppServices services;

  setUp(() {
    db = ArchlenceDatabase.memory();
    services = testServices(db);
  });

  tearDown(() => db.close());

  Future<void> pump(WidgetTester tester) =>
      pumpScreen(tester, services, const HomeScreen());

  testWidgets('the ring carries net worth and the stats its components', (
    tester,
  ) async {
    await services.accounts.createAccount(
      name: 'Maaş',
      accountType: AccountType.checking,
      initialBalance: 17300,
    );
    await services.accounts.createAccount(
      name: 'Kart',
      accountType: AccountType.creditCard,
      initialBalance: 3500,
      creditLimit: 20000,
    );

    await pump(tester);

    expect(find.text('13.800,00 ₺'), findsOneWidget, reason: 'net worth');
    expect(find.text('17.300,00 ₺'), findsOneWidget, reason: 'cash');
    expect(find.text('3.500,00 ₺'), findsOneWidget, reason: 'card debt');
  });

  testWidgets('an empty database reads as zero, which is the truth', (
    tester,
  ) async {
    // Distinct from the unreadable case below: nothing recorded really does
    // mean nothing, and saying so is correct rather than evasive.
    await pump(tester);
    expect(find.text('0,00 ₺'), findsWidgets);
  });

  testWidgets('subscriptions come from the recurring service', (tester) async {
    final accountId = await services.accounts.createAccount(
      name: 'Maaş',
      accountType: AccountType.checking,
      initialBalance: 10000,
    );
    await services.recurring.insertRecurringPayment(
      name: 'Netflix',
      amount: 229.99,
      category: 'Dijital Abonelik',
      frequency: RecurrenceFrequency.monthly,
      nextDueDate: DateTime(2026, 9, 15),
      accountId: accountId,
    );

    await pump(tester);

    expect(find.text('Netflix'), findsOneWidget);
    expect(find.text('229,99 ₺'), findsOneWidget);
    expect(find.text('Next on 15.09.2026'), findsOneWidget);
  });

  testWidgets('a subscription that will not decrypt says so', (tester) async {
    final accountId = await services.accounts.createAccount(
      name: 'Maaş',
      accountType: AccountType.checking,
      initialBalance: 10000,
    );
    await services.recurring.insertRecurringPayment(
      name: 'Netflix',
      amount: 229.99,
      frequency: RecurrenceFrequency.monthly,
      nextDueDate: DateTime(2026, 9, 15),
      accountId: accountId,
    );
    await db.customUpdate(
      "UPDATE recurring_payments SET name = ?, amount = ?",
      variables: [
        Variable<String>('AEADv1:broken'),
        Variable<String>('AEADv1:broken'),
      ],
      updates: const {},
    );

    await pump(tester);

    expect(find.text('Unreadable subscription'), findsOneWidget);
    expect(find.text('unreadable'), findsOneWidget);
    expect(find.text('229,99 ₺'), findsNothing);
  });

  testWidgets('no subscriptions says so rather than showing an empty card', (
    tester,
  ) async {
    await pump(tester);
    expect(find.textContaining('Nothing recurring yet'), findsOneWidget);
  });

  group('the change chip', () {
    /// Moves every event written so far back to [daysAgo], so a test can put
    /// the ledger's beginning before the chip's 30-day window.
    Future<void> backdate(int daysAgo) async {
      final when = DateTime.now().subtract(Duration(days: daysAgo));
      final stamp =
          '${when.year.toString().padLeft(4, '0')}-'
          '${when.month.toString().padLeft(2, '0')}-'
          '${when.day.toString().padLeft(2, '0')} 09:00:00';
      await db.customUpdate(
        'UPDATE balance_events SET ts = ?',
        variables: [Variable<String>(stamp)],
        updates: const {},
      );
    }

    testWidgets('none is drawn when the ledger cannot answer', (tester) async {
      // Caught on the emulator, not in a test: an empty label still drew the
      // chip, so the ring showed a bare green pill with an upward arrow and no
      // number — which reads as a gain.
      //
      // The reason it cannot answer has changed since. The period services
      // used to be unported; now the account is opened TODAY, so the
      // baseline — thirty days back — falls before the ledger begins, and
      // "I do not know" is the honest answer.
      await services.accounts.createAccount(
        name: 'Maaş',
        accountType: AccountType.checking,
        initialBalance: 100,
      );

      await pump(tester);

      expect(find.byType(TrendChip), findsNothing);
      expect(find.text('Net Worth'), findsOneWidget);
    });

    testWidgets('a real move is drawn in lira and per cent', (tester) async {
      final id = await services.accounts.createAccount(
        name: 'Maaş',
        accountType: AccountType.checking,
        initialBalance: 1000,
      );
      await backdate(40);
      await services.transactions.addTransaction(
        accountId: id,
        amount: 250,
        transactionType: 'income',
        category: 'Maaş',
      );

      await pump(tester);

      expect(find.byType(TrendChip), findsOneWidget);
      expect(find.text('+250,00 ₺ · +%25'), findsOneWidget);
      // The window is named, so the figure is never a change over an
      // unstated period.
      expect(find.text('Net Worth · 30 days'), findsOneWidget);
    });

    testWidgets('a fall is drawn as a fall', (tester) async {
      final id = await services.accounts.createAccount(
        name: 'Maaş',
        accountType: AccountType.checking,
        initialBalance: 1000,
      );
      await backdate(40);
      await services.transactions.addTransaction(
        accountId: id,
        amount: 400,
        transactionType: 'expense',
        category: 'Market',
      );

      await pump(tester);

      expect(find.text('-400,00 ₺ · -%40'), findsOneWidget);
      expect(
        tester.widget<TrendChip>(find.byType(TrendChip)).positive,
        isFalse,
      );
    });

    testWidgets('a move off zero shows the lira and no percentage', (
      tester,
    ) async {
      // The rule that is easiest to get backwards: there is no finite
      // percentage from a real zero, and inventing one would be worse than
      // leaving it out. The lira figure is true either way.
      final id = await services.accounts.createAccount(
        name: 'Maaş',
        accountType: AccountType.checking,
        initialBalance: 0,
      );
      await backdate(40);
      await services.transactions.addTransaction(
        accountId: id,
        amount: 500,
        transactionType: 'income',
        category: 'Maaş',
      );

      await pump(tester);

      expect(find.text('+500,00 ₺'), findsOneWidget);
      expect(find.textContaining('%'), findsNothing);
    });
  });

  group('the search box', () {
    /// Types [query] and lets the debounce elapse.
    ///
    /// `pump(Duration)` rather than `pumpAndSettle`: the field waits 300ms
    /// before it searches anything, and settling would return the instant the
    /// timer was scheduled with nothing on screen yet.
    Future<void> type(WidgetTester tester, String query) async {
      await tester.enterText(find.byType(TextField), query);
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
    }

    testWidgets('it is live, not the disabled placeholder it used to be', (
      tester,
    ) async {
      await pump(tester);
      expect(find.text('Search — not yet'), findsNothing);

      // Asserted by TYPING rather than by reading `TextField.enabled`, which
      // is null by default and derives from the decoration — so `isTrue`
      // fails on a perfectly live field. The question is what the user can
      // do, which is the same lesson the disabled-button defect taught.
      await tester.enterText(find.byType(TextField), 'maas');
      await tester.pump();
      expect(find.text('maas'), findsOneWidget);
    });

    testWidgets('nothing is searched until the user types', (tester) async {
      await services.accounts.createAccount(
        name: 'Maaş',
        accountType: AccountType.checking,
        initialBalance: 100,
      );
      await pump(tester);

      // No panel at all, rather than one listing the whole profile.
      expect(find.text('Account'), findsNothing);
      expect(find.text('Nothing found'), findsNothing);
    });

    testWidgets('an account is found without its accents', (tester) async {
      await services.accounts.createAccount(
        name: 'Şirket Hesabı',
        accountType: AccountType.checking,
        initialBalance: 100,
      );
      await pump(tester);
      await type(tester, 'sirket');

      expect(find.text('Şirket Hesabı'), findsOneWidget);
      expect(find.text('Account'), findsOneWidget);
    });

    testWidgets('a query that matches nothing says where it looked', (
      tester,
    ) async {
      await pump(tester);
      await type(tester, 'zzzzzz');

      expect(find.text('Nothing found'), findsOneWidget);
      // Without this line an empty panel reads as "I never recorded it",
      // which may be false for a description outside the search window.
      expect(
        find.textContaining('descriptions of recent transactions'),
        findsOneWidget,
      );
    });

    testWidgets('clearing the field takes the panel with it', (tester) async {
      await pump(tester);
      await type(tester, 'maas');
      expect(find.text('Maaş'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(find.text('Category'), findsNothing);
    });

    testWidgets('at most five results are drawn, and the rest are counted', (
      tester,
    ) async {
      // Seven seeded categories contain "ev"; only five may be drawn.
      await pump(tester);
      await type(tester, 'e');

      // Exactly five rows drawn — not "at most", which would also pass if
      // the panel drew nothing at all.
      expect(find.byIcon(Icons.sell_outlined), findsNWidgets(5));
      expect(find.textContaining('more not shown'), findsOneWidget);
    });

    testWidgets('a category result opens the screen that owns it', (
      tester,
    ) async {
      await pump(tester);
      await type(tester, 'maas');

      await tester.tap(find.text('Maaş'));
      await tester.pumpAndSettle();

      expect(find.byType(CategorySettingsScreen), findsOneWidget);
    });

    testWidgets('a locked profile is not reported as an empty one', (
      tester,
    ) async {
      // The one answer this app never gives: "no results" when the truth is
      // that nothing could be read.
      final locked = testServices(db, keyProvider: UnavailableKeyProvider());
      await tester.pumpWidget(testApp(locked, const HomeScreen()));
      await tester.pumpAndSettle();
      await type(tester, 'maas');

      expect(find.text('Nothing found'), findsNothing);
    });
  });

  testWidgets('the insight cards are not drawn at all', (tester) async {
    // The mockup fills both with numbers. Those services are not ported, and
    // a health score with nothing behind it would be the most confidently
    // wrong thing on the screen.
    //
    // They used to be drawn empty with a NOT YET chip, which was the honest
    // answer to "is this computed?" and the wrong answer to "is this app
    // finished?" — the forecast card sat directly under the balance ring, so
    // the first thing a new user saw was a card saying it did not exist. See
    // `showUnbuiltFeatures`, and note that the constant is what this test is
    // really pinned to: flip it and this file expects them back.
    await pump(tester);

    expect(find.text('Algorithmic Forecast'), findsNothing);
    expect(find.text('Financial Health Score'), findsNothing);
    expect(find.text('NOT YET'), findsNothing);
    // The point of the original test, and it outlives the cards: no figure is
    // invented for either of them anywhere on this screen.
    expect(find.text('72'), findsNothing);
  }, skip: showUnbuiltFeatures);
}
