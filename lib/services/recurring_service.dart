/// Recurring payments and the subscription radar.
///
/// A port of `services/recurring_service.py` together with the
/// `recurring_payments` helpers that live in the desktop's `database/db.py`
/// (`insert_recurring_payment`, `get_active_recurring_payments`,
/// `has_active_recurring_payment`, `_advance_due_date`,
/// `process_due_recurring_payment`).
///
/// THE SINGLE RECORD LOCATION is `recurring_payments`. The desktop once had a
/// second `subscriptions` table that nothing ever read; two sources of truth,
/// one of them empty, is silent inconsistency, so it does not exist here.
///
/// Departures from the Python, each for a stated reason:
///
///  * An unreadable name or a non-positive amount reads back as `null`, not
///    as `"Bilinmeyen Ödeme"` / `0.0`. Same reasoning as
///    `LedgerEntry.isCorrupt`: a placeholder that looks like data is worse
///    than an absence that says so.
///  * [RecurringService.processDueRecurringPayment] REFUSES a payment whose
///    name cannot be read, where the desktop charges it under a placeholder.
///    The description is the only key [RecurringService.findCurrentPeriodCharge]
///    has, so a charge written as `"Bilinmeyen Ödeme (Otomatik)"` can never be
///    refunded — and with two such rows, a refund would match the wrong one.
///  * `apply_category_trigger` is not ported: it flips a Kivy switch widget.
library;

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';

import '../crypto/field_crypto.dart';
import '../crypto/key_provider.dart';
import '../data/balance_events.dart';
import '../data/database.dart';
import '../money/financial_decimal.dart';
import 'account_service.dart';

/// The category that turns the "recurring" switch on by itself.
const String subscriptionCategory = 'Dijital Abonelik';

/// Categories that are, on their own, enough to call something a
/// subscription. Stored strings, so they stay Turkish — the desktop groups
/// on the literal.
const Set<String> subscriptionCategories = {
  'Dijital Abonelik',
  'Dijital Platformlar',
  'Yazılım & Lisans',
  'Eğitim & Kurs',
  'Spor & Sağlık (Abonelik)',
  'Bağış (Düzenli)',
};

/// Brand names that identify a subscription from a transaction description.
///
/// Verbatim from the desktop's `KNOWN_BRANDS`. It is a heuristic list, not a
/// contract: adding to it only widens what the radar notices.
const List<String> knownBrands = [
  'netflix',
  'spotify',
  'youtube premium',
  'youtube music',
  'amazon prime',
  'prime video',
  'disney+',
  'disney plus',
  'blutv',
  'exxen',
  'mubi',
  'deezer',
  'tabii',
  'hbo max',
  'apple music',
  'apple tv',
  'apple one',
  'twitch',
  'paramount plus',
  'paramount+',
  'peacock',
  'crunchyroll',
  'tidal',
  'soundcloud go',
  'soundcloud',
  'storytel',
  'audible',
  'kindle unlimited',
  'blinkist',
  'adobe',
  'creative cloud',
  'microsoft 365',
  'office 365',
  'icloud',
  'google one',
  'dropbox',
  'notion',
  'figma',
  'canva',
  'jetbrains',
  'github',
  '1password',
  'lastpass',
  'nordvpn',
  'expressvpn',
  'proton vpn',
  'protonvpn',
  'proton mail',
  'protonmail',
  'proton pass',
  'protonpass',
  'proton drive',
  'protondrive',
  'proton calendar',
  'protoncalendar',
  'proton unlimited',
  'proton duo',
  'proton family',
  'proton visionary',
  'proton',
  'türk telekom',
  'turk telekom',
  'türktelekom',
  'turktelekom',
  'ttnet',
  'vodafone türkiye',
  'vodafone turkey',
  'vodafone net',
  'vodafone',
  'turkcell superonline',
  'superonline',
  'turkcell',
  'chatgpt',
  'openai',
  'claude',
  'anthropic',
  'gemini advanced',
  'slack',
  'zoom',
  'linkedin premium',
  'meta verified',
  'udemy',
  'coursera',
  'duolingo',
  'skillshare',
  'macfit',
  'club sporium',
  'clubsporium',
  'sporium',
  'strava',
  'headspace',
  'spotify premium',
  'patreon',
  'wikipedia',
  'playstation plus',
  'ps plus',
  'xbox game pass',
  'game pass',
  'nintendo online',
  'ea play',
  'ubisoft+',
  'ubisoft plus',
];

