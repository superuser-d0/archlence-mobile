/// The month grid and one day's transactions.
///
/// A port of the desktop's `services/calendar_service.py`.
///
/// **The split between SQL and Dart is the whole design.** `amount` and
/// `description` are AES-encrypted TEXT, so neither can be grouped or filtered
/// in SQL. What the month grid needs is only a DAY and a COUNT, and both come
/// off the plain `transaction_date` — so a month costs one aggregate query and
/// opens nothing. Only the day a user actually taps is decrypted.
///
/// **No `localtime` here, unlike the dashboard's periods.** `DashboardPeriod`
/// compares against `now`, so it has to convert; this compares against a date
/// the caller names, and the stored stamp is already local. Adding a
/// conversion would shift every day of the grid by the timezone offset.
library;

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';

import '../crypto/field_crypto.dart';
import '../data/database.dart';
import 'transaction_service.dart';

/// One transaction on a day, as the calendar draws it.
class CalendarEntry {
  const CalendarEntry({
    required this.amount,
    required this.type,
    required this.category,
    required this.description,
    required this.time,
    required this.isCorrupt,
  });

  /// Null when the stored amount could not be decrypted.
  ///
  /// **The desktop substitutes 0.0 here and logs.** This does not, for the
  /// reason the roadmap settled once for the whole app: on a phone that log
  /// has no reader, and a day listing a real expense as ₺0,00 is a wrong
  /// number presented as a right one. The row is still listed — dropping it
  /// would hide that anything happened — but it says it cannot be read.
  final Decimal? amount;

  final String type;

  /// Never blank: an uncategorised row is filed under 'Diğer', as the desktop
  /// does, so a list does not grow a nameless line.
  final String category;

  final String description;

  /// `HH:MM` off the stored stamp.
  final String time;

  final bool isCorrupt;

  bool get isIncome => incomeTransactionTypes.contains(type);
  bool get isExpense => expenseTransactionTypes.contains(type);
}

class CalendarService {
  CalendarService(this._db, this._crypto);

  final ArchlenceDatabase _db;
  final FieldCrypto _crypto;

  /// `{day of month: how many transactions}` — which days the grid marks.
  ///
  /// A month with nothing in it returns an empty map rather than a map of
  /// zeroes: "no transactions" and "a day with none" are the same thing to a
  /// caller, and building 31 entries to say it would be work for nothing.
  Future<Map<int, int>> getMonthTransactionDays(int year, int month) async {
    final rows = await _db
        .customSelect(
          "SELECT CAST(strftime('%d', transaction_date) AS INTEGER) AS day, "
          'COUNT(*) AS cnt FROM transactions '
          "WHERE strftime('%Y-%m', transaction_date) = ? "
          'AND $completedTransactionCondition '
          'GROUP BY day',
          variables: [
            Variable<String>(
              '${year.toString().padLeft(4, '0')}-'
              '${month.toString().padLeft(2, '0')}',
            ),
          ],
        )
        .get();

    return {
      for (final row in rows)
        // A row whose stamp will not parse as a day is dropped rather than
        // filed under a made-up one. `strftime` gives NULL for a malformed
        // date, and CAST(NULL) stays null.
        if (row.data['day'] != null)
          row.read<int>('day'): row.read<int>('cnt'),
    };
  }

  /// One day's transactions, earliest first.
  ///
  /// [day]'s time of day is ignored — only its date is used.
  Future<List<CalendarEntry>> getDayTransactions(DateTime day) async {
    final date =
        '${day.year.toString().padLeft(4, '0')}-'
        '${day.month.toString().padLeft(2, '0')}-'
        '${day.day.toString().padLeft(2, '0')}';

    final rows = await _db
        .customSelect(
          'SELECT type, category, amount, description, '
          "strftime('%H:%M', transaction_date) AS time "
          'FROM transactions WHERE date(transaction_date) = ? '
          'AND $completedTransactionCondition '
          'ORDER BY transaction_date ASC, id ASC',
          variables: [Variable<String>(date)],
        )
        .get();

    final entries = <CalendarEntry>[];
    for (final row in rows) {
      final amount = await readStoredAmount(_crypto, row.data['amount']);
      final description = await readStoredText(
        _crypto,
        row.data['description'],
      );
      final category = row.data['category'] as String?;
      entries.add(
        CalendarEntry(
          amount: amount,
          type: row.data['type'] as String? ?? '',
          category: category == null || category.isEmpty ? 'Diğer' : category,
          description: description ?? '',
          time: row.data['time'] as String? ?? '',
          isCorrupt: amount == null || description == null,
        ),
      );
    }
    return entries;
  }
}
