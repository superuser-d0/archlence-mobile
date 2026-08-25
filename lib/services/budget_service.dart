/// Category-based monthly budget planning and tracking.
///
/// A port of `services/budget_service.py`.
///
/// NO MONEY IS AGGREGATED IN SQL. `transactions.amount` is encrypted, so a
/// `SUM()` over it would add up ciphertext; every total here is decrypted and
/// summed in Dart. `monthly_budget_plan.amount` is a plain REAL, but it goes
/// through the same reader so that one rule covers both.
///
/// An amount that cannot be read invalidates the WHOLE derived result rather
/// than counting as zero. A budget that is silently short by one category is
/// worse than one that refuses to draw.
library;

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';

import '../crypto/field_crypto.dart';
import '../crypto/key_provider.dart';
import '../data/database.dart';
import '../money/financial_decimal.dart';
import 'recurring_service.dart';

/// Stored `type` values that count as an expense.
///
/// 'Gider' is the Turkish spelling on rows the desktop wrote before its
/// columns were standardised, and is still read.
const Set<String> expensePlanTypes = {'expense', 'Gider'};

/// Stored `type` values that count as income.
const Set<String> incomePlanTypes = {'income', 'Gelir'};

/// Every `type` a plan item may be SAVED with.
const Set<String> planItemTypes = {'income', 'expense', 'Gelir', 'Gider'};

enum BudgetErrorCode {
  unknownItemType,
  emptyName,
  invalidAmount,
  amountNotPositive,
  invalidMonth,
  invalidAlertThreshold,
}

class BudgetError implements Exception {
  const BudgetError(this.code, this.message);

  final BudgetErrorCode code;
  final String message;

  @override
  String toString() => 'BudgetError(${code.name}): $message';
}

/// A stored amount that could be read neither plainly nor by decrypting it.
///
/// Raised rather than skipped: see the library note — a derived total built
/// over a row nobody could read is a wrong number presented as a right one.
class BudgetDataIntegrityError implements Exception {
  const BudgetDataIntegrityError(this.table, this.recordId, this.field);

  final String table;
  final int? recordId;
  final String field;

  @override
  String toString() =>
      'BudgetDataIntegrityError($table#$recordId.$field): the stored amount '
      'could not be read.';
}

/// What makes two plan items "the same item" across months.
///
/// A category-bearing item is identified by its category; one without falls
/// back to its name. Both are compared case-insensitively, so "Market" and
/// "market" do not become two lines in the same plan.
typedef PlanIdentity = (String kind, String type, String key);

PlanIdentity _identityOf(Map<String, Object?> row) {
  final category = row['category_name'] as String?;
  final type = row['type']! as String;
  if (category != null && category.isNotEmpty) {
    return ('category', type, category.toLowerCase());
  }
  return ('name', type, (row['name']! as String).trim().toLowerCase());
}

/// One line of a monthly budget plan.
class BudgetPlanItem {
  const BudgetPlanItem({
    required this.id,
    required this.type,
    required this.name,
    required this.amount,
    required this.targetMonth,
    required this.targetYear,
    required this.categoryName,
    required this.rolloverEnabled,
    required this.isTemplate,
    required this.alertThresholdPct,
  });

  factory BudgetPlanItem.fromRow(Map<String, Object?> row, Decimal amount) {
    return BudgetPlanItem(
      id: row['id']! as int,
      type: row['type']! as String,
      name: row['name']! as String,
      amount: amount,
      targetMonth: row['target_month'] as int?,
      targetYear: row['target_year'] as int?,
      categoryName: row['category_name'] as String?,
      rolloverEnabled: (row['rollover_enabled'] as int? ?? 0) != 0,
      isTemplate: (row['is_template'] as int? ?? 0) != 0,
      alertThresholdPct: row['alert_threshold_pct'] as int? ?? 80,
    );
  }

  final int id;
  final String type;
  final String name;
  final Decimal amount;
  final int? targetMonth;
  final int? targetYear;
  final String? categoryName;
  final bool rolloverEnabled;

  /// A template applies to every month, until a concrete item of the same
  /// identity overrides it in one.
  final bool isTemplate;
  final int alertThresholdPct;

  bool get isExpense => expensePlanTypes.contains(type);
  bool get isIncome => incomePlanTypes.contains(type);
}

