import 'package:flutter/material.dart';

import '../theme/obsidian_prime.dart';
import '../widgets/balance_ring.dart';
import '../widgets/surfaces.dart';

/// Dashboard. Figures are placeholders until the data layer lands.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _periods = ['Today', '1 Week', '1 Month', '1 Year'];
  int _period = 3;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    // AppShell folds the translucent header and nav bar into this inset.
    final inset = MediaQuery.paddingOf(context);

    return ListView(
      key: const PageStorageKey('home'),
      padding: EdgeInsets.fromLTRB(
        Spacing.containerMargin,
        inset.top + Spacing.stackMd,
        Spacing.containerMargin,
        inset.bottom + Spacing.stackLg,
      ),
      children: [
        const _SearchField(),
        const SizedBox(height: Spacing.stackMd),
        const Center(child: _WalletSelector()),
        const SizedBox(height: Spacing.stackLg),

        const Center(
          child: BalanceRing(
            amount: '334.401,80 ₺',
            changeLabel: '-%6.2',
            changeIsPositive: false,
            periodLabel: 'Change (1 Year)',
            progress: 0.75,
          ),
        ),
        const SizedBox(height: Spacing.stackLg),

        _PeriodSelector(
          periods: _periods,
          selected: _period,
          onChanged: (index) => setState(() => _period = index),
        ),
        const SizedBox(height: Spacing.stackMd),

        Row(
          spacing: Spacing.gutter,
          children: const [
            Expanded(
              child: _MiniStat(label: '1 Year', value: '-22.131,50 ₺'),
            ),
            Expanded(
              child: _MiniStat(label: 'Total', value: '334.401,80 ₺'),
            ),
          ],
        ),
        const SizedBox(height: Spacing.sectionGap),

        const _ForecastCard(),
        const SizedBox(height: Spacing.sectionGap),

        const _HealthScoreCard(),
        const SizedBox(height: Spacing.sectionGap),

        Row(
          spacing: Spacing.stackSm,
          children: [
            const Icon(Icons.autorenew, size: 20,
                color: ObsidianPalette.tertiary),
            Text('My Active Subscriptions', style: text.titleLarge),
          ],
        ),
        const SizedBox(height: Spacing.stackMd),
        const _SubscriptionCard(
          name: 'Rent',
          amount: '₺30.000,00',
          renews: 'Renews on the 7th of each month',
        ),
        const SizedBox(height: Spacing.stackMd),
        const _SubscriptionCard(
          name: 'Fiber internet',
          amount: '₺690,00',
          renews: 'Renews on the 9th of each month',
        ),
      ],
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField();

  @override
  Widget build(BuildContext context) {
    return TextField(
      decoration: InputDecoration(
        hintText: 'Search in Archlence...',
        prefixIcon: const Icon(Icons.search, size: 20),
        fillColor: ObsidianPalette.surfaceContainerHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.full),
          borderSide: const BorderSide(color: ObsidianPalette.cardStroke),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.full),
          borderSide: const BorderSide(color: ObsidianPalette.cardStroke),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.full),
          borderSide: BorderSide(
            color: ObsidianPalette.primary.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }
}

class _WalletSelector extends StatelessWidget {
  const _WalletSelector();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      radius: Radii.full,
      color: ObsidianPalette.surfaceContainerHigh,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      onTap: () {},
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: Spacing.stackSm,
        children: [
          const Icon(Icons.account_balance_wallet_outlined, size: 18),
          Text(
            'My Wallet',
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(letterSpacing: 0),
          ),
          const Icon(Icons.expand_more, size: 18),
        ],
      ),
    );
  }
}

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({
    required this.periods,
    required this.selected,
    required this.onChanged,
  });

  final List<String> periods;
  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: ObsidianPalette.surfaceContainer,
        borderRadius: BorderRadius.circular(Radii.full),
        border: Border.all(color: ObsidianPalette.cardStroke),
      ),
      child: Row(
        children: [
          for (var i = 0; i < periods.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(i),
                child: Container(
                  // 44px minimum touch target.
                  height: 36,
                  alignment: Alignment.center,
                  decoration: i == selected
                      ? BoxDecoration(
                          color: ObsidianPalette.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(Radii.full),
                          border:
                              Border.all(color: ObsidianPalette.cardStroke),
                        )
                      : null,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      periods[i],
                      style:
                          Theme.of(context).textTheme.labelMedium?.copyWith(
                                letterSpacing: 0,
                                color: i == selected
                                    ? ObsidianPalette.onSurface
                                    : ObsidianPalette.onSurfaceVariant,
                              ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AppCard(
      radius: Radii.md,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: text.labelMedium?.copyWith(
              letterSpacing: 0,
              color: ObsidianPalette.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, maxLines: 1, style: text.titleLarge),
          ),
        ],
      ),
    );
  }
}

