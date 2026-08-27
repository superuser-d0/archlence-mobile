/// The calendar's two queries: which days are marked, and what a day holds.
library;

import 'package:archlence_mobile/crypto/field_crypto.dart';
import 'package:archlence_mobile/crypto/key_provider.dart';
import 'package:archlence_mobile/data/database.dart';
import 'package:archlence_mobile/money/financial_decimal.dart';
import 'package:archlence_mobile/services/account_service.dart';
import 'package:archlence_mobile/services/calendar_service.dart';
import 'package:archlence_mobile/services/transaction_service.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';

import 'support/fixed_key_provider.dart';

void main() {
  late ArchlenceDatabase db;
  late FieldCrypto crypto;
  late AccountService accounts;
  late TransactionService transactions;
  late CalendarService calendar;
  late int accountId;

  setUp(() async {
    db = ArchlenceDatabase.memory();
    crypto = FieldCrypto(FixedKeyProvider.arbitrary());
    accounts = AccountService(db, crypto);
    transactions = TransactionService(db, crypto, accounts);
    calendar = CalendarService(db, crypto);
    accountId = await accounts.createAccount(
      name: 'Nakit',
      accountType: AccountType.checking,
      initialBalance: 100000,
    );
  });

  tearDown(() => db.close());

  /// Records a completed transaction on a fixed past date.
  ///
  /// A PAST date on purpose: a future-dated row is written `pending` and does
  /// not belong on the calendar until it settles, which is asserted on its
  /// own below.
  Future<void> record({
    required DateTime when,
    Object amount = 100,
    String type = 'expense',
    String category = 'Market',
    String description = '',
  }) => transactions.addTransaction(
    accountId: accountId,
    amount: amount,
    transactionType: type,
    category: category,
    description: description,
    transactionDate: when,
  );

  group('the month grid', () {
    test('counts each day that has something on it', () async {
      await record(when: DateTime(2026, 3, 4, 9, 0));
      await record(when: DateTime(2026, 3, 4, 18, 30));
      await record(when: DateTime(2026, 3, 17, 12, 0));

      expect(await calendar.getMonthTransactionDays(2026, 3), {4: 2, 17: 1});
    });

    test('a month with nothing in it is empty, not a map of zeroes', () async {
      await record(when: DateTime(2026, 3, 4));
      expect(await calendar.getMonthTransactionDays(2026, 4), isEmpty);
    });

    test('a neighbouring month does not leak in', () async {
      // The boundary the `strftime('%Y-%m')` filter exists for: without it a
      // naive BETWEEN on dates is easy to get wrong by a day at each end.
      await record(when: DateTime(2026, 2, 28, 23, 59));
      await record(when: DateTime(2026, 3, 1, 0, 1));
      await record(when: DateTime(2026, 3, 31, 23, 59));
      await record(when: DateTime(2026, 4, 1, 0, 1));

      expect(await calendar.getMonthTransactionDays(2026, 3), {1: 1, 31: 1});
    });

    test('a single-digit month is not read as a different one', () async {
      // '2026-3' would match nothing; the padding is what makes it '2026-03'.
      await record(when: DateTime(2026, 3, 9));
      expect(await calendar.getMonthTransactionDays(2026, 3), {9: 1});
    });

    test('a pending row is not marked until it settles', () async {
      // Money does not appear before its date, and neither does its mark.
      final future = DateTime.now().add(const Duration(days: 3));
      await record(when: future);

      expect(
        await calendar.getMonthTransactionDays(future.year, future.month),
        isEmpty,
      );

      await transactions.settleDueTransactions();
      // Still pending: the day has not arrived.
      expect(
        await calendar.getMonthTransactionDays(future.year, future.month),
        isEmpty,
      );
    });

    test('a row the desktop wrote with no status still counts', () async {
      // `COALESCE(status, 'completed')`: rows written before the column
      // existed carry NULL and are, by definition, completed.
      await record(when: DateTime(2026, 5, 6));
      await db.customUpdate(
        'UPDATE transactions SET status = NULL',
        updates: const {},
      );
      expect(await calendar.getMonthTransactionDays(2026, 5), {6: 1});
    });
  });

  group('a day', () {
    test('lists its transactions earliest first, with the time', () async {
      await record(when: DateTime(2026, 3, 4, 18, 30), category: 'Market');
      await record(when: DateTime(2026, 3, 4, 9, 5), category: 'Ulaşım');

      final entries = await calendar.getDayTransactions(DateTime(2026, 3, 4));
      expect([for (final e in entries) e.time], ['09:05', '18:30']);
      expect([for (final e in entries) e.category], ['Ulaşım', 'Market']);
    });

    test('carries the amount, the type and the description', () async {
      await record(
        when: DateTime(2026, 3, 4, 10, 0),
        amount: '249.90',
        type: 'income',
        category: 'Maaş',
        description: 'Mart maaşı',
      );

      final entry = (await calendar.getDayTransactions(
        DateTime(2026, 3, 4),
      )).single;
      expect(entry.amount, fiat('249.90'));
      expect(entry.isIncome, isTrue);
      expect(entry.isExpense, isFalse);
      expect(entry.description, 'Mart maaşı');
      expect(entry.isCorrupt, isFalse);
    });

    test('the time of day in the argument is ignored', () async {
      await record(when: DateTime(2026, 3, 4, 9, 0));
      expect(
        await calendar.getDayTransactions(DateTime(2026, 3, 4, 23, 59)),
        hasLength(1),
      );
    });

    test('an uncategorised row is filed under Diğer, not left nameless', () async {
      await record(when: DateTime(2026, 3, 4), category: '');
      final entry = (await calendar.getDayTransactions(
        DateTime(2026, 3, 4),
      )).single;
      expect(entry.category, 'Diğer');
    });

    test('a day with nothing on it is empty', () async {
      await record(when: DateTime(2026, 3, 4));
      expect(await calendar.getDayTransactions(DateTime(2026, 3, 5)), isEmpty);
    });

    test('an unreadable amount is REPORTED, never shown as zero', () async {
      // The one place this port deliberately departs from the desktop, which
      // substitutes 0.0 and logs. A day listing a real expense as ₺0,00 is a
      // wrong number presented as a right one.
      await record(when: DateTime(2026, 3, 4), amount: 500);
      await db.customUpdate(
        'UPDATE transactions SET amount = ?',
        variables: [Variable<String>('AEADv1:not-an-envelope')],
        updates: const {},
      );

      final entry = (await calendar.getDayTransactions(
        DateTime(2026, 3, 4),
      )).single;
      expect(entry.amount, isNull);
      expect(entry.isCorrupt, isTrue);
      // Still listed: dropping it would hide that anything happened at all.
      expect(entry.category, 'Market');
    });

    test('an unreadable description does not take the amount with it', () async {
      await record(
        when: DateTime(2026, 3, 4),
        amount: 500,
        description: 'okunacak',
      );
      await db.customUpdate(
        'UPDATE transactions SET description = ?',
        variables: [Variable<String>('AEADv1:not-an-envelope')],
        updates: const {},
      );

      final entry = (await calendar.getDayTransactions(
        DateTime(2026, 3, 4),
      )).single;
      expect(entry.amount, fiat(500));
      expect(entry.description, '');
      expect(entry.isCorrupt, isTrue);
    });

    test('a missing key stops the day rather than emptying it', () async {
      await record(when: DateTime(2026, 3, 4));
      final locked = CalendarService(
        db,
        FieldCrypto(UnavailableKeyProvider()),
      );
      expect(
        () => locked.getDayTransactions(DateTime(2026, 3, 4)),
        throwsA(isA<KeyUnavailableError>()),
      );
    });

    test('the grid needs no key at all', () async {
      // Nothing in the month query is encrypted, so a locked profile still
      // knows WHICH days had activity — it just cannot say what happened.
      await record(when: DateTime(2026, 3, 4));
      final locked = CalendarService(
        db,
        FieldCrypto(UnavailableKeyProvider()),
      );
      expect(await locked.getMonthTransactionDays(2026, 3), {4: 1});
    });
  });
}