/// How often a recurring payment comes round.
enum RecurrenceFrequency {
  weekly('weekly'),
  biweekly('biweekly'),
  monthly('monthly'),
  quarterly('quarterly'),
  yearly('yearly');

  const RecurrenceFrequency(this.wireValue);

  /// The exact string in `recurring_payments.frequency`.
  final String wireValue;

  /// Reads a stored frequency, rejecting anything unrecognised.
  ///
  /// The desktop is explicit that an unknown value must NOT be silently
  /// treated as monthly: a payment quietly rescheduled to the wrong period
  /// is worse than one that fails loudly.
  static RecurrenceFrequency fromWire(String? value) {
    for (final frequency in RecurrenceFrequency.values) {
      if (frequency.wireValue == value) return frequency;
    }
    throw RecurringError(
      RecurringErrorCode.unknownFrequency,
      'Unsupported recurrence frequency: $value',
    );
  }
}

enum RecurringErrorCode {
  unknownFrequency,
  invalidRecurrenceDay,
  invalidAmount,
  amountNotPositive,
  invalidTransactionType,
  unreadablePayment,
}

class RecurringError implements Exception {
  const RecurringError(this.code, this.message);

  final RecurringErrorCode code;
  final String message;

  @override
  String toString() => 'RecurringError(${code.name}): $message';
}

/// A charge or refund whose stored amount is unusable.
///
/// Distinct from a missing charge: "there was no charge this month" and
/// "there was one but its amount is corrupt" must not collapse into the same
/// answer, or a corrupt row reads as nothing to refund.
class RecurringDataIntegrityError implements Exception {
  const RecurringDataIntegrityError(this.table, this.recordId, this.field);

  final String table;
  final int? recordId;
  final String field;

  @override
  String toString() =>
      'RecurringDataIntegrityError($table#$recordId.$field): the stored value '
      'could not be read as a positive amount.';
}

/// One active recurring payment, decrypted.
class RecurringPayment {
  const RecurringPayment({
    required this.id,
    required this.name,
    required this.amount,
    required this.category,
    required this.frequency,
    required this.nextDueDate,
    required this.recurrenceDay,
    required this.autoDeduct,
    required this.accountId,
    required this.transactionType,
  });

  final int id;

  /// Null when the stored name could not be decrypted.
  final String? name;

  /// Null when the stored amount could not be read OR is not positive.
  ///
  /// The column is a MAGNITUDE — direction lives in [transactionType] — so a
  /// negative value is not a reversed payment but an invalid record. The
  /// desktop learned this the expensive way: a stored -10.00 entered the
  /// monthly budget as a -10.00 reserve and silently overstated the
  /// spendable amount by 10 lira.
  final Decimal? amount;

  final String? category;
  final String frequency;
  final String nextDueDate;
  final int? recurrenceDay;
  final bool autoDeduct;
  final int accountId;
  final String transactionType;

  bool get amountIsValid => amount != null;

  /// The day of the month this repeats on, falling back to the day in
  /// [nextDueDate] for rows written before the column existed.
  int get effectiveRecurrenceDay =>
      recurrenceDay ?? int.parse(nextDueDate.substring(8, 10));
}

/// An automatic charge found for the current period.
class PeriodCharge {
  const PeriodCharge({
    required this.id,
    required this.amount,
    required this.date,
  });

  final int id;

  /// Null when the stored amount could not be read as a positive number.
  final Decimal? amount;
  final String date;
}

/// The last day of [when]'s month.
int _lastDayOfMonth(DateTime when) =>
    DateTime(when.year, when.month + 1, 0).day;