/// An active subscription reserved against a month's plan.
class ReservedRecurringItem {
  const ReservedRecurringItem({
    required this.payment,
    required this.occurrences,
    required this.reservedAmount,
  });

  final RecurringPayment payment;

  /// How many times it falls due inside the month — a weekly subscription
  /// reserves four or five times its fee, not one.
  final int occurrences;
  final Decimal reservedAmount;
}

/// A month's plan totals and what is left to spend.
class MonthlyBudget {
  const MonthlyBudget({
    required this.plannedIncome,
    required this.plannedExpense,
    required this.reservedRecurring,
    required this.remainingBudget,
  });

  final Decimal plannedIncome;
  final Decimal plannedExpense;

  /// Subscriptions due this month, held back before anything is called
  /// spendable.
  final Decimal reservedRecurring;
  final Decimal remainingBudget;
}

/// One category's plan against what was actually spent.
class CategoryBudgetProgress {
  const CategoryBudgetProgress({
    required this.category,
    required this.planned,
    required this.actual,
    required this.pct,
    required this.remaining,
    required this.alertThresholdPct,
    required this.rolloverEnabled,
  });

  final String category;
  final Decimal planned;
  final Decimal actual;

  /// Null when nothing was planned — a percentage of zero is not zero
  /// percent, it is undefined.
  final Decimal? pct;

  /// Negative when the category is overspent.
  final Decimal remaining;
  final int alertThresholdPct;
  final bool rolloverEnabled;
}

/// One point on the plan-versus-actual series.
class BudgetTrendPoint {
  const BudgetTrendPoint({
    required this.month,
    required this.year,
    required this.planned,
    required this.actual,
  });

  final int month;
  final int year;
  final Decimal planned;
  final Decimal actual;

  /// `MM/YYYY`, the label the desktop's chart draws.
  String get label => '${month.toString().padLeft(2, '0')}/$year';
}

/// The months a planner may target: this one through December.
///
/// Ported from the desktop's `planner_month_range`. A plan for a month that
/// has already gone is not something the user can act on.
List<int> plannerMonthRange(DateTime today) => [
  for (var month = today.month; month <= 12; month++) month,
];

/// Moves [delta] months from ([year], [month]), returning the new pair.
(int year, int month) shiftMonth(int year, int month, int delta) {
  final index = year * 12 + month - 1 + delta;
  return (index ~/ 12, index % 12 + 1);
}

class BudgetService {
  BudgetService(this._db, this._crypto, this._recurring);

  final ArchlenceDatabase _db;
  final FieldCrypto _crypto;
  final RecurringService _recurring;

  /// The plan items visible in a month: its own concrete rows, plus every
  /// template not overridden by one of them.
  ///
  /// "Latest wins" among templates of the same identity — a second template
  /// for the same category replaces the first rather than adding to it.
  Future<List<BudgetPlanItem>> getEffectivePlanItems(
    int targetMonth,
    int targetYear,
  ) async {
    final concrete = await _db
        .customSelect(
          'SELECT * FROM monthly_budget_plan '
          'WHERE target_month = ? AND target_year = ? AND is_template = 0 '
          'ORDER BY id',
          variables: [Variable<int>(targetMonth), Variable<int>(targetYear)],
        )
        .get();
    final templates = await _db
        .customSelect(
          'SELECT * FROM monthly_budget_plan WHERE is_template = 1 ORDER BY id',
        )
        .get();

    final concreteKeys = {for (final row in concrete) _identityOf(row.data)};
    final latestTemplates = <PlanIdentity, Map<String, Object?>>{};
    for (final row in templates) {
      latestTemplates[_identityOf(row.data)] = row.data;
    }

    final items = <BudgetPlanItem>[];
    for (final row in concrete) {
      items.add(await _planItem(row.data));
    }
    for (final entry in latestTemplates.entries) {
      if (concreteKeys.contains(entry.key)) continue;
      items.add(await _planItem(entry.value));
    }
    return items;
  }

