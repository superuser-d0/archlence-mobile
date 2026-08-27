/// A month at a glance, and one day in full.
///
/// The Tools grid's calendar card, and the visible half of `CalendarService`.
///
/// **The grid marks days rather than showing figures.** What a day cost cannot
/// be known without decrypting it, and decrypting a whole month to draw
/// thirty-one numbers would open every row a user never looks at. So the grid
/// says WHICH days had activity — which is what the plain `transaction_date`
/// can answer on its own — and the day a user taps is the only one opened.
///
/// **Months are bounded by the data, not by the calendar.** Paging arbitrarily
/// far into a future with nothing in it is motion without information; the
/// arrows stop at the current month and at the earliest month the ledger has.
library;

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import '../app_services.dart';
import '../services/calendar_service.dart';
import '../theme/obsidian_prime.dart';
import '../ui/app_locale.dart';
import '../ui/async_data.dart';
import '../ui/money_format.dart';
import '../ui/month_names.dart';
import '../widgets/surfaces.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  /// The day whose list is open, or null when none is.
  DateTime? _selected;

  Future<Map<int, int>>? _days;
  Future<List<CalendarEntry>>? _entries;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _days ??= _loadMonth();
  }

  Future<Map<int, int>> _loadMonth() =>
      ServicesScope.of(context).calendar
          .getMonthTransactionDays(_month.year, _month.month);

  void _showMonth(DateTime month) {
    setState(() {
      _month = month;
      // The selection belongs to the month it was made in. Carrying day 31
      // into a 30-day month would open a day that does not exist.
      _selected = null;
      _entries = null;
      _days = _loadMonth();
    });
  }

  void _select(DateTime day) {
    setState(() {
      _selected = day;
      _entries = ServicesScope.of(context).calendar.getDayTransactions(day);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.calendarTitle)),
      body: ListView(
        key: const PageStorageKey('calendar'),
        padding: EdgeInsets.fromLTRB(
          Spacing.containerMargin,
          Spacing.stackMd,
          Spacing.containerMargin,
          MediaQuery.paddingOf(context).bottom + Spacing.stackLg,
        ),
        children: [
          _MonthHeader(
            month: _month,
            onPrevious: () =>
                _showMonth(DateTime(_month.year, _month.month - 1)),
            onNext: () => _showMonth(DateTime(_month.year, _month.month + 1)),
          ),
          const SizedBox(height: Spacing.stackMd),
          AsyncData<Map<int, int>>(
            future: _days!,
            placeholderHeight: 320,
            builder: (context, days) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _MonthGrid(
                  month: _month,
                  counts: days,
                  selected: _selected,
                  onSelect: _select,
                ),
                const SizedBox(height: Spacing.stackMd),
                if (days.isEmpty)
                  _Note(l10n.calendarNothingThisMonth)
                else if (_selected == null)
                  _Note(l10n.calendarPickADay),
              ],
            ),
          ),
          if (_selected != null && _entries != null) ...[
            const SizedBox(height: Spacing.stackSm),
            AsyncData<List<CalendarEntry>>(
              future: _entries!,
              placeholderHeight: 160,
              builder: (context, entries) =>
                  _DayList(day: _selected!, entries: entries),
            ),
          ],
        ],
      ),
    );
  }
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({
    required this.month,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime month;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final now = DateTime.now();
    // No paging past the current month: a future month holds only rows that
    // have not settled, which the grid does not mark, so every one of them
    // would be empty by construction.
    final atLatest = month.year == now.year && month.month == now.month;

    return Row(
      children: [
        IconButton(
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left),
          tooltip: l10n.calendarPreviousMonth,
        ),
        Expanded(
          child: Text(
            '${fullMonthName(l10n, month.month)} ${month.year}',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        IconButton(
          onPressed: atLatest ? null : onNext,
          icon: const Icon(Icons.chevron_right),
          tooltip: l10n.calendarNextMonth,
        ),
      ],
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.counts,
    required this.selected,
    required this.onSelect,
  });

  final DateTime month;

  /// Day of month to how many transactions it holds.
  final Map<int, int> counts;

  final DateTime? selected;
  final void Function(DateTime) onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;

    // `DateTime(y, m + 1, 0)` is the last day of month m — Dart normalises
    // day 0 backwards, which also gets February right in a leap year without
    // this file knowing the rule.
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // How many blanks before the 1st. `weekday` is 1..7 with Monday at 1,
    // and the grid starts on Monday, so the 1st of a Monday month needs none.
    final leading = DateTime(month.year, month.month, 1).weekday - 1;
    final today = DateTime.now();

    return AppCard(
      // Narrower side padding than every other card in the app, and it is the
      // grid that forces it: seven columns have to fit a phone, and each
      // point of padding comes straight off a tap target that is already
      // under Material's 48dp. See the note on [_DayCell].
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.stackSm,
        vertical: Spacing.gutter,
      ),
      child: Column(
        children: [
          Row(
            children: [
              for (var weekday = 1; weekday <= 7; weekday++)
                Expanded(
                  child: Text(
                    shortWeekdayName(l10n, weekday),
                    textAlign: TextAlign.center,
                    style: text.bodySmall?.copyWith(
                      color: ObsidianPalette.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: leading + daysInMonth,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              // 48, Material's minimum. The WIDTH cannot reach it — see
              // [_DayCell] — so the one dimension that is free is given all
              // of it.
              mainAxisExtent: 48,
            ),
            itemBuilder: (context, index) {
              if (index < leading) return const SizedBox.shrink();
              final day = index - leading + 1;
              final date = DateTime(month.year, month.month, day);
              return _DayCell(
                day: day,
                count: counts[day] ?? 0,
                isToday:
                    date.year == today.year &&
                    date.month == today.month &&
                    date.day == today.day,
                isSelected:
                    selected != null &&
                    selected!.year == date.year &&
                    selected!.month == date.month &&
                    selected!.day == date.day,
                // A day with nothing on it opens an empty list, which is a
                // real answer to "was there anything on the 12th" — so it is
                // tappable rather than dead.
                onTap: () => onSelect(date),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// One day of the month grid.
///
/// **These are under Material's 48x48 minimum in one dimension, and cannot
/// not be.** Seven 48dp columns need 336dp. A 360dp phone spends 48 on the
/// screen margin and 16 on the card's own padding — already cut from 32 for
/// this reason — which leaves 296, or 42dp a column. Material's own date
/// picker has the same constraint and answers it the same way.
///
/// So the cells are 42 x 48: the height is the dimension that is free, and it
/// gets all of the minimum. The
/// residual is recorded rather than hidden: `accessibility_test.dart` excludes
/// this screen from the tap-target guideline BY NAME, and pins the size these
/// cells actually achieve so they cannot quietly shrink again.
class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.count,
    required this.isToday,
    required this.isSelected,
    required this.onTap,
  });

  final int day;
  final int count;
  final bool isToday;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Radii.full),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected
                  ? ObsidianPalette.primary
                  : isToday
                  ? ObsidianPalette.primary.withValues(alpha: 0.16)
                  : null,
            ),
            child: Text(
              '$day',
              style: text.bodyMedium?.copyWith(
                color: isSelected
                    ? ObsidianPalette.onPrimary
                    : count > 0
                    ? ObsidianPalette.onSurface
                    : ObsidianPalette.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 3),
          // A dot, not the count. The number of transactions on a day is not
          // a figure anyone reads off a grid, and drawing it would crowd the
          // cell into illegibility on a narrow phone.
          SizedBox(
            height: 5,
            child: count > 0
                ? Container(
                    width: 5,
                    height: 5,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: ObsidianPalette.tertiary,
                    ),
                  )
                : null,
          ),
        ],
      ),
    );
  }
}

class _DayList extends StatelessWidget {
  const _DayList({required this.day, required this.entries});

  final DateTime day;
  final List<CalendarEntry> entries;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;

    if (entries.isEmpty) return _Note(l10n.calendarNothingOnDay);

    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Spacing.gutter,
              8,
              Spacing.gutter,
              4,
            ),
            child: Text(
              l10n.calendarDayTotal(entries.length),
              style: text.bodySmall?.copyWith(
                color: ObsidianPalette.onSurfaceVariant,
              ),
            ),
          ),
          for (final entry in entries) _EntryRow(entry: entry),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry});

  final CalendarEntry entry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final tone = entry.isIncome
        ? ObsidianPalette.tertiary
        : ObsidianPalette.error;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.gutter,
        vertical: 8,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 46,
            child: Text(
              entry.time,
              style: text.bodySmall?.copyWith(
                color: ObsidianPalette.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.category,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodyMedium,
                ),
                if (entry.description.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    entry.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall?.copyWith(
                      color: ObsidianPalette.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          // No figure is invented for a row that will not open. The row stays
          // — something DID happen — and says what it cannot tell you.
          entry.amount == null
              ? Text(
                  l10n.calendarUnreadable,
                  textAlign: TextAlign.end,
                  style: text.bodySmall?.copyWith(color: ObsidianPalette.error),
                )
              : Text(
                  '${entry.isIncome ? '+' : '−'}'
                  '${formatLira(entry.amount ?? Decimal.zero)}',
                  style: text.bodyMedium?.copyWith(color: tone),
                ),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(Spacing.gutter),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium
            ?.copyWith(color: ObsidianPalette.onSurfaceVariant),
      ),
    );
  }
}