/// Advances [from] by one period of [frequency].
///
/// Weekly periods move by fixed days, monthly ones by calendar month — so 31
/// January plus three months is 30 April, not 3 May. Dart's `DateTime`
/// happily rolls a day overflow into the next month, which is exactly the
/// wrong answer here, so the day is clamped explicitly.
DateTime advanceDueDate(DateTime from, RecurrenceFrequency frequency) {
  switch (frequency) {
    case RecurrenceFrequency.weekly:
      return from.add(const Duration(days: 7));
    case RecurrenceFrequency.biweekly:
      return from.add(const Duration(days: 14));
    case RecurrenceFrequency.yearly:
      final next = DateTime(from.year + 1, from.month, 1);
      // 29 February has no counterpart in a common year; the desktop falls
      // back to the 28th rather than spilling into March.
      return DateTime(
        from.year + 1,
        from.month,
        from.day > _lastDayOfMonth(next) ? 28 : from.day,
      );
    case RecurrenceFrequency.monthly:
    case RecurrenceFrequency.quarterly:
      final months = frequency == RecurrenceFrequency.quarterly ? 3 : 1;
      final firstOfTarget = DateTime(from.year, from.month + months, 1);
      final lastDay = _lastDayOfMonth(firstOfTarget);
      return DateTime(
        firstOfTarget.year,
        firstOfTarget.month,
        from.day < lastDay ? from.day : lastDay,
      );
  }
}

/// The next occurrence after [from], pinned to [recurrenceDay].
///
/// Advancing alone is not enough: a payment set to the 31st that fell due on
/// 28 February must go back to the 31st in March, not stay on the 28th.
DateTime nextDueForRecurrence(
  DateTime from,
  RecurrenceFrequency frequency,
  int recurrenceDay,
) {
  _requireValidRecurrenceDay(recurrenceDay);
  final advanced = advanceDueDate(from, frequency);
  final lastDay = _lastDayOfMonth(advanced);
  return DateTime(
    advanced.year,
    advanced.month,
    recurrenceDay < lastDay ? recurrenceDay : lastDay,
  );
}

/// When the first occurrence of a recurring income should be recorded, or
/// null if the user chose not to include the current month.
///
/// If the chosen day has already passed, "include this month" records it
/// today; if it has not arrived, it is scheduled for that day — which
/// `TransactionService.addTransaction` will write as `pending`. Days 29-31
/// clamp to the last day in a short month.
DateTime? initialRecurringIncomeDate(
  DateTime reference,
  int recurrenceDay, {
  required bool includeCurrentMonth,
}) {
  if (!includeCurrentMonth) return null;
  _requireValidRecurrenceDay(recurrenceDay);
  final lastDay = _lastDayOfMonth(reference);
  final occurrence = DateTime(
    reference.year,
    reference.month,
    recurrenceDay < lastDay ? recurrenceDay : lastDay,
  );
  return occurrence.isAfter(reference) ? occurrence : reference;
}

/// Does this transaction look like a recurring subscription?
///
/// Two signals, either one enough: the category is explicitly a subscription
/// category, or a known brand appears in the description.
///
/// The desktop's version takes an `is_credit_card` argument that its body
/// never reads — the caller does the gating — so it is dropped here rather
/// than kept as a parameter that does nothing. The gate itself survives in
/// [RecurringService.registerSubscriptionFromTransaction]: a card alone is
/// NOT a signal, or every supermarket run on the card would fill the radar.
bool looksLikeSubscription(String? category, {String description = ''}) {
  final normalizedCategory = (category ?? '').trim();
  if (subscriptionCategories.contains(normalizedCategory)) return true;

  final haystack = '$description $normalizedCategory'.toLowerCase();
  return knownBrands.any((brand) => haystack.contains(brand.toLowerCase()));
}

void _requireValidRecurrenceDay(int day) {
  if (day < 1 || day > 31) {
    throw RecurringError(
      RecurringErrorCode.invalidRecurrenceDay,
      'The recurrence day must be between 1 and 31, got $day.',
    );
  }
}

class RecurringService {
  RecurringService(this._db, this._crypto, this._accounts);

  final ArchlenceDatabase _db;
  final FieldCrypto _crypto;
  final AccountService _accounts;