  /// The active subscriptions falling due in the target month.
  ///
  /// A payment whose stored amount is unusable raises rather than being left
  /// out: an under-reported reservation overstates what is spendable, which
  /// is precisely the error a reservation exists to prevent.
  Future<List<ReservedRecurringItem>> getReservedRecurringItems(
    int targetMonth,
    int targetYear,
  ) async {
    final items = <ReservedRecurringItem>[];
    for (final payment in await _recurring.getActiveRecurringPayments()) {
      final occurrences = _occurrencesInMonth(payment, targetYear, targetMonth);
      if (occurrences == 0) continue;

      final amount = payment.amount;
      if (amount == null) {
        throw BudgetDataIntegrityError(
          'recurring_payments',
          payment.id,
          'amount',
        );
      }
      items.add(
        ReservedRecurringItem(
          payment: payment,
          occurrences: occurrences,
          reservedAmount: fiat(amount * Decimal.fromInt(occurrences)),
        ),
      );
    }
    return items;
  }

  /// The month's plan total, subscription reservation and spendable balance.
  Future<MonthlyBudget> calculateMonthlyBudget(
    int targetMonth, [
    int? targetYear,
  ]) async {
    _requireValidMonth(targetMonth);
    final year = targetYear ?? DateTime.now().year;

    var plannedIncome = Decimal.zero;
    var plannedExpense = Decimal.zero;
    for (final item in await getEffectivePlanItems(targetMonth, year)) {
      if (item.isIncome) plannedIncome += item.amount;
      if (item.isExpense) plannedExpense += item.amount;
    }

    var reserved = Decimal.zero;
    for (final item in await getReservedRecurringItems(targetMonth, year)) {
      reserved += item.reservedAmount;
    }

    return MonthlyBudget(
      plannedIncome: fiat(plannedIncome),
      plannedExpense: fiat(plannedExpense),
      reservedRecurring: fiat(reserved),
      remainingBudget: fiat(plannedIncome - plannedExpense - reserved),
    );
  }

  /// Each category's plan against the same month's actual spending.
  Future<List<CategoryBudgetProgress>> getCategoryBudgetProgress(
    int targetMonth,
    int targetYear,
  ) async {
    final planTotals = <String, Decimal>{};
    final thresholds = <String, int>{};
    final rolloverFlags = <String, bool>{};

    for (final item in await getEffectivePlanItems(targetMonth, targetYear)) {
      final category = item.categoryName;
      if (category == null || category.isEmpty || !item.isExpense) continue;
      planTotals[category] =
          (planTotals[category] ?? Decimal.zero) + item.amount;
      thresholds[category] = item.alertThresholdPct;
      rolloverFlags[category] = item.rolloverEnabled;
    }

    final actuals = await _actualCategoryTotals(targetMonth, targetYear);
    final result = <CategoryBudgetProgress>[];
    for (final entry in planTotals.entries) {
      final planned = entry.value;
      final actual = actuals[entry.key] ?? Decimal.zero;
      result.add(
        CategoryBudgetProgress(
          category: entry.key,
          planned: fiat(planned),
          actual: fiat(actual),
          pct: planned == Decimal.zero
              ? null
              : percentage(
                  (actual / planned).toDecimal(scaleOnInfinitePrecision: 20) *
                      Decimal.fromInt(100),
                ),
          remaining: fiat(planned - actual),
          alertThresholdPct: thresholds[entry.key]!,
          rolloverEnabled: rolloverFlags[entry.key]!,
        ),
      );
    }
    result.sort(
      (a, b) => a.category.toLowerCase().compareTo(b.category.toLowerCase()),
    );
    return result;
  }

  /// The category's limit adjusted by LAST MONTH's balance alone.
  ///
  /// Deliberately not chained: the previous month's own `planned - actual` is
  /// carried, not whatever it had itself inherited. Chaining would let a
  /// single frugal January quietly inflate every month after it.
  ///
  /// Returns zero when the category has no plan in the target month.
  Future<Decimal> getEffectiveLimit(
    String categoryName,
    int targetMonth,
    int targetYear,
  ) async {
    final progress = await getCategoryBudgetProgress(targetMonth, targetYear);
    final current = progress
        .where((item) => item.category == categoryName)
        .firstOrNull;
    if (current == null) return Decimal.zero;
    if (!current.rolloverEnabled) return current.planned;

    final (prevYear, prevMonth) = shiftMonth(targetYear, targetMonth, -1);
    final previous = (await getCategoryBudgetProgress(
      prevMonth,
      prevYear,
    )).where((item) => item.category == categoryName).firstOrNull;
    final carry = previous?.remaining ?? Decimal.zero;
    return fiat(current.planned + carry);
  }

