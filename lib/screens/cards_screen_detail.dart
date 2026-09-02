part of 'cards_screen.dart';

class _CardDetail extends StatefulWidget {
  const _CardDetail({required this.card, required this.onChanged, super.key});

  final Account card;

  /// Called after a control writes, so the summary row and the carousel are
  /// re-read from the same source the switch just changed.
  final VoidCallback onChanged;

  @override
  State<_CardDetail> createState() => _CardDetailState();
}

class _CardDetailState extends State<_CardDetail> {
  /// Set while a switch is being written, so a second tap cannot race the
  /// first — the switch shows the value it is moving to meanwhile.
  bool? _pendingFrozen;
  bool? _pendingOnline;

  Future<void> _setFrozen(bool value) async {
    setState(() => _pendingFrozen = value);
    await ServicesScope.of(context).accounts
        .setCardFrozen(widget.card.id, value);
    if (!mounted) return;
    setState(() => _pendingFrozen = null);
    widget.onChanged();
  }

  Future<void> _setOnlinePayments(bool value) async {
    setState(() => _pendingOnline = value);
    await ServicesScope.of(context).accounts
        .setOnlinePayments(widget.card.id, value);
    if (!mounted) return;
    setState(() => _pendingOnline = null);
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final card = widget.card;
    // A limit of zero means "none recorded", not "none left" — the same rule
    // the spending check applies — so there is no usage bar to draw.
    final usage = card.creditLimit > Decimal.zero
        ? (card.debt / card.creditLimit).toDouble().clamp(0.0, 1.0)
        : 0.0;

    return AppCard(
      padding: const EdgeInsets.all(Spacing.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Expanded, not Flexible-plus-Spacer: two flex children with
              // the same factor split the free space evenly, which squeezed
              // the card's name down to "World Pl…" while blank space sat
              // beside it.
              Expanded(
                child: Text(
                  card.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleLarge,
                ),
              ),
              const SizedBox(width: Spacing.stackSm),
              // The badge is flexible too, and it has to be. With only the
              // name `Expanded`, a large font scale squeezes the name to
              // nothing and the badge STILL overflows — by 0.6 pixels at
              // 2.0x, which is as much a failed layout as 300 would be. Both
              // texts can now give ground, and the name gives it first
              // because it is the one with a flex factor.
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: ObsidianPalette.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(Radii.full),
                  ),
                  child: Text(
                    context.l10n.cardsCreditCardBadge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.labelMedium?.copyWith(
                      fontSize: 10,
                      color: ObsidianPalette.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.more_horiz, size: 20),
            ],
          ),
          const SizedBox(height: Spacing.stackMd),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _Figure(
                  label: context.l10n.cardsAvailableLimit,
                  value: formatLira(card.availableLimit),
                ),
              ),
              Expanded(
                child: _Figure(
                  label: context.l10n.cardsCurrentDebt,
                  value: formatLira(card.debt),
                  color: ObsidianPalette.error,
                  alignEnd: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.stackSm),
          ClipRRect(
            borderRadius: BorderRadius.circular(Radii.full),
            child: LinearProgressIndicator(
              value: usage,
              minHeight: 5,
              backgroundColor: ObsidianPalette.surfaceContainerHigh,
              valueColor: const AlwaysStoppedAnimation(ObsidianPalette.primary),
            ),
          ),
          const SizedBox(height: Spacing.stackLg),

          SectionLabel(context.l10n.cardsControls),
          const SizedBox(height: Spacing.stackSm),
          _ControlRow(
            icon: Icons.public,
            title: context.l10n.cardsOnlineShopping,
            subtitle: context.l10n.cardsOnlineShoppingNote,
            value: _pendingOnline ?? card.onlinePaymentsEnabled,
            onChanged: _setOnlinePayments,
          ),
          _ControlRow(
            icon: Icons.ac_unit,
            title: context.l10n.cardsFreeze,
            subtitle: context.l10n.cardsFreezeNote,
            value: _pendingFrozen ?? card.isFrozen,
            onChanged: _setFrozen,
          ),
          const SizedBox(height: Spacing.stackMd),

          SectionLabel(context.l10n.cardsRecentTransactions),
          const SizedBox(height: Spacing.stackSm),
          _RecentTransactions(accountId: card.id),
          const SizedBox(height: Spacing.stackMd),

          Row(
            spacing: Spacing.stackMd,
            children: [
              // Statement has no screen yet; Pay Debt has
              // AccountService.payCreditCardDebt behind it and no form.
              Expanded(
                child: OutlinedButton(
                  onPressed: null,
                  child: Text(context.l10n.cardsStatement),
                ),
              ),
              Expanded(
                child: OutlinedButton(
                  // Only when there is something to pay: a payment against a
                  // clear card is refused by the service, and offering it
                  // would be inviting the error rather than preventing it.
                  onPressed: card.debt > Decimal.zero
                      ? () async {
                          final paid = await showPayDebtSheet(context, card);
                          if (paid ?? false) widget.onChanged();
                        }
                      : null,
                  child: Text(context.l10n.cardsPayDebt),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({
    required this.label,
    required this.value,
    this.color,
    this.alignEnd = false,
  });

  final String label;
  final String value;
  final Color? color;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: text.labelMedium?.copyWith(
            letterSpacing: 0,
            color: ObsidianPalette.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
          child: Text(
            value,
            maxLines: 1,
            style: text.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

class _ControlRow extends StatelessWidget {
  const _ControlRow({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    // One node, not three. The title lives in a sibling `Text`, so without
    // this the switch is its own tappable node carrying NO label — a screen
    // reader reads the title, then reaches a control it can only call
    // "switch". `MergeSemantics` folds the row into a single toggleable node
    // announced with its title, its subtitle and its state.
    //
    // Two of these failed `labeledTapTargetGuideline` on the Cards tab and
    // nothing had ever run it there; see `test/screens/tab_sweep_test.dart`.
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: text.bodySmall),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: text.labelMedium?.copyWith(
                        letterSpacing: 0,
                        color: ObsidianPalette.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            Switch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}
