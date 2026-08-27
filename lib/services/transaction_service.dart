/// The ledger: everything that writes to `transactions`, and the balance
/// changes that go with it.
///
/// A port of the desktop's `services/transaction_service.py`. Two rules carry
/// the file:
///
///  * A transaction and the balance it moves are ONE commit. The credit-limit
///    decision is taken inside that commit too, against the same snapshot the
///    write will use.
///  * A future-dated transaction is `pending` and does NOT touch the balance.
///    Money does not appear in an account before its date; [settleDueTransactions]
///    applies it when the day arrives. Nothing else applies it, so a build
///    that never calls that method never posts a future-dated row at all.
///
/// Departures from the Python, each for a stated reason:
///
///  * [addTransaction] takes a `DateTime`, not a timestamp string. The desktop
///    had to pin down "always a full timestamp, never date-only" in a test —
///    a date-only row broke its time chart. A `DateTime` plus [sqliteTimestamp]
///    makes that structural instead.
///  * A row whose amount will not decrypt is REPORTED, not quietly counted as
///    zero. The desktop logs and substitutes 0.0; on a phone that log has no
///    reader, and a false ₺0,00 on screen is the exact failure the money layer
///    refuses ("showing no total is safer than showing a false one"). The
///    entry carries [LedgerEntry.isCorrupt] and [settleDueTransactions]
///    returns how many rows it had to skip.
///  * Subscription detection is not called. `recurring_service` is not ported
///    yet; the hook belongs here when it is.
///  * Display fallbacks are not invented here. The desktop substitutes the
///    category, then the word "İşlem", for a blank description; that choice
///    belongs to whatever renders the row.
///
/// Subscription detection is still absent — the hook `add_transaction` calls
/// after a card expense. It belongs here now that `recurring_service` exists.
library;

import 'dart:developer' as developer;

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';

import '../crypto/field_crypto.dart';
import '../crypto/key_provider.dart';
import '../data/balance_events.dart';
import '../data/database.dart';
import '../money/financial_decimal.dart';
import 'account_service.dart';

/// A window the dashboard reports over.
///
/// The desktop passes its Turkish UI labels ('1 Hafta', 'Hayat Boyu') as the
/// filter value, which makes the interface's wording part of the query. An
/// enum keeps the period a decision and leaves the wording to whatever draws
/// the chips.
enum DashboardPeriod {
  today,
  week,
  month,
  year,
  allTime;

  /// The SQL predicate for this window over [column].
  ///
  /// `localtime` matters: without it SQLite compares against UTC, and for the
  /// several hours a day when Türkiye is ahead of it, "today" would silently
  /// start yesterday.
  ///
  /// [column] is interpolated, so it must be a column name this file chooses —
  /// never anything a caller supplies.
  String condition(String column) => switch (this) {
    DashboardPeriod.today => "date($column) = date('now', 'localtime')",
    DashboardPeriod.week =>
      "date($column) >= date('now', '-7 days', 'localtime')",
    DashboardPeriod.month =>
      "date($column) >= date('now', '-1 month', 'localtime')",
    DashboardPeriod.year =>
      "date($column) >= date('now', '-1 year', 'localtime')",
    DashboardPeriod.allTime => 'date($column) IS NOT NULL',
  };
}

/// One completed transaction, as the dashboard reads it.
class PeriodEntry {
  const PeriodEntry({
    required this.amount,
    required this.type,
    required this.category,
    required this.transactionDate,
    required this.importance,
  });

  final Decimal amount;
  final String type;

  /// Never blank: an uncategorised row is filed under 'Diğer', matching the
  /// desktop, so a chart does not grow a nameless slice.
  final String category;
  final String transactionDate;

  /// `'main'` or `'extra'` — from the `categories` table, defaulting to
  /// `'extra'` for a category that has no row there.
  ///
  /// This said `'essential'` until the summary port was written, and nothing
  /// had ever compared the value, so the wrong word cost nothing until the
  /// moment it would have cost a bucket. 'Essential' is the name of the
  /// EXPENSE bucket that a 'main' importance lands in — see
  /// `financial_summary.dart` — not a value this column ever holds.
  final String importance;

  bool get isIncome => incomeTransactionTypes.contains(type);
  bool get isExpense => expenseTransactionTypes.contains(type);
}

