/// Recurring payments and the subscription radar, ported from the desktop's
/// `test_recurring_service.py` and `test_recurring_charge_integrity.py`.
library;

import 'package:archlence_mobile/crypto/field_crypto.dart';
import 'package:archlence_mobile/data/database.dart';
import 'package:archlence_mobile/money/financial_decimal.dart';
import 'package:archlence_mobile/services/account_service.dart';
import 'package:archlence_mobile/services/recurring_service.dart';
import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';

import 'support/fixed_key_provider.dart';

void main() {
  late ArchlenceDatabase db;
  late FieldCrypto crypto;
  late AccountService accounts;
  late RecurringService recurring;

  /// Builds a fresh stack over a new in-memory database.
  ///
  /// A few tests below need one PER CASE rather than per test: they corrupt a
  /// stored column, and `UPDATE ... SET amount = ?` with no WHERE would
  /// otherwise reach rows left by the previous iteration.
  void wire() {
    db = ArchlenceDatabase.memory();
    crypto = FieldCrypto(FixedKeyProvider.arbitrary());
    accounts = AccountService(db, crypto);
    recurring = RecurringService(db, crypto, accounts);
  }

  setUp(wire);

  tearDown(() => db.close());

  Decimal money(String value) => fiat(value);

  Future<int> count(String table) async {
    final row = await db
        .customSelect('SELECT COUNT(*) AS n FROM $table')
        .getSingle();
    return row.read<int>('n');
  }

  Future<int> newAccount({Object? balance = 10000}) => accounts.createAccount(
    name: 'Maaş Hesabı',
    accountType: AccountType.checking,
    initialBalance: balance,
  );

  Future<Decimal> balanceOf(int id) async =>
      (await accounts.getAccount(id))!.balance;

  /// Overwrites a stored encrypted column with an arbitrary value, standing
  /// in for a row an older version or a restored backup left behind.
  Future<void> corrupt(String table, String column, String stored) async {
    await db.customUpdate(
      'UPDATE $table SET $column = ?',
      variables: [Variable<String>(stored)],
      updates: const {},
    );
  }

  group('advancing a due date', () {
    test('weekly and biweekly move by fixed days', () {
      expect(
        advanceDueDate(DateTime(2026, 2, 26), RecurrenceFrequency.weekly),
        DateTime(2026, 3, 5),
      );
      expect(
        advanceDueDate(DateTime(2026, 2, 26), RecurrenceFrequency.biweekly),
        DateTime(2026, 3, 12),
      );
    });

    test('monthly clamps to the last day of a short month', () {
      // Dart's DateTime would happily roll 31 January into 3 March; the
      // clamp is what stops a payment skipping a month entirely.
      expect(
        advanceDueDate(DateTime(2026, 1, 31), RecurrenceFrequency.monthly),
        DateTime(2026, 2, 28),
      );
      expect(
        advanceDueDate(DateTime(2026, 1, 15), RecurrenceFrequency.monthly),
        DateTime(2026, 2, 15),
      );
      expect(
        advanceDueDate(DateTime(2026, 12, 31), RecurrenceFrequency.monthly),
        DateTime(2027, 1, 31),
      );
    });

    test('quarterly moves three calendar months, not ninety days', () {
      // 31 January plus three months is 30 April — the desktop's own example.
      expect(
        advanceDueDate(DateTime(2026, 1, 31), RecurrenceFrequency.quarterly),
        DateTime(2026, 4, 30),
      );
    });

    test('yearly falls back to the 28th from a leap day', () {
      expect(
        advanceDueDate(DateTime(2028, 2, 29), RecurrenceFrequency.yearly),
        DateTime(2029, 2, 28),
      );
      expect(
        advanceDueDate(DateTime(2026, 6, 15), RecurrenceFrequency.yearly),
        DateTime(2027, 6, 15),
      );
    });

    test('an unrecognised frequency is rejected, not treated as monthly', () {
      // Silently rescheduling to the wrong period is worse than failing.
      expect(
        () => RecurrenceFrequency.fromWire('fortnightly'),
        throwsA(
          isA<RecurringError>().having(
            (e) => e.code,
            'code',
            RecurringErrorCode.unknownFrequency,
          ),
        ),
      );
    });
  });

  group('pinning to the recurrence day', () {
    test('returns to the chosen day after a short month', () {
      // A payment set to the 31st that fell due on 28 February must go back
      // to the 31st in March, not stay on the 28th for good.
      expect(
        nextDueForRecurrence(
          DateTime(2026, 2, 28),
          RecurrenceFrequency.monthly,
          31,
        ),
        DateTime(2026, 3, 31),
      );
    });

    test('clamps the chosen day inside a short month', () {
      expect(
        nextDueForRecurrence(
          DateTime(2026, 1, 31),
          RecurrenceFrequency.monthly,
          31,
        ),
        DateTime(2026, 2, 28),
      );
    });

    test('rejects a day outside 1-31', () {
      for (final day in [0, 32, -1]) {
        expect(
          () => nextDueForRecurrence(
            DateTime(2026, 1, 1),
            RecurrenceFrequency.monthly,
            day,
          ),
          throwsA(
            isA<RecurringError>().having(
              (e) => e.code,
              'code',
              RecurringErrorCode.invalidRecurrenceDay,
            ),
          ),
        );
      }
    });
  });

  group('the first recurring income date', () {
    // The desktop's own table, kept as it stands.
    test('is nothing when the month is not included', () {
      expect(
        initialRecurringIncomeDate(
          DateTime(2026, 7, 29),
          15,
          includeCurrentMonth: false,
        ),
        isNull,
      );
    });

    test('is today when the chosen day has already passed', () {
      final today = DateTime(2026, 7, 29);
      expect(
        initialRecurringIncomeDate(today, 15, includeCurrentMonth: true),
        today,
      );
    });

    test('is the chosen day when it has not arrived yet', () {
      expect(
        initialRecurringIncomeDate(
          DateTime(2026, 7, 29),
          31,
          includeCurrentMonth: true,
        ),
        DateTime(2026, 7, 31),
      );
    });

    test('clamps to the last day of a short month', () {
      expect(
        initialRecurringIncomeDate(
          DateTime(2026, 2, 10),
          31,
          includeCurrentMonth: true,
        ),
        DateTime(2026, 2, 28),
      );
    });
  });

  group('spotting a subscription', () {
    test('a subscription category is enough on its own', () {
      expect(looksLikeSubscription('Dijital Abonelik'), isTrue);
      expect(looksLikeSubscription('Yazılım & Lisans'), isTrue);
    });

    test('a known brand in the description is enough on its own', () {
      expect(
        looksLikeSubscription('Eğlence', description: 'Netflix aylık'),
        isTrue,
      );
      expect(
        looksLikeSubscription('Diğer', description: 'SPOTIFY PREMIUM'),
        isTrue,
      );
    });

    test('an ordinary spend is not a subscription', () {
      expect(
        looksLikeSubscription('Süpermarket', description: 'Market alışverişi'),
        isFalse,
      );
      expect(looksLikeSubscription(null), isFalse);
    });
  });

  group('recording a recurring payment', () {
    test('stores the name and amount encrypted and reads them back', () async {
      final accountId = await newAccount();
      final id = await recurring.insertRecurringPayment(
        name: 'Netflix',
        amount: '149.99',
        category: 'Dijital Abonelik',
        frequency: RecurrenceFrequency.monthly,
        nextDueDate: DateTime(2026, 9, 15),
        accountId: accountId,
      );

      final row = await db
          .customSelect('SELECT * FROM recurring_payments')
          .getSingle();
      expect(FieldCrypto.isEncrypted(row.read<String>('name')), isTrue);
      expect(FieldCrypto.isEncrypted(row.read<String>('amount')), isTrue);
      // The category stays in the clear: the desktop groups on the literal.
      expect(row.read<String>('category'), 'Dijital Abonelik');
      expect(row.read<String>('next_due_date'), '2026-09-15');

      final payment = (await recurring.getActiveRecurringPayments()).single;
      expect(payment.id, id);
      expect(payment.name, 'Netflix');
      expect(payment.amount, money('149.99'));
      expect(payment.amountIsValid, isTrue);
      expect(payment.recurrenceDay, 15, reason: 'defaulted from the due date');
      expect(payment.transactionType, 'expense');
    });

    test('rejects a non-finite or non-positive amount', () async {
      final accountId = await newAccount();
      for (final amount in [double.nan, double.infinity, 0, -5]) {
        await expectLater(
          () => recurring.insertRecurringPayment(
            name: 'X',
            amount: amount,
            frequency: RecurrenceFrequency.monthly,
            nextDueDate: DateTime(2026, 9, 15),
            accountId: accountId,
          ),
          throwsA(isA<RecurringError>()),
        );
      }
      expect(await count('recurring_payments'), 0);
    });

    test(
      'rejects a transaction type that is neither income nor expense',
      () async {
        final accountId = await newAccount();
        await expectLater(
          () => recurring.insertRecurringPayment(
            name: 'X',
            amount: 10,
            frequency: RecurrenceFrequency.monthly,
            nextDueDate: DateTime(2026, 9, 15),
            accountId: accountId,
            transactionType: 'transfer',
          ),
          throwsA(
            isA<RecurringError>().having(
              (e) => e.code,
              'code',
              RecurringErrorCode.invalidTransactionType,
            ),
          ),
        );
        expect(await count('recurring_payments'), 0);
      },
    );
  });

  group('rows an older version left behind', () {
    Future<RecurringPayment> withStoredAmount(String stored) async {
      final accountId = await newAccount();
      await recurring.insertRecurringPayment(
        name: 'Bozuk',
        amount: 10,
        frequency: RecurrenceFrequency.monthly,
        nextDueDate: DateTime(2026, 9, 15),
        accountId: accountId,
      );
      await corrupt(
        'recurring_payments',
        'amount',
        (await crypto.encryptField(stored))!,
      );
      return (await recurring.getActiveRecurringPayments()).single;
    }

    test('a non-finite amount reads as invalid, not as a number', () async {
      // NaN raises no exception on its own, so the desktop's flag once said
      // "valid" and the monthly budget broke somewhere far away instead.
      final payment = await withStoredAmount('nan');
      expect(payment.amount, isNull);
      expect(payment.amountIsValid, isFalse);
    });

    test('a zero or negative amount reads as invalid too', () async {
      // The column is a MAGNITUDE — direction lives in transaction_type — so
      // -10.00 is not a reversed payment but an invalid record. This was the
      // silent one: it entered the desktop's budget as a -10.00 reserve and
      // overstated the spendable amount by 10 lira.
      for (final stored in ['-10', '0', '0.0', '-0.004']) {
        await db.close();
        wire();
        final payment = await withStoredAmount(stored);
        expect(payment.amount, isNull, reason: stored);
        expect(payment.amountIsValid, isFalse, reason: stored);
      }
    });

    test('the row is reported, never quietly corrected', () async {
      await withStoredAmount('-10');
      final row = await db
          .customSelect('SELECT amount FROM recurring_payments')
          .getSingle();
      expect(
        await crypto.decryptField(row.read<String>('amount')),
        '-10',
        reason: 'no abs() was taken and the row was not rewritten',
      );
    });

    test('an unreadable name reads as null', () async {
      final accountId = await newAccount();
      await recurring.insertRecurringPayment(
        name: 'Bozuk',
        amount: 10,
        frequency: RecurrenceFrequency.monthly,
        nextDueDate: DateTime(2026, 9, 15),
        accountId: accountId,
      );
      await corrupt('recurring_payments', 'name', 'AEADv1:broken');
      expect(
        (await recurring.getActiveRecurringPayments()).single.name,
        isNull,
      );
    });
  });

  group('duplicate names', () {
    test('matches case-insensitively and ignores cancelled rows', () async {
      final accountId = await newAccount();
      final id = await recurring.insertRecurringPayment(
        name: 'Netflix',
        amount: 100,
        frequency: RecurrenceFrequency.monthly,
        nextDueDate: DateTime(2026, 9, 15),
        accountId: accountId,
      );

      expect(await recurring.hasActiveRecurringPayment('netflix'), isTrue);
      expect(await recurring.hasActiveRecurringPayment('  NETFLIX '), isTrue);
      expect(await recurring.hasActiveRecurringPayment('Spotify'), isFalse);

      await recurring.cancelSubscription(id);
      expect(await recurring.hasActiveRecurringPayment('Netflix'), isFalse);
    });

    test('cancelling deactivates rather than deletes', () async {
      // Past transactions and the radar's "already tracked" check both rely
      // on the row existing; deleting it would turn settled history back into
      // a fresh candidate.
      final accountId = await newAccount();
      final id = await recurring.insertRecurringPayment(
        name: 'Netflix',
        amount: 100,
        frequency: RecurrenceFrequency.monthly,
        nextDueDate: DateTime(2026, 9, 15),
        accountId: accountId,
      );
      expect(await recurring.cancelSubscription(id), isTrue);
      expect(await count('recurring_payments'), 1);
      expect(await recurring.getActiveRecurringPayments(), isEmpty);
    });
  });

  group('the subscription radar', () {
    test('records a card spend that looks like a subscription', () async {
      final accountId = await newAccount();
      final id = await recurring.registerSubscriptionFromTransaction(
        accountId: accountId,
        amount: 149.99,
        category: 'Dijital Abonelik',
        description: 'Netflix',
        transactionDate: DateTime(2026, 8, 10),
        isCreditCard: true,
      );

      expect(id, isNotNull);
      final payment = (await recurring.getActiveRecurringPayments()).single;
      expect(payment.name, 'Netflix');
      expect(payment.nextDueDate, '2026-09-10');
    });

    test('a card alone is not a signal', () async {
      // Otherwise every supermarket run on the card would fill the radar.
      final accountId = await newAccount();
      expect(
        await recurring.registerSubscriptionFromTransaction(
          accountId: accountId,
          amount: 250,
          category: 'Süpermarket',
          description: 'Market alışverişi',
          isCreditCard: true,
        ),
        isNull,
      );
      expect(await count('recurring_payments'), 0);
    });

    test(
      'a subscription paid from a checking account is not recorded',
      () async {
        final accountId = await newAccount();
        expect(
          await recurring.registerSubscriptionFromTransaction(
            accountId: accountId,
            amount: 149.99,
            category: 'Dijital Abonelik',
            description: 'Netflix',
            isCreditCard: false,
          ),
          isNull,
        );
      },
    );

    test('entering the same subscription again keeps one record', () async {
      final accountId = await newAccount();
      for (var month = 8; month <= 10; month++) {
        await recurring.registerSubscriptionFromTransaction(
          accountId: accountId,
          amount: 149.99,
          category: 'Dijital Abonelik',
          description: 'Netflix',
          transactionDate: DateTime(2026, month, 10),
          isCreditCard: true,
        );
      }
      expect(await count('recurring_payments'), 1);
    });
  });

  group('changing a subscription', () {
    late int accountId;
    late int paymentId;

    setUp(() async {
      accountId = await newAccount();
      paymentId = await recurring.insertRecurringPayment(
        name: 'Netflix',
        amount: 100,
        category: 'Dijital Abonelik',
        frequency: RecurrenceFrequency.monthly,
        nextDueDate: DateTime(2026, 9, 15),
        accountId: accountId,
      );
    });

    test('a price rise changes the amount and nothing else', () async {
      expect(
        await recurring.updateSubscriptionAmount(paymentId, 149.99),
        isTrue,
      );
      final payment = (await recurring.getActiveRecurringPayments()).single;
      expect(payment.amount, money('149.99'));
      expect(
        payment.nextDueDate,
        '2026-09-15',
        reason: 'the due alignment must survive a price change',
      );
    });

    test('a price rise rejects a non-finite or non-positive amount', () async {
      for (final amount in [double.nan, double.infinity, 0, -5]) {
        await expectLater(
          () => recurring.updateSubscriptionAmount(paymentId, amount),
          throwsA(isA<RecurringError>()),
        );
      }
      expect(
        (await recurring.getActiveRecurringPayments()).single.amount,
        money('100'),
      );
    });

    test('a cancelled subscription cannot have its price changed', () async {
      await recurring.cancelSubscription(paymentId);
      expect(await recurring.updateSubscriptionAmount(paymentId, 200), isFalse);
    });

    test('skipping moves the due date on one period, staying active', () async {
      final newDue = await recurring.skipNextOccurrence(paymentId);
      expect(newDue, DateTime(2026, 10, 15));

      final payment = (await recurring.getActiveRecurringPayments()).single;
      expect(payment.nextDueDate, '2026-10-15');
      expect(
        await count("transactions"),
        0,
        reason: 'skipping charges nothing',
      );
    });

    test('skipping a missing or cancelled subscription does nothing', () async {
      expect(await recurring.skipNextOccurrence(404), isNull);
      await recurring.cancelSubscription(paymentId);
      expect(await recurring.skipNextOccurrence(paymentId), isNull);
    });
  });

  group('charging what is due', () {
    Future<(int, RecurringPayment)> subscription({
      Object amount = 100,
      Object? accountBalance = 10000,
      String transactionType = 'expense',
    }) async {
      final accountId = await newAccount(balance: accountBalance);
      await recurring.insertRecurringPayment(
        name: 'Netflix',
        amount: amount,
        category: 'Dijital Abonelik',
        frequency: RecurrenceFrequency.monthly,
        nextDueDate: DateTime(2026, 9, 15),
        accountId: accountId,
        transactionType: transactionType,
      );
      return (accountId, (await recurring.getActiveRecurringPayments()).single);
    }

    test('an expense leaves the balance and advances the due date', () async {
      final (accountId, payment) = await subscription();

      expect(await recurring.processDueRecurringPayment(payment), isTrue);

      expect(await balanceOf(accountId), money('9900'));
      final updated = (await recurring.getActiveRecurringPayments()).single;
      expect(updated.nextDueDate, '2026-10-15');
    });

    test('an income adds to the balance', () async {
      final accountId = await newAccount(balance: 1000);
      await recurring.insertRecurringPayment(
        name: 'Maaş',
        amount: 5000,
        category: 'Maaş',
        frequency: RecurrenceFrequency.monthly,
        nextDueDate: DateTime(2026, 9, 15),
        accountId: accountId,
        recurrenceDay: 15,
        transactionType: 'income',
      );
      final payment = (await recurring.getActiveRecurringPayments()).single;
      expect(payment.transactionType, 'income');

      await recurring.processDueRecurringPayment(payment);

      expect(await balanceOf(accountId), money('6000'));
      final row = await db
          .customSelect('SELECT * FROM transactions ORDER BY id DESC LIMIT 1')
          .getSingle();
      expect(row.read<String>('type'), 'income');
      expect(
        fiat(await crypto.decryptField(row.read<String>('amount'))),
        money('5000'),
      );
    });

    test('the marker records the transaction it charged', () async {
      final (_, payment) = await subscription();
      await recurring.processDueRecurringPayment(payment);

      final transaction = await db
          .customSelect('SELECT id FROM transactions')
          .getSingle();
      final marker = await db
          .customSelect('SELECT * FROM recurring_operation_markers')
          .getSingle();
      expect(marker.read<String>('operation_type'), 'charge');
      expect(
        marker.read<String>('due_date'),
        '2026-09-15',
        reason: 'keyed on the generation, not the new due date',
      );
      expect(marker.read<int>('transaction_id'), transaction.read<int>('id'));
    });

    test('the ledger event points at the same transaction', () async {
      final (_, payment) = await subscription();
      await recurring.processDueRecurringPayment(payment);

      final transaction = await db
          .customSelect('SELECT id FROM transactions')
          .getSingle();
      final event = await db
          .customSelect(
            "SELECT * FROM balance_events WHERE source = 'recurring_payment'",
          )
          .getSingle();
      expect(event.read<double>('delta'), -100.0);
      expect(event.read<int>('ref_id'), transaction.read<int>('id'));
    });

    test('a second pass over the same generation changes nothing', () async {
      // Idempotence is SQLite's job, not the interface's: a stale object
      // still holding the old due date must collide with the same marker.
      final (accountId, payment) = await subscription();
      expect(await recurring.processDueRecurringPayment(payment), isTrue);

      expect(
        await recurring.processDueRecurringPayment(payment),
        isFalse,
        reason: 'the same generation must not charge twice',
      );
      expect(await count('transactions'), 1);
      expect(await count('balance_events'), 2, reason: 'opening + one charge');
      expect(await balanceOf(accountId), money('9900'));
    });

    test('a card limit is enforced and leaves no partial record', () async {
      final cardId = await accounts.createAccount(
        name: 'Kart',
        accountType: AccountType.creditCard,
        creditLimit: 100,
      );
      await recurring.insertRecurringPayment(
        name: 'Pahalı abonelik',
        amount: 150,
        frequency: RecurrenceFrequency.monthly,
        nextDueDate: DateTime(2026, 9, 15),
        accountId: cardId,
      );
      final payment = (await recurring.getActiveRecurringPayments()).single;

      await expectLater(
        () => recurring.processDueRecurringPayment(payment),
        throwsA(
          isA<AccountError>().having(
            (e) => e.code,
            'code',
            AccountErrorCode.insufficientLimit,
          ),
        ),
      );
      expect(await count('transactions'), 0);
      expect(
        await count('recurring_operation_markers'),
        0,
        reason: 'the claimed marker must roll back with the charge',
      );
      expect((await accounts.getAccount(cardId))!.debt, Decimal.zero);
    });

    test('a frozen account blocks the charge', () async {
      final (accountId, payment) = await subscription();
      await accounts.setCardFrozen(accountId, true);

      await expectLater(
        () => recurring.processDueRecurringPayment(payment),
        throwsA(
          isA<AccountError>().having(
            (e) => e.code,
            'code',
            AccountErrorCode.cardFrozen,
          ),
        ),
      );
      expect(await count('transactions'), 0);
      expect(await count('recurring_operation_markers'), 0);
    });

    test('an invalid stored amount refuses to charge', () async {
      final (accountId, _) = await subscription();
      await corrupt(
        'recurring_payments',
        'amount',
        (await crypto.encryptField('nan'))!,
      );
      final payment = (await recurring.getActiveRecurringPayments()).single;

      await expectLater(
        () => recurring.processDueRecurringPayment(payment),
        throwsA(isA<RecurringDataIntegrityError>()),
      );
      expect(await count('transactions'), 0);
      expect(await balanceOf(accountId), money('10000'));
    });

    test('an unreadable name refuses to charge', () async {
      // Stricter than the desktop, which charges under a placeholder. The
      // description is the only handle findCurrentPeriodCharge has, so such a
      // charge could never be refunded.
      await subscription();
      await corrupt('recurring_payments', 'name', 'AEADv1:broken');
      final payment = (await recurring.getActiveRecurringPayments()).single;

      await expectLater(
        () => recurring.processDueRecurringPayment(payment),
        throwsA(isA<RecurringDataIntegrityError>()),
      );
      expect(await count('transactions'), 0);
    });
  });

  group('refunding this period', () {
    Future<(int, RecurringPayment)> charged({Object amount = 100}) async {
      final accountId = await newAccount();
      await recurring.insertRecurringPayment(
        name: 'Netflix',
        amount: amount,
        category: 'Dijital Abonelik',
        frequency: RecurrenceFrequency.monthly,
        nextDueDate: sqliteDateToday(),
        accountId: accountId,
      );
      final payment = (await recurring.getActiveRecurringPayments()).single;
      await recurring.processDueRecurringPayment(payment);
      return (accountId, payment);
    }

    test('finds the charge it wrote and puts the money back', () async {
      final (accountId, payment) = await charged();
      expect(await balanceOf(accountId), money('9900'));

      final charge = await recurring.findCurrentPeriodCharge(payment.id);
      expect(charge, isNotNull);
      expect(charge!.amount, money('100'));

      expect(
        await recurring.refundCurrentPeriodCharge(payment.id),
        money('100'),
      );
      expect(await balanceOf(accountId), money('10000'));
    });

    test('reverses rather than rewrites history', () async {
      // The original expense stays; a compensating income row is written, so
      // the ledger and the balance stay in step.
      final (_, payment) = await charged();
      await recurring.refundCurrentPeriodCharge(payment.id);

      final types = await db
          .customSelect('SELECT type FROM transactions ORDER BY id')
          .get();
      expect(
        [for (final row in types) row.read<String>('type')],
        ['expense', 'income'],
      );
    });

    test('a second refund returns zero and writes nothing', () async {
      final (accountId, payment) = await charged();
      await recurring.refundCurrentPeriodCharge(payment.id);
      final after = await count('transactions');

      expect(
        await recurring.refundCurrentPeriodCharge(payment.id),
        Decimal.zero,
      );
      expect(await count('transactions'), after);
      expect(await balanceOf(accountId), money('10000'));
    });

    test('no charge this period refunds nothing', () async {
      final accountId = await newAccount();
      final id = await recurring.insertRecurringPayment(
        name: 'Netflix',
        amount: 100,
        category: 'Dijital Abonelik',
        frequency: RecurrenceFrequency.monthly,
        nextDueDate: sqliteDateToday(),
        accountId: accountId,
      );
      expect(await recurring.findCurrentPeriodCharge(id), isNull);
      expect(await recurring.refundCurrentPeriodCharge(id), Decimal.zero);
      expect(await count('transactions'), 0);
    });

    test(
      'a corrupt charge amount is reported, not treated as no charge',
      () async {
        // Measured on the desktop before the guard: `inf` committed a refund
        // and left the balance permanently infinite; a negative or zero amount
        // was silently counted as "nothing to refund".
        for (final stored in ['nan', 'inf', '-inf', '-50.0', '0.0']) {
          await db.close();
          wire();
          final (accountId, payment) = await charged();
          await db.customUpdate(
            "UPDATE transactions SET amount = ? WHERE type = 'expense'",
            variables: [Variable<String>((await crypto.encryptField(stored))!)],
            updates: const {},
          );
          final before = await count('transactions');
          final balanceBefore = await balanceOf(accountId);

          await expectLater(
            () => recurring.refundCurrentPeriodCharge(payment.id),
            throwsA(isA<RecurringDataIntegrityError>()),
            reason: stored,
          );
          expect(await count('transactions'), before, reason: stored);
          expect(await balanceOf(accountId), balanceBefore, reason: stored);
        }
      },
    );
  });
}

/// Today, so a charge written now lands in the month
/// `findCurrentPeriodCharge` looks in.
DateTime sqliteDateToday() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}
