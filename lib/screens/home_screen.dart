import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import '../app_services.dart';
import '../services/account_service.dart';
import '../services/recurring_service.dart';
import '../theme/obsidian_prime.dart';
import '../ui/app_locale.dart';
import '../ui/async_data.dart';
import '../ui/money_format.dart';
import '../widgets/balance_ring.dart';
import '../widgets/not_yet.dart';
import 'subscription_sheet.dart';
import '../widgets/surfaces.dart';

/// Dashboard.
///
/// Two of its cards — the forecast and the health score — are drawn WITHOUT
/// figures. Both come from the desktop's dashboard/insight services, which
/// this port has not reached; the mockup fills them with numbers, and showing
/// those would be inventing financial advice. They say what they are waiting
/// for instead.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Future<_HomeData>? _data;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _data ??= _load();
  }

  void _reload() {
    setState(() {
      _data = _load();
    });
  }

  Future<_HomeData> _load() async {
    final services = ServicesScope.of(context);
    return _HomeData(
      netWorth: await services.accounts.getNetWorth(),
      subscriptions: await services.recurring.getActiveRecurringPayments(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    // AppShell folds the translucent header and nav bar into this inset.
    final inset = MediaQuery.paddingOf(context);

    return RefreshIndicator(
      onRefresh: () async {
        // A block body, not an arrow: an arrow would hand setState a closure
        // returning a Future, which Flutter asserts on.
        setState(() {
          _data = _load();
        });
      },
      child: ListView(
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

          AsyncData<_HomeData>(
            future: _data!,
            placeholderHeight: 320,
            builder: (context, data) => _HomeBody(data: data),
          ),
          const SizedBox(height: Spacing.sectionGap),

          const _ForecastCard(),
          const SizedBox(height: Spacing.sectionGap),

          const _HealthScoreCard(),
          const SizedBox(height: Spacing.sectionGap),

          Row(
            spacing: Spacing.stackSm,
            children: [
              const Icon(
                Icons.autorenew,
                size: 20,
                color: ObsidianPalette.tertiary,
              ),
              Text(context.l10n.homeActiveSubscriptions, style: text.titleLarge),
            ],
          ),
          const SizedBox(height: Spacing.stackMd),
          AsyncData<_HomeData>(
            future: _data!,
            placeholderHeight: 96,
            builder: (context, data) =>
                _Subscriptions(data.subscriptions, onChanged: _reload),
          ),
        ],
      ),
    );
  }
}

class _HomeData {
  const _HomeData({required this.netWorth, required this.subscriptions});

  final NetWorth netWorth;
  final List<RecurringPayment> subscriptions;
}

class _HomeBody extends StatelessWidget {
  const _HomeBody({required this.data});

  final _HomeData data;