/// An account's opening balance, with the moment it was recorded.
///
/// An opening balance NEVER reaches the `transactions` table — only
/// `accounts.balance` and a `balance_events` row. That is deliberate: a
/// savings rate or a cash-flow chart fed from the ledger must not be inflated
/// by money that was simply already there. The dashboard's distribution is
/// the one place it is shown, as its own slice, because a user with a single
/// newly opened account would otherwise see an empty chart beside a full
/// balance.
class OpeningEntry {
  const OpeningEntry({required this.amount, required this.recordedAt});

  final Decimal amount;
  final String recordedAt;
}

/// Stored `type` values that count as income.
const Set<String> incomeTransactionTypes = {'income', 'Gelir'};

/// Stored `type` values that count as an expense.
///
/// 'payment' is NOT here: a card debt payment moves money between the user's
/// own accounts, and counting it as spending would double-count the original
/// purchase.
const Set<String> expenseTransactionTypes = {'expense', 'Gider'};

/// Only rows in this state have been applied to a balance.
///
/// The condition is written with `COALESCE` because rows the desktop wrote
/// before the `status` column existed carry NULL and are, by definition,
/// completed.
const String completedTransactionCondition =
    "COALESCE(status, 'completed') = 'completed'";

/// The instalment table, created on first use.
///
/// The desktop creates it lazily too, which is why a fresh database
/// legitimately lacks it and `schema_parity_test.dart` exempts it. The DDL is
/// verbatim from `transaction_service.py` so that a table created by either
/// app is the same table.
const String _installmentsTable = 'installment_plans';

const String _createInstallmentsTable =
    '''CREATE TABLE IF NOT EXISTS $_installmentsTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        account_id INTEGER NOT NULL,
        description TEXT NOT NULL,
        total_amount TEXT NOT NULL,
        monthly_amount TEXT NOT NULL,
        total_installments INTEGER NOT NULL,
        paid_installments INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
    )''';

/// Rejected transaction input.
class TransactionError implements Exception {
  const TransactionError(this.code, this.message);

  final TransactionErrorCode code;
  final String message;

  @override
  String toString() => 'TransactionError(${code.name}): $message';
}

/// A ledger row whose amount could not be read, on a path where skipping it
/// would falsify a total rather than mark one row.
class TransactionDataIntegrityError implements Exception {
  const TransactionDataIntegrityError(this.transactionId, this.message);

  final int transactionId;
  final String message;

  @override
  String toString() =>
      'TransactionDataIntegrityError(transactions#$transactionId): $message';
}

enum TransactionErrorCode {
  invalidAmount,
  amountNotPositive,
  installmentCountOutOfRange,
  negativeLimit,
}

/// A transaction not yet due, and so not yet in any balance.
class PendingTransaction {
  const PendingTransaction({
    required this.id,
    required this.accountId,
    required this.amount,
    required this.type,
    required this.category,
    required this.description,
    required this.executionDate,
    required this.isCorrupt,
  });

  final int id;
  final int accountId;

  /// Null when the stored amount could not be decrypted. Render the row as
  /// unreadable; do not fall back to zero.
  final Decimal? amount;
  final String type;
  final String category;
  final String description;

  /// The day it falls due, as `YYYY-MM-DD`.
  final String executionDate;

  /// True when any encrypted column on the row failed to open.
  final bool isCorrupt;
}

/// One line of an account's statement.
class LedgerEntry {
  const LedgerEntry({
    required this.amount,
    required this.type,
    required this.category,
    required this.description,
    required this.date,
    required this.isCorrupt,
  });

  /// Null when the stored amount could not be decrypted.
  final Decimal? amount;
  final String type;
  final String category;
  final String description;

  /// The transaction day, as `YYYY-MM-DD`.
  final String date;
  final bool isCorrupt;
}

/// A running instalment plan on a card.
class InstallmentPlan {
  const InstallmentPlan({
    required this.id,
    required this.description,
    required this.totalAmount,
    required this.monthlyAmount,
    required this.totalInstallments,
    required this.paidInstallments,
    required this.createdAt,
  });

  final int id;
  final String description;
  final Decimal totalAmount;
  final Decimal monthlyAmount;
  final int totalInstallments;
  final int paidInstallments;
  final String createdAt;

  int get remainingInstallments => totalInstallments - paidInstallments;

  /// What is left to pay.
  ///
  /// Derived from what has been paid rather than stored, so it cannot drift
  /// away from the counter beside it.
  Decimal get remainingAmount =>
      fiat(totalAmount - monthlyAmount * Decimal.fromInt(paidInstallments));
}

