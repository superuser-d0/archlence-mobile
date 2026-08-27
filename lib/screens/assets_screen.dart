import 'package:decimal/decimal.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../app_services.dart';
import '../l10n/app_localizations.dart';
import '../money/financial_decimal.dart';
import '../services/asset_service.dart';
import '../services/financial_summary.dart';
import '../services/live_price_service.dart';
import '../services/savings_service.dart';
import '../services/transaction_service.dart';
import '../theme/obsidian_prime.dart';
import '../ui/app_locale.dart';
import '../ui/async_data.dart';
import '../ui/money_format.dart';
import '../ui/month_names.dart';
import '../ui/price_freshness.dart';
import '../widgets/savings_goal_card.dart';
import 'asset_sheets.dart';
import 'savings_sheets.dart';
import '../widgets/summary_row.dart';
import '../widgets/surfaces.dart';

/// Portfolio: cash-flow distribution, savings goals and holdings.
///
/// HOLDINGS ARE LIVE-PRICED WHERE THIS APP HAS A SOURCE. Crypto, gold and
/// currency go through `LivePriceService`; shares stay at cost, because
/// there is no keyless BIST source — see the roadmap's price-fetching
/// decision. A holding this screen cannot price, for either reason, is drawn
/// at what was paid and LABELLED as such: a cost basis presented as a market
/// value is a lie the user cannot see through, and the mockup's "Current"
/// column always claiming one is exactly that.
class AssetsScreen extends StatefulWidget {
  const AssetsScreen({super.key});

  @override
  State<AssetsScreen> createState() => _AssetsScreenState();
}

/// Everything the page draws, read in one pass so the summary, the chart and
/// the list cannot disagree with each other mid-load.
class _AssetsData {
  _AssetsData({
    required this.entries,
    required this.openingTotal,
    required this.holdings,
    required this.goals,
    required this.livePrices,
  }) : summary = summarizeTransactions(entries);

  final List<PeriodEntry> entries;

  /// The period's four buckets. Computed once here rather than per widget
  /// that wants a number out of it, so the summary line, the split card and
  /// the net figure cannot disagree.
  final FinancialSummary summary;

  /// Opening balances inside the window. They never reach `transactions`, so
  /// without this a user who has just opened a funded account sees an empty
  /// chart beside a full balance.
  final Decimal openingTotal;

  final List<Asset> holdings;
  final List<SavingsGoal> goals;

  /// Live prices, keyed by holding id. A holding absent from this map is
  /// drawn at cost — shares, an unrecognised symbol, or a symbol neither the
  /// live fetch nor the cache could answer for. See
  /// `lib/services/live_price_service.dart`.
  final Map<int, CachedPrice> livePrices;

  /// These three came from two inline loops over [entries] before the summary
  /// port. They read from it now so there is ONE definition of what counts as
  /// income on this screen — the split card underneath must not be able to add
  /// up to a different total than the line above it.
  Decimal get income => summary.totalIncome;

  Decimal get expense => summary.totalExpense;

  Decimal get net => summary.net;

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
  /// The five period chips. Held as bare [DashboardPeriod] values, with the
  /// label looked up when the chip is drawn: the desktop passes its Turkish
  /// UI labels ('1 Hafta', 'Hayat Boyu') as the filter itself, which is
  /// exactly the coupling that would break the moment the language changed.
  static const _periods = <DashboardPeriod>[
    DashboardPeriod.today,
    DashboardPeriod.week,
    DashboardPeriod.month,
    DashboardPeriod.year,
    DashboardPeriod.allTime,
  ];

