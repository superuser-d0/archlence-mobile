import 'package:decimal/decimal.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../app_services.dart';
import '../money/financial_decimal.dart';
import '../services/asset_service.dart';
import '../services/savings_service.dart';
import '../services/transaction_service.dart';
import '../theme/obsidian_prime.dart';
import '../ui/async_data.dart';
import '../ui/money_format.dart';
import '../widgets/savings_goal_card.dart';
import 'asset_sheets.dart';
import '../widgets/summary_row.dart';
import '../widgets/surfaces.dart';

/// Portfolio: cash-flow distribution, savings goals and holdings.
///
/// HOLDINGS ARE SHOWN AT COST. There is no price source yet (roadmap open
/// question 3), so every figure here is what was paid, labelled as such. A
/// cost basis presented as a market value is a lie the user cannot see
/// through, and the mockup's "Current" column is exactly that.
class AssetsScreen extends StatefulWidget {
  const AssetsScreen({super.key});

  @override
  State<AssetsScreen> createState() => _AssetsScreenState();
}

/// Everything the page draws, read in one pass so the summary, the chart and
/// the list cannot disagree with each other mid-load.
class _AssetsData {
  const _AssetsData({
    required this.entries,
    required this.openingTotal,
    required this.holdings,
    required this.goals,
  });

  final List<PeriodEntry> entries;

  /// Opening balances inside the window. They never reach `transactions`, so
  /// without this a user who has just opened a funded account sees an empty
  /// chart beside a full balance.
  final Decimal openingTotal;

  final List<Asset> holdings;
  final List<SavingsGoal> goals;

  Decimal get income {
    var total = Decimal.zero;
    for (final entry in entries) {
      if (entry.isIncome) total += entry.amount;
    }
    return fiat(total);
  }

  Decimal get expense {
    var total = Decimal.zero;
    for (final entry in entries) {
      if (entry.isExpense) total += entry.amount;
    }
    return fiat(total);
  }

  Decimal get net => fiat(income - expense);

  /// What the holdings cost, never what they are worth.
  Decimal get holdingsCost {
    var total = Decimal.zero;
    for (final holding in holdings) {
      total += holding.purchasePrice * holding.quantity;
    }
    return fiat(total);
  }
}

class _AssetsScreenState extends State<AssetsScreen> {
  static const _periods = <(String, DashboardPeriod)>[
    ('Today', DashboardPeriod.today),
    ('1 Week', DashboardPeriod.week),
    ('1 Month', DashboardPeriod.month),
    ('1 Year', DashboardPeriod.year),
    ('All Time', DashboardPeriod.allTime),
  ];
  int _period = 3;
  Future<_AssetsData>? _data;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _data ??= _load();
  }

  Future<_AssetsData> _load() async {
    final services = ServicesScope.of(context);
    final period = _periods[_period].$2;
    return _AssetsData(
      entries: await services.transactions.getTransactionsByPeriod(period),
      openingTotal: await services.transactions.getOpeningBaselineByPeriod(
        period,
      ),
      holdings: await services.assets.getAllAssets(),
      goals: await services.savings.getGoals(),
    );
  }

  void _reload() {
    setState(() {
      _data = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final inset = MediaQuery.paddingOf(context);
    const horizontal = EdgeInsets.symmetric(
      horizontal: Spacing.containerMargin,
    );

    return RefreshIndicator(
      onRefresh: () async => _reload(),
      child: ListView(
        key: const PageStorageKey('assets'),
        padding: EdgeInsets.only(
          top: inset.top + Spacing.stackMd,
          bottom: inset.bottom + Spacing.stackLg,
        ),
        children: [
          Padding(
            padding: horizontal,
            child: Text('Details', style: text.titleLarge),
          ),
          const SizedBox(height: Spacing.stackMd),

          // Five period chips genuinely do not fit at 412dp, so this row
          // really does scroll — unlike the summary figures below, no single
          // chip is information the user must not miss.
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: horizontal,
              itemCount: _periods.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) => _PeriodChip(
                label: _periods[i].$1,
                selected: i == _period,
                onTap: () {
                  setState(() {
                    _period = i;
                    _data = _load();
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: Spacing.stackLg),

          AsyncData<_AssetsData>(
            future: _data!,
            placeholderHeight: 420,
            builder: (context, data) =>
                _AssetsBody(data: data, onChanged: _reload),
          ),
        ],
      ),
    );
  }
}

class _AssetsBody extends StatelessWidget {
  const _AssetsBody({required this.data, required this.onChanged});

  final _AssetsData data;

  /// Called after a write, so the page re-reads what it just changed.
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    const horizontal = EdgeInsets.symmetric(
      horizontal: Spacing.containerMargin,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: horizontal,
          child: SummaryRow(
            stats: [
              SummaryStat(
                label: 'Income',
                value: formatLira(data.income),
                tone: SummaryTone.positive,
              ),
              SummaryStat(
                label: 'Expense',
                value: formatLira(data.expense),
                tone: SummaryTone.negative,
              ),
              SummaryStat(
                label: 'Net Balance',
                value: formatSignedLira(data.net),
              ),
            ],
          ),
        ),
        const SizedBox(height: Spacing.stackLg),

        Padding(
          padding: horizontal,
          child: _DistributionCard(data: data),
        ),
        const SizedBox(height: Spacing.stackMd),

        const Padding(padding: horizontal, child: _TrendCard()),
        const SizedBox(height: Spacing.stackMd),

        Padding(
          padding: horizontal,
          child: _TotalHoldingsCard(data: data),
        ),
        const SizedBox(height: Spacing.stackMd),

        Padding(
          padding: horizontal,
          child: _SavingsGoals(goals: data.goals),
        ),
        const SizedBox(height: Spacing.sectionGap),

        Padding(
          padding: horizontal,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.trending_up,
                    size: 20,
                    color: ObsidianPalette.tertiary,
                  ),
                  const SizedBox(width: Spacing.stackSm),
                  Expanded(
                    child: Text('My Active Assets', style: text.titleLarge),
                  ),
                  // AssetPurchaseService.createPurchase is ready and has no
                  // form; a disabled button says so.
                  IconButton(
                    onPressed: () async {
                      final bought = await showBuyAssetSheet(context);
                      if (bought != null) onChanged();
                    },
                    icon: const Icon(Icons.add, color: ObsidianPalette.primary),
                  ),
                ],
              ),
              // The mockup says "Last updated: 23:00" beside a live price.
              // There is no price feed, so the honest line is what these
              // figures actually are.
              Text(
                'Valued at purchase cost — no price source yet',
                style: text.labelMedium?.copyWith(
                  letterSpacing: 0,
                  color: ObsidianPalette.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: Spacing.stackMd),
              if (data.holdings.isEmpty)
                const NothingYet(
                  message:
                      'No holdings yet. Anything you buy shows here with '
                      'what it cost.',
                )
              else
                for (final holding in data.holdings) ...[
                  _HoldingTile(holding: holding, onChanged: onChanged),
                  const SizedBox(height: Spacing.stackMd),
                ],
            ],
          ),
        ),
      ],
    );
  }
}