class _ForecastCard extends StatelessWidget {
  const _ForecastCard();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(Radii.lg),
      child: Stack(
        children: [
          AppCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  spacing: 12,
                  children: [
                    const Icon(Icons.trending_up, size: 20,
                        color: ObsidianPalette.tertiary),
                    Text('Algorithmic Forecast', style: text.titleLarge),
                  ],
                ),
                const SizedBox(height: Spacing.stackMd),
                Text(
                  'Compared with the previous period, your spending this '
                  'month %9.1 increased.',
                  style: text.bodySmall
                      ?.copyWith(color: ObsidianPalette.onSurfaceVariant),
                ),
                const SizedBox(height: Spacing.stackSm),
                Text(
                  'Highest-spending category: Asset Purchase.',
                  style: text.bodySmall
                      ?.copyWith(color: ObsidianPalette.onSurfaceVariant),
                ),
                const SizedBox(height: Spacing.stackSm),
                Text(
                  'Your net savings rate this month: %-2.5.',
                  style: text.bodySmall
                      ?.copyWith(color: ObsidianPalette.onSurfaceVariant),
                ),
                const SizedBox(height: Spacing.stackMd),
                const Divider(),
                const SizedBox(height: Spacing.stackMd),
                Text(
                  'Based on the last 3 months of statistics, you are expected '
                  'to have 359.843,69 ₺ left at the end of this month; you '
                  'could consider putting it toward an investment.',
                  style: text.bodySmall
                      ?.copyWith(color: ObsidianPalette.onSurfaceVariant),
                ),
              ],
            ),
          ),
          // The tertiary-to-primary hairline along the card's top edge.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 3,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    ObsidianPalette.tertiary.withValues(alpha: 0.5),
                    ObsidianPalette.primary.withValues(alpha: 0.5),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HealthScoreCard extends StatelessWidget {
  const _HealthScoreCard();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AppCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            spacing: 12,
            children: [
              const Icon(Icons.monitor_heart_outlined, size: 20,
                  color: ObsidianPalette.primary),
              Text('Financial Health Score', style: text.titleLarge),
            ],
          ),
          const SizedBox(height: Spacing.stackMd),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            spacing: 12,
            children: [
              Text(
                '72',
                style: text.displayLarge
                    ?.copyWith(color: ObsidianPalette.tertiary),
              ),
              Text('Good', style: text.bodyLarge),
            ],
          ),
          const SizedBox(height: Spacing.stackMd),
          ClipRRect(
            borderRadius: BorderRadius.circular(Radii.full),
            child: LinearProgressIndicator(
              value: 0.72,
              minHeight: 6,
              backgroundColor: ObsidianPalette.surfaceContainerHigh,
              valueColor: const AlwaysStoppedAnimation(
                ObsidianPalette.tertiary,
              ),
            ),
          ),
          const SizedBox(height: Spacing.stackSm),
          Text(
            'Savings rate %21   ·   Debt/income %15   ·   '
            'Expense volatility %41',
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

class _SubscriptionCard extends StatelessWidget {
  const _SubscriptionCard({
    required this.name,
    required this.amount,
    required this.renews,
  });

  final String name;
  final String amount;
  final String renews;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AppCard(
      color: ObsidianPalette.tertiary.withValues(alpha: 0.08),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.autorenew, size: 18,
                  color: ObsidianPalette.tertiary),
              const SizedBox(width: Spacing.stackSm),
              Expanded(
                child: Text(
                  name,
                  style: text.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                amount,
                style: text.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 26),
            child: Text(
              renews,
              style: text.bodySmall
                  ?.copyWith(color: ObsidianPalette.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: Spacing.stackSm),
          Padding(
            padding: const EdgeInsets.only(left: 18),
            child: Row(
              children: [
                TextButton(onPressed: () {}, child: const Text('EDIT')),
                TextButton(
                  onPressed: () {},
                  style: TextButton.styleFrom(
                    foregroundColor: ObsidianPalette.onSurfaceVariant,
                  ),
                  child: const Text('REMOVE'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
