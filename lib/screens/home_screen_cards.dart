part of 'home_screen.dart';

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

/// The one nudge this app gives, and the reason it needs one.
///
/// There is no account and no server, by decision, so nobody else holds a
/// copy. Onboarding says so in its third card — at the one moment the user
/// has nothing to lose yet — and until this existed nothing said it again.
///
/// Shown only when there is a backup worth making AND none has been made for
/// a month. Both halves matter: a reminder on an empty install is a nag about
/// nothing, and one that appears every week is one a user learns not to read.
/// See `BackupReminder`.
class _BackupNudge extends StatelessWidget {
  const _BackupNudge();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final l10n = context.l10n;
    return AppCard(
      padding: const EdgeInsets.all(20),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const BackupScreen()),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            spacing: 12,
            children: [
              const Icon(
                Icons.cloud_off_outlined,
                size: 20,
                color: ObsidianPalette.tertiary,
              ),
              Expanded(
                child: Text(l10n.backupStaleTitle, style: text.titleMedium),
              ),
            ],
          ),
          const SizedBox(height: Spacing.stackSm),
          Text(
            l10n.backupStaleBody,
            style: text.bodySmall?.copyWith(
              color: ObsidianPalette.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Spacing.stackSm),
          Text(
            l10n.backupStaleAction,
            style: text.labelLarge?.copyWith(color: ObsidianPalette.tertiary),
          ),
        ],
      ),
    );
  }
}