class _PeriodChip extends StatelessWidget {
  const _PeriodChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: selected
              ? ObsidianPalette.primaryContainer
              : ObsidianPalette.surfaceContainer,
          borderRadius: BorderRadius.circular(Radii.full),
          border: Border.all(color: ObsidianPalette.cardStroke),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            letterSpacing: 0,
            color: selected
                ? ObsidianPalette.onPrimary
                : ObsidianPalette.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _Slice {
  const _Slice(this.label, this.amount, this.share, this.color);

  final String label;
  final Decimal amount;

  /// 0..100.
  final Decimal share;
  final Color color;
}

/// Where the period's money came from and went, by category.
///
/// Income and expense are shown TOGETHER, as the desktop does: the chart is a
/// distribution of everything that moved, not of spending alone. Opening
/// balances get their own slice because they never reach `transactions` and a
/// user who has just funded an account would otherwise see an empty chart.
class _DistributionCard extends StatelessWidget {
  const _DistributionCard({required this.data});

  final _AssetsData data;

  /// Enough hues to tell slices apart, cycled if a user has more categories
  /// than colours. Green reads as income and red as expense in this palette,
  /// so those two lead their own groups.
  static const _incomeColors = [
    Color(0xFF4EDEA3),
    Color(0xFF00885D),
    Color(0xFFC0C1FF),
  ];
  static const _expenseColors = [
    Color(0xFFFFB4AB),
    Color(0xFFD0BCFF),
    Color(0xFF93000A),
  ];

