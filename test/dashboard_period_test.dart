/// Differential tests against the desktop's `dashboard_period_service.py`,
/// plus the ledger slice the chip reads its baseline from.
///
/// The period half is vector-driven: `tool/emit_period_vectors.py` CALLS the
/// desktop module, which is pure and takes its balance reader as an argument.
/// The ledger half is not — `history_service.get_balance_at` needs a database
/// — so that is tested against a ledger this suite builds, and the reduction
/// it makes against the desktop is stated in `balance_history.dart`.
library;

import 'dart:io';

import 'package:archlence_mobile/crypto/field_crypto.dart';
import 'package:archlence_mobile/data/database.dart';
import 'package:archlence_mobile/money/financial_decimal.dart';
import 'package:archlence_mobile/services/account_service.dart';
import 'package:archlence_mobile/services/balance_history.dart';
import 'package:archlence_mobile/services/dashboard_period.dart';
import 'package:archlence_mobile/services/transaction_service.dart';
import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';

import 'support/fixed_key_provider.dart';

List<List<String>> _vectors(String kind) => [
  for (final line in File('test/period_vectors.txt').readAsLinesSync())
    if (line.startsWith('$kind|')) line.split('|').sublist(1),
];

DashboardPeriod _period(String name) => switch (name) {
  'today' => DashboardPeriod.today,
  'week' => DashboardPeriod.week,
  'month' => DashboardPeriod.month,
  'year' => DashboardPeriod.year,
  _ => DashboardPeriod.allTime,
};

