part of 'assets_screen.dart';

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
                  l10n.assetsHoldingName(holding.assetName, holding.assetCode),
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
          // The trailing block is `Flexible` for the same reason the credit-card
          // badge is: with only the middle column `Expanded`, a narrow phone
          // squeezes that to nothing and this side STILL overflows. Found by
          // moving `pumpScreen` to a phone width -- the tab and route sweeps
          // do not reach this state, because a holding only has a Current
          // column once a price has arrived.
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  priced ? l10n.assetCurrent : l10n.assetsCost,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.labelMedium?.copyWith(
                    letterSpacing: 0,
                    color: ObsidianPalette.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  formatLira(priced ? pnl.totalValue! : cost),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: priced ? tone : null,
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