  List<_Slice> _slices() {
    final incomeByCategory = <String, Decimal>{};
    final expenseByCategory = <String, Decimal>{};
    for (final entry in data.entries) {
      if (entry.isIncome) {
        incomeByCategory[entry.category] =
            (incomeByCategory[entry.category] ?? Decimal.zero) + entry.amount;
      } else if (entry.isExpense) {
        expenseByCategory[entry.category] =
            (expenseByCategory[entry.category] ?? Decimal.zero) + entry.amount;
      }
    }

    var total = data.openingTotal;
    for (final amount in incomeByCategory.values) {
      total += amount;
    }
    for (final amount in expenseByCategory.values) {
      total += amount;
    }
    if (total <= Decimal.zero) return const [];

    Decimal shareOf(Decimal amount) => percentage(
      (amount / total).toDecimal(scaleOnInfinitePrecision: 20) *
          Decimal.fromInt(100),
    );

    final slices = <_Slice>[];
    var index = 0;
    for (final entry in incomeByCategory.entries) {
      slices.add(
        _Slice(
          entry.key,
          entry.value,
          shareOf(entry.value),
          _incomeColors[index++ % _incomeColors.length],
        ),
      );
    }
    if (data.openingTotal > Decimal.zero) {
      slices.add(
        _Slice(
          'Opening Balance',
          data.openingTotal,
          shareOf(data.openingTotal),
          _incomeColors[index++ % _incomeColors.length],
        ),
      );
    }
    index = 0;
    for (final entry in expenseByCategory.entries) {
      slices.add(
        _Slice(
          entry.key,
          entry.value,
          shareOf(entry.value),
          _expenseColors[index++ % _expenseColors.length],
        ),
      );
    }
    return slices;
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final slices = _slices();

    if (slices.isEmpty) {
      return const NothingYet(
        message:
            'Nothing moved in this period, so there is no distribution '
            'to draw.',
      );
    }

    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          SizedBox(
            height: 200,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 58,
                    startDegreeOffset: -90,
                    sections: [
                      for (final slice in slices)
                        PieChartSectionData(
                          value: slice.share.toDouble(),
                          color: slice.color,
                          radius: 26,
                          showTitle: false,
                        ),
                    ],
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Asset', style: text.titleLarge),
                    Text(
                      'Distribution',
                      style: text.labelMedium?.copyWith(
                        letterSpacing: 0,
                        color: ObsidianPalette.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: Spacing.stackMd),
          for (final slice in slices)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: slice.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: Spacing.stackSm),
                  Expanded(
                    child: Text(
                      slice.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall,
                    ),
                  ),
                  Text(
                    formatPercent(slice.share),
                    style: text.bodySmall?.copyWith(
                      color: ObsidianPalette.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

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
  String get label {
    const names = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return "${names[month - 1]}'${year.toString().substring(2)}";
  }
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
      return const NothingYet(
        message:
            'No income or spending in the last year, so there is no '
            'trend to draw yet.',
      );
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
          const Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _LegendDot(color: ObsidianPalette.tertiary, label: 'Income'),
              SizedBox(width: Spacing.stackMd),
              _LegendDot(color: ObsidianPalette.error, label: 'Expense'),
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
              for (final index in [0, 4, 8, 11])
                Text(
                  series[index].label,
                  style: text.labelMedium?.copyWith(
                    fontSize: 10,
                    letterSpacing: 0,
                    color: ObsidianPalette.onSurfaceVariant,
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

/// What the portfolio cost, said plainly.
///
/// The mockup shows a total with a "+₺7.858,53 (+1.52%) Today" chip beside
/// it. Both need a price feed; without one the total is a cost basis and the
/// change does not exist, so the chip is gone rather than filled with a
/// figure that would look like a gain.
class _TotalHoldingsCard extends StatelessWidget {
  const _TotalHoldingsCard({required this.data});

  final _AssetsData data;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Text(
            'Holdings at Cost',
            style: text.bodySmall?.copyWith(
              color: ObsidianPalette.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              formatLira(data.holdingsCost),
              maxLines: 1,
              style: text.headlineLarge,
            ),
          ),
          const SizedBox(height: Spacing.stackSm),
          Text(
            data.holdings.isEmpty
                ? 'Nothing bought yet'
                : '${data.holdings.length} holdings',
            style: text.labelMedium?.copyWith(
              letterSpacing: 0,
              color: ObsidianPalette.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// The savings goals, in place of the mockup's single "Emergency Fund".
///
/// The mockup hard-codes one fund with a fixed target; the data model has
/// however many goals the user opened, each with its own target and status.
/// Showing only the first would hide the rest.
class _SavingsGoals extends StatelessWidget {
  const _SavingsGoals({required this.goals});

  final List<SavingsGoal> goals;

  @override
  Widget build(BuildContext context) {
    if (goals.isEmpty) {
      return const NothingYet(
        message:
            'No savings goals yet. A goal holds money aside from your '
            'balance without counting as spending.',
      );
    }
    return Column(
      children: [
        for (final goal in goals) ...[
          SavingsGoalCard(goal: goal),
          if (goal != goals.last) const SizedBox(height: Spacing.stackMd),
        ],
      ],
    );
  }
}

/// One holding, shown at what it cost.
///
/// The mockup's right-hand column is "Current" with a live price and a
/// green/red tone. Without a price feed there is no current value and no
/// direction, so the column shows the cost of the position and carries no
/// colour that would imply a gain or a loss.
class _HoldingTile extends StatelessWidget {
  const _HoldingTile({required this.holding, required this.onChanged});

  final Asset holding;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cost = fiat(holding.purchasePrice * holding.quantity);

    return AppCard(
      // No detail screen; tapping sells, which is the only thing there is to
      // do with a holding today.
      onTap: () async {
        final sold = await showSellAssetSheet(context, holding);
        if (sold != null) onChanged();
      },
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: ObsidianPalette.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              // The code's first character, upper-cased — enough to tell
              // holdings apart at a glance without inventing an icon set.
              holding.assetCode.isEmpty
                  ? '?'
                  : holding.assetCode.substring(0, 1),
              style: text.bodyLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: ObsidianPalette.primary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${holding.assetName} (${holding.assetCode})',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  'Purchase: ${formatLira(holding.purchasePrice)} × '
                  '${holding.quantity}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.labelMedium?.copyWith(
                    letterSpacing: 0,
                    color: ObsidianPalette.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: Spacing.stackSm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Cost',
                style: text.labelMedium?.copyWith(
                  letterSpacing: 0,
                  color: ObsidianPalette.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                formatLira(cost),
                style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