  /// Records a new recurring payment and returns its id.
  Future<int> insertRecurringPayment({
    required String name,
    required Object? amount,
    String? category,
    required RecurrenceFrequency frequency,
    required DateTime nextDueDate,
    bool autoDeduct = false,
    required int accountId,
    int? recurrenceDay,
    String transactionType = 'expense',
  }) async {
    final day = recurrenceDay ?? nextDueDate.day;
    _requireValidRecurrenceDay(day);

    final normalizedType = transactionType.trim().toLowerCase();
    if (normalizedType != 'income' && normalizedType != 'expense') {
      throw RecurringError(
        RecurringErrorCode.invalidTransactionType,
        'A recurring payment must be income or expense, got $transactionType.',
      );
    }

    final quantized = _requirePositiveAmount(amount);

    return _db.customInsert(
      'INSERT INTO recurring_payments (name, amount, category, frequency, '
      'next_due_date, recurrence_day, auto_deduct, is_active, account_id, '
      'transaction_type) VALUES (?, ?, ?, ?, ?, ?, ?, 1, ?, ?)',
      variables: [
        Variable<String>((await _crypto.encryptField(name))!),
        Variable<String>((await _crypto.encryptField(quantized.toString()))!),
        Variable<String>(category),
        Variable<String>(frequency.wireValue),
        Variable<String>(sqliteDate(nextDueDate)),
        Variable<int>(day),
        Variable<int>(autoDeduct ? 1 : 0),
        Variable<int>(accountId),
        Variable<String>(normalizedType),
      ],
    );
  }

  /// Every active recurring payment, soonest due first.
  Future<List<RecurringPayment>> getActiveRecurringPayments() async {
    final rows = await _db
        .customSelect(
          'SELECT * FROM recurring_payments WHERE is_active = 1 '
          'ORDER BY next_due_date ASC',
        )
        .get();

    final payments = <RecurringPayment>[];
    for (final row in rows) {
      payments.add(
        RecurringPayment(
          id: row.read<int>('id'),
          name: await _readText(row.data['name']),
          amount: await _readPositiveAmount(row.data['amount']),
          category: row.data['category'] as String?,
          frequency: row.read<String>('frequency'),
          nextDueDate: row.read<String>('next_due_date'),
          recurrenceDay: row.data['recurrence_day'] as int?,
          autoDeduct: (row.data['auto_deduct'] as int? ?? 0) != 0,
          accountId: row.read<int>('account_id'),
          transactionType: row.data['transaction_type'] as String? ?? 'expense',
        ),
      );
    }
    return payments;
  }

  /// Is there already an active payment under this name?
  ///
  /// Names are encrypted, so this cannot be a SQL `WHERE`: the active rows
  /// are decrypted and compared here. A row that will not decrypt is skipped
  /// rather than failing the check — it cannot be the name being asked about,
  /// since the answer would be unknowable either way.
  Future<bool> hasActiveRecurringPayment(String name) async {
    final target = name.trim().toLowerCase();
    final rows = await _db
        .customSelect('SELECT name FROM recurring_payments WHERE is_active = 1')
        .get();
    for (final row in rows) {
      final existing = await _readText(row.data['name']);
      if (existing != null && existing.trim().toLowerCase() == target) {
        return true;
      }
    }
    return false;
  }

  /// Stops a recurring payment permanently. Returns whether a row changed.
  ///
  /// The row is NOT deleted, only deactivated: past transactions and the
  /// radar's "already tracked" check both rely on it existing, and a physical
  /// delete would turn settled history back into a fresh candidate.
  Future<bool> cancelSubscription(int paymentId) async {
    final updated = await _db.customUpdate(
      'UPDATE recurring_payments SET is_active = 0 WHERE id = ?',
      variables: [Variable<int>(paymentId)],
      updates: const {},
    );
    return updated > 0;
  }

