part of 'assets_screen.dart';

/// Income against expense, month by month, over the last twelve months.
///
/// Bucketed here rather than in SQL because `transactions.amount` is
/// encrypted — a `SUM() GROUP BY month` would add up ciphertext. The window
/// is fixed at a year regardless of the period chips above: a trend line over
/// "Today" would be a single point, and the chips select what the summary and
/// the distribution report on, not the shape of history.
class _TrendCard extends StatefulWidget {
  const _TrendCard();

  @override
  State<_TrendCard> createState() => _TrendCardState();
}

/// One month's totals.
class _MonthlyTotals {
  const _MonthlyTotals({
    required this.year,
    required this.month,
    required this.income,
    required this.expense,
  });

  final int year;
  final int month;
  final Decimal income;
  final Decimal expense;

  /// `Sep'25` — the mockup's axis form.
  String label(AppLocalizations l10n) => l10n.monthYearShort(
    shortMonthName(l10n, month),
    year.toString().substring(2),
  );
}

class _TrendCardState extends State<_TrendCard> {
  Future<List<_MonthlyTotals>>? _series;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _series ??= _load();
  }

  Future<List<_MonthlyTotals>> _load() async {
    final entries = await ServicesScope.of(context).transactions
        .getTransactionsByPeriod(DashboardPeriod.year);

    final income = <String, Decimal>{};
    final expense = <String, Decimal>{};
    for (final entry in entries) {
      // A stored stamp is always `YYYY-MM-DD...`; anything shorter is not a
      // date this app wrote and is left out rather than guessed at.
      if (entry.transactionDate.length < 7) continue;
      final key = entry.transactionDate.substring(0, 7);
      if (entry.isIncome) {
        income[key] = (income[key] ?? Decimal.zero) + entry.amount;
      } else if (entry.isExpense) {
        expense[key] = (expense[key] ?? Decimal.zero) + entry.amount;
      }
    }

    // Every month in the window appears, including the empty ones: a gap
    // silently closed would make a quiet month look like it never happened.
    final now = DateTime.now();
    return [
      for (var back = 11; back >= 0; back--)
        () {
          final month = DateTime(now.year, now.month - back, 1);
          final key =
              '${month.year.toString().padLeft(4, '0')}-'
              '${month.month.toString().padLeft(2, '0')}';
          return _MonthlyTotals(
            year: month.year,
            month: month.month,
            income: income[key] ?? Decimal.zero,
            expense: expense[key] ?? Decimal.zero,
          );
        }(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return AsyncData<List<_MonthlyTotals>>(
      future: _series!,
      placeholderHeight: 220,
      builder: (context, series) => _TrendChart(series: series),
    );
  }
}

class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.series});

  final List<_MonthlyTotals> series;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    // A shared scale for both lines, so income and expense can be compared
    // against each other rather than each filling the card on its own.
    var peak = Decimal.zero;
    for (final month in series) {
      if (month.income > peak) peak = month.income;
      if (month.expense > peak) peak = month.expense;
    }
    if (peak <= Decimal.zero) {
      return NothingYet(message: context.l10n.assetsNoTrend);
    }
    final maxY = peak.toDouble();

    List<FlSpot> spots(Decimal Function(_MonthlyTotals) pick) => [
      for (var i = 0; i < series.length; i++)
        FlSpot(i.toDouble(), pick(series[i]).toDouble()),
    ];

    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        children: [
          // A `Wrap`, not a `Row`: at a large font scale the two labels are
          // wider than the card and a `Row` has nowhere to put the overflow —
          // 12 pixels over at 1.5x, 90 at 2.0x. This drops the second entry
          // onto its own line instead, which is what a legend is allowed to
          // do and an overflow is not.
          Wrap(
            alignment: WrapAlignment.end,
            spacing: Spacing.stackMd,
            runSpacing: Spacing.stackSm,
            children: [
              _LegendDot(
                color: ObsidianPalette.tertiary,
                label: context.l10n.assetsIncome,
              ),
              _LegendDot(
                color: ObsidianPalette.error,
                label: context.l10n.assetsExpense,
              ),
            ],
          ),
          const SizedBox(height: Spacing.stackMd),
          SizedBox(
            height: 150,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY / 4,
                  getDrawingHorizontalLine: (_) => const FlLine(
                    color: ObsidianPalette.surfaceContainerHigh,
                    strokeWidth: 1,
                  ),
                ),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineTouchData: const LineTouchData(enabled: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots((month) => month.income),
                    color: ObsidianPalette.tertiary,
                    barWidth: 2,
                    isCurved: true,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: ObsidianPalette.tertiary.withValues(alpha: 0.12),
                    ),
                  ),
                  LineChartBarData(
                    spots: spots((month) => month.expense),
                    color: ObsidianPalette.error,
                    barWidth: 2,
                    isCurved: true,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Spacing.stackSm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Four labels across twelve months: every month would not fit.
              //
              // `Flexible` because four of them do not fit either, on a 320dp
              // phone — two pixels over, which is enough to paint the stripes
              // and enough to fail a layout. A month label that has to give
              // up a character is a better answer than a row that cannot be
              // laid out at all.
              for (final index in [0, 4, 8, 11])
                Flexible(
                  child: Text(
                    series[index].label(context.l10n),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.labelMedium?.copyWith(
                      fontSize: 10,
                      letterSpacing: 0,
                      color: ObsidianPalette.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 14, height: 2, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            letterSpacing: 0,
            color: ObsidianPalette.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