String _day(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

void main() {
  group('the windows the desktop draws', () {
    final cases = _vectors('BOUNDS');

    test('the fixture covers every period, including the unbounded one', () {
      expect(cases, hasLength(DashboardPeriod.values.length));
      expect(cases.any((c) => c[2].isEmpty), isTrue, reason: 'allTime');
    });

    test('every window matches', () {
      for (final row in cases) {
        final today = DateTime.parse(row[1]);
        final (start, end) = periodBounds(_period(row[0]), today);
        expect(
          start == null ? '' : _day(start),
          row[2],
          reason: '${row[0]} start',
        );
        expect(_day(end), row[3], reason: '${row[0]} end');
      }
    });

    test('a period of one day starts and ends on the same day', () {
      // The inclusive arithmetic: `today` covers one day, not zero and not
      // two, and `end - (days - 1)` is what makes that true.
      final (start, end) = periodBounds(
        DashboardPeriod.today,
        DateTime(2026, 8, 27),
      );
      expect(start, end);
    });
  });

  group('the percentage rules', () {
    final cases = _vectors('PERCENT');

    test('the fixture carries both zero rules and a negative baseline', () {
      expect(cases.any((c) => c[0] == '0' && c[1] == '0'), isTrue);
      expect(cases.any((c) => c[0] == '0' && c[1] != '0'), isTrue);
      expect(cases.any((c) => c[0].startsWith('-')), isTrue);
    });

    test('every case answers what the desktop answered', () {
      for (final row in cases) {
        final starting = row[0].isEmpty ? null : fiat(row[0]);
        final result = percentageChange(starting, fiat(row[1]));
        final where = '${row[0]} -> ${row[1]}';

        if (row[2].isEmpty) {
          expect(result, isNull, reason: where);
          continue;
        }
        expect(result, isNotNull, reason: where);
        // Compared at the app's percent precision, not bit for bit: the
        // desktop's figure is a float and this side is a Decimal, so the
        // agreement that matters is the one the screen shows.
        expect(
          result,
          percentage(double.parse(row[2])),
          reason: where,
        );
      }
    });

    test('a move off zero has no percentage, and is not called zero', () {
      // The trap: "no finite answer" and "no change" are different, and
      // returning 0% for the first would tell a user nothing happened when
      // their balance went from nothing to 500.
      expect(percentageChange(Decimal.zero, fiat(500)), isNull);
      expect(percentageChange(Decimal.zero, Decimal.zero), Decimal.zero);
    });
  });

  group('the change over a period', () {
    final cases = _vectors('CHANGE');

    test('the fixture includes an unanswerable baseline', () {
      expect(cases.any((c) => c[2].isEmpty), isTrue);
    });

    test('every case matches the desktop', () async {
      for (final row in cases) {
        final starting = row[2].isEmpty ? null : fiat(row[2]);
        final change = await calculateBalanceChange(
          period: _period(row[0]),
          currentBalance: fiat(row[3]),
          today: DateTime.parse(row[1]),
          readBalanceAt: (_) async => starting,
        );
        final where = '${row[0]} ${row[2]} -> ${row[3]}';

        expect(
          change.baselineDate == null ? '' : _day(change.baselineDate!),
          row[4],
          reason: '$where baseline',
        );
        expect(
          change.nominal == null ? '' : change.nominal.toString(),
          row[5].isEmpty ? '' : fiat(row[5]).toString(),
          reason: '$where nominal',
        );
        if (row[6].isEmpty) {
          expect(change.percent, isNull, reason: '$where percent');
        } else {
          expect(
            change.percent,
            percentage(double.parse(row[6])),
            reason: '$where percent',
          );
        }
      }
    });

    test('an unknown baseline leaves nothing to draw', () async {
      final change = await calculateBalanceChange(
        period: DashboardPeriod.month,
        currentBalance: fiat(1250),
        today: DateTime(2026, 8, 27),
        readBalanceAt: (_) async => null,
      );
      expect(change.isKnown, isFalse);
      expect(change.nominal, isNull);
      expect(change.percent, isNull);
    });

    test('the whole history reports the balance, with no percentage', () async {
      final change = await calculateBalanceChange(
        period: DashboardPeriod.allTime,
        currentBalance: fiat(1250),
        today: DateTime(2026, 8, 27),
        readBalanceAt: (_) async => fiat(1000),
      );
      expect(change.nominal, fiat(1250));
      expect(change.percent, isNull);
      expect(change.baselineDate, isNull);
    });
  });

  group('the baseline, off a real ledger', () {
    late ArchlenceDatabase db;
    late AccountService accounts;
    late TransactionService transactions;
    late BalanceHistoryService history;

    setUp(() {
      db = ArchlenceDatabase.memory();
      final crypto = FieldCrypto(FixedKeyProvider.arbitrary());
      accounts = AccountService(db, crypto);
      transactions = TransactionService(db, crypto, accounts);
      history = BalanceHistoryService(db);
    });

    tearDown(() => db.close());

    /// Backdates every event written so far, so a test can place the ledger
    /// in the past without waiting.
    Future<void> backdateEvents(String timestamp) => db.customUpdate(
      'UPDATE balance_events SET ts = ?',
      variables: [Variable<String>(timestamp)],
      updates: const {},
    );

    test('an empty ledger cannot answer, and does not say zero', () async {
      // The rule that matters most here: "I do not know" and "you had
      // nothing" are different answers.
      expect(await history.ledgerStartDate(), isNull);
      expect(await history.totalAt(DateTime(2026, 8, 1)), isNull);
    });

    test('a date before the ledger begins cannot be answered', () async {
      await accounts.createAccount(
        name: 'Nakit',
        accountType: AccountType.checking,
        initialBalance: 1000,
      );
      await backdateEvents('2026-08-10 09:00:00');

      expect(await history.ledgerStartDate(), '2026-08-10');
      expect(await history.totalAt(DateTime(2026, 8, 9)), isNull);
      expect(await history.totalAt(DateTime(2026, 8, 10)), fiat(1000));
    });

    test('the balance at a day excludes what happened after it', () async {
      final id = await accounts.createAccount(
        name: 'Nakit',
        accountType: AccountType.checking,
        initialBalance: 1000,
      );
      await backdateEvents('2026-08-10 09:00:00');

      await transactions.addTransaction(
        accountId: id,
        amount: 250,
        transactionType: 'expense',
        category: 'Market',
      );
      await db.customUpdate(
        "UPDATE balance_events SET ts = '2026-08-20 12:00:00' "
        "WHERE ts <> '2026-08-10 09:00:00'",
        updates: const {},
      );

      expect(await history.totalAt(DateTime(2026, 8, 10)), fiat(1000));
      expect(await history.totalAt(DateTime(2026, 8, 19)), fiat(1000));
      // The whole of the 20th is included, not up to its start.
      expect(await history.totalAt(DateTime(2026, 8, 20)), fiat(750));
      expect(await history.totalAt(DateTime(2026, 8, 21)), fiat(750));
    });

    test('a card debt pulls the total down, under the same convention', () async {
      await accounts.createAccount(
        name: 'Nakit',
        accountType: AccountType.checking,
        initialBalance: 5000,
      );
      await backdateEvents('2026-08-10 09:00:00');
      await accounts.createAccount(
        name: 'Kart',
        accountType: AccountType.creditCard,
        initialBalance: 2000,
        creditLimit: 20000,
      );
      await db.customUpdate(
        "UPDATE balance_events SET ts = '2026-08-15 09:00:00' "
        "WHERE ts <> '2026-08-10 09:00:00'",
        updates: const {},
      );

      // Net worth is `SUM(accounts.balance)` under the app's sign convention,
      // and the ledger's deltas follow it — so the history agrees with the
      // figure the ring shows rather than telling a second story.
      final worth = await accounts.getNetWorth();
      expect(await history.totalAt(DateTime(2026, 8, 20)), worth.net);
      expect(await history.totalAt(DateTime(2026, 8, 10)), fiat(5000));
    });

    test('the chip reads a real change end to end', () async {
      final id = await accounts.createAccount(
        name: 'Nakit',
        accountType: AccountType.checking,
        initialBalance: 1000,
      );
      final today = DateTime.now();
      await backdateEvents(
        '${_day(today.subtract(const Duration(days: 40)))} 09:00:00',
      );
      await transactions.addTransaction(
        accountId: id,
        amount: 250,
        transactionType: 'income',
        category: 'Maaş',
      );

      final worth = await accounts.getNetWorth();
      final change = await balanceChangeFor(
        history,
        period: DashboardPeriod.month,
        currentBalance: worth.net,
        today: today,
      );

      expect(change.isKnown, isTrue);
      expect(change.nominal, fiat(250));
      expect(change.percent, percentage(25));
    });
  });
}
