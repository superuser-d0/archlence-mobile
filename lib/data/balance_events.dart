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
