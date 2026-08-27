/// The calendar screen: the grid, the day it opens, and what it refuses to
/// invent.
library;

import 'package:archlence_mobile/app_services.dart';
import 'package:archlence_mobile/data/database.dart';
import 'package:archlence_mobile/screens/calendar_screen.dart';
import 'package:archlence_mobile/services/account_service.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_app.dart';

void main() {
  late ArchlenceDatabase db;
  late AppServices services;
  late int accountId;

  /// Days inside the CURRENT month, so the screen opens on them without any
  /// paging. A fixed date would fall out of view the moment the month rolls
  /// over, and a test that only passes in some months is worse than none.
  final now = DateTime.now();
  DateTime dayInThisMonth(int day) => DateTime(now.year, now.month, day, 10);

  setUp(() async {
    db = ArchlenceDatabase.memory();
    services = testServices(db);
    accountId = await services.accounts.createAccount(
      name: 'Nakit',
      accountType: AccountType.checking,
      initialBalance: 100000,
    );
  });

  tearDown(() => db.close());

  Future<void> record({
    required DateTime when,
    Object amount = 250,
    String type = 'expense',
    String category = 'Market',
    String description = '',
  }) => services.transactions.addTransaction(
    accountId: accountId,
    amount: amount,
    transactionType: type,
    category: category,
    description: description,
    transactionDate: when,
  );

  Future<void> pump(WidgetTester tester) async {
    await pumpScreen(tester, services, const CalendarScreen());
    await tester.pumpAndSettle();
  }

  testWidgets('the month it opens on is this one', (tester) async {
    await pump(tester);
    expect(find.textContaining('${now.year}'), findsOneWidget);
  });

  testWidgets('a day with nothing recorded carries no dot', (tester) async {
    await record(when: dayInThisMonth(1));
    await pump(tester);

    // One transaction, one marked day — so exactly one dot on the grid.
    // `findsNWidgets(1)` rather than `findsWidgets`: a grid that marked every
    // day would pass the looser matcher.
    expect(_dots(tester), 1);
  });

  testWidgets('two days with activity carry two dots', (tester) async {
    await record(when: dayInThisMonth(1));
    await record(when: dayInThisMonth(2));
    await record(when: dayInThisMonth(2));
    await pump(tester);

    // Two DAYS, three transactions: the grid marks days, not rows.
    expect(_dots(tester), 2);
  });

  testWidgets('tapping a day lists what happened on it', (tester) async {
    await record(
      when: dayInThisMonth(4).copyWith(hour: 9, minute: 5),
      category: 'Ulaşım',
      description: 'Metro',
    );
    await record(
      when: dayInThisMonth(4).copyWith(hour: 18, minute: 30),
      category: 'Market',
    );
    await pump(tester);

    await tester.tap(find.text('4'));
    await tester.pumpAndSettle();

    expect(find.text('09:05'), findsOneWidget);
    expect(find.text('18:30'), findsOneWidget);
    expect(find.text('Ulaşım'), findsOneWidget);
    expect(find.text('Metro'), findsOneWidget);
    expect(find.text('2 transactions'), findsOneWidget);
  });

  testWidgets('income and expense are signed differently', (tester) async {
    await record(
      when: dayInThisMonth(5),
      amount: 1000,
      type: 'income',
      category: 'Maaş',
    );
    await record(when: dayInThisMonth(5), amount: 250, category: 'Market');
    await pump(tester);

    await tester.tap(find.text('5'));
    await tester.pumpAndSettle();

    expect(find.text('+1.000,00 ₺'), findsOneWidget);
    expect(find.text('−250,00 ₺'), findsOneWidget);
  });

  testWidgets('a day with nothing on it says so rather than doing nothing', (
    tester,
  ) async {
    await record(when: dayInThisMonth(4));
    await pump(tester);

    // An unmarked day is still tappable: "was there anything on the 6th" is a
    // real question, and a dead cell would leave it unanswered.
    await tester.tap(find.text('6'));
    await tester.pumpAndSettle();

    expect(find.text('Nothing on this day.'), findsOneWidget);
  });

  testWidgets('an empty month says so instead of an unexplained blank grid', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Nothing recorded this month.'), findsOneWidget);
  });

  testWidgets('a month with data asks the user to pick a day', (tester) async {
    await record(when: dayInThisMonth(4));
    await pump(tester);
    expect(find.textContaining('Pick a marked day'), findsOneWidget);
  });

  testWidgets('an unreadable amount is named, not drawn as zero', (
    tester,
  ) async {
    await record(when: dayInThisMonth(7), amount: 500, category: 'Market');
    await db.customUpdate(
      'UPDATE transactions SET amount = ?',
      variables: [Variable<String>('AEADv1:not-an-envelope')],
      updates: const {},
    );
    await pump(tester);

    await tester.tap(find.text('7'));
    await tester.pumpAndSettle();

    expect(find.text('This amount cannot be read'), findsOneWidget);
    // The row is still there — something happened — and no figure is invented.
    expect(find.text('Market'), findsOneWidget);
    expect(find.text('−0,00 ₺'), findsNothing);
    expect(find.text('0,00 ₺'), findsNothing);
  });

  testWidgets('paging past the current month is not offered', (tester) async {
    await pump(tester);
    final next = tester.widget<IconButton>(
      find.ancestor(
        of: find.byIcon(Icons.chevron_right),
        matching: find.byType(IconButton),
      ),
    );
    // A future month can only hold pending rows, which the grid does not
    // mark, so every one of them is empty by construction.
    expect(next.onPressed, isNull);
  });

  testWidgets('paging back changes the month and drops the selection', (
    tester,
  ) async {
    await record(when: dayInThisMonth(4));
    await pump(tester);
    await tester.tap(find.text('4'));
    await tester.pumpAndSettle();
    expect(find.text('1 transaction'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();

    // Carrying a day across a month boundary could open one that does not
    // exist there — the 31st of a 30-day month.
    expect(find.text('1 transaction'), findsNothing);
    expect(find.text('Nothing recorded this month.'), findsOneWidget);
  });
}

/// How many day cells carry an activity dot.
///
/// The dot is the only 5x5 circle on the screen, and counting the containers
/// is the only way to assert it is DRAWN — the same lesson the split bar
/// taught, where a widget was in the tree at zero height and every
/// text-based assertion passed.
int _dots(WidgetTester tester) {
  var count = 0;
  for (final container in tester.widgetList<Container>(
    find.byType(Container),
  )) {
    final decoration = container.decoration;
    if (decoration is! BoxDecoration) continue;
    if (decoration.shape != BoxShape.circle) continue;
    final size = tester.getSize(find.byWidget(container));
    if (size.width == 5 && size.height == 5) count++;
  }
  return count;
}