  /// The monthly average actually spent on a category over the last
  /// [lookbackMonths] COMPLETED months, or null when there is no history.
  ///
  /// The current month is excluded on purpose — averaging in a month that is
  /// only a third over would suggest a limit a third of the truth.
  Future<Decimal?> suggestCategoryBudget(
    String categoryName, {
    int lookbackMonths = 3,
  }) async {
    if (lookbackMonths <= 0) {
      throw const BudgetError(
        BudgetErrorCode.invalidMonth,
        'The look-back window must be a positive number of months.',
      );
    }
    final today = DateTime.now();
    var total = Decimal.zero;
    var anyData = false;
    for (var offset = 1; offset <= lookbackMonths; offset++) {
      final (year, month) = shiftMonth(today.year, today.month, -offset);
      final amount =
          (await _actualCategoryTotals(month, year))[categoryName] ??
          Decimal.zero;
      total += amount;
      anyData = anyData || amount > Decimal.zero;
    }
    if (!anyData) return null;
    return fiat(
      (total / Decimal.fromInt(lookbackMonths)).toDecimal(
        scaleOnInfinitePrecision: 20,
      ),
    );
  }

  /// The plan-versus-actual series going backwards, [endDate]'s month last.
  Future<List<BudgetTrendPoint>> getBudgetTrend({
    int months = 6,
    DateTime? endDate,
  }) async {
    final end = endDate ?? DateTime.now();
    final series = <BudgetTrendPoint>[];
    for (var offset = months - 1; offset >= 0; offset--) {
      final (year, month) = shiftMonth(end.year, end.month, -offset);
      final progress = await getCategoryBudgetProgress(month, year);
      var planned = Decimal.zero;
      var actual = Decimal.zero;
      for (final item in progress) {
        planned += item.planned;
        actual += item.actual;
      }
      series.add(
        BudgetTrendPoint(
          month: month,
          year: year,
          planned: fiat(planned),
          actual: fiat(actual),
        ),
      );
    }
    return series;
  }

  /// Creates or updates a plan item, and any copies of it, in one commit.
  ///
  /// WHY THIS LIVES IN A SERVICE: the desktop's SQL for this sat directly in
  /// its Kivy mixin, which made the interface's own field validation the only
  /// thing standing between a user and `monthly_budget_plan.amount`. That was
  /// not a known hole — the form could not produce `nan` — but a rule that
  /// lives in the interface is a rule the next caller bypasses without ever
  /// seeing it. Every other monetary write in this app passes a `fiat()`
  /// boundary; so does this one.
  ///
  /// [propagateToMonths] copies the item into those months as well, in the
  /// SAME commit — a half-finished propagation would leave a plan the user
  /// cannot see and cannot fix. Copies are never templates.
  ///
  /// Editing a template with [editingATemplate] leaves the template alone and
  /// creates a concrete item for this month instead: the point of editing one
  /// month of a repeating line is that the other months keep the old value.
  Future<void> savePlanItem({
    required String itemType,
    required String name,
    required Object? amount,
    required int month,
    required int year,
    String? category,
    bool rolloverEnabled = false,
    bool isTemplate = false,
    int alertThresholdPct = 80,
    int? itemId,
    bool editingATemplate = false,
    Iterable<int> propagateToMonths = const [],
  }) async {
    final normalizedType = itemType.trim();
    if (!planItemTypes.contains(normalizedType)) {
      throw BudgetError(
        BudgetErrorCode.unknownItemType,
        'Unknown budget item type: $itemType',
      );
    }

    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw const BudgetError(
        BudgetErrorCode.emptyName,
        'A budget item needs a name.',
      );
    }

    final Decimal quantized;
    try {
      quantized = fiat(amount);
    } on FinancialValueError catch (error) {
      throw BudgetError(
        BudgetErrorCode.invalidAmount,
        'The budget amount must be a finite number: ${error.message}',
      );
    }
    if (quantized <= Decimal.zero) {
      throw const BudgetError(
        BudgetErrorCode.amountNotPositive,
        'The budget amount must be greater than zero.',
      );
    }

    _requireValidMonth(month);
    if (alertThresholdPct < 1 || alertThresholdPct > 100) {
      throw BudgetError(
        BudgetErrorCode.invalidAlertThreshold,
        'The alert threshold must be between 1 and 100, got $alertThresholdPct.',
      );
    }