  static String _periodLabel(AppLocalizations l10n, DashboardPeriod period) =>
      switch (period) {
        DashboardPeriod.today => l10n.periodToday,
        DashboardPeriod.week => l10n.periodWeek,
        DashboardPeriod.month => l10n.periodMonth,
        DashboardPeriod.year => l10n.periodYear,
        DashboardPeriod.allTime => l10n.periodAllTime,
      };
  int _period = 3;
  Future<_AssetsData>? _data;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _data ??= _load();
  }

  Future<_AssetsData> _load() async {
    final services = ServicesScope.of(context);
    final period = _periods[_period];
    final holdings = await services.assets.getAllAssets();
    return _AssetsData(
      entries: await services.transactions.getTransactionsByPeriod(period),
      openingTotal: await services.transactions.getOpeningBaselineByPeriod(
        period,
      ),
      holdings: holdings,
      goals: await services.savings.getGoals(),
      // A network round trip, awaited alongside the local reads above rather
      // than kicked off separately: a screen that drew at cost and then
      // silently repainted itself with live figures a moment later would be
      // more confusing than one load that takes slightly longer. A provider
      // outage does not fail this call — see LivePriceService's own doc —
      // so a holding this cannot price simply stays at cost.
      livePrices: await services.livePrices.priceHoldings(holdings),
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
    final horizontal = EdgeInsets.symmetric(
      horizontal: contentInset(context),
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
            child: Text(context.l10n.assetsDetails, style: text.titleLarge),
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
                label: _periodLabel(context.l10n, _periods[i]),
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
    final horizontal = EdgeInsets.symmetric(
      horizontal: contentInset(context),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: horizontal,
          child: SummaryRow(
            stats: [
              SummaryStat(
                label: context.l10n.assetsIncome,
                value: formatLira(data.income),
                tone: SummaryTone.positive,
              ),
              SummaryStat(
                label: context.l10n.assetsExpense,
                value: formatLira(data.expense),
                tone: SummaryTone.negative,
              ),
              SummaryStat(
                label: context.l10n.assetsNetBalance,
                value: formatSignedLira(data.net),
              ),
            ],
          ),
        ),
        const SizedBox(height: Spacing.stackMd),

        Padding(padding: horizontal, child: _SplitCard(summary: data.summary)),
        const SizedBox(height: Spacing.stackMd),

        Padding(
          padding: horizontal,
          child: _DistributionCard(data: data),
        ),
        const SizedBox(height: Spacing.stackMd),

        Padding(padding: horizontal, child: const _TrendCard()),
        const SizedBox(height: Spacing.stackMd),

        Padding(
          padding: horizontal,
          child: _TotalHoldingsCard(data: data),
        ),
        const SizedBox(height: Spacing.stackMd),

        Padding(
          padding: horizontal,
          child: _SavingsGoals(goals: data.goals, onChanged: onChanged),
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
                    child: Text(
                      context.l10n.assetsMyActiveAssets,
                      style: text.titleLarge,
                    ),
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
              // The mockup says "Last updated: 23:00" beside a live price;
              // this app has one now, for three of the four kinds of
              // holding — see the roadmap's price-fetching decision for
              // which and why. Each TILE says whether it is live or at
              // cost, so this line only needs to set the expectation once
              // rather than repeat a state that can differ row to row.
              Text(
                context.l10n.assetsLivePricingNote,
                style: text.labelMedium?.copyWith(
                  letterSpacing: 0,
                  color: ObsidianPalette.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: Spacing.stackMd),
              if (data.holdings.isEmpty)
                NothingYet(message: context.l10n.assetsNoHoldings)
              else
                for (final holding in data.holdings) ...[
                  _HoldingTile(
                    holding: holding,
                    price: data.livePrices[holding.id],
                    onChanged: onChanged,
                  ),
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
/// What the period was SPENT ON having to be, against what it chose to be.
///
/// The visible half of `categories.importance` — the column this app read and
/// never used until the settings screen gave the user a way to set it. Two
/// bars rather than one: income splits main/extra and expense splits
/// essential/chosen, and putting all four on one scale would invite reading a
/// salary against the rent as if they were parts of the same whole.
///
/// **It says when it has nothing to say.** A household that has marked nothing
/// essential gets a sentence pointing at the screen that decides it, not two
/// bars silently pinned to one end — which looks like a bug in the chart
/// rather than a setting nobody has touched.
class _SplitCard extends StatelessWidget {
  const _SplitCard({required this.summary});

  final FinancialSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;

    return AppCard(
      padding: const EdgeInsets.all(Spacing.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.assetsSplitTitle, style: text.titleLarge),
          const SizedBox(height: Spacing.stackSm),
          if (summary.isEmpty)
            Text(
              l10n.assetsSplitEmpty,
              style: text.bodyMedium?.copyWith(
                color: ObsidianPalette.onSurfaceVariant,
              ),
            )
          else ...[
            if (summary.totalIncome > Decimal.zero) ...[
              _SplitBar(
                firstLabel: l10n.categoryMainIncome,
                first: summary.mainIncome,
                firstColor: ObsidianPalette.tertiary,
                secondLabel: l10n.categoryExtraIncome,
                second: summary.extraIncome,
                secondColor: ObsidianPalette.secondary,
              ),
              const SizedBox(height: Spacing.stackMd),
            ],
            if (summary.totalExpense > Decimal.zero)
              _SplitBar(
                firstLabel: l10n.categoryEssentialExpense,
                first: summary.essentialExpense,
                firstColor: ObsidianPalette.error,
                secondLabel: l10n.categoryExtraExpense,
                second: summary.extraExpense,
                secondColor: ObsidianPalette.primary,
              ),
            if (summary.essentialExpense == Decimal.zero &&
                summary.mainIncome == Decimal.zero) ...[
              const SizedBox(height: Spacing.stackSm),
              Text(
                l10n.assetsSplitNothingMarked,
                style: text.bodySmall?.copyWith(
                  color: ObsidianPalette.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// One two-part bar with both figures spelled out under it.
///
/// The numbers are printed as well as drawn. A proportion bar answers "how
/// much of it", never "how much" — and this app does not make a user estimate
/// an amount off a width.
class _SplitBar extends StatelessWidget {
  const _SplitBar({
    required this.firstLabel,
    required this.first,
    required this.firstColor,
    required this.secondLabel,
    required this.second,
    required this.secondColor,
  });

  final String firstLabel;
  final Decimal first;
  final Color firstColor;
  final String secondLabel;
  final Decimal second;
  final Color secondColor;

  @override
  Widget build(BuildContext context) {
    final total = first + second;
    // Guarded because a bar of nothing would divide by zero; the caller only
    // draws this when the total is positive, and this keeps that true here
    // rather than by remote agreement.
    final firstShare = total > Decimal.zero
        ? (first / total).toDouble()
        : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(Radii.full),
          child: SizedBox(
            height: 10,
            child: Row(
              // STRETCH, not the default centre. A `ColoredBox` with no child
              // asks for no height at all, so a centred row gave each side a
              // full width and a height of ZERO: the bar was in the tree, laid
              // out, and invisible. Every widget test passed — they assert the
              // figures, and the figures were right. It took opening the
              // screen on the emulator to see the empty strip.
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (firstShare > 0)
                  Expanded(
                    flex: (firstShare * 1000).round(),
                    child: ColoredBox(color: firstColor),
                  ),
                if (firstShare < 1)
                  Expanded(
                    flex: ((1 - firstShare) * 1000).round(),
                    child: ColoredBox(color: secondColor),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Spacing.stackSm),
        Row(
          children: [
            Expanded(
              child: _SplitLegend(
                label: firstLabel,
                amount: first,
                share: firstShare,
                color: firstColor,
              ),
            ),
            Expanded(
              child: _SplitLegend(
                label: secondLabel,
                amount: second,
                share: 1 - firstShare,
                color: secondColor,
                alignEnd: true,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SplitLegend extends StatelessWidget {
  const _SplitLegend({
    required this.label,
    required this.amount,
    required this.share,
    required this.color,
    this.alignEnd = false,
  });

  final String label;
  final Decimal amount;

  /// This side's part of the bar, 0..1. Printed as well as drawn: a width
  /// answers "how much of it", and a reader should not have to estimate the
  /// proportion off one.
  final double share;

  final Color color;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: alignEnd
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: text.bodySmall?.copyWith(
                  color: ObsidianPalette.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(formatLira(amount), style: text.bodyMedium),
        Text(
          formatPercent(Decimal.parse((share * 100).toStringAsFixed(1))),
          style: text.bodySmall?.copyWith(
            color: ObsidianPalette.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

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

  /// [openingBalanceLabel] is passed in rather than read from a context:
  /// this builds the chart's data, and the one slice that is not a stored
  /// category still needs a name in the user's language.
  List<_Slice> _slices(String openingBalanceLabel) {
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
          openingBalanceLabel,
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
    final slices = _slices(context.l10n.assetsOpeningBalance);

    if (slices.isEmpty) {
      return NothingYet(message: context.l10n.assetsNoDistribution);
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
                    Text(
                      context.l10n.assetsDistributionTitle,
                      style: text.titleLarge,
                    ),
                    Text(
                      context.l10n.assetsDistributionSubtitle,
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
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _LegendDot(
                color: ObsidianPalette.tertiary,
                label: context.l10n.assetsIncome,
              ),
              const SizedBox(width: Spacing.stackMd),
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
              for (final index in [0, 4, 8, 11])
                Text(
                  series[index].label(context.l10n),
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
/// it. That is not what this card shows — DELIBERATELY, even now that a
/// price feed exists for three of the four holding kinds. This card sums
/// PURCHASE PRICE across a portfolio that can hold shares at cost beside
/// crypto at a live price at the same time; blending the two into one total
/// would present a figure that is part market value and part cost basis
/// under a single number with no way to tell which parts are which. Each
/// [_HoldingTile] draws that distinction correctly, tile by tile; this card
/// stays what it has always been; an honest cost total, not an approximate
/// portfolio value.
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
            context.l10n.assetsHoldingsAtCost,
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
                ? context.l10n.assetsNothingBought
                : context.l10n.assetsHoldingCount(data.holdings.length),
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
  const _SavingsGoals({required this.goals, required this.onChanged});

  final List<SavingsGoal> goals;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    if (goals.isEmpty) {
      return NothingYet(message: context.l10n.assetsNoGoals);
    }
    return Column(
      children: [
        for (final goal in goals) ...[
          SavingsGoalCard(
            goal: goal,
            onMoveMoney: () async {
              final moved = await showMoveMoneySheet(context, goal);
              if (moved ?? false) onChanged();
            },
          ),
          if (goal != goals.last) const SizedBox(height: Spacing.stackMd),
        ],
      ],
    );
  }
}

/// One holding, live-priced where a price was found and at cost otherwise.
///
/// The mockup's right-hand column is "Current" with a live price and a
/// green/red tone, always. That is now true for three of the four kinds of
/// holding this app knows — [price] is null for the fourth (shares) and for
/// anything neither the live fetch nor the cache could answer — and for
/// those the column stays exactly what it always was: the cost of the
/// position, with no colour that would imply a gain or a loss that was never
/// measured.
class _HoldingTile extends StatelessWidget {
  const _HoldingTile({
    required this.holding,
    required this.price,
    required this.onChanged,
  });

  final Asset holding;

  /// Null means "show this at cost" — see the class doc for the two reasons
  /// that happens.
  final CachedPrice? price;

  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final l10n = context.l10n;
    final cost = fiat(holding.purchasePrice * holding.quantity);
    final live = price;
    // `PnlSignal.error` is the same "could not be read" case
    // `AsyncData`/`DataUnavailable` refuse to show as a figure elsewhere in
    // this app — a price this method could not turn into a number is drawn
    // exactly like having no price at all, never as a silent zero.
    final pnl = live == null
        ? null
        : AssetService.calculatePnl(
            currentPrice: live.pricePerUnit,
            purchasePrice: holding.purchasePrice,
            quantity: holding.quantity,
          );
    final priced = pnl != null && pnl.signal != PnlSignal.error;
    final tone = switch (pnl?.signal) {
      PnlSignal.profit => ObsidianPalette.tertiary,
      PnlSignal.loss => ObsidianPalette.error,
      _ => null,
    };

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
                  l10n.assetsHoldingName(
                    holding.assetName,
                    holding.assetCode,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.assetsPurchaseLine(
                    formatLira(holding.purchasePrice),
                    '${holding.quantity}',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.labelMedium?.copyWith(
                    letterSpacing: 0,
                    color: ObsidianPalette.onSurfaceVariant,
                  ),
                ),
                if (priced) ...[
                  const SizedBox(height: 2),
                  Text(
                    l10n.assetPnlAndAge(
                      formatPercent(pnl.pnlPct!, signed: true),
                      priceAge(
                        l10n,
                        DateTime.now().toUtc().difference(live!.asOf.toUtc()),
                      ),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.labelMedium?.copyWith(
                      letterSpacing: 0,
                      color: tone,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: Spacing.stackSm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                priced ? l10n.assetCurrent : l10n.assetsCost,
                style: text.labelMedium?.copyWith(
                  letterSpacing: 0,
                  color: ObsidianPalette.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                formatLira(priced ? pnl.totalValue! : cost),
                style: text.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: priced ? tone : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
