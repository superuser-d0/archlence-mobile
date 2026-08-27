/// What the accounts held at the end of a past day.
///
/// **A narrow slice of the desktop's `history_service.py`, and only that.**
/// The full module is the "time machine" — 321 lines, `diff_between`, event
/// attribution by source — and the roadmap keeps it out of 1.0 deliberately.
/// The balance ring's change chip needs exactly one of its questions, and this
/// answers that one.
///
/// **It derives BACKWARDS from the current balance, where the desktop replays
/// forwards from a snapshot.** The desktop starts at the nearest
/// `daily_balance_snapshot` and adds every event since; this takes what the
/// accounts hold now and subtracts every event since the date asked about.
/// The two are algebraically the same whenever the ledger is complete —
/// `sum(all deltas) - sum(deltas after d)` is `sum(deltas up to d)` — and
/// where they differ, anchoring on the balance the accounts ACTUALLY hold is
/// the one that cannot drift.
///
/// That also removes the need for `daily_balance_snapshot` entirely, which is
/// convenient: nothing in this app writes that table. The snapshot is an
/// optimisation for replaying forward, and there is no forward replay here.
///
/// **Before the ledger begins, the answer is "not known", never zero.** The
/// desktop's own rule, and the important one: a date earlier than the oldest
/// recorded event is a date this app has no information about, and answering
/// zero would tell the user they had no money at all.
library;

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';

import '../data/balance_events.dart';
import '../data/database.dart';
import '../money/financial_decimal.dart';

class BalanceHistoryService {
  BalanceHistoryService(this._db);

  final ArchlenceDatabase _db;

  /// The day of the oldest event in the ledger, as `YYYY-MM-DD`, or null when
  /// nothing has ever been recorded.
  Future<String?> ledgerStartDate() async {
    final row = await _db
        .customSelect(
          "SELECT MIN(date(ts)) AS started FROM balance_events "
          'WHERE entity_type = ?',
          variables: [Variable<String>(accountEntity)],
        )
        .getSingle();
    return row.data['started'] as String?;
  }

  /// What the accounts totalled at the END of [day], or null if that cannot
  /// be known.
  ///
  /// Null means one of two things, and both are "no answer" rather than zero:
  /// the ledger holds nothing at all, or [day] falls before it begins.
  Future<Decimal?> totalAt(DateTime day) async {
    final started = await ledgerStartDate();
    if (started == null) return null;

    final date =
        '${day.year.toString().padLeft(4, '0')}-'
        '${day.month.toString().padLeft(2, '0')}-'
        '${day.day.toString().padLeft(2, '0')}';
    if (date.compareTo(started) < 0) return null;

    // `ts` is stored as 'YYYY-MM-DD HH:MM:SS', so a string comparison is
    // chronological and '<= date 23:59:59' covers the whole day. Everything
    // AFTER that boundary is what gets subtracted.
    final row = await _db
        .customSelect(
          'SELECT COALESCE(SUM(delta), 0) AS moved FROM balance_events '
          'WHERE entity_type = ? AND ts > ?',
          variables: [
            Variable<String>(accountEntity),
            Variable<String>('$date 23:59:59'),
          ],
        )
        .getSingle();

    final since = fiat(row.read<double>('moved'));
    return fiat(await _currentTotal() - since);
  }

  /// What every account holds right now.
  ///
  /// Read from `accounts.balance` rather than by replaying the whole ledger:
  /// that column is the truth the rest of the app shows, and a history that
  /// disagreed with the balance on screen would be the wrong one.
  Future<Decimal> _currentTotal() async {
    final row = await _db
        .customSelect('SELECT COALESCE(SUM(balance), 0) AS total FROM accounts')
        .getSingle();
    return fiat(row.read<double>('total'));
  }
}