    // Validated BEFORE the transaction opens, so an invalid copy list cannot
    // leave the original write half-done.
    final targets = propagateToMonths.toSet().toList()..sort();
    for (final target in targets) {
      _requireValidMonth(target);
    }

    final storedAmount = quantized.toDouble();
    final rollover = rolloverEnabled ? 1 : 0;

    await _db.transaction(() async {
      if (itemId != null && !editingATemplate) {
        await _db.customUpdate(
          'UPDATE monthly_budget_plan SET type = ?, name = ?, amount = ?, '
          'target_month = ?, target_year = ?, category_name = ?, '
          'rollover_enabled = ?, is_template = ?, alert_threshold_pct = ? '
          'WHERE id = ? AND target_month = ? AND target_year = ?',
          variables: [
            Variable<String>(normalizedType),
            Variable<String>(trimmedName),
            Variable<double>(storedAmount),
            Variable<int>(month),
            Variable<int>(year),
            Variable<String>(category),
            Variable<int>(rollover),
            Variable<int>(isTemplate ? 1 : 0),
            Variable<int>(alertThresholdPct),
            Variable<int>(itemId),
            Variable<int>(month),
            Variable<int>(year),
          ],
          updates: const {},
        );
      } else {
        await _insertPlanRow(
          type: normalizedType,
          name: trimmedName,
          amount: storedAmount,
          month: month,
          year: year,
          category: category,
          rollover: rollover,
          // An item derived from a template is never itself a template.
          isTemplate: itemId != null ? 0 : (isTemplate ? 1 : 0),
          alertThresholdPct: alertThresholdPct,
        );
      }

      for (final target in targets) {
        if (target == month) continue;
        await _insertPlanRow(
          type: normalizedType,
          name: trimmedName,
          amount: storedAmount,
          month: target,
          year: year,
          category: category,
          rollover: rollover,
          isTemplate: 0,
          alertThresholdPct: alertThresholdPct,
        );
      }
    });
  }

  /// Carries this month's concrete plan items through to December, and
  /// returns how many rows were added.
  ///
  /// Templates are not copied — they already apply to every month. An item
  /// whose identity already exists in a target month is skipped, so
  /// confirming twice adds nothing.
  Future<int> applyPlanToYearEnd(int sourceMonth, int sourceYear) async {
    _requireValidMonth(sourceMonth);
    return _db.transaction(() async {
      final sourceRows = await _db
          .customSelect(
            'SELECT * FROM monthly_budget_plan '
            'WHERE target_month = ? AND target_year = ? AND is_template = 0 '
            'ORDER BY id',
            variables: [Variable<int>(sourceMonth), Variable<int>(sourceYear)],
          )
          .get();
      if (sourceRows.isEmpty) return 0;

      var copied = 0;
      // Starting at the month AFTER the source is belt-and-braces: the
      // identity skip below would eliminate the source month's own rows
      // anyway, so removing the `+ 1` changes no observable behaviour (it was
      // measured). The bound stays because "carry this plan FORWARD" is what
      // the method means, and a reader should not have to derive that from
      // the deduplication.
      for (
        var targetMonth = sourceMonth + 1;
        targetMonth <= 12;
        targetMonth++
      ) {
        final existing = await _db
            .customSelect(
              'SELECT * FROM monthly_budget_plan '
              'WHERE target_month = ? AND target_year = ? AND is_template = 0',
              variables: [
                Variable<int>(targetMonth),
                Variable<int>(sourceYear),
              ],
            )
            .get();
        final existingKeys = {
          for (final row in existing) _identityOf(row.data),
        };

        for (final row in sourceRows) {
          if (existingKeys.contains(_identityOf(row.data))) continue;
          await _insertPlanRow(
            type: row.read<String>('type'),
            name: row.read<String>('name'),
            amount: row.read<double>('amount'),
            month: targetMonth,
            year: sourceYear,
            category: row.data['category_name'] as String?,
            rollover: row.data['rollover_enabled'] as int? ?? 0,
            isTemplate: 0,
            alertThresholdPct: row.data['alert_threshold_pct'] as int? ?? 80,
          );
          copied++;
        }
      }
      return copied;
    });
  }

  Future<int> _insertPlanRow({
    required String type,
    required String name,
    required double amount,
    required int month,
    required int year,
    required String? category,
    required int rollover,
    required int isTemplate,
    required int alertThresholdPct,
  }) {
    return _db.customInsert(
      'INSERT INTO monthly_budget_plan (type, name, amount, target_month, '
      'target_year, category_name, rollover_enabled, is_template, '
      'alert_threshold_pct) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
      variables: [
        Variable<String>(type),
        Variable<String>(name),
        Variable<double>(amount),
        Variable<int>(month),
        Variable<int>(year),
        Variable<String>(category),
        Variable<int>(rollover),
        Variable<int>(isTemplate),
        Variable<int>(alertThresholdPct),
      ],
    );
  }

  /// What was actually spent per category in the month.
  ///
  /// Only completed rows count — a pending transaction has not left the
  /// account, so counting it would report money spent that is still there.
  Future<Map<String, Decimal>> _actualCategoryTotals(
    int targetMonth,
    int targetYear,
  ) async {
    final rows = await _db
        .customSelect(
          'SELECT id, category, amount FROM transactions '
          "WHERE type IN ('expense', 'Gider') "
          "AND strftime('%m', transaction_date) = ? "
          "AND strftime('%Y', transaction_date) = ? "
          "AND COALESCE(status, 'completed') = 'completed'",
          variables: [
            Variable<String>(targetMonth.toString().padLeft(2, '0')),
            Variable<String>(targetYear.toString()),
          ],
        )
        .get();

    final totals = <String, Decimal>{};
    for (final row in rows) {
      final category = row.data['category'] as String? ?? '';
      final amount = await _readAmount(
        row.data['amount'],
        table: 'transactions',
        recordId: row.read<int>('id'),
      );
      totals[category] = (totals[category] ?? Decimal.zero) + amount;
    }
    return totals;
  }

  Future<BudgetPlanItem> _planItem(Map<String, Object?> row) async {
    return BudgetPlanItem.fromRow(
      row,
      await _readAmount(
        row['amount'],
        table: 'monthly_budget_plan',
        recordId: row['id'] as int?,
      ),
    );
  }

  /// Reads an amount that may be stored plainly or encrypted.
  ///
  /// `monthly_budget_plan.amount` is a REAL and `transactions.amount` is an
  /// AEAD token, and older databases blur even that — so the plain reading is
  /// tried first and decryption is the fallback, exactly as the desktop does
  /// it. Failing both raises: see the library note.
  Future<Decimal> _readAmount(
    Object? value, {
    required String table,
    required int? recordId,
    String field = 'amount',
  }) async {
    try {
      return decimalFrom(value);
    } on FinancialValueError {
      // Not a plain number — fall through to the encrypted reading.
    }
    try {
      return decimalFrom(await _crypto.decryptField(value));
    } on KeyUnavailableError {
      rethrow;
    } on Exception {
      throw BudgetDataIntegrityError(table, recordId, field);
    }
  }

  /// How many times [payment] falls due inside the given month.
  ///
  /// Walks the recurrence forward from its stored due date. The guard is not
  /// decoration: a corrupted daily-looking recurrence over a year's gap would
  /// otherwise spin here rather than fail.
  int _occurrencesInMonth(RecurringPayment payment, int year, int month) {
    final frequency = RecurrenceFrequency.fromWire(payment.frequency);
    final recurrenceDay = payment.effectiveRecurrenceDay;
    var due = DateTime.parse(payment.nextDueDate);
    final monthStart = DateTime(year, month, 1);
    final monthEnd = DateTime(year, month + 1, 1);

    var guard = 0;
    while (due.isBefore(monthStart) && guard < 800) {
      due = nextDueForRecurrence(due, frequency, recurrenceDay);
      guard++;
    }

    var count = 0;
    while (due.isBefore(monthEnd) && guard < 800) {
      if (!due.isBefore(monthStart)) count++;
      due = nextDueForRecurrence(due, frequency, recurrenceDay);
      guard++;
    }
    return count;
  }

  void _requireValidMonth(int month) {
    if (month < 1 || month > 12) {
      throw BudgetError(
        BudgetErrorCode.invalidMonth,
        'The month must be between 1 and 12, got $month.',
      );
    }
  }
}
