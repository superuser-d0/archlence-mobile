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

part 'assets_screen_distribution.dart';
part 'assets_screen_trend.dart';
part 'assets_screen_holdings.dart';

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

  /// [force] is the pull-to-refresh path and nothing else.
  ///
  /// Every OTHER caller of this — the first build, a period chip, a holding
  /// bought or sold — wants the screen's data, not a new quote. The prices
  /// come back from `asset_price_cache` while they are inside the lifetime
  /// in `price_ttl.dart`, so those callers cost no network at all.
  Future<_AssetsData> _load({bool force = false}) async {
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
      livePrices: await services.livePrices.priceHoldings(
        holdings,
        force: force,
      ),
    );
  }

  void _reload({bool force = false}) {
    setState(() {
      _data = _load(force: force);
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final inset = MediaQuery.paddingOf(context);
    final horizontal = EdgeInsets.symmetric(horizontal: contentInset(context));

    return RefreshIndicator(
      // The one gesture that means "give me a new number now".
      onRefresh: () async => _reload(force: true),
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
    final horizontal = EdgeInsets.symmetric(horizontal: contentInset(context));

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

        Padding(
          padding: horizontal,
          child: _SplitCard(summary: data.summary),
        ),
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
                    // Its own announcement. Text loose in a scroll body —
                    // outside any `AppCard` — merges upward into the body's
                    // own semantics node, which then gets announced BEFORE
                    // everything it contains. Making the heading a container
                    // takes it out of that node; measured on a device, which
                    // is where the residue showed after the cards were split.
                    child: Semantics(
                      container: true,
                      child: Text(
                        context.l10n.assetsMyActiveAssets,
                        style: text.titleLarge,
                      ),
                    ),
                  ),
                  // AssetPurchaseService.createPurchase is ready and has no
                  // form; a disabled button says so.
                  IconButton(
                    // A tooltip IS the semantic label on an `IconButton`, and
                    // without one this button was absent from the semantics
                    // tree entirely — confirmed on a device, where every
                    // other control on the screen was in it and this one was
                    // not. `labeledTapTargetGuideline` does not catch it,
                    // because it sits below where the guideline lays the
                    // screen out.
                    tooltip: context.l10n.buyAssetTitle,
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
              // A container for the same reason as the heading above it: loose
              // text in a scroll body merges into the body's own node, and
              // that node is then announced first, before everything it
              // contains. Three sentences of explanation arriving before the
              // figures they explain is the worst possible order for it.
              Semantics(
                container: true,
                child: Text(
                  context.l10n.assetsLivePricingNote,
                  style: text.labelMedium?.copyWith(
                    letterSpacing: 0,
                    color: ObsidianPalette.onSurfaceVariant,
                  ),
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
