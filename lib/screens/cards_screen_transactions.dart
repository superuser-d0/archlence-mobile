part of 'cards_screen.dart';

/// The last few completed rows on one account.
///
/// Its own loader rather than part of the screen's single read: the statement
/// changes only when the account it belongs to changes, and folding it into
/// the page load would re-decrypt every row each time a switch is flipped.
class _RecentTransactions extends StatefulWidget {
  const _RecentTransactions({required this.accountId});

  final int accountId;

  @override
  State<_RecentTransactions> createState() => _RecentTransactionsState();
}

class _RecentTransactionsState extends State<_RecentTransactions> {
  Future<List<LedgerEntry>>? _entries;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _entries ??= ServicesScope.of(context).transactions
        .getRecentForAccount(widget.accountId);
  }

  @override
  Widget build(BuildContext context) {
    return AsyncData<List<LedgerEntry>>(
      future: _entries!,
      placeholderHeight: 72,
      builder: (context, entries) {
        if (entries.isEmpty) {
          return NothingYet(message: context.l10n.cardsNothingOnCard);
        }
        return Column(
          children: [for (final entry in entries) _TxRow(entry: entry)],
        );
      },
    );
  }
}

class _TxRow extends StatelessWidget {
  const _TxRow({required this.entry});

  final LedgerEntry entry;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    // Income on a card is a payment against the debt, so it reads as a
    // credit; everything else grows what is owed.
    final isCredit = entry.type == 'income' || entry.type == 'payment';
    final amount = entry.amount;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(
            formatStoredDayMonth(entry.date),
            style: text.bodySmall?.copyWith(
              color: ObsidianPalette.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              // The service returns what was stored and invents no fallback,
              // so the category stands in for a description left blank.
              entry.description.isNotEmpty ? entry.description : entry.category,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.bodySmall,
            ),
          ),
          if (amount == null)
            // Never a zero: this row's amount could not be decrypted, and
            // printing 0,00 ₺ would present that as a fact.
            Text(
              context.l10n.amountUnreadable,
              style: text.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
                color: ObsidianPalette.error,
              ),
            )
          else
            Text(
              '${isCredit ? '+' : '-'}${formatLira(amount)}',
              style: text.bodySmall?.copyWith(
                color: isCredit
                    ? ObsidianPalette.tertiary
                    : ObsidianPalette.error,
              ),
            ),
        ],
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({
    required this.name,
    required this.meta,
    required this.balance,
    this.highlighted = false,
  });

  final String name;
  final String meta;
  final String balance;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AppCard(
      color: highlighted
          ? ObsidianPalette.tertiary.withValues(alpha: 0.08)
          : null,
      // No account detail screen yet, so the tile does not offer one.
      child: Row(
        children: [
          if (highlighted) ...[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: ObsidianPalette.tertiary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(Radii.md),
              ),
              child: const Icon(
                Icons.account_balance_wallet_outlined,
                size: 20,
                color: ObsidianPalette.tertiary,
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  meta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.labelMedium?.copyWith(
                    letterSpacing: 0,
                    color: ObsidianPalette.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: Spacing.stackSm),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                balance,
                maxLines: 1,
                style: text.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: highlighted ? ObsidianPalette.tertiary : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
