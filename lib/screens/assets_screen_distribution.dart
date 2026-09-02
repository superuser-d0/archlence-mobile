part of 'assets_screen.dart';

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
    final firstShare = total > Decimal.zero ? (first / total).toDouble() : 0.0;

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
