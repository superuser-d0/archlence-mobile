/// How much the balance moved over a period, and by what percentage.
///
/// A port of the desktop's `services/dashboard_period_service.py`, whose own
/// docstring records why it exists: the dashboard used to compare this
/// period's CASH FLOW against the previous period's cash flow, which is a
/// growth rate and not a balance change, and it produced a misleading ±100%
/// whenever the previous period happened to be empty.
///
/// **A change from zero has no percentage, and none is invented.** Zero to
/// zero is the one well-defined no-change case and answers 0%; zero to
/// anything else answers nothing at all. Those two rules sit next to each
/// other and are easy to get backwards, which is why they have their own
/// vectors — see `tool/emit_period_vectors.py`.
///
/// **A baseline the ledger cannot answer for produces no change either.**
/// `BalanceHistoryService.totalAt` returns null before the ledger begins, and
/// that null travels all the way to the ring, which then draws no chip. An
/// empty chip drawn as a green pill with an upward arrow reads as a gain — the
/// defect this app already found once by opening the screen.
library;

import 'package:decimal/decimal.dart';

import '../money/financial_decimal.dart';
import 'balance_history.dart';
import 'transaction_service.dart';

/// How many days each period covers, inclusive of today.
///
/// `allTime` is absent on purpose, exactly as the desktop's `PERIOD_DAYS` has
/// no entry for its own "Hayat Boyu": no lower bound means the change IS the
/// balance, and there is nothing to compare it against.
const Map<DashboardPeriod, int> periodDays = {
  DashboardPeriod.today: 1,
  DashboardPeriod.week: 7,
  DashboardPeriod.month: 30,
  DashboardPeriod.year: 365,
};

/// The inclusive window [period] covers, ending on [today].
///
/// A null start means "as far back as there is", which only `allTime` gives.
(DateTime? start, DateTime end) periodBounds(
  DashboardPeriod period,
  DateTime today,
) {
  final end = DateTime(today.year, today.month, today.day);
  final days = periodDays[period];
  if (days == null) return (null, end);
  return (end.subtract(Duration(days: days - 1)), end);
}

/// The percentage move from [startingBalance] to [currentBalance].
///
/// Null when there is no finite answer: an unknown baseline, or a move away
/// from an actual zero.
Decimal? percentageChange(Decimal? startingBalance, Decimal currentBalance) {
  if (startingBalance == null) return null;
  if (startingBalance == Decimal.zero) {
    return currentBalance == Decimal.zero ? Decimal.zero : null;
  }
  // The divisor is the ABSOLUTE baseline, so climbing out of debt reads as a
  // gain rather than a loss.
  return percentage(
    ((currentBalance - startingBalance) / startingBalance.abs()).toDecimal(
      scaleOnInfinitePrecision: 20,
    ) *
        Decimal.fromInt(100),
  );
}

/// What a period's change came to.
class BalanceChange {
  const BalanceChange({
    required this.start,
    required this.end,
    required this.baselineDate,
    required this.startingBalance,
    required this.nominal,
    required this.percent,
  });

  /// The first day of the window, or null for the whole history.
  final DateTime? start;

  final DateTime end;

  /// The day the baseline is read at: the end of the day BEFORE the window
  /// opens. Null for the whole history.
  final DateTime? baselineDate;

  /// What the accounts held at [baselineDate], or null if unknowable.
  final Decimal? startingBalance;

  /// The move in lira, or null when there is no baseline to move from.
  final Decimal? nominal;

  /// The move as a percentage, or null when there is no finite one.
  final Decimal? percent;

  /// Whether there is anything to draw.
  bool get isKnown => nominal != null;
}

/// Works out [period]'s change against [currentBalance].
///
/// [readBalanceAt] is injected the way the desktop injects `balance_reader`,
/// which is what makes the boundary behaviour testable without a ledger.
Future<BalanceChange> calculateBalanceChange({
  required DashboardPeriod period,
  required Decimal currentBalance,
  required DateTime today,
  required Future<Decimal?> Function(DateTime) readBalanceAt,
}) async {
  final (start, end) = periodBounds(period, today);

  if (start == null) {
    // The whole history: the change IS the balance, and no percentage.
    return BalanceChange(
      start: null,
      end: end,
      baselineDate: null,
      startingBalance: null,
      nominal: currentBalance,
      percent: null,
    );
  }

  final baselineDate = start.subtract(const Duration(days: 1));
  final starting = await readBalanceAt(baselineDate);

  return BalanceChange(
    start: start,
    end: end,
    baselineDate: baselineDate,
    startingBalance: starting,
    nominal: starting == null ? null : fiat(currentBalance - starting),
    percent: percentageChange(starting, currentBalance),
  );
}

/// [calculateBalanceChange] wired to a real ledger.
Future<BalanceChange> balanceChangeFor(
  BalanceHistoryService history, {
  required DashboardPeriod period,
  required Decimal currentBalance,
  DateTime? today,
}) => calculateBalanceChange(
  period: period,
  currentBalance: currentBalance,
  today: today ?? DateTime.now(),
  readBalanceAt: history.totalAt,
);
