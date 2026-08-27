/// The Assets screen against a real service graph.
library;

import 'package:archlence_mobile/app_services.dart';
import 'package:archlence_mobile/data/database.dart';
import 'package:archlence_mobile/screens/assets_screen.dart';
import 'package:archlence_mobile/widgets/summary_row.dart';
import 'package:archlence_mobile/services/account_service.dart';
import 'package:flutter/material.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';

import '../support/test_app.dart';

/// Canned CoinGecko/Frankfurter bodies for the one test that drives a real
/// price through this screen; every other test in this file keeps the
/// network-refusing default from `testServices`.
Future<String> _fakeLiveGet(
  Uri uri, {
  Map<String, String> headers = const {},
}) async {
  if (uri.host == 'api.coingecko.com') {
    return '{"bitcoin": {"usd": 78402}}';
  }
  if (uri.host == 'api.frankfurter.dev') {
    return '{"rates": {"USD": 0.02079}}';
  }
  throw StateError('unexpected host: ${uri.host}');
}

void main() {
  late ArchlenceDatabase db;
  late AppServices services;

  setUp(() {
    db = ArchlenceDatabase.memory();
    services = testServices(db);
  });

  tearDown(() => db.close());

  Future<void> pump(WidgetTester tester) =>
      pumpScreen(tester, services, const AssetsScreen());

  Future<int> cashAccount({Object balance = 1000000}) =>
      services.accounts.createAccount(
        name: 'Maaş',
        accountType: AccountType.checking,
        initialBalance: balance,
      );

  testWidgets('the summary reports the selected period, not all of history', (
    tester,
  ) async {
    final accountId = await cashAccount();
    await services.transactions.addTransaction(
      accountId: accountId,
      amount: 900,
      transactionType: 'expense',
      category: 'Süpermarket',
    );
    await services.transactions.addTransaction(
      accountId: accountId,
      amount: 40000,
      transactionType: 'expense',
      category: 'Eski',
      transactionDate: DateTime(2019, 3, 4),
    );

    await pump(tester);

    // Scoped to the summary row on purpose. The split card underneath prints
    // the same total when every expense falls on one side of the main/extra
    // line, and a bare `findsWidgets` here would pass with the SUMMARY
    // showing the wrong figure — the exact shape of assertion this suite has
    // been caught by before.
    Finder inSummary(String amount) => find.descendant(
      of: find.byType(SummaryRow),
      matching: find.text(amount),
    );

    // The screen opens on '1 Year', so the 2019 row is outside it.
    expect(inSummary('900,00 ₺'), findsOneWidget);
    // Nowhere on the screen, not just nowhere in the summary.
    expect(find.text('40.000,00 ₺'), findsNothing);

    await tester.tap(find.text('All Time'));
    await tester.pumpAndSettle();
    expect(inSummary('40.900,00 ₺'), findsOneWidget);
  });

  testWidgets('net balance carries an explicit sign', (tester) async {
    final accountId = await cashAccount();
    await services.transactions.addTransaction(
      accountId: accountId,
      amount: 5000,
      transactionType: 'income',
      category: 'Maaş',
    );
    await services.transactions.addTransaction(
      accountId: accountId,
      amount: 1200,
      transactionType: 'expense',
      category: 'Kira',
    );

    await pump(tester);

    expect(find.text('+3.800,00 ₺'), findsOneWidget);
  });

  group('the essential/chosen split', () {
    testWidgets('divides expense by the importance the categories carry', (
      tester,
    ) async {
      // 'Ev Kirası' is seeded 'main' and 'Emlak Vergisi' 'extra', so the two
      // rows land on opposite sides of the bar without this test writing to
      // the categories table at all.
      final accountId = await cashAccount();
      await services.transactions.addTransaction(
        accountId: accountId,
        amount: 3000,
        transactionType: 'expense',
        category: 'Ev Kirası',
      );
      await services.transactions.addTransaction(
        accountId: accountId,
        amount: 1000,
        transactionType: 'expense',
        category: 'Emlak Vergisi',
      );

      await pump(tester);

      expect(find.text('Essential and chosen'), findsOneWidget);
      expect(find.text('3.000,00 ₺'), findsOneWidget);
      expect(find.text('1.000,00 ₺'), findsOneWidget);
      // The shares are printed, not only drawn: %75 / %25 of 4.000.
      expect(find.text('%75'), findsOneWidget);
      expect(find.text('%25'), findsOneWidget);
    });

    testWidgets('the bar is actually drawn, at the widths it claims', (
      tester,
    ) async {
      // This assertion exists because the first version of the bar was in the
      // tree, laid out, and INVISIBLE: the row centred its children and a
      // `ColoredBox` with no child asks for no height, so both sides came out
      // 10px wide and 0px tall. Every other test here passed, because they
      // assert the figures and the figures were right. Measuring the painted
      // size is the only assertion that could have caught it.
      final accountId = await cashAccount();
      await services.transactions.addTransaction(
        accountId: accountId,
        amount: 3000,
        transactionType: 'expense',
        category: 'Ev Kirası',
      );
      await services.transactions.addTransaction(
        accountId: accountId,
        amount: 1000,
        transactionType: 'expense',
        category: 'Emlak Vergisi',
      );

      await pump(tester);

      final segments = find.descendant(
        of: find.byType(ClipRRect),
        matching: find.byType(ColoredBox),
      );
      expect(segments, findsNWidgets(2));

      final essential = tester.getSize(segments.at(0));
      final chosen = tester.getSize(segments.at(1));
      expect(essential.height, greaterThan(0));
      expect(chosen.height, greaterThan(0));
      // 3.000 against 1.000, so three times the width, within a pixel of
      // rounding.
      expect(essential.width / chosen.width, closeTo(3, 0.01));
    });

    testWidgets('follows the switch, not the seed', (tester) async {
      final accountId = await cashAccount();
      await services.transactions.addTransaction(
        accountId: accountId,
        amount: 500,
        transactionType: 'expense',
        category: 'Emlak Vergisi',
      );
      // The whole point of the settings screen: flipping this moves the money
      // from one side of the bar to the other.
      await services.categories.setImportance('Emlak Vergisi', isMain: true);

      await pump(tester);

      expect(find.text('Essential'), findsOneWidget);
      expect(find.text('%100'), findsOneWidget);
      expect(find.text('A choice'), findsOneWidget);
      expect(find.text('%0'), findsOneWidget);
    });

    testWidgets('says nothing is marked rather than drawing an empty bar', (
      tester,
    ) async {
      final accountId = await cashAccount();
      await services.transactions.addTransaction(
        accountId: accountId,
        amount: 40,
        transactionType: 'expense',
        category: 'Emlak Vergisi',
      );

      await pump(tester);

      // Every category involved is 'extra', so the bar sits at one end. A
      // reader has to be told that is a setting and not a broken chart.
      expect(
        find.textContaining('No category is marked as one you must have'),
        findsOneWidget,
      );
    });

    testWidgets('an empty period says so instead of splitting nothing', (
      tester,
    ) async {
      await cashAccount();

      await pump(tester);

      expect(
        find.textContaining('there is nothing to split'),
        findsOneWidget,
      );
    });
  });

  testWidgets('the distribution names real categories and their shares', (
    tester,
  ) async {
    final accountId = await cashAccount(balance: 0);
    await services.transactions.addTransaction(
      accountId: accountId,
      amount: 750,
      transactionType: 'income',
      category: 'Maaş',
    );
    await services.transactions.addTransaction(
      accountId: accountId,
      amount: 250,
      transactionType: 'expense',
      category: 'Süpermarket',
    );

    await pump(tester);

    expect(find.text('Maaş'), findsOneWidget);
    expect(find.text('Süpermarket'), findsOneWidget);
    expect(find.text('%75'), findsOneWidget);
    expect(find.text('%25'), findsOneWidget);
  });

  testWidgets('an opening balance gets its own slice', (tester) async {
    // It never reaches the transactions table, so without this a user who has
    // just funded an account sees an empty chart beside a full balance.
    await cashAccount(balance: 17300);

    await pump(tester);

    expect(find.text('Opening Balance'), findsOneWidget);
    expect(find.text('%100'), findsOneWidget);
  });

  testWidgets(
    'nothing in the period says so rather than drawing an empty pie',
    (tester) async {
      await pump(tester);
      expect(find.textContaining('no distribution'), findsOneWidget);
    },
  );

  testWidgets(
    'a symbol this app cannot classify is shown at cost, not invented',
    (tester) async {
      // 'EURTRY=X' is a Yahoo-style ticker, not the bare 3-letter code
      // `ticker_mapper.dart` recognises — exactly the shape a restored
      // desktop backup could carry. It must stay at cost rather than being
      // guessed at.
      await services.assets.insertAsset(
        assetName: 'Euro',
        assetCode: 'EURTRY=X',
        assetType: 'Döviz',
        purchasePrice: '37.80',
        quantity: 400,
      );

      await pump(tester);

      expect(find.text('Euro (EURTRY=X)'), findsOneWidget);
      expect(find.text('Purchase: 37,80 ₺ × 400'), findsOneWidget);
      expect(find.text('Cost'), findsOneWidget);
      // Twice: once on the tile, once in the total above it. `findsWidgets`
      // would pass on a tile showing the UNIT price, because the total would
      // still carry the figure on its own.
      expect(find.text('15.120,00 ₺'), findsNWidgets(2));
      expect(find.text('Holdings at Cost'), findsOneWidget);
      expect(
        find.textContaining('Shares are shown at cost'),
        findsOneWidget,
        reason: 'the section banner still has to set the expectation',
      );
      expect(find.text('Current'), findsNothing);
    },
  );

  testWidgets(
    'a holding the live fetch cannot reach also stays at cost',
    (tester) async {
      // A bare, recognised currency code — but `testServices` wires a
      // network that refuses every call, the same as a phone with no
      // connection. The row must fall back to cost rather than break.
      await services.assets.insertAsset(
        assetName: 'Dolar',
        assetCode: 'USD',
        assetType: 'Döviz',
        purchasePrice: '37.80',
        quantity: 400,
      );

      await pump(tester);

      expect(find.text('Cost'), findsOneWidget);
      expect(find.text('Current'), findsNothing);
    },
  );

  testWidgets(
    'a live-priced holding shows Current, not Cost, with its own gain and age',
    (tester) async {
      final live = testServices(db, httpGet: _fakeLiveGet);
      await live.assets.insertAsset(
        assetName: 'Bitcoin',
        assetCode: 'BTC',
        assetType: 'Kripto',
        purchasePrice: '1000000',
        quantity: '1',
      );

      await pumpScreen(tester, live, const AssetsScreen());

      expect(find.text('Current'), findsOneWidget);
      // No standalone 'Cost' tile label: the only holding is live-priced.
      // The TOTAL card above it still reads 'Holdings at Cost' — a
      // different string, on purpose, since it always sums at cost — so
      // this checks the bare word is not ALSO sitting on the tile.
      expect(find.text('Cost'), findsNothing);
      expect(find.text('Holdings at Cost'), findsOneWidget);
      // The tile's own gain line: a live price this far above the purchase
      // price is a profit, so it carries a leading '+'.
      expect(find.textContaining('+'), findsWidgets);
      expect(find.textContaining('just now'), findsOneWidget);
    },
  );

  testWidgets('no holdings says so', (tester) async {
    await pump(tester);
    expect(find.textContaining('No holdings yet'), findsOneWidget);
    expect(find.text('Nothing bought yet'), findsOneWidget);
  });

  testWidgets('savings goals come from the savings service', (tester) async {
    final accountId = await cashAccount();
    final goalId = await services.savings.createGoal(
      goalName: 'Acil Durum Fonu',
      targetAmount: 350000,
    );
    await services.savings.depositToGoal(
      goalId: goalId,
      amount: 260000,
      accountId: accountId,
    );

    await pump(tester);

    expect(find.text('Acil Durum Fonu'), findsOneWidget);
    expect(find.text('260.000,00 ₺'), findsOneWidget);
    expect(find.text('350.000,00 ₺'), findsOneWidget);
    expect(find.text('%74,29'), findsOneWidget);
  });

  testWidgets('every goal is shown, not just the first', (tester) async {
    // The mockup hard-codes one "Emergency Fund"; the model has however many
    // the user opened.
    await services.savings.createGoal(goalName: 'Tatil', targetAmount: 20000);
    await services.savings.createGoal(goalName: 'Araba', targetAmount: 500000);

    await pump(tester);

    expect(find.text('Tatil'), findsOneWidget);
    expect(find.text('Araba'), findsOneWidget);
  });

  testWidgets('a goal whose name will not decrypt says so', (tester) async {
    await services.savings.createGoal(goalName: 'Tatil', targetAmount: 20000);
    await db.customUpdate(
      "UPDATE savings_goals SET goal_name = 'AEADv1:broken'",
      updates: const {},
    );

    await pump(tester);

    expect(find.text('Unreadable goal'), findsOneWidget);
    expect(find.text('Tatil'), findsNothing);
  });

  testWidgets('an unreadable amount fails the page rather than skewing it', (
    tester,
  ) async {
    // A slice quietly missing from a pie is a wrong picture presented as a
    // right one, so the period query raises and the page says so.
    final accountId = await cashAccount();
    await db.customInsert(
      'INSERT INTO transactions (account_id, amount, type, category, '
      "description, transaction_date, status) "
      "VALUES (?, 'AEADv1:broken', 'expense', 'Test', 'x', ?, 'completed')",
      variables: [
        Variable<int>(accountId),
        Variable<String>(
          '${DateTime.now().toIso8601String().substring(0, 10)} 12:00:00',
        ),
      ],
    );

    await pump(tester);

    expect(find.text('This could not be read'), findsOneWidget);
  });

  testWidgets('the trend says so when there is nothing to plot', (
    tester,
  ) async {
    await pump(tester);
    expect(find.textContaining('no trend to draw'), findsOneWidget);
  });
}