/// What one settlement round did.
class SettleOutcome {
  const SettleOutcome({required this.settled, required this.skipped});

  /// How many transactions were applied to a balance.
  final int settled;

  /// How many due rows could not be applied and were left `pending`.
  ///
  /// Non-zero means either an unreadable amount or a write that failed. The
  /// rows are still there and a later round will try again; a build that
  /// ignores this number silently loses money off the screen.
  final int skipped;
}

class TransactionService {
  TransactionService(this._db, this._crypto, this._accounts);

  final ArchlenceDatabase _db;
  final FieldCrypto _crypto;
  final AccountService _accounts;

  /// Records a transaction and, unless it is future-dated, applies it to the
  /// balance.
  ///
  /// [transactionDate] defaults to now. A back-dated import passes it
  /// explicitly and still travels this same atomic path.
  ///
  /// A card expense is checked against the available limit. An import
  /// reconstructing history passes `enforceCreditLimit: false`: a real past
  /// spend that filled the limit has to be importable, and refusing it would
  /// make the reconstruction wrong.
  ///
  /// [installments] (2-12) makes it an instalment purchase: the WHOLE amount
  /// is charged to the card at once, because that is what the bank blocks
  /// against the limit, and the monthly plan is written in the same commit so
  /// the two can never come apart. A count of 1 is not an instalment plan.
  ///
  /// Returns the new transaction's id.
  Future<int> addTransaction({
    required int accountId,
    required Object? amount,
    required String transactionType,
    String category = '',
    String description = '',
    DateTime? transactionDate,
    bool enforceCreditLimit = true,
    int? installments,
  }) async {
    // The service boundary for money arriving from a form, an import or an
    // API. SQLite must never be the thing that decides what NaN means for a
    // financial operation.
    final Decimal quantized;
    try {
      quantized = fiat(amount);
    } on FinancialValueError catch (error) {
      throw TransactionError(
        TransactionErrorCode.invalidAmount,
        'The transaction amount must be a finite number: ${error.message}',
      );
    }
    if (quantized <= Decimal.zero) {
      throw const TransactionError(
        TransactionErrorCode.amountNotPositive,
        'The transaction amount must be greater than zero.',
      );
    }

    var planCount = installments;
    if (planCount != null) {
      if (planCount < 1 || planCount > 12) {
        throw const TransactionError(
          TransactionErrorCode.installmentCountOutOfRange,
          'The instalment count must be between 1 and 12.',
        );
      }
      if (planCount == 1) {
        planCount = null;
      }
    }

    // The legacy schema stores money as REAL, and sqlite3 has no Decimal
    // adapter, so only an already-quantized finite value crosses over.
    final amountAsDouble = quantized.toDouble();

    final when = transactionDate ?? DateTime.now();
    final stamp = sqliteTimestamp(when);
    final isFuture = _isAfterToday(when);
    final status = isFuture ? 'pending' : 'completed';

    return _db.transaction(() async {
      // Inside the transaction, so the limit decision and the balance write
      // see one snapshot. Drift opens this with BEGIN IMMEDIATE, which
      // serialises competing card charges before either can spend the same
      // available limit.
      await _accounts.assertSpendingAllowed(
        accountId,
        quantized,
        transactionType: transactionType,
        enforceLimits: enforceCreditLimit,
      );

      final encryptedAmount = await _crypto.encryptField(
        amountAsDouble.toString(),
      );
      final encryptedDescription = await _crypto.encryptField(description);

      final transactionId = await _db.customInsert(
        'INSERT INTO transactions (account_id, amount, type, category, '
        'description, transaction_date, status, execution_date) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        variables: [
          Variable<int>(accountId),
          Variable<String>(encryptedAmount),
          Variable<String>(transactionType),
          Variable<String>(category),
          Variable<String>(encryptedDescription),
          Variable<String>(stamp),
          Variable<String>(status),
          Variable<String>(stamp),
        ],
      );

      if (!isFuture) {
        await adjustAccountBalance(
          _db,
          accountId: accountId,
          transactionType: transactionType,
          amount: amountAsDouble,
          refId: transactionId,
        );
      }

      if (planCount != null) {
        final monthly = fiat(
          (quantized / Decimal.fromInt(planCount)).toDecimal(
            scaleOnInfinitePrecision: 20,
          ),
        );
        await _db.customStatement(_createInstallmentsTable);
        await _db.customInsert(
          'INSERT INTO $_installmentsTable (account_id, description, '
          'total_amount, monthly_amount, total_installments, '
          'paid_installments, created_at) VALUES (?, ?, ?, ?, ?, 0, ?)',
          variables: [
            Variable<int>(accountId),
            Variable<String>(encryptedDescription),
            Variable<String>(
              await _crypto.encryptField(amountAsDouble.toString()),
            ),
            Variable<String>(await _crypto.encryptField(monthly.toString())),
            Variable<int>(planCount),
            Variable<String>(stamp),
          ],
        );
      }

      return transactionId;
    });
  }

  /// Applies every future-dated transaction whose day has arrived.
  ///
  /// Safe to call repeatedly: the query selects `pending` and the update sets
  /// `completed`, so nothing is applied to a balance twice.
  ///
  /// Each row settles inside its own savepoint, so one unreadable amount does
  /// not strand the rows behind it.
  ///
  /// The credit limit is NOT re-checked. A bill falling due is not left
  /// unprocessed because the limit is full — it becomes debt. The limit was
  /// the question when the row was created.
  ///
  /// A frozen account is skipped entirely, and its rows stay pending.
  Future<SettleOutcome> settleDueTransactions({DateTime? today}) async {
    final referenceDay = sqliteTimestamp(today ?? DateTime.now())
        .substring(0, 10);

    var settled = 0;
    var skipped = 0;

    await _db.transaction(() async {
      final dueRows = await _db
          .customSelect(
            'SELECT t.id, t.account_id, t.amount, t.type, '
            'COALESCE(a.is_frozen, 0) AS is_frozen '
            'FROM transactions AS t '
            'LEFT JOIN accounts AS a ON a.id = t.account_id '
            "WHERE t.status = 'pending' AND date(t.execution_date) <= date(?) "
            'ORDER BY date(t.execution_date), t.id',
            variables: [Variable<String>(referenceDay)],
          )
          .get();

      for (final row in dueRows) {
        if (row.read<int>('is_frozen') != 0) {
          continue;
        }

        final Decimal amount;
        try {
          amount = fiat(await _crypto.decryptField(row.read<String>('amount')));
        } on KeyUnavailableError {
          // A missing key is a configuration problem, not a corrupt row.
          // Skipping every transaction over it would look like the ledger had
          // emptied itself.
          rethrow;
        } on Exception catch (error) {
          developer.log(
            'Pending transaction ${row.read<int>('id')} has an amount that '
            'could not be read; leaving it pending.',
            name: 'archlence.transactions',
            error: error,
          );
          skipped++;
          continue;
        }

        try {
          // A nested transaction is a SAVEPOINT: this row rolls back alone.
          await _db.transaction(() async {
            await adjustAccountBalance(
              _db,
              accountId: row.read<int>('account_id'),
              transactionType: row.read<String>('type'),
              amount: amount.toDouble(),
              refId: row.read<int>('id'),
            );
            await _db.customUpdate(
              "UPDATE transactions SET status = 'completed' WHERE id = ?",
              variables: [Variable<int>(row.read<int>('id'))],
              updates: const {},
            );
          });
        } on Exception catch (error) {
          developer.log(
            'Due transaction ${row.read<int>('id')} could not be settled; '
            'continuing with the rest.',
            name: 'archlence.transactions',
            error: error,
          );
          skipped++;
          continue;
        }
        settled++;
      }
    });

    return SettleOutcome(settled: settled, skipped: skipped);
  }

  /// Transactions not yet due, oldest first.
  Future<List<PendingTransaction>> getPendingTransactions() async {
    final rows = await _db
        .customSelect(
          'SELECT id, account_id, amount, type, category, description, '
          "execution_date FROM transactions WHERE status = 'pending' "
          'ORDER BY date(execution_date), id',
        )
        .get();

    final items = <PendingTransaction>[];
    for (final row in rows) {
      final amount = await _readAmount(row.read<String>('amount'));
      final description = await _readText(row.data['description']);
      items.add(
        PendingTransaction(
          id: row.read<int>('id'),
          accountId: row.read<int>('account_id'),
          amount: amount,
          type: row.read<String>('type'),
          category: row.data['category'] as String? ?? '',
          description: description ?? '',
          executionDate: _dayOf(row.data['execution_date'] as String?),
          isCorrupt: amount == null || description == null,
        ),
      );
    }
    return items;
  }

  /// Deletes a pending transaction. Returns whether a row went.
  ///
  /// Only `pending` rows are touched. Deleting one that has already moved a
  /// balance would leave the balance without the record that explains it.
  Future<bool> cancelPendingTransaction(int transactionId) async {
    final deleted = await _db.customUpdate(
      "DELETE FROM transactions WHERE id = ? AND status = 'pending'",
      variables: [Variable<int>(transactionId)],
      updates: const {},
    );
    return deleted > 0;
  }

  /// Moves a pending transaction's due date. Returns whether a row moved.
  ///
  /// No balance is applied here even if the new date is today: the next
  /// settlement round picks it up, so posting stays in one place.
  Future<bool> reschedulePendingTransaction(
    int transactionId,
    DateTime newDate,
  ) async {
    // 09:00 local, matching the desktop, so a rescheduled row sorts against
    // existing ones the same way in both apps.
    final stamp = sqliteTimestamp(
      DateTime(newDate.year, newDate.month, newDate.day, 9),
    );
    final updated = await _db.customUpdate(
      'UPDATE transactions SET transaction_date = ?, execution_date = ? '
      "WHERE id = ? AND status = 'pending'",
      variables: [
        Variable<String>(stamp),
        Variable<String>(stamp),
        Variable<int>(transactionId),
      ],
      updates: const {},
    );
    return updated > 0;
  }

  /// A card's instalment plans that still have instalments left.
  ///
  /// A plan whose amounts will not decrypt is left out rather than shown with
  /// a wrong figure; the count of what was dropped is not returned, because
  /// unlike a due transaction there is no balance waiting on it.
  Future<List<InstallmentPlan>> getInstallmentPlans(int accountId) async {
    await _db.customStatement(_createInstallmentsTable);
    final rows = await _db
        .customSelect(
          'SELECT * FROM $_installmentsTable WHERE account_id = ? '
          'AND paid_installments < total_installments '
          'ORDER BY created_at DESC, id DESC',
          variables: [Variable<int>(accountId)],
        )
        .get();

    final plans = <InstallmentPlan>[];
    for (final row in rows) {
      final total = await _readAmount(row.read<String>('total_amount'));
      final monthly = await _readAmount(row.read<String>('monthly_amount'));
      if (total == null || monthly == null) {
        developer.log(
          'Instalment plan ${row.read<int>('id')} has amounts that could not '
          'be read; leaving it out of the list.',
          name: 'archlence.transactions',
        );
        continue;
      }
      plans.add(
        InstallmentPlan(
          id: row.read<int>('id'),
          description: await _readText(row.data['description']) ?? '',
          totalAmount: total,
          monthlyAmount: monthly,
          totalInstallments: row.read<int>('total_installments'),
          paidInstallments: row.read<int>('paid_installments'),
          createdAt: row.read<String>('created_at'),
        ),
      );
    }
    return plans;
  }

  /// An account's completed transactions, newest first.
  ///
  /// Ordering and the limit stay in SQL, over plain columns; the amount and
  /// description are encrypted and so cannot be sorted or aggregated there.
  Future<List<LedgerEntry>> getRecentForAccount(
    int accountId, {
    int? limit = 3,
  }) async {
    if (limit != null && limit < 0) {
      throw const TransactionError(
        TransactionErrorCode.negativeLimit,
        'The limit cannot be negative.',
      );
    }

    final rows = await _db
        .customSelect(
          'SELECT amount, type, category, description, transaction_date '
          'FROM transactions WHERE account_id = ? '
          'AND $completedTransactionCondition '
          'ORDER BY transaction_date DESC, id DESC'
          '${limit == null ? '' : ' LIMIT ?'}',
          variables: [
            Variable<int>(accountId),
            if (limit != null) Variable<int>(limit),
          ],
        )
        .get();

    final items = <LedgerEntry>[];
    for (final row in rows) {
      final amount = await _readAmount(row.read<String>('amount'));
      final description = await _readText(row.data['description']);
      items.add(
        LedgerEntry(
          amount: amount,
          type: row.read<String>('type'),
          category: row.data['category'] as String? ?? '',
          description: description ?? '',
          date: _dayOf(row.data['transaction_date'] as String?),
          isCorrupt: amount == null || description == null,
        ),
      );
    }
    return items;
  }

  /// The categories available for a transaction of [transactionType].
  ///
  /// Read from the table rather than a constant, so a category the user adds
  /// on the desktop appears here after a restore.
  Future<List<String>> getCategories(String transactionType) async {
    final wanted = incomeTransactionTypes.contains(transactionType)
        ? 'income'
        : 'expense';
    final rows = await _db
        .customSelect(
          'SELECT name FROM categories WHERE type = ? ORDER BY id',
          variables: [Variable<String>(wanted)],
        )
        .get();
    return [for (final row in rows) row.read<String>('name')];
  }

  /// Completed transactions inside [period].
  ///
  /// An amount that cannot be read RAISES rather than being skipped: this
  /// feeds totals and a distribution chart, and a slice quietly missing from
  /// a pie is a wrong picture presented as a right one. That is the same
  /// choice `BudgetService` makes, and the opposite of
  /// [getRecentForAccount] — a statement row can honestly say "unreadable"
  /// beside its neighbours, a percentage cannot.
  Future<List<PeriodEntry>> getTransactionsByPeriod(
    DashboardPeriod period,
  ) async {
    final rows = await _db
        .customSelect(
          'SELECT t.id, t.amount, t.type, t.category, t.transaction_date, '
          'c.importance FROM transactions t '
          'LEFT JOIN categories c ON t.category = c.name '
          'WHERE ${period.condition('t.transaction_date')} '
          "AND COALESCE(t.status, 'completed') = 'completed'",
        )
        .get();

    final entries = <PeriodEntry>[];
    for (final row in rows) {
      final Decimal amount;
      try {
        amount = fiat(await _crypto.decryptField(row.read<String>('amount')));
      } on KeyUnavailableError {
        rethrow;
      } on Exception catch (error) {
        throw TransactionDataIntegrityError(row.read<int>('id'), '$error');
      }
      final category = row.data['category'] as String?;
      entries.add(
        PeriodEntry(
          amount: amount,
          type: row.read<String>('type'),
          category: category == null || category.isEmpty ? 'Diğer' : category,
          transactionDate: row.data['transaction_date'] as String? ?? '',
          importance: row.data['importance'] as String? ?? 'extra',
        ),
      );
    }
    return entries;
  }

  /// The opening balances recorded inside [period].
  ///
  /// A credit card's opening DEBT is excluded — it arrives as a negative
  /// delta, and a debt appearing in an income breakdown would make no sense.
  Future<List<OpeningEntry>> getOpeningEventsByPeriod(
    DashboardPeriod period,
  ) async {
    final rows = await _db
        .customSelect(
          'SELECT ts, delta FROM balance_events '
          "WHERE entity_type = ? AND source = 'account_opened' "
          'AND ${period.condition('ts')} ORDER BY ts',
          variables: [Variable<String>(accountEntity)],
        )
        .get();

    return [
      for (final row in rows)
        if (row.read<double>('delta') > 0)
          OpeningEntry(
            amount: fiat(row.read<double>('delta')),
            recordedAt: row.read<String>('ts'),
          ),
    ];
  }

  /// The total of the opening balances inside [period].
  Future<Decimal> getOpeningBaselineByPeriod(DashboardPeriod period) async {
    var total = Decimal.zero;
    for (final entry in await getOpeningEventsByPeriod(period)) {
      total += entry.amount;
    }
    return fiat(total);
  }

  /// Decrypts a stored amount, or returns null if the row cannot be read.
  ///
  /// A missing key is rethrown: it says nothing about this row, and treating
  /// every row as corrupt because of it would misreport a settings problem as
  /// data loss.
  Future<Decimal?> _readAmount(Object? stored) async {
    try {
      return fiat(await _crypto.decryptField(stored));
    } on KeyUnavailableError {
      rethrow;
    } on Exception {
      return null;
    }
  }

  Future<String?> _readText(Object? stored) async {
    try {
      return (await _crypto.decryptField(stored))?.trim() ?? '';
    } on KeyUnavailableError {
      rethrow;
    } on Exception {
      return null;
    }
  }

  static String _dayOf(String? stamp) =>
      stamp == null || stamp.length < 10 ? '' : stamp.substring(0, 10);

  /// Is [when] on a later DAY than today? The time of day is irrelevant: a
  /// transaction entered at 23:00 for today is today's.
  static bool _isAfterToday(DateTime when) {
    final now = DateTime.now();
    return DateTime(
      when.year,
      when.month,
      when.day,
    ).isAfter(DateTime(now.year, now.month, now.day));
  }
}