  /// Puts a transaction that looks like a subscription onto the radar.
  ///
  /// Writing the transaction itself is the CALLER's job — this only adds the
  /// tracking record, so one spend both appears as an ordinary expense and
  /// shows up under "My Active Subscriptions".
  ///
  /// Idempotent by name: entering the same subscription by hand every month
  /// keeps a single radar record. Returns the new row's id, or null when
  /// nothing was recorded.
  Future<int?> registerSubscriptionFromTransaction({
    required int accountId,
    required Object? amount,
    String? category,
    String description = '',
    RecurrenceFrequency frequency = RecurrenceFrequency.monthly,
    int? recurrenceDay,
    DateTime? transactionDate,
    required bool isCreditCard,
  }) async {
    // The card is a GATE, not a signal. Without it every supermarket run
    // would land on the radar; with it alone, so would every card purchase.
    if (!isCreditCard) return null;
    if (!looksLikeSubscription(category, description: description)) return null;

    final name = (description.isNotEmpty ? description : (category ?? ''))
        .trim();
    if (name.isEmpty) return null;
    if (await hasActiveRecurringPayment(name)) return null;

    final reference = transactionDate ?? DateTime.now();
    final day = recurrenceDay ?? reference.day;

    return insertRecurringPayment(
      name: name,
      amount: amount,
      category: category,
      frequency: frequency,
      nextDueDate: nextDueForRecurrence(reference, frequency, day),
      accountId: accountId,
      recurrenceDay: day,
    );
  }

  /// Changes what a subscription costs, for the price-rise case.
  ///
  /// Only the amount moves. Deleting and recreating the subscription would
  /// also reset its due history and `next_due_date` alignment, which is not
  /// what "the price went up" means.
  Future<bool> updateSubscriptionAmount(
    int paymentId,
    Object? newAmount,
  ) async {
    final quantized = _requirePositiveAmount(newAmount);
    final updated = await _db.customUpdate(
      'UPDATE recurring_payments SET amount = ? WHERE id = ? AND is_active = 1',
      variables: [
        Variable<String>((await _crypto.encryptField(quantized.toString()))!),
        Variable<int>(paymentId),
      ],
      updates: const {},
    );
    return updated > 0;
  }

  /// Skips the next charge without cancelling the subscription.
  ///
  /// The record stays active and the due date moves on one period, so the
  /// user can drop a single month without losing the ones after it. Returns
  /// the new due date, or null if there is no such active subscription.
  Future<DateTime?> skipNextOccurrence(int paymentId) async {
    return _db.transaction(() async {
      final row = await _rawPayment(paymentId);
      if (row == null || (row['is_active'] as int? ?? 0) == 0) return null;

      final nextDue = nextDueForRecurrence(
        DateTime.parse(row['next_due_date']! as String),
        RecurrenceFrequency.fromWire(row['frequency'] as String?),
        (row['recurrence_day'] as int?) ??
            int.parse((row['next_due_date']! as String).substring(8, 10)),
      );
      await _db.customUpdate(
        'UPDATE recurring_payments SET next_due_date = ? WHERE id = ?',
        variables: [
          Variable<String>(sqliteDate(nextDue)),
          Variable<int>(paymentId),
        ],
        updates: const {},
      );
      return nextDue;
    });
  }

