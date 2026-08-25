/// The balance ledger: one row for every change to an account or a savings
/// goal.
///
/// A port of `record_balance_event` in the desktop's `database/db.py`. The
/// point of the ledger is that replaying it reproduces the current balance,
/// which only holds if every event lands in the same transaction as the
/// balance change it describes — a rolled-back UPDATE with a committed event
/// leaves a ghost row and the replay drifts.
library;

import 'package:drift/drift.dart';

import 'database.dart';

/// `entity_type` values, matching the constants in `database/db.py`.
const String accountEntity = 'account';
const String savingsGoalEntity = 'savings_goal';

/// Appends one event and returns its row id.
///
/// [db] is whatever handle the caller is already writing through. Inside
/// `ArchlenceDatabase.transaction`, drift routes these statements into that
/// transaction, so passing the database itself is enough to stay in the
/// caller's commit — but calling this outside one writes immediately, which
/// is exactly the failure mode above.
///
/// Events whose delta is zero are written too. An account opened at zero does
/// not move any total, but leaving it out would make the ledger's record of
/// the account's existence incomplete.
Future<int> recordBalanceEvent(
  DatabaseConnectionUser db, {
  required String entityType,
  required int entityId,
  required double delta,
  required double? resultingValue,
  required String source,
  int? refId,
}) {
  return db.customInsert(
    'INSERT INTO balance_events '
    '(ts, entity_type, entity_id, delta, resulting_value, source, ref_id) '
    'VALUES (?, ?, ?, ?, ?, ?, ?)',
    variables: [
      Variable<String>(sqliteTimestamp(DateTime.now())),
      Variable<String>(entityType),
      Variable<int>(entityId),
      Variable<double>(delta),
      Variable<double>(resultingValue),
      Variable<String>(source),
      Variable<int>(refId),
    ],
  );
}

/// A balance change named an account that does not exist.
///
/// Fail loud rather than write an ownerless record: the desktop removed its
/// seeded default account, so a stale `DEFAULT_ACCOUNT_ID` matches nothing on
/// a fresh install and the rows it produced belonged to no one.
class UnknownAccountError implements Exception {
  const UnknownAccountError(this.accountId);

  final int accountId;

  @override
  String toString() =>
      'UnknownAccountError: no account with id $accountId; the balance change '
      'could not be applied.';
}

/// Moves `accounts.balance` in step with a transaction, and records the move.
///
/// Takes the caller's handle so the balance, the ledger row and whatever
/// `transactions` row prompted them all land in one commit. Splitting them
/// across connections would leave an observable state where the ledger and
/// the balance disagree.
///
/// THE SIGN: income adds, everything else subtracts. On a checking account
/// that is the obvious arithmetic; on a credit card it means an expense
/// pushes the balance further negative — the debt GROWS — and a payment moves
/// it toward zero. The one benefit that justifies the convention is that net
/// worth stays correct from a plain `SUM(balance)`, so no caller has to tell
/// the two kinds of account apart.
///
/// 'Gelir' is the Turkish spelling carried by rows the desktop wrote before
/// its columns were standardised, and is still accepted on the way in.
Future<void> adjustAccountBalance(
  DatabaseConnectionUser db, {
  required int accountId,
  required String transactionType,
  required double amount,
  int? refId,
  String source = 'transaction',
}) async {
  final delta = (transactionType == 'income' || transactionType == 'Gelir')
      ? amount
      : -amount;

  final updated = await db.customUpdate(
    'UPDATE accounts SET balance = balance + ? WHERE id = ?',
    variables: [Variable<double>(delta), Variable<int>(accountId)],
    updates: const {},
  );
  if (updated == 0) {
    throw UnknownAccountError(accountId);
  }

  final row = await db
      .customSelect(
        'SELECT balance FROM accounts WHERE id = ?',
        variables: [Variable<int>(accountId)],
      )
      .getSingle();

  await recordBalanceEvent(
    db,
    entityType: accountEntity,
    entityId: accountId,
    delta: delta,
    resultingValue: row.read<double>('balance'),
    source: source,
    refId: refId,
  );
}
