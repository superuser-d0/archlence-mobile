import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import '../app_services.dart';
import '../app_shell.dart';
import '../services/account_service.dart';
import '../services/dashboard_period.dart';
import '../services/recurring_service.dart';
import '../services/search_service.dart';
import '../services/transaction_service.dart';
import '../theme/obsidian_prime.dart';
import '../ui/app_locale.dart';
import '../ui/async_data.dart';
import '../ui/money_format.dart';
import '../widgets/balance_ring.dart';
import '../widgets/not_yet.dart';
import 'category_settings_screen.dart';
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

/// The window the ring's change chip reports over.
///
/// Fixed rather than chosen, because Home has no period selector — the Assets
/// tab is where periods are picked. A month is the desktop's own middle
/// option and the one a household thinks in; the ring says which window it is
/// so the figure is never a change over an unstated period.
const DashboardPeriod _changePeriod = DashboardPeriod.month;

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
    final netWorth = await services.accounts.getNetWorth();
    return _HomeData(
      netWorth: netWorth,
      // Read in the same pass as the balance it is a change TO. Two loads
      // could answer from either side of a write, and a chip that disagreed
      // with the figure above it is worse than no chip.
      change: await balanceChangeFor(
        services.balanceHistory,
        period: _changePeriod,
        currentBalance: netWorth.net,
      ),
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
          contentInset(context),
          inset.top + Spacing.stackMd,
          contentInset(context),
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
  const _HomeData({
    required this.netWorth,
    required this.change,
    required this.subscriptions,
  });

  final NetWorth netWorth;

  /// How the balance moved over [_changePeriod]. Its [BalanceChange.isKnown]
  /// is false when the ledger cannot answer, and then no chip is drawn.
  final BalanceChange change;

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
            // Empty when the ledger cannot answer — a date before it began,
            // or no events at all. The ring drops the chip entirely then,
            // because an empty green pill with an upward arrow reads as a
            // gain.
            changeLabel: _changeLabel(context, data.change),
            changeIsPositive:
                (data.change.nominal ?? Decimal.zero) >= Decimal.zero,
            periodLabel: data.change.isKnown
                ? context.l10n.homeNetWorthOverMonth
                : context.l10n.homeNetWorth,
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

/// The chip's text: the move in lira, and the percentage when there is one.
///
/// **The percentage is dropped rather than faked.** A balance that was zero a
/// month ago and is 500 now has no finite percentage — the desktop refuses to
/// give one, and so does this. The lira figure is always true, so it carries
/// the chip on its own.
String _changeLabel(BuildContext context, BalanceChange change) {
  final nominal = change.nominal;
  if (nominal == null) return '';
  final percent = change.percent;
  if (percent == null) return formatSignedLira(nominal);
  return '${formatSignedLira(nominal)} · ${formatPercent(percent, signed: true)}';
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

/// The home search box, and the results panel under it.
///
/// **Inline, not a pushed screen or a menu.** The desktop gives its reason —
/// its dropdown grabbed focus and made a second keystroke impossible — and the
/// mobile reason is the same shape: the keyboard is already up, the field
/// already has focus, and taking either away between characters is the one
/// thing a search box must not do.
///
/// **Debounced by [_debounce].** Every keystroke would otherwise decrypt a
/// window of descriptions; the desktop waits 300ms and so does this. A result
/// from a query the user has already typed past is dropped rather than drawn,
/// which is why the query is checked again when the future returns.
class _SearchField extends StatefulWidget {
  const _SearchField();

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

const Duration _debounce = Duration(milliseconds: 300);

/// How many results fit under the field before it stops being a glance.
const int _maxVisibleResults = 5;

class _SearchFieldState extends State<_SearchField> {
  final TextEditingController _controller = TextEditingController();
  Timer? _pending;

  /// The query the visible results belong to, so a late answer to an older
  /// query can be recognised and dropped.
  String _shown = '';
  List<SearchHit>? _results;
  Object? _error;

  @override
  void dispose() {
    _pending?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _pending?.cancel();
    if (value.trim().isEmpty) {
      setState(() {
        _shown = '';
        _results = null;
        _error = null;
      });
      return;
    }
    _pending = Timer(_debounce, () => _run(value));
  }

  Future<void> _run(String query) async {
    final services = ServicesScope.of(context);
    try {
      final hits = await services.search.search(query);
      if (!mounted || _controller.text != query) return;
      setState(() {
        _shown = query;
        _results = hits;
        _error = null;
      });
    } on Object catch (error) {
      if (!mounted || _controller.text != query) return;
      // A missing key reaches here. Drawing "no results" would say the
      // profile is empty when it is unreadable — the one answer this app
      // never gives.
      setState(() {
        _shown = query;
        _results = null;
        _error = error;
      });
    }
  }

  void _clear() {
    _pending?.cancel();
    _controller.clear();
    setState(() {
      _shown = '';
      _results = null;
      _error = null;
    });
  }

  void _open(SearchHit hit) {
    final shell = AppShellScope.maybeOf(context);
    FocusScope.of(context).unfocus();
    switch (hit.kind) {
      // Where the thing LIVES, which is what the desktop does too. An account
      // and the transactions against it are both on Cards.
      case SearchKind.account:
      case SearchKind.transaction:
        shell?.selectTab(ShellTab.cards);
      case SearchKind.category:
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const CategorySettingsScreen(),
          ),
        );
    }
    _clear();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _field(context),
        if (_error != null) ...[
          const SizedBox(height: Spacing.stackSm),
          DataUnavailable(error: _error!),
        ] else if (_results != null) ...[
          const SizedBox(height: Spacing.stackSm),
          _SearchResults(
            query: _shown,
            hits: _results!,
            onOpen: _open,
          ),
        ],
      ],
    );
  }

  Widget _field(BuildContext context) {
    return TextField(
      controller: _controller,
      onChanged: _onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: context.l10n.homeSearchHint,
        suffixIcon: _controller.text.isEmpty
            ? null
            : IconButton(
                onPressed: _clear,
                icon: const Icon(Icons.close, size: 18),
                tooltip: context.l10n.homeSearchClear,
              ),
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

/// What the search found, or that it found nothing.
///
/// The "nothing" case says WHERE it looked. Search here covers account names,
/// category names and the descriptions of recent transactions, and a user who
/// does not know that reads an empty panel as "I never recorded it" — which
/// may be false, because an older description is outside the window the
/// service opens.
class _SearchResults extends StatelessWidget {
  const _SearchResults({
    required this.query,
    required this.hits,
    required this.onOpen,
  });

  final String query;
  final List<SearchHit> hits;
  final void Function(SearchHit) onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;

    if (hits.isEmpty) {
      return AppCard(
        padding: const EdgeInsets.all(Spacing.gutter),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.homeSearchNoResults, style: text.bodyMedium),
            const SizedBox(height: 2),
            Text(
              l10n.homeSearchScope,
              style: text.bodySmall?.copyWith(
                color: ObsidianPalette.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    final visible = hits.take(_maxVisibleResults).toList();
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          for (final hit in visible)
            _SearchResultRow(hit: hit, onTap: () => onOpen(hit)),
          if (hits.length > visible.length)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Spacing.gutter,
                4,
                Spacing.gutter,
                8,
              ),
              child: Text(
                l10n.homeSearchMore(hits.length - visible.length),
                style: text.bodySmall?.copyWith(
                  color: ObsidianPalette.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SearchResultRow extends StatelessWidget {
  const _SearchResultRow({required this.hit, required this.onTap});

  final SearchHit hit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final (icon, label) = switch (hit.kind) {
      SearchKind.account => (
        Icons.account_balance_wallet_outlined,
        l10n.searchKindAccount,
      ),
      SearchKind.category => (Icons.sell_outlined, l10n.searchKindCategory),
      SearchKind.transaction => (
        Icons.receipt_long_outlined,
        l10n.searchKindTransaction,
      ),
    };

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.gutter,
            vertical: 10,
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: ObsidianPalette.onSurfaceVariant),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hit.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodyMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      // The date earns its place on a transaction: two
                      // descriptions can read the same and only the date says
                      // which one this is.
                      hit.date == null
                          ? label
                          : '$label · ${formatStoredDate(hit.date)}',
                      style: text.bodySmall?.copyWith(
                        color: ObsidianPalette.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