  /// Charges a due recurring payment and moves its due date on.
  ///
  /// Returns false when this generation has already been charged. Idempotence
  /// is enforced by SQLite, not by UI state: the marker's primary key is
  /// `(payment, due date, 'charge')`, and it is keyed on the due date the
  /// payment had GOING IN — a stale object still holding the old date must
  /// collide with the same marker, not mint a second charge.
  ///
  /// The spending rule is checked on this transaction's own handle, inside
  /// the write lock, so a card's limit cannot be consumed twice by two
  /// concurrent charges.
  Future<bool> processDueRecurringPayment(RecurringPayment payment) async {
    final amount = payment.amount;
    if (amount == null) {
      throw RecurringDataIntegrityError(
        'recurring_payments',
        payment.id,
        'amount',
      );
    }
    final name = payment.name;
    if (name == null) {
      // Deliberately stricter than the desktop, which charges under
      // "Bilinmeyen Ödeme". The description is the only handle
      // findCurrentPeriodCharge has, so such a charge could never be
      // refunded — and two of them would make a refund match the wrong one.
      throw RecurringDataIntegrityError(
        'recurring_payments',
        payment.id,
        'name',
      );
    }

    final transactionType = payment.transactionType.trim().toLowerCase();
    if (transactionType != 'income' && transactionType != 'expense') {
      throw RecurringError(
        RecurringErrorCode.invalidTransactionType,
        'A recurring payment must be income or expense, '
        'got ${payment.transactionType}.',
      );
    }

    final newDue = nextDueForRecurrence(
      DateTime.parse(payment.nextDueDate),
      RecurrenceFrequency.fromWire(payment.frequency),
      payment.effectiveRecurrenceDay,
    );
    final amountAsDouble = amount.toDouble();

    return _db.transaction(() async {
      final claimed = await _db.customUpdate(
        'INSERT OR IGNORE INTO recurring_operation_markers '
        "(recurring_payment_id, due_date, operation_type) VALUES (?, ?, 'charge')",
        variables: [
          Variable<int>(payment.id),
          Variable<String>(payment.nextDueDate),
        ],
        updates: const {},
      );
      if (claimed == 0) return false;

      await _accounts.assertSpendingAllowed(
        payment.accountId,
        amount,
        transactionType: transactionType,
      );

      final now = sqliteTimestamp(DateTime.now());
      final transactionId = await _db.customInsert(
        'INSERT INTO transactions (account_id, amount, type, category, '
        'description, transaction_date) VALUES (?, ?, ?, ?, ?, ?)',
        variables: [
          Variable<int>(payment.accountId),
          Variable<String>(
            (await _crypto.encryptField(amountAsDouble.toString()))!,
          ),
          Variable<String>(transactionType),
          Variable<String>(payment.category),
          Variable<String>((await _crypto.encryptField('$name (Otomatik)'))!),
          Variable<String>(now),
        ],
      );

      await adjustAccountBalance(
        _db,
        accountId: payment.accountId,
        transactionType: transactionType,
        amount: amountAsDouble,
        refId: transactionId,
        source: 'recurring_payment',
      );

      await _db.customUpdate(
        'UPDATE recurring_payments SET next_due_date = ? WHERE id = ?',
        variables: [
          Variable<String>(sqliteDate(newDue)),
          Variable<int>(payment.id),
        ],
        updates: const {},
      );
      await _db.customUpdate(
        'UPDATE recurring_operation_markers SET transaction_id = ? '
        'WHERE recurring_payment_id = ? AND due_date = ? '
        "AND operation_type = 'charge'",
        variables: [
          Variable<int>(transactionId),
          Variable<int>(payment.id),
          Variable<String>(payment.nextDueDate),
        ],
        updates: const {},
      );
      return true;
    });
  }

  /// Finds this period's automatic charge for a subscription.
  ///
  /// The description is written encrypted as `"{name} (Otomatik)"`, so it
  /// cannot be matched in SQL: candidates are narrowed by account, type,
  /// category and month, then decrypted and compared here.
  Future<PeriodCharge?> findCurrentPeriodCharge(
    int paymentId, {
    DateTime? today,
  }) async {
    final reference = today ?? DateTime.now();
    final row = await _rawPayment(paymentId);
    if (row == null) return null;

    final name = await _readText(row['name']);
    if (name == null) return null;
    final expectedDescription = '$name (Otomatik)';

    final candidates = await _db
        .customSelect(
          'SELECT id, amount, description, transaction_date FROM transactions '
          "WHERE account_id = ? AND type = 'expense' "
          "AND COALESCE(category, '') = COALESCE(?, '') "
          "AND strftime('%Y-%m', transaction_date) = ? "
          'ORDER BY id DESC',
          variables: [
            Variable<int>(row['account_id']! as int),
            Variable<String>(row['category'] as String?),
            Variable<String>(sqliteDate(reference).substring(0, 7)),
          ],
        )
        .get();

    for (final candidate in candidates) {
      final description = await _readText(candidate.data['description']);
      if (description != expectedDescription) continue;
      return PeriodCharge(
        id: candidate.read<int>('id'),
        amount: await _readPositiveAmount(candidate.data['amount']),
        date: candidate.read<String>('transaction_date'),
      );
    }
    return null;
  }

