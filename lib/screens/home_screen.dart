import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import '../app_services.dart';
import '../app_shell.dart';
import '../services/account_service.dart';
import '../services/backup_reminder.dart';
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
import 'backup_screen.dart';
import 'category_settings_screen.dart';
import 'subscription_sheet.dart';
import '../widgets/surfaces.dart';

part 'home_screen_search.dart';
part 'home_screen_cards.dart';

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

  final _reminder = BackupReminder();

  /// Whether it is time to say something about backing up. Read once per
  /// build of the screen rather than per rebuild, because it touches the
  /// platform store.
  Future<bool>? _backupStale;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _data ??= _load();
    _backupStale ??= _reminder.isStale();
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

          // Two conditions, and the card is drawn only when both hold: there
          // is something to lose, and it has not been copied anywhere for a
          // month. Nothing is reserved for it in the layout — an empty gap
          // where a warning might go is worse than the warning.
          FutureBuilder<bool>(
            future: _backupStale,
            builder: (context, stale) => FutureBuilder<_HomeData>(
              future: _data,
              builder: (context, home) {
                final worth = home.data?.netWorth;
                final hasSomethingToLose =
                    worth != null &&
                    (worth.net != Decimal.zero ||
                        worth.cardDebt != Decimal.zero ||
                        (home.data?.subscriptions.isNotEmpty ?? false));
                if (stale.data != true || !hasSomethingToLose) {
                  return const SizedBox.shrink();
                }
                return const Column(
                  children: [
                    _BackupNudge(),
                    SizedBox(height: Spacing.sectionGap),
                  ],
                );
              },
            ),
          ),

          // Both need the dashboard, insight, projection and metrics services
          // together, which is a project rather than a session. Until then
          // they are not drawn — a card whose entire content is "this does
          // not exist yet", directly under the balance ring, is the first
          // thing a new user sees. See `showUnbuiltFeatures`.
          if (showUnbuiltFeatures) ...[
            const _ForecastCard(),
            const SizedBox(height: Spacing.sectionGap),

            const _HealthScoreCard(),
            const SizedBox(height: Spacing.sectionGap),
          ],

          Row(
            spacing: Spacing.stackSm,
            children: [
              const Icon(
                Icons.autorenew,
                size: 20,
                color: ObsidianPalette.tertiary,
              ),
              // Expanded, because this heading is the longest string on the
              // screen in both languages and `titleLarge` is 22sp: unwrapped
              // it overflows a 360dp phone by 176 pixels. It had done all
              // along and nothing saw it — `ListView` lays out only what is
              // near the viewport, and the two cards that used to sit above
              // this row pushed it past the cache extent, so the layout test
              // walked the screen without this row ever being laid out.
              // Removing those cards is what made it appear.
              Expanded(
                child: Text(
                  context.l10n.homeActiveSubscriptions,
                  style: text.titleLarge,
                ),
              ),
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
