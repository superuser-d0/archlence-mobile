/// The ledger's rules, ported from the desktop's `test_add_transaction.py`,
/// `test_pending_transactions.py` and the transaction-dependent half of
/// `test_account_service.py`.
///
/// The acceptance scenario the user originally asked the desktop for is here:
/// a card with a 10,000 limit, a 500 supermarket spend, and net worth falling
/// by exactly 500.
library;

import 'package:archlence_mobile/crypto/field_crypto.dart';
import 'package:archlence_mobile/data/database.dart';
import 'package:archlence_mobile/money/financial_decimal.dart';
import 'package:archlence_mobile/services/account_service.dart';
import 'package:archlence_mobile/services/transaction_service.dart';
import 'package:decimal/decimal.dart';
// Only the variable binder: drift also exports `isNull`/`isNotNull` as SQL
// expression builders, which would shadow the matchers of the same name.
import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';

import 'support/fixed_key_provider.dart';

void main() {
  late ArchlenceDatabase db;
  late FieldCrypto crypto;
  late AccountService accounts;
  late TransactionService ledger;

  setUp(() {
    db = ArchlenceDatabase.memory();
    crypto = FieldCrypto(FixedKeyProvider.arbitrary());
    accounts = AccountService(db, crypto);
    ledger = TransactionService(db, crypto, accounts);
  });

  tearDown(() => db.close());

  Decimal money(String value) => fiat(value);

  DateTime dayOffset(int days) => DateTime.now().add(Duration(days: days));

  Future<int> count(String table) async {
    final row = await db
        .customSelect('SELECT COUNT(*) AS n FROM $table')
        .getSingle();
    return row.read<int>('n');
  }

  Future<List<String>> statuses() async {
    final rows = await db
        .customSelect('SELECT status FROM transactions ORDER BY id')
        .get();
    return [for (final row in rows) row.read<String>('status')];
  }

  Future<Decimal> balanceOf(int accountId) async =>
      (await accounts.getAccount(accountId))!.balance;

  Future<int> newChecking({Object? balance = 10000}) => accounts.createAccount(
    name: 'Vadesiz',
    accountType: AccountType.checking,
    initialBalance: balance,
  );

  Future<int> newCard({Object? debt = 0, Object? limit = 10000}) =>
      accounts.createAccount(
        name: 'Bonus Kart',
        accountType: AccountType.creditCard,
        initialBalance: debt,
        creditLimit: limit,
      );

  group('adding a transaction', () {
    test(
      'a spend today is completed and leaves the balance immediately',
      () async {
        final id = await newChecking();
        await ledger.addTransaction(
          accountId: id,
          amount: 300,
          transactionType: 'expense',
          category: 'Süpermarket',
          description: 'Market',
        );

        expect(await statuses(), ['completed']);
        expect(await balanceOf(id), money('9700'));
      },
    );

    test('a back-dated spend takes the same path', () async {
      final id = await newChecking();
      await ledger.addTransaction(
        accountId: id,
        amount: 750,
        transactionType: 'expense',
        transactionDate: dayOffset(-4),
      );

      expect(await statuses(), ['completed']);
      expect(await balanceOf(id), money('9250'));
    });

    test('income raises the balance', () async {
      final id = await newChecking();
      await ledger.addTransaction(
        accountId: id,
        amount: 1200,
        transactionType: 'income',
        category: 'Maaş',
      );
      expect(await balanceOf(id), money('11200'));
    });

    test('a future-dated transaction is pending and moves nothing', () async {
      final id = await newChecking();
      await ledger.addTransaction(
        accountId: id,
        amount: 500,
        transactionType: 'expense',
        transactionDate: dayOffset(3),
      );

      expect(await statuses(), ['pending']);
      expect(await balanceOf(id), money('10000'));
      expect(await count('balance_events'), 1, reason: 'only the opening one');
    });

    test('a transaction entered late in the day is still today\'s', () async {
      // The comparison is by DAY. A row entered at 23:00 for today must post
      // now, not wait for a settlement round that would never come.
      final id = await newChecking();
      final now = DateTime.now();
      await ledger.addTransaction(
        accountId: id,
        amount: 100,
        transactionType: 'expense',
        transactionDate: DateTime(now.year, now.month, now.day, 23, 59, 59),
      );
      expect(await statuses(), ['completed']);
    });

    test('the date is always written as a full timestamp', () async {
      // A date-only value broke the desktop's time chart. Taking a DateTime
      // rather than a string is what makes this structural.
      final id = await newChecking();
      await ledger.addTransaction(
        accountId: id,
        amount: 10,
        transactionType: 'expense',
        transactionDate: DateTime(2026, 3, 7, 14, 5, 9),
      );
      final row = await db
          .customSelect('SELECT * FROM transactions')
          .getSingle();
      expect(row.read<String>('transaction_date'), '2026-03-07 14:05:09');
      expect(row.read<String>('execution_date'), '2026-03-07 14:05:09');
    });

    test('the amount and description are stored encrypted', () async {
      final id = await newChecking();
      await ledger.addTransaction(
        accountId: id,
        amount: 42.5,
        transactionType: 'expense',
        category: 'Süpermarket',
        description: 'Market alışverişi',
      );

      final row = await db
          .customSelect('SELECT * FROM transactions')
          .getSingle();
      expect(FieldCrypto.isEncrypted(row.read<String>('amount')), isTrue);
      expect(FieldCrypto.isEncrypted(row.read<String>('description')), isTrue);
      // The category is deliberately NOT encrypted: the desktop groups and
      // reports on it in SQL.
      expect(row.read<String>('category'), 'Süpermarket');
      expect(await crypto.decryptField(row.read<String>('amount')), '42.5');
    });

    test('rejects an amount of zero or less', () async {
      final id = await newChecking();
      for (final amount in [0, -1, '-0.01']) {
        await expectLater(
          () => ledger.addTransaction(
            accountId: id,
            amount: amount,
            transactionType: 'expense',
          ),
          throwsA(
            isA<TransactionError>().having(
              (e) => e.code,
              'code',
              TransactionErrorCode.amountNotPositive,
            ),
          ),
        );
      }
      expect(await count('transactions'), 0);
      expect(await balanceOf(id), money('10000'));
    });

    test('rejects a non-finite amount before any write', () async {
      final id = await newChecking();
      for (final amount in [double.nan, double.infinity, 'not a number']) {
        await expectLater(
          () => ledger.addTransaction(
            accountId: id,
            amount: amount,
            transactionType: 'expense',
          ),
          throwsA(
            isA<TransactionError>().having(
              (e) => e.code,
              'code',
              TransactionErrorCode.invalidAmount,
            ),
          ),
        );
      }
      expect(await count('transactions'), 0);
      expect(await balanceOf(id), money('10000'));
    });

    test('an unknown account is refused and writes nothing', () async {
      await expectLater(
        () => ledger.addTransaction(
          accountId: 404,
          amount: 100,
          transactionType: 'expense',
        ),
        throwsA(
          isA<AccountError>().having(
            (e) => e.code,
            'code',
            AccountErrorCode.accountNotFound,
          ),
        ),
      );
      expect(await count('transactions'), 0);
    });

    test('a frozen account takes nothing', () async {
      final id = await newCard(debt: 100);
      await accounts.setCardFrozen(id, true);
      await expectLater(
        () => ledger.addTransaction(
          accountId: id,
          amount: 50,
          transactionType: 'expense',
        ),
        throwsA(
          isA<AccountError>().having(
            (e) => e.code,
            'code',
            AccountErrorCode.cardFrozen,
          ),
        ),
      );
      expect(await count('transactions'), 0);
      expect((await accounts.getAccount(id))!.debt, money('100'));
    });
  });

  group('the credit-card scenario', () {
    test('a card spend lowers net worth by exactly its amount', () async {
      // The acceptance scenario: a 10,000-limit card, a 500 supermarket
      // spend, net worth down 500 and cash untouched.
      await newChecking(balance: 17300);
      final before = await accounts.getNetWorth();

      final cardId = await newCard(limit: 10000);

      final afterOpening = await accounts.getNetWorth();
      expect(
        afterOpening.net,
        before.net,
        reason: 'opening a card owes nothing',
      );
      expect(
        (await accounts.getAccount(cardId))!.availableLimit,
        money('10000'),
      );

      await ledger.addTransaction(
        accountId: cardId,
        amount: 500,
        transactionType: 'expense',
        category: 'Süpermarket',
        description: 'Market alışverişi',
      );

      final card = (await accounts.getAccount(cardId))!;
      expect(
        card.debt,
        money('500'),
        reason: 'a card spend must GROW the debt',
      );
      expect(card.availableLimit, money('9500'));

      final after = await accounts.getNetWorth();
      expect(after.cardDebt, before.cardDebt + money('500'));
      expect(
        after.cash,
        before.cash,
        reason: 'a card spend must not touch cash',
      );
      expect(after.net, before.net - money('500'));
    });

    test('income on a card pays the debt down and raises net worth', () async {
      final cardId = await newCard(debt: 2000);
      final netBefore = (await accounts.getNetWorth()).net;

      await ledger.addTransaction(
        accountId: cardId,
        amount: 800,
        transactionType: 'income',
        category: 'Borç Ödeme',
      );

      expect((await accounts.getAccount(cardId))!.debt, money('1200'));
      expect((await accounts.getNetWorth()).net, netBefore + money('800'));
    });

    test('net worth stays equal to the plain sum of balances', () async {
      final checkingId = await newChecking(balance: 4000);
      final cardId = await newCard(debt: 1200);
      await ledger.addTransaction(
        accountId: cardId,
        amount: 300,
        transactionType: 'expense',
      );
      await ledger.addTransaction(
        accountId: checkingId,
        amount: 150,
        transactionType: 'expense',
      );

      final row = await db
          .customSelect('SELECT SUM(balance) AS total FROM accounts')
          .getSingle();
      expect(
        (await accounts.getNetWorth()).net,
        fiat(row.read<double>('total')),
      );
    });

    test('a spend past the limit is refused and writes nothing', () async {
      final cardId = await newCard(debt: 900, limit: 1000);
      await expectLater(
        () => ledger.addTransaction(
          accountId: cardId,
          amount: 250,
          transactionType: 'expense',
        ),
        throwsA(
          isA<AccountError>().having(
            (e) => e.code,
            'code',
            AccountErrorCode.insufficientLimit,
          ),
        ),
      );
      expect((await accounts.getAccount(cardId))!.debt, money('900'));
      expect(await count('transactions'), 0);
    });

    test('an import may exceed the limit', () async {
      // A past spend that filled the limit is a fact. Refusing it would make
      // the reconstruction wrong, not safe.
      final cardId = await newCard(debt: 900, limit: 1000);
      await ledger.addTransaction(
        accountId: cardId,
        amount: 250,
        transactionType: 'expense',
        enforceCreditLimit: false,
      );
      expect((await accounts.getAccount(cardId))!.debt, money('1150'));
    });
  });

  group('instalment plans', () {
    test(
      'the whole amount is charged at once and the plan is written',
      () async {
        // The bank blocks the full amount against the limit, so the card is
        // charged in full; the monthly plan rides in the same commit.
        final cardId = await newCard(limit: 10000);
        await ledger.addTransaction(
          accountId: cardId,
          amount: 1200,
          transactionType: 'expense',
          description: 'Telefon',
          installments: 6,
        );

        expect((await accounts.getAccount(cardId))!.debt, money('1200'));

        final plans = await ledger.getInstallmentPlans(cardId);
        expect(plans, hasLength(1));
        expect(plans.single.description, 'Telefon');
        expect(plans.single.totalAmount, money('1200'));
        expect(plans.single.monthlyAmount, money('200'));
        expect(plans.single.totalInstallments, 6);
        expect(plans.single.paidInstallments, 0);
        expect(plans.single.remainingInstallments, 6);
        expect(plans.single.remainingAmount, money('1200'));
      },
    );

    test('the monthly amount uses the same rounding as the desktop', () async {
      // Each pair separates one rounding rule from another, so a green result
      // means the port agrees with Python's ROUND_HALF_EVEN rather than
      // merely that some rounding happened:
      //
      //   100 / 6  = 16.666...  truncate 16.66, half-even 16.67
      //   0.05 / 2 = 0.025      half-up   0.03,  half-even 0.02
      //   0.15 / 2 = 0.075      truncate  0.07,  half-even 0.08
      //   100 / 3  = 33.333...  no rule disagrees; the ordinary case
      const cases = [
        (100, 6, '16.67'),
        ('0.05', 2, '0.02'),
        ('0.15', 2, '0.08'),
        (100, 3, '33.33'),
      ];

      for (final (amount, installments, expected) in cases) {
        final cardId = await accounts.createAccount(
          name: 'Kart \$expected',
          accountType: AccountType.creditCard,
          creditLimit: 10000,
        );
        await ledger.addTransaction(
          accountId: cardId,
          amount: amount,
          transactionType: 'expense',
          installments: installments,
        );
        expect(
          (await ledger.getInstallmentPlans(cardId)).single.monthlyAmount,
          money(expected),
          reason: '\$amount over \$installments instalments',
        );
      }
    });

    test('a single instalment is not a plan', () async {
      final cardId = await newCard(limit: 10000);
      await ledger.addTransaction(
        accountId: cardId,
        amount: 500,
        transactionType: 'expense',
        installments: 1,
      );
      expect(await ledger.getInstallmentPlans(cardId), isEmpty);
      expect((await accounts.getAccount(cardId))!.debt, money('500'));
    });

    test('rejects a count outside 1-12', () async {
      final cardId = await newCard(limit: 10000);
      for (final installments in [0, 13, -2]) {
        await expectLater(
          () => ledger.addTransaction(
            accountId: cardId,
            amount: 500,
            transactionType: 'expense',
            installments: installments,
          ),
          throwsA(
            isA<TransactionError>().having(
              (e) => e.code,
              'code',
              TransactionErrorCode.installmentCountOutOfRange,
            ),
          ),
        );
      }
      expect(await count('transactions'), 0);
    });

    test('a refused spend leaves no orphan plan behind', () async {
      // The plan and the transaction share one commit precisely so this
      // cannot happen.
      final cardId = await newCard(debt: 900, limit: 1000);
      await expectLater(
        () => ledger.addTransaction(
          accountId: cardId,
          amount: 600,
          transactionType: 'expense',
          installments: 6,
        ),
        throwsA(isA<AccountError>()),
      );
      expect(await ledger.getInstallmentPlans(cardId), isEmpty);
      expect(await count('transactions'), 0);
    });

    test('a finished plan drops off the list', () async {
      final cardId = await newCard(limit: 10000);
      await ledger.addTransaction(
        accountId: cardId,
        amount: 600,
        transactionType: 'expense',
        installments: 3,
      );
      await db.customUpdate(
        'UPDATE installment_plans SET paid_installments = 3',
        updates: const {},
      );
      expect(await ledger.getInstallmentPlans(cardId), isEmpty);
      expect(await accounts.getActiveInstallmentPlanCount(cardId), 0);
    });

    test('what is left to pay follows the counter', () async {
      final cardId = await newCard(limit: 10000);
      await ledger.addTransaction(
        accountId: cardId,
        amount: 600,
        transactionType: 'expense',
        installments: 3,
      );
      await db.customUpdate(
        'UPDATE installment_plans SET paid_installments = 2',
        updates: const {},
      );
      final plan = (await ledger.getInstallmentPlans(cardId)).single;
      expect(plan.remainingInstallments, 1);
      expect(plan.remainingAmount, money('200'));
      expect(await accounts.getActiveInstallmentPlanCount(cardId), 1);
    });
  });

  group('settling what has fallen due', () {
    test('applies the balance when the day arrives', () async {
      final id = await newChecking(balance: 0);
      await ledger.addTransaction(
        accountId: id,
        amount: 40000,
        transactionType: 'income',
        transactionDate: dayOffset(2),
      );
      expect(await balanceOf(id), Decimal.zero);

      final outcome = await ledger.settleDueTransactions(today: dayOffset(2));

      expect(outcome.settled, 1);
      expect(outcome.skipped, 0);
      expect(await balanceOf(id), money('40000'));
      expect(await statuses(), ['completed']);
    });

    test('is safe to call twice', () async {
      final id = await newChecking(balance: 0);
      await ledger.addTransaction(
        accountId: id,
        amount: 500,
        transactionType: 'income',
        transactionDate: dayOffset(1),
      );

      await ledger.settleDueTransactions(today: dayOffset(1));
      final second = await ledger.settleDueTransactions(today: dayOffset(1));

      expect(second.settled, 0);
      expect(await balanceOf(id), money('500'));
    });

    test('leaves what is not yet due alone', () async {
      final id = await newChecking(balance: 0);
      await ledger.addTransaction(
        accountId: id,
        amount: 500,
        transactionType: 'income',
        transactionDate: dayOffset(10),
      );
      final outcome = await ledger.settleDueTransactions();
      expect(outcome.settled, 0);
      expect(await statuses(), ['pending']);
      expect(await balanceOf(id), Decimal.zero);
    });

    test('an expense settles as a deduction', () async {
      final id = await newChecking(balance: 1000);
      await ledger.addTransaction(
        accountId: id,
        amount: 250,
        transactionType: 'expense',
        transactionDate: dayOffset(1),
      );
      await ledger.settleDueTransactions(today: dayOffset(1));
      expect(await balanceOf(id), money('750'));
    });

    test('writes a ledger row pointing at the transaction', () async {
      final id = await newChecking(balance: 0);
      final transactionId = await ledger.addTransaction(
        accountId: id,
        amount: 700,
        transactionType: 'income',
        transactionDate: dayOffset(1),
      );
      await ledger.settleDueTransactions(today: dayOffset(1));

      final events = await db
          .customSelect(
            "SELECT * FROM balance_events WHERE source = 'transaction'",
          )
          .get();
      expect(events, hasLength(1));
      expect(events.single.read<double>('delta'), 700.0);
      expect(events.single.read<double>('resulting_value'), 700.0);
      expect(events.single.read<int>('ref_id'), transactionId);
    });

    test('a frozen account keeps its rows pending', () async {
      final id = await newChecking(balance: 1000);
      await ledger.addTransaction(
        accountId: id,
        amount: 100,
        transactionType: 'expense',
        transactionDate: dayOffset(1),
      );
      await accounts.setCardFrozen(id, true);

      final outcome = await ledger.settleDueTransactions(today: dayOffset(1));
      expect(outcome.settled, 0);
      expect(await statuses(), ['pending']);
      expect(await balanceOf(id), money('1000'));
    });

    test(
      'a row that cannot be read does not strand the ones behind it',
      () async {
        // The failure this guards is invisible by nature: the desktop rolled a
        // bad row back silently, so an unprocessed salary left no trace at all.
        final id = await newChecking(balance: 0);
        final due = dayOffset(1);

        // An amount that will not decrypt, sorted first by its earlier id.
        await db.customInsert(
          'INSERT INTO transactions (account_id, amount, type, category, '
          'description, transaction_date, execution_date, status) '
          "VALUES (?, ?, 'income', 'Test', ?, ?, ?, 'pending')",
          variables: [
            Variable<int>(id),
            Variable<String>('AEADv1:this-is-not-a-valid-envelope'),
            Variable<String>('AEADv1:this-is-not-a-valid-envelope'),
            Variable<String>(sqliteTimestamp(due)),
            Variable<String>(sqliteTimestamp(due)),
          ],
        );
        await ledger.addTransaction(
          accountId: id,
          amount: 500,
          transactionType: 'income',
          transactionDate: due,
        );

        final outcome = await ledger.settleDueTransactions(today: due);

        expect(outcome.settled, 1, reason: 'the readable row still posted');
        expect(
          outcome.skipped,
          1,
          reason: 'and the caller is told one did not',
        );
        expect(await balanceOf(id), money('500'));
        expect(await statuses(), ['pending', 'completed']);
      },
    );

    test('a row whose account has gone does not strand the rest', () async {
      final id = await newChecking(balance: 0);
      final due = dayOffset(1);

      // Enforcement is switched off to plant the orphan, which is how one
      // really arrives: a backup restored by a writer that never turned
      // foreign keys on.
      await db.customStatement('PRAGMA foreign_keys = OFF');
      await db.customInsert(
        'INSERT INTO transactions (account_id, amount, type, category, '
        'description, transaction_date, execution_date, status) '
        "VALUES (999999, ?, 'expense', 'Market', ?, ?, ?, 'pending')",
        variables: [
          Variable<String>((await crypto.encryptField('50.00'))!),
          Variable<String>((await crypto.encryptField('yetim kayıt'))!),
          Variable<String>(sqliteTimestamp(due)),
          Variable<String>(sqliteTimestamp(due)),
        ],
      );
      await db.customStatement('PRAGMA foreign_keys = ON');

      await ledger.addTransaction(
        accountId: id,
        amount: 500,
        transactionType: 'income',
        transactionDate: due,
      );

      final outcome = await ledger.settleDueTransactions(today: due);

      expect(outcome.settled, 1);
      expect(outcome.skipped, 1);
      expect(await balanceOf(id), money('500'));
    });
  });

  group('the pending list', () {
    test('shows what is due and when', () async {
      final id = await newChecking();
      final target = dayOffset(7);
      await ledger.addTransaction(
        accountId: id,
        amount: 1250,
        transactionType: 'expense',
        category: 'Kira',
        description: 'Kira ödemesi',
        transactionDate: target,
      );

      final pending = await ledger.getPendingTransactions();
      expect(pending, hasLength(1));
      expect(pending.single.amount, money('1250'));
      expect(pending.single.description, 'Kira ödemesi');
      expect(
        pending.single.executionDate,
        sqliteTimestamp(target).substring(0, 10),
      );
      expect(pending.single.isCorrupt, isFalse);
    });

    test('does not show what has already posted', () async {
      final id = await newChecking();
      await ledger.addTransaction(
        accountId: id,
        amount: 100,
        transactionType: 'expense',
        transactionDate: dayOffset(-2),
      );
      expect(await ledger.getPendingTransactions(), isEmpty);
    });

    test('reports an unreadable row instead of calling it zero', () async {
      // A false ₺0,00 on screen is the failure the money layer refuses:
      // showing no figure is safer than showing a wrong one.
      final id = await newChecking();
      await db.customInsert(
        'INSERT INTO transactions (account_id, amount, type, category, '
        'description, transaction_date, execution_date, status) '
        "VALUES (?, ?, 'expense', 'Test', ?, ?, ?, 'pending')",
        variables: [
          Variable<int>(id),
          Variable<String>('AEADv1:broken'),
          Variable<String>('AEADv1:broken'),
          Variable<String>(sqliteTimestamp(dayOffset(1))),
          Variable<String>(sqliteTimestamp(dayOffset(1))),
        ],
      );

      final pending = await ledger.getPendingTransactions();
      expect(pending.single.amount, isNull);
      expect(pending.single.isCorrupt, isTrue);
    });

    test('cancelling removes the row and touches no balance', () async {
      final id = await newChecking();
      final transactionId = await ledger.addTransaction(
        accountId: id,
        amount: 400,
        transactionType: 'expense',
        transactionDate: dayOffset(3),
      );

      expect(await ledger.cancelPendingTransaction(transactionId), isTrue);
      expect(await count('transactions'), 0);
      expect(await balanceOf(id), money('10000'));
    });

    test('cancelling refuses a transaction that has already posted', () async {
      // Deleting it would leave the balance without the record explaining it.
      final id = await newChecking();
      final transactionId = await ledger.addTransaction(
        accountId: id,
        amount: 400,
        transactionType: 'expense',
      );

      expect(await ledger.cancelPendingTransaction(transactionId), isFalse);
      expect(await count('transactions'), 1);
      expect(await balanceOf(id), money('9600'));
    });

    test('rescheduling to today lets the next round settle it', () async {
      final id = await newChecking(balance: 1000);
      final transactionId = await ledger.addTransaction(
        accountId: id,
        amount: 250,
        transactionType: 'expense',
        transactionDate: dayOffset(10),
      );

      expect(
        await ledger.reschedulePendingTransaction(
          transactionId,
          DateTime.now(),
        ),
        isTrue,
      );
      // Rescheduling itself posts nothing: settling stays in one place.
      expect(await balanceOf(id), money('1000'));

      final outcome = await ledger.settleDueTransactions();
      expect(outcome.settled, 1);
      expect(await balanceOf(id), money('750'));
    });

    test('rescheduling keeps the full timestamp form', () async {
      final id = await newChecking();
      final transactionId = await ledger.addTransaction(
        accountId: id,
        amount: 100,
        transactionType: 'expense',
        transactionDate: dayOffset(5),
      );
      await ledger.reschedulePendingTransaction(
        transactionId,
        DateTime(2026, 12, 1),
      );

      final row = await db
          .customSelect('SELECT * FROM transactions')
          .getSingle();
      for (final column in ['transaction_date', 'execution_date']) {
        expect(row.read<String>(column), '2026-12-01 09:00:00');
      }
    });

    test(
      'rescheduling refuses a transaction that has already posted',
      () async {
        final id = await newChecking();
        final transactionId = await ledger.addTransaction(
          accountId: id,
          amount: 100,
          transactionType: 'expense',
        );
        expect(
          await ledger.reschedulePendingTransaction(
            transactionId,
            dayOffset(5),
          ),
          isFalse,
        );
      },
    );
  });

  group('the dashboard period queries', () {
    Future<void> spendOn(String date, Object amount, String category) async {
      final id = await newChecking(balance: 1000000);
      await ledger.addTransaction(
        accountId: id,
        amount: amount,
        transactionType: 'expense',
        category: category,
        transactionDate: DateTime.parse(date),
      );
    }

    test('a row dated today is in the today window', () async {
      final id = await newChecking();
      await ledger.addTransaction(
        accountId: id,
        amount: 100,
        transactionType: 'expense',
        category: 'Süpermarket',
      );

      final today = await ledger.getTransactionsByPeriod(DashboardPeriod.today);
      expect(today, hasLength(1));
      expect(today.single.amount, money('100'));
    });

    test('every window that asks SQLite for "now" asks in local time', () {
      // Deliberately structural rather than behavioural. Without 'localtime'
      // SQLite compares against UTC, and the two only disagree during the
      // hours a timezone runs across a UTC date boundary — in Türkiye,
      // between local midnight and 03:00. A behavioural test would therefore
      // pass on most runs and fail on some, which is worse than no test: it
      // would look like flakiness rather than the defect it is.
      for (final period in DashboardPeriod.values) {
        final condition = period.condition('t.transaction_date');
        if (!condition.contains("'now'")) continue;
        expect(
          condition,
          contains("'localtime'"),
          reason: '${period.name} would compare against UTC',
        );
      }
    });

    test('each window reaches back as far as it says', () async {
      final now = DateTime.now();
      await spendOn(sqliteDate(now), 10, 'Bugün');
      await spendOn(
        sqliteDate(now.subtract(const Duration(days: 3))),
        20,
        'Hafta',
      );
      await spendOn(
        sqliteDate(now.subtract(const Duration(days: 20))),
        30,
        'Ay',
      );
      await spendOn(
        sqliteDate(now.subtract(const Duration(days: 200))),
        40,
        'Yıl',
      );
      await spendOn('2019-01-05', 50, 'Eski');

      Future<Set<String>> categoriesIn(DashboardPeriod period) async => {
        for (final entry in await ledger.getTransactionsByPeriod(period))
          entry.category,
      };

      expect(await categoriesIn(DashboardPeriod.today), {'Bugün'});
      expect(await categoriesIn(DashboardPeriod.week), {'Bugün', 'Hafta'});
      expect(await categoriesIn(DashboardPeriod.month), {
        'Bugün',
        'Hafta',
        'Ay',
      });
      expect(await categoriesIn(DashboardPeriod.year), {
        'Bugün',
        'Hafta',
        'Ay',
        'Yıl',
      });
      expect(await categoriesIn(DashboardPeriod.allTime), {
        'Bugün',
        'Hafta',
        'Ay',
        'Yıl',
        'Eski',
      });
    });

    test('a pending row is not in any period', () async {
      final id = await newChecking();
      await ledger.addTransaction(
        accountId: id,
        amount: 999,
        transactionType: 'expense',
        transactionDate: dayOffset(5),
      );
      expect(
        await ledger.getTransactionsByPeriod(DashboardPeriod.allTime),
        isEmpty,
      );
    });

    test(
      'an uncategorised row is filed under Diğer, not left nameless',
      () async {
        final id = await newChecking();
        await ledger.addTransaction(
          accountId: id,
          amount: 50,
          transactionType: 'expense',
        );
        expect(
          (await ledger.getTransactionsByPeriod(DashboardPeriod.allTime))
              .single
              .category,
          'Diğer',
        );
      },
    );

    test(
      'importance comes from the categories table, defaulting to extra',
      () async {
        await db.customInsert(
          "INSERT INTO categories (name, type, importance) "
          "VALUES ('Kira', 'expense', 'essential')",
        );
        await spendOn(sqliteDate(DateTime.now()), 5000, 'Kira');
        await spendOn(sqliteDate(DateTime.now()), 200, 'Eğlence');

        final byCategory = {
          for (final entry in await ledger.getTransactionsByPeriod(
            DashboardPeriod.allTime,
          ))
            entry.category: entry.importance,
        };
        expect(byCategory['Kira'], 'essential');
        expect(byCategory['Eğlence'], 'extra');
      },
    );

    test('a debt payment is neither income nor an expense', () async {
      // Counting it as spending would double-count the purchase it settles.
      final id = await newChecking();
      await db.customInsert(
        'INSERT INTO transactions (account_id, amount, type, category, '
        "description, transaction_date, status) "
        "VALUES (?, ?, 'payment', 'Borç Ödeme', ?, ?, 'completed')",
        variables: [
          Variable<int>(id),
          Variable<String>((await crypto.encryptField('900'))!),
          Variable<String>((await crypto.encryptField('Kart ödemesi'))!),
          Variable<String>(sqliteTimestamp(DateTime.now())),
        ],
      );

      final entry = (await ledger.getTransactionsByPeriod(
        DashboardPeriod.allTime,
      )).single;
      expect(entry.isIncome, isFalse);
      expect(entry.isExpense, isFalse);
    });

    test(
      'an unreadable amount fails the whole period, never a silent gap',
      () async {
        // A slice quietly missing from a pie is a wrong picture presented as a
        // right one — the opposite call from getRecentForAccount, where a row
        // can honestly say "unreadable" beside its neighbours.
        final id = await newChecking();
        await db.customInsert(
          'INSERT INTO transactions (account_id, amount, type, category, '
          "description, transaction_date, status) "
          "VALUES (?, 'AEADv1:broken', 'expense', 'Test', 'x', ?, 'completed')",
          variables: [
            Variable<int>(id),
            Variable<String>(sqliteTimestamp(DateTime.now())),
          ],
        );

        await expectLater(
          ledger.getTransactionsByPeriod(DashboardPeriod.allTime),
          throwsA(isA<TransactionDataIntegrityError>()),
        );
      },
    );

    test(
      'opening balances are read from the ledger, not from transactions',
      () async {
        // An opening balance never reaches the transactions table, so a chart
        // fed only from there shows nothing for a user who has just opened an
        // account with money in it.
        await newChecking(balance: 17300);

        expect(
          await ledger.getTransactionsByPeriod(DashboardPeriod.allTime),
          isEmpty,
        );
        final openings = await ledger.getOpeningEventsByPeriod(
          DashboardPeriod.allTime,
        );
        expect(openings.single.amount, money('17300'));
        expect(
          await ledger.getOpeningBaselineByPeriod(DashboardPeriod.allTime),
          money('17300'),
        );
      },
    );

    test('an opening card DEBT is left out of the baseline', () async {
      // It arrives as a negative delta; a debt in an income breakdown would
      // make no sense.
      await accounts.createAccount(
        name: 'Kart',
        accountType: AccountType.creditCard,
        initialBalance: 3500,
        creditLimit: 20000,
      );
      expect(
        await ledger.getOpeningBaselineByPeriod(DashboardPeriod.allTime),
        Decimal.zero,
      );
    });

    test('an opening balance outside the window is left out', () async {
      await newChecking(balance: 500);
      await db.customUpdate(
        "UPDATE balance_events SET ts = '2019-01-05 10:00:00'",
        updates: const {},
      );
      expect(
        await ledger.getOpeningBaselineByPeriod(DashboardPeriod.today),
        Decimal.zero,
      );
      expect(
        await ledger.getOpeningBaselineByPeriod(DashboardPeriod.allTime),
        money('500'),
      );
    });
  });

  group('an account statement', () {
    test('shows completed rows newest first and honours the limit', () async {
      final id = await newChecking();
      for (var day = 1; day <= 4; day++) {
        await ledger.addTransaction(
          accountId: id,
          amount: day * 10,
          transactionType: 'expense',
          category: 'Süpermarket',
          description: 'Gün $day',
          transactionDate: DateTime(2026, 3, day, 12),
        );
      }

      final recent = await ledger.getRecentForAccount(id);
      expect(recent, hasLength(3));
      expect(recent.first.description, 'Gün 4');
      expect(recent.first.amount, money('40'));
      expect(recent.first.date, '2026-03-04');

      expect(await ledger.getRecentForAccount(id, limit: null), hasLength(4));
      expect(await ledger.getRecentForAccount(id, limit: 0), isEmpty);
    });

    test('leaves pending rows out', () async {
      final id = await newChecking();
      await ledger.addTransaction(
        accountId: id,
        amount: 999,
        transactionType: 'expense',
        transactionDate: dayOffset(5),
      );
      expect(await ledger.getRecentForAccount(id, limit: null), isEmpty);
    });

    test('includes rows written before the status column existed', () async {
      // A NULL status is, by definition, completed; the COALESCE is what
      // keeps those rows visible.
      final id = await newChecking();
      await db.customInsert(
        'INSERT INTO transactions (account_id, amount, type, category, '
        'description, transaction_date, status) '
        "VALUES (?, ?, 'expense', 'Eski', ?, '2020-01-01 10:00:00', NULL)",
        variables: [
          Variable<int>(id),
          Variable<String>((await crypto.encryptField('12.34'))!),
          Variable<String>((await crypto.encryptField('Eski kayıt'))!),
        ],
      );
      final recent = await ledger.getRecentForAccount(id, limit: null);
      expect(recent, hasLength(1));
      expect(recent.single.amount, money('12.34'));
    });

    test('refuses a negative limit', () {
      expect(
        () => ledger.getRecentForAccount(1, limit: -1),
        throwsA(
          isA<TransactionError>().having(
            (e) => e.code,
            'code',
            TransactionErrorCode.negativeLimit,
          ),
        ),
      );
    });
  });
}