  @override
  Widget build(BuildContext context) {
    final worth = data.netWorth;
    // How much of the ring is filled: cash against everything the user holds,
    // so a debt-free account reads full. With nothing at all it stays empty
    // rather than dividing by zero into a full ring.
    final total = worth.cash + worth.cardDebt;
    final progress = total > Decimal.zero
        ? (worth.cash / total).toDouble().clamp(0.0, 1.0)
        : 0.0;

    return Column(
      children: [
        Center(
          child: BalanceRing(
            amount: formatLira(worth.net),
            // The change over a period needs the dashboard's period queries,
            // which are not ported. An empty label draws no figure rather
            // than a made-up one.
            changeLabel: '',
            changeIsPositive: worth.net >= Decimal.zero,
            periodLabel: context.l10n.homeNetWorth,
            progress: progress,
          ),
        ),
        const SizedBox(height: Spacing.stackLg),
        Row(
          spacing: Spacing.gutter,
          children: [
            Expanded(
              child: _MiniStat(
                label: context.l10n.homeCash,
                value: formatLira(worth.cash),
              ),
            ),
            Expanded(
              child: _MiniStat(
                label: context.l10n.homeCardDebt,
                value: formatLira(worth.cardDebt),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Subscriptions extends StatelessWidget {
  const _Subscriptions(this.payments, {required this.onChanged});

  final List<RecurringPayment> payments;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    if (payments.isEmpty) {
      return NothingYet(message: context.l10n.homeNoSubscriptions);
    }
    return Column(
      children: [
        for (final payment in payments) ...[
          _SubscriptionCard(payment: payment, onChanged: onChanged),
          const SizedBox(height: Spacing.stackMd),
        ],
      ],
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField();

  @override
  Widget build(BuildContext context) {
    return TextField(
      // Disabled: search is not ported. A field that accepts typing and
      // returns nothing is worse than one that plainly cannot be used.
      enabled: false,
      decoration: InputDecoration(
        hintText: context.l10n.homeSearchDisabled,
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
      // Not tappable: there is one wallet and no picker to open. The chevron
      // goes with it — it promises a menu that does not exist.
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: Spacing.stackSm,
        children: [
          const Icon(Icons.account_balance_wallet_outlined, size: 18),
          Text(
            context.l10n.homeMyWallet,
            style: Theme.of(context).textTheme.labelMedium
                ?.copyWith(letterSpacing: 0),
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

/// The forecast card, with its analysis missing rather than invented.
///
/// The mockup fills this with a spending trend, a top category and a
/// month-end projection. Every one of those comes from the desktop's
/// `insights_service` / `projection_service` / `dashboard_period_service`,
/// none of which is ported — so the numbers in the mockup are decoration, and
/// drawing them would be presenting made-up financial advice as analysis.
class _ForecastCard extends StatelessWidget {
  const _ForecastCard();

  @override
  Widget build(BuildContext context) {
    return _PendingInsightCard(
      icon: Icons.trending_up,
      accent: ObsidianPalette.tertiary,
      title: context.l10n.homeForecastTitle,
      message: context.l10n.homeForecastPending,
      showsGradientEdge: true,
    );
  }
}

/// The health-score card, likewise unscored.
///
/// The score is a weighted read of savings rate, debt-to-income and expense
/// volatility — `financial_metrics_service` on the desktop. A number here
/// with nothing behind it would be the most confidently wrong thing on the
/// screen.
class _HealthScoreCard extends StatelessWidget {
  const _HealthScoreCard();

  @override
  Widget build(BuildContext context) {
    return _PendingInsightCard(
      icon: Icons.monitor_heart_outlined,
      accent: ObsidianPalette.primary,
      title: context.l10n.homeHealthScoreTitle,
      message: context.l10n.homeHealthScorePending,
    );
  }
}

/// A card that names what it is waiting for instead of drawing a figure.
class _PendingInsightCard extends StatelessWidget {
  const _PendingInsightCard({
    required this.icon,
    required this.accent,
    required this.title,
    required this.message,
    this.showsGradientEdge = false,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String message;
  final bool showsGradientEdge;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final card = AppCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            spacing: 12,
            children: [
              Icon(icon, size: 20, color: accent),
              Expanded(child: Text(title, style: text.titleLarge)),
              const NotYetChip(),
            ],
          ),
          const SizedBox(height: Spacing.stackMd),
          Text(
            message,
            style: text.bodySmall?.copyWith(
              color: ObsidianPalette.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );

    if (!showsGradientEdge) return card;
    return ClipRRect(
      borderRadius: BorderRadius.circular(Radii.lg),
      child: Stack(
        children: [
          card,
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

class _SubscriptionCard extends StatelessWidget {
  const _SubscriptionCard({required this.payment, required this.onChanged});

  final RecurringPayment payment;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final amount = payment.amount;
    final name = payment.name;

    return AppCard(
      color: ObsidianPalette.tertiary.withValues(alpha: 0.08),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.autorenew,
                size: 18,
                color: ObsidianPalette.tertiary,
              ),
              const SizedBox(width: Spacing.stackSm),
              Expanded(
                child: Text(
                  // A name that will not decrypt is said so, not replaced
                  // with a plausible-looking placeholder.
                  name ?? context.l10n.subscriptionUnreadableName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontStyle: name == null ? FontStyle.italic : null,
                    color: name == null ? ObsidianPalette.error : null,
                  ),
                ),
              ),
              if (amount == null)
                Text(
                  context.l10n.amountUnreadable,
                  style: text.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: ObsidianPalette.error,
                  ),
                )
              else
                Text(
                  formatLira(amount),
                  style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 26),
            child: Text(
              context.l10n.subscriptionNextOn(
                formatStoredDate(payment.nextDueDate),
              ),
              style: text.bodySmall?.copyWith(
                color: ObsidianPalette.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: Spacing.stackSm),
          Padding(
            padding: const EdgeInsets.only(left: 18),
            child: Row(
              children: [
                TextButton(
                  onPressed: () async {
                    final changed = await showSubscriptionSheet(
                      context,
                      payment,
                    );
                    if (changed ?? false) onChanged();
                  },
                  child: Text(context.l10n.subscriptionManage),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