  /// Puts this period's subscription fee back on the balance.
  ///
  /// The original expense is NOT deleted; a compensating income row is
  /// written instead. History is reversed, never rewritten, so the ledger and
  /// the balance stay in step.
  ///
  /// Returns the amount refunded, or zero when there was no charge this
  /// period. A charge whose stored amount is unreadable or non-positive
  /// raises instead — collapsing that into "nothing to refund" is how the
  /// desktop once committed a refund that left a balance of `inf`.
  ///
  /// Idempotent: a marker keyed on the CHARGE's transaction id claims the
  /// refund, so a second call returns zero and writes nothing.
  Future<Decimal> refundCurrentPeriodCharge(
    int paymentId, {
    DateTime? today,
  }) async {
    final charge = await findCurrentPeriodCharge(paymentId, today: today);
    if (charge == null) return Decimal.zero;

    final amount = charge.amount;
    if (amount == null) {
      throw RecurringDataIntegrityError('transactions', charge.id, 'amount');
    }
    final amountAsDouble = amount.toDouble();

    return _db.transaction(() async {
      // `due_date` holds the CHARGE's transaction id here, not a date. It is
      // an odd use of the column, but it is the desktop's storage contract
      // and it is what makes a refund unique per charge rather than per
      // period.
      final claimed = await _db.customUpdate(
        'INSERT OR IGNORE INTO recurring_operation_markers '
        "(recurring_payment_id, due_date, operation_type) "
        "VALUES (?, ?, 'refund')",
        variables: [
          Variable<int>(paymentId),
          Variable<String>(charge.id.toString()),
        ],
        updates: const {},
      );
      if (claimed == 0) return Decimal.zero;

      final row = await _rawPayment(paymentId);
      if (row == null) return Decimal.zero;
      final name = await _readText(row['name']);
      if (name == null) {
        throw RecurringDataIntegrityError(
          'recurring_payments',
          paymentId,
          'name',
        );
      }

      final now = sqliteTimestamp(DateTime.now());
      final transactionId = await _db.customInsert(
        'INSERT INTO transactions (account_id, amount, type, category, '
        "description, transaction_date, status, execution_date) "
        "VALUES (?, ?, 'income', ?, ?, ?, 'completed', ?)",
        variables: [
          Variable<int>(row['account_id']! as int),
          Variable<String>(
            (await _crypto.encryptField(amountAsDouble.toString()))!,
          ),
          Variable<String>(row['category'] as String?),
          Variable<String>(
            (await _crypto.encryptField('$name aboneliği iadesi'))!,
          ),
          Variable<String>(now),
          Variable<String>(now),
        ],
      );

      await adjustAccountBalance(
        _db,
        accountId: row['account_id']! as int,
        transactionType: 'income',
        amount: amountAsDouble,
        refId: transactionId,
        source: 'subscription_refund',
      );
      return amount;
    });
  }

  Future<Map<String, Object?>?> _rawPayment(int paymentId) async {
    final row = await _db
        .customSelect(
          'SELECT * FROM recurring_payments WHERE id = ?',
          variables: [Variable<int>(paymentId)],
        )
        .getSingleOrNull();
    return row?.data;
  }

  Decimal _requirePositiveAmount(Object? value) {
    final Decimal quantized;
    try {
      quantized = fiat(value);
    } on FinancialValueError catch (error) {
      throw RecurringError(
        RecurringErrorCode.invalidAmount,
        'The amount must be a finite number: ${error.message}',
      );
    }
    if (quantized <= Decimal.zero) {
      throw const RecurringError(
        RecurringErrorCode.amountNotPositive,
        'The amount must be greater than zero.',
      );
    }
    return quantized;
  }

  /// Decrypts a stored amount, returning null when it cannot be read OR is
  /// not positive — the two ways a row is unusable, kept together because
  /// callers treat them the same.
  Future<Decimal?> _readPositiveAmount(Object? stored) async {
    try {
      final value = fiat(await _crypto.decryptField(stored));
      return value > Decimal.zero ? value : null;
    } on KeyUnavailableError {
      rethrow;
    } on Exception {
      return null;
    }
  }

  Future<String?> _readText(Object? stored) async {
    try {
      return (await _crypto.decryptField(stored)) ?? '';
    } on KeyUnavailableError {
      rethrow;
    } on Exception {
      return null;
    }
  }
}
